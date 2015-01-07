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

  DEFAULT_FIELDSEP = ","
  DEFAULT_FIELDQUOTE = "\""
  DEFAULT_LINEBREAK = "\n"

  #if RUBY_PLATFORM =~ /java/
  #  require 'jruby'
  #  org.brightcode.CsvParserService.new.basicLoad(JRuby.runtime)
  #end

  def self.version
    VERSION
  end

  def self.assert_valid_grammar(_fieldsep, _fieldquote, _linebreak)
    if !((_fieldsep.is_a? String) && _fieldsep.length == 1)
      raise "separator character must be a string of length 1"
    end
    if !((_fieldquote.is_a? String) && _fieldquote.length == 1)
      raise "quote character must be a string of length 1"
    end
    if !(["\r", "\n", "\r\n"].include? _linebreak)
      raise "linebreak must be CR, LF, or CR LF"
    end
    if (_fieldsep == _fieldquote)
      raise "separator and quote characters cannot be the same"
    end
    true
  end

  # Pass each line of the specified +path+ as array to the provided +block+
  def self.foreach(path, _opts={}, &block)
    open(path, "rb:UTF-8", _opts) do |reader|
      reader.each(&block)
    end
  end

  # Opens a csv file. Pass a FastestCSV instance to the provided block,
  # or return it when no block is provided.
  # Note that if you want to pass options, you'll have to pass a mode too,
  # otherwise the opts will be assigned to mode. Maybe move to named args in a
  # later version.
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
  def self.read(path, _opts={})
    open(path, "rb:UTF-8", _opts) { |csv| csv.read }
  end

  # Alias for FastestCSV.read
  def self.readlines(path, _opts={})
    read(path, _opts)
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

  def self.parse_line(line, _opts = {})
    _opts = {
      col_sep:    DEFAULT_FIELDSEP,
      row_sep:    DEFAULT_LINEBREAK,
      quote_char: DEFAULT_FIELDQUOTE,
    }.merge(_opts)
    assert_valid_grammar(_opts[:col_sep], _opts[:quote_char], _opts[:row_sep])
    self.parse_line_no_check(line, _opts)
  end

  def self.parse_line_no_check(line, _opts)
    CsvParser.parse_line(line,
                         _opts[:col_sep],
                         _opts[:quote_char],
                         _opts[:row_sep])
  end

  def self.generate_line(data, _opts = {})
    _opts = {
      col_sep:    DEFAULT_FIELDSEP,
      row_sep:    DEFAULT_LINEBREAK,
      quote_char: DEFAULT_FIELDQUOTE,
      force_quotes: false,
    }.merge(_opts)
    assert_valid_grammar(_opts[:col_sep], _opts[:quote_char], _opts[:row_sep])
    self.generate_line_no_check(data, _opts)
  end

  def self.generate_line_no_check(data, _opts)
    CsvParser.generate_line(data.map{|x| x.nil? ? x : x.to_s},
                            _opts[:col_sep],
                            _opts[:quote_char],
                            _opts[:row_sep],
                            !!_opts[:force_quotes]) + _opts[:row_sep]
  end

  # Create new FastestCSV wrapping the specified IO object
  def initialize(io, _opts = {})

    _opts = {
      col_sep:    DEFAULT_FIELDSEP,
      row_sep:    DEFAULT_LINEBREAK,
      quote_char: DEFAULT_FIELDQUOTE,
      force_quotes: false,
      force_utf8:   false,
      write_buffer_lines: DEFAULT_WRITE_BUFFER_LINES,
    }.merge(_opts)

    self.class.assert_valid_grammar(_opts[:col_sep], _opts[:quote_char], _opts[:row_sep])
    @opts = _opts

    @io = io
    @current_buffer_count = 0
    @current_write_buffer = ""

  end

  def col_sep; @opts[:col_sep]; end
  def row_sep; @opts[:row_sep]; end
  def quote_char; @opts[:quote_char]; end
  def force_quotes; @opts[:force_quotes]; end
  def force_utf8; @opts[:force_utf8]; end
  def write_buffer_lines; @opts[:write_buffer_lines]; end

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
    if line = @io.gets(@opts[:row_sep])
      begin
        quote_count = line.count(@opts[:quote_char])
      rescue ArgumentError
        line.encode!(UTF_8_STRING, BINARY_STRING, invalid: :replace, undef: :replace, replace: SINGLE_SPACE)
        quote_count = line.count(@opts[:quote_char])
      end
      if(quote_count % 2 == 0)
        self.class.parse_line_no_check(line, @opts)
      else
        while(quote_count % 2 != 0)
          break unless new_line = @io.gets(@opts[:row_sep])
          line << new_line
          begin
            quote_count = line.count(@opts[:quote_char])
          rescue ArgumentError
            line.encode!(UTF_8_STRING, BINARY_STRING, invalid: :replace, undef: :replace, replace: SINGLE_SPACE)
            quote_count = line.count(@opts[:quote_char])
          end
        end
        self.class.parse_line_no_check(line, @opts)
      end
    else
      nil
    end
  end
  alias_method :gets,     :shift
  alias_method :readline, :shift

  def <<(_array)
    @current_buffer_count += 1
    @current_write_buffer << FastestCSV.generate_line_no_check(_array, @opts)
    if(@current_buffer_count == @opts[:write_buffer_lines])
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
