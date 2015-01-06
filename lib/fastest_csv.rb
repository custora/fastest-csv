# This loads either csv_parser.so, csv_parser.bundle or
# csv_parser.jar, depending on your Ruby platform and OS
require 'csv_parser'
require 'stringio'

# Fast CSV parser using native code
class FastestCSV

  DEFAULT_WRITE_BUFFER_LINES = 250_000
  UTF_8_STRING = "UTF-8"
  BINARY_STRING = "binary"
  SINGLE_SPACE = ' '

  # See grammar.md; these are default values

  FIELDSEP = ","
  FIELDENCL = "\""
  LINEBREAK = "\n"

  #if RUBY_PLATFORM =~ /java/
  #  require 'jruby'
  #  org.brightcode.CsvParserService.new.basicLoad(JRuby.runtime)
  #end

  def self.version
    VERSION
  end

  # Pass each line of the specified +path+ as array to the provided +block+
  def self.foreach(path, _opts={}, &block)
    open(path, "rb:UTF-8", _opts) do |reader|
      reader.each(&block)
    end
  end

  # Opens a csv file. Pass a FastestCSV instance to the provided block,
  # or return it when no block is provided
  def self.open(path, mode = "rb:UTF-8", _opts = {})
    csv = new(File.open(path, mode), _opts)
    if block_given?
      begin
        yield csv
      ensure
        csv.close
      end
    else
      csv
    end
  end

  # Read all lines from the specified +path+ into an array of arrays
  def self.read(path)
    open(path, "rb:UTF-8") { |csv| csv.read }
  end

  # Alias for FastestCSV.read
  def self.readlines(path)
    read(path)
  end

  # Read all lines from the specified String into an array of arrays
  def self.parse(data, _opts = {}, &block)
    csv = new(StringIO.new(data), _opts)
    if block.nil?
      begin
        csv.read
      ensure
        csv.close
      end
    else
      csv.each(&block)
    end
  end

  def self.parse_line(line, _fieldsep = FIELDSEP, _fieldencl = FIELDENCL)
    if !((_fieldsep.is_a? String) && _fieldsep.length == 1)
      raise "separator character must be a string of length 1"
    end
    if !((_fieldencl.is_a? String) && _fieldencl.length == 1)
      raise "encloser character must be a string of length 1"
    end
    if (_fieldsep == _fieldencl)
      raise "separator and encloser characters cannot be the same"
    end
    CsvParser.parse_line(line, _fieldsep, _fieldencl)
  end

  def self.generate_line(data, _fieldsep = FIELDSEP, _fieldencl = FIELDENCL, _force_quote = false)
    if !((_fieldsep.is_a? String) && _fieldsep.length == 1)
      raise "separator character must be a string of length 1"
    end
    if !((_fieldencl.is_a? String) && _fieldencl.length == 1)
      raise "encloser character must be a string of length 1"
    end
    if (_fieldsep == _fieldencl)
      raise "separator and encloser characters cannot be the same"
    end
    CsvParser.generate_line(data.map{|x| x.nil? ? x : x.to_s}, _fieldsep, _fieldencl, !!_force_quote)
  end

  # Create new FastestCSV wrapping the specified IO object
  def initialize(io, _opts = {})

    opts = {
      write_buffer_lines: DEFAULT_WRITE_BUFFER_LINES,
      force_utf8: false
    }.merge(_opts)

    @@separator = opts[:col_sep] || FIELDSEP
    @@quote_character = opts[:quote_character] || FIELDENCL
    @@write_buffer_lines = opts[:write_buffer_lines]
    @@linebreak = opts[:line_break] || "\n"
    @@encode = opts[:force_utf8]

    @io = io
    @current_buffer_count = 0
    @current_write_buffer = ""

  end

  # Read from the wrapped IO passing each line as array to the specified block
  def each
    while row = shift
      yield row
    end
  end

  # Read all remaining lines from the wrapped IO into an array of arrays
  def read
    table = Array.new
    each {|row| table << row}
    table
  end
  alias_method :readlines, :read

  # Read next line from the wrapped IO and return as array or nil at EOF
  def shift
    if line = @io.gets(@@linebreak)
      begin
        quote_count = line.count(@@quote_character)
      rescue ArgumentError
        line.encode!(UTF_8_STRING, BINARY_STRING, invalid: :replace, undef: :replace, replace: SINGLE_SPACE)
        quote_count = line.count(@@quote_character)
      end
      if(quote_count % 2 == 0)
        CsvParser.parse_line(line, @@separator, @@quote_character)
      else
        while(quote_count % 2 != 0)
          break unless new_line = @io.gets(@@linebreak)
          line << new_line
          begin
            quote_count = line.count(@@quote_character)
          rescue ArgumentError
            line.encode!(UTF_8_STRING, BINARY_STRING, invalid: :replace, undef: :replace, replace: SINGLE_SPACE)
            quote_count = line.count(@@quote_character)
          end
        end
        CsvParser.parse_line(line, @@separator, @@quote_character)
      end
    else
      nil
    end
  end
  alias_method :gets,     :shift
  alias_method :readline, :shift

  def <<(_array)
    @current_buffer_count += 1
    # Below call to generate_line does NOT use @@separator or @@quote_character
    # but only to ensure compatibility with old versions of the code. It seems 
    # like a good idea to change this at some point.
    @current_write_buffer << FastestCSV.generate_line(_array, FIELDSEP, '"') + "\n"
    if(@current_buffer_count == @@write_buffer_lines)
      flush(false)
    end
  end

  def flush(force_flush = true)
    # TODO: could probably use write_nonblock to eek out a bit more performance
    @io.write(@current_write_buffer)
    # io object maintains it's own buffer, so to ensure
    # data gets written to the disk immediately need to call flush explicitly
    @io.flush if force_flush
    @current_write_buffer = ""
    @current_buffer_count = 0
  end

  # Close the wrapped IO
  def close
    @io.write(@current_write_buffer) unless @current_write_buffer == ""
    @io.close
  end

  def closed?
    @io.closed?
  end

end
