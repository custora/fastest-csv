
require 'csv_parser'
require 'stringio'

# Fast CSV parser using native code
class FastestCSV

  DEFAULT_WRITE_BUFFER_LINES = 250_000
  SINGLE_SPACE = ' '

  # See grammar.md; these are default values

  DEFAULT_FIELDSEP = ","
  DEFAULT_FIELDQUOTE = "\""
  DEFAULT_LINEBREAK = "\n"

  def self.version
    VERSION
  end

  def self.assert_valid_grammar(fieldsep, fieldquote, linebreak, grammar)
    if !((fieldsep.is_a? String) && fieldsep.length == 1)
      raise "separator character must be a string of length 1"
    end
    if !(fieldquote.nil? || ((fieldquote.is_a? String) && fieldquote.length == 1))
      raise "quote character must be a string of length 1 (or nil, but only if we are parsing-only)"
    end
    if !(["\r", "\n", "\r\n"].include? linebreak)
      raise "linebreak must be CR, LF, or CR LF"
    end
    if fieldsep == fieldquote
      raise "separator and quote characters cannot be the same"
    end
    if !(['strict', 'relaxed', 'c_escaped', 'c_escaped_relaxed'].include? grammar)
      raise "grammar must be 'strict', 'relaxed', or 'c_escaped'"
    end
    if ['c_escaped', 'c_escaped_relaxed'].include?(grammar) && fieldquote != DEFAULT_FIELDQUOTE
      raise "C-escaped grammar must use default field quote #{DEFAULT_FIELDQUOTE}"
    end
    true
  end

  # Pass each line of the specified +path+ as array to the provided +block+
  def self.foreach(path, _opts = {}, &block)
    open(path, "r:bom|utf-8", _opts) do |reader|
      reader.each(&block)
    end
  end

  def self.foreach_raw_line(path, _opts = {}, &block)
    open(path, "r:bom|utf-8", _opts) do |reader|
      reader.each_raw_line(&block)
    end
  end

  # Opens a csv file. Pass a FastestCSV instance to the provided block,
  # or return it when no block is provided.
  # Note that if you want to pass options, you'll have to pass a mode too,
  # otherwise the opts will be assigned to mode. Maybe move to named args in a
  # later version.

  # rb:bom will ignore the first character if it's an invisible Byte order mark
  def self.open(path, mode = "rb:bom|utf-8", _opts = {})
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
  def self.read(path, _opts = {})
    open(path, "r:bom|utf-8", _opts, &:read)
  end

  # Alias for FastestCSV.read
  def self.readlines(path, _opts = {})
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
      grammar:    'relaxed',
    }.merge(_opts)
    assert_valid_grammar(_opts[:col_sep], _opts[:quote_char], _opts[:row_sep], _opts[:grammar])
    _opts[:grammar] =
      case _opts[:grammar]
      when 'strict'
        0
      when 'relaxed'
        1
      when 'c_escaped'
        2
      when 'c_escaped_relaxed'
        3
      else
        raise "grammar must be 'strict', 'relaxed', 'c_escaped', or 'c_escaped_relaxed'"
      end
    output = CsvParser.parse_line(
      line,
      _opts[:col_sep],
      _opts[:quote_char],
      _opts[:row_sep],
      _opts[:grammar],
      0,
    )
    if [0, 2].include?(_opts[:grammar]) && !output[1]
      raise "Incomplete CSV line under strict grammar: #{line}"
    end
    output[0]
  end

  def self.generate_line(data, _opts = {})
    _opts = {
      col_sep:      DEFAULT_FIELDSEP,
      row_sep:      DEFAULT_LINEBREAK,
      quote_char:   DEFAULT_FIELDQUOTE,
      grammar:      'relaxed',
      force_quotes: false,
    }.merge(_opts)
    assert_valid_grammar(_opts[:col_sep], _opts[:quote_char], _opts[:row_sep], _opts[:grammar])
    CsvParser.generate_line(
      data,
      _opts[:col_sep],
      _opts[:quote_char],
      _opts[:row_sep],
      _opts[:force_quotes],
    )
  end

  # Create new FastestCSV wrapping the specified IO object
  def initialize(io, _opts = {})
    # for << we will try these encodings in sequence if the string
    # produced by generate_line is not valid UTF-8 (default, try ISO-8859-1)

    _opts = {
      col_sep:      DEFAULT_FIELDSEP,
      row_sep:      DEFAULT_LINEBREAK,
      quote_char:   DEFAULT_FIELDQUOTE,
      grammar:      'relaxed',
      force_quotes: false,
      force_utf8:   false,
      write_buffer_lines: DEFAULT_WRITE_BUFFER_LINES,
      check_field_count:  false,
      field_count:        nil,
      non_utf8_encodings: ["ISO-8859-1"],
    }.merge(_opts)

    self.class.assert_valid_grammar(_opts[:col_sep], _opts[:quote_char], _opts[:row_sep], _opts[:grammar])
    _opts[:grammar] =
      case _opts[:grammar]
      when 'strict'
        0
      when 'relaxed'
        1
      when 'c_escaped'
        2
      when 'c_escaped_relaxed'
        3
      else
        raise "grammar must be 'strict', 'relaxed', 'c_escaped', or 'c_escaped_relaxed'"
      end

    @opts = _opts
    _opts.each do |k, v|
      instance_variable_set(:"@#{k}", v)
      self.class.send(:attr_reader, k) if !self.respond_to?(k)
    end

    @io = io
    @current_buffer_count = 0
    @current_write_buffer = ""
    @field_count = @opts[:field_count]
  end

  # Read from the wrapped IO passing each line as array to the specified block
  def each
    row_sep = @opts[:row_sep]
    check_field_count = @opts[:check_field_count]
    col_sep = @opts[:col_sep]
    quote_char = @opts[:quote_char]
    grammar = @opts[:grammar]

    shift(row_sep, check_field_count, col_sep, quote_char, grammar) if @opts[:skip_header]

    row = shift(row_sep, check_field_count, col_sep, quote_char, grammar)
    while row
      yield row
      row = shift(row_sep, check_field_count, col_sep, quote_char, grammar)
    end
  end

  def each_raw_line
    shift_raw_line if @opts[:skip_header]

    row = shift_raw_line
    while row
      yield row
      row = shift_raw_line
    end
  end

  # Read all remaining lines from the wrapped IO into an array of arrays
  def read
    table = []
    each { |row| table << row }
    table
  end
  alias_method :readlines, :read

  # Read next line from the wrapped IO and return as array or nil at EOF.
  # Gets read in as UTF-8, it's up to you right now to correct this if this is
  # incorrect.

  def shift(row_sep = @opts[:row_sep], check_field_count = @opts[:check_field_count], col_sep = @opts[:col_sep],
            quote_char = @opts[:quote_char], grammar = @opts[:grammar])
    line = @io.gets(row_sep)
    if line
      parsed_line, complete_line = CsvParser.parse_line(line, col_sep, quote_char, row_sep, grammar, 0)
      while !complete_line && (line = @io.gets(row_sep))
        parsed_partial_line, complete_line = CsvParser.parse_line(line, col_sep, quote_char, row_sep, grammar, 1)
        parsed_line[parsed_line.length - 1] << parsed_partial_line.shift
        parsed_line.concat(parsed_partial_line)
      end
      if check_field_count && @field_count.nil?
        @field_count = parsed_line.length
      elsif check_field_count && @field_count != parsed_line.length
        raise "Default field count is #{@field_count}, but the following line parsed into #{parsed_line.length} entries: \n#{line}"
      end
      parsed_line
    end
  end

  def shift_raw_line
    line = @io.gets(row_sep)
    if line
      complete_line = CsvParser.parse_line(line, col_sep, quote_char, row_sep, grammar, 0)[1]

      while !complete_line && (next_line = @io.gets(row_sep))
        line += next_line
        complete_line = CsvParser.parse_line(line, col_sep, quote_char, row_sep, grammar, 1)[1]
      end

      line
    end
  end

  alias_method :gets,     :shift
  alias_method :readline, :shift

  # Write array to the wrapped IO. Will try to write as UTF-8, but if it is not
  # validly encoded, will cycle through non_utf8_encodings until it gets a
  # valid encoding, then will force_encode and reencode to UTF-8

  def <<(_array)
    @current_buffer_count += 1
    line = CsvParser.generate_line(_array, col_sep, quote_char, row_sep, force_quotes) # should be UTF-8
    encoding_i = 0
    until line.valid_encoding?
      # try encodings in sequence until one works, or raise exception if none work
      if encoding_i >= non_utf8_encodings.length
        raise "Unable to encode following non-UTF-8 string to UTF-8 using any of #{non_utf8_encodings}:\n#{line}"
      end
      line = line.force_encoding(non_utf8_encodings[encoding_i]).encode("UTF-8")
      encoding_i += 1
    end
    @current_write_buffer << line
    if @current_buffer_count == write_buffer_lines
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
