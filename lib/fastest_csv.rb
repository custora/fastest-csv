# This loads either csv_parser.so, csv_parser.bundle or
# csv_parser.jar, depending on your Ruby platform and OS
require 'csv_parser'
require 'stringio'

# Fast CSV parser using native code
class FastestCSV
  DEFAULT_WRITE_BUFFER_LINES = 250_000

  def self.version
    VERSION
  end
  
  #if RUBY_PLATFORM =~ /java/
  #  require 'jruby'
  #  org.brightcode.CsvParserService.new.basicLoad(JRuby.runtime)
  #end

  # Pass each line of the specified +path+ as array to the provided +block+
  def self.foreach(path, opts, &block)
    open(path, "rb", opts) do |reader|
      reader.each(&block)
    end
  end

  # Opens a csv file. Pass a FastestCSV instance to the provided block,
  # or return it when no block is provided
  def self.open(path, mode = "rb", _opts = {})
    opts = {col_sep: ",", write_buffer_lines: DEFAULT_WRITE_BUFFER_LINES}.merge(_opts)
    @@separator = opts[:col_sep]
    @@write_buffer_lines = opts[:write_buffer_lines]
    csv = new(File.open(path, mode))
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
    open(path, "rb") { |csv| csv.read }
  end

  # Alias for FastestCSV.read
  def self.readlines(path)
    read(path)
  end

  # Read all lines from the specified String into an array of arrays
  def self.parse(data, &block)
    csv = new(StringIO.new(data))
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
  
  def self.parse_line(line, _sep)
    CsvParser.parse_line(line, @@separator)
  end

  # Create new FastestCSV wrapping the specified IO object
  def initialize(io)
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
    if line = @io.gets
      quote_count = line.count("\"")
      if(quote_count % 2 == 0)
        CsvParser.parse_line(line, @@separator)
      else
        while(quote_count % 2 != 0)
          break unless new_line = @io.gets
          line << new_line
          quote_count = line.count("\"")
        end
        CsvParser.parse_line(line, @@separator)
      end
    else
      nil
    end
  end
  alias_method :gets,     :shift
  alias_method :readline, :shift

  def <<(_array)
    @current_buffer_count += 1
    @current_write_buffer << to_csv(_array)
    if(@current_buffer_count == @@write_buffer_lines)
      # TODO: would write_nonblock help?
      @io.write(@current_write_buffer)
      @current_write_buffer = ""
      @current_buffer_count = 0
    end
  end
  def to_csv(_array)
    "#{_array.map{|x| x ? "\"#{x.to_s.gsub("\"", "\"\"")}\"" : ""}.join(@@separator)}\n"
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

class String
  # Equivalent to <tt>FasterCSV::parse_line(self)</tt>
  def parse_csv
    CsvParser.parse_line(self, @@separator)
  end
end

