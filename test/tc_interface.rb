# Tests adapted from faster_csv:
# https://github.com/JEG2/faster_csv/blob/master/test/tc_csv_parsing.rb
# See LICENSE file for full license details.

require 'minitest/autorun'
require 'fastest_csv'

class TestFastestCSVInterface < Minitest::Test

  def setup

    base_dir = File.join(File.dirname(__FILE__))

    @path_basic = File.join(base_dir, "temp_test_data_basic.csv")
    File.open(@path_basic, "w") do |file|
      file << "1,2,3\n"
      file << "4,5\n"
    end

    @path_crlf = File.join(base_dir, "temp_test_data_crlf.csv")
    File.open(@path_crlf, "w") do |file|
      file << "1,2,3\r\n"
      file << "4,5\r\n"
    end

    @path_cr = File.join(base_dir, "temp_test_data_cr.csv")
    File.open(@path_cr, "w") do |file|
      file << "1,2,3\r"
      file << "4,5\r"
    end

    @expected = [%w{1 2 3}, %w{4 5}]

  end

  def teardown
    File.unlink(@path_basic)
    File.unlink(@path_crlf)
    File.unlink(@path_cr)
  end

  ### Test Read Interface ###

  def test_foreach

    expected = Array.new(@expected)
    FastestCSV.foreach(@path_basic) do |row|
      assert_equal(expected.shift, row)
    end

    expected = Array.new(@expected)
    FastestCSV.foreach(@path_crlf, row_sep: "\r\n") do |row|
      assert_equal(expected.shift, row)
    end

    expected = Array.new(@expected)
    FastestCSV.foreach(@path_cr, row_sep: "\r") do |row|
      assert_equal(expected.shift, row)
    end

  end

  def test_open_and_close

    csv = FastestCSV.open(@path_basic, "r+")
    refute_nil(csv)
    assert_instance_of(FastestCSV, csv)
    assert_equal(false, csv.closed?)
    csv.close
    assert(csv.closed?)

    ret = FastestCSV.open(@path_basic) do |csv|
      assert_instance_of(FastestCSV, csv)
      "Return value."
    end
    assert(csv.closed?)
    assert_equal("Return value.", ret)

  end

  def test_parse

    expected = Array.new(@expected)
    data = File.read(@path_basic)
    assert_equal( @expected,
                  FastestCSV.parse(data) )

    FastestCSV.parse(data) do |row|
      assert_equal(expected.shift, row)
    end

    expected = Array.new(@expected)
    data = File.read(@path_crlf, row_sep: "\r\n")
    assert_equal( @expected,
                  FastestCSV.parse(data, row_sep: "\r\n") )

    FastestCSV.parse(data, row_sep: "\r\n") do |row|
      assert_equal(expected.shift, row)
    end

    expected = Array.new(@expected)
    data = File.read(@path_cr, row_sep: "\r")
    assert_equal( @expected,
                  FastestCSV.parse(data, row_sep: "\r") )

    FastestCSV.parse(data, row_sep: "\r") do |row|
      assert_equal(expected.shift, row)
    end

  end

  def test_parse_line_with_empty_lines
    assert_equal(nil,       FastestCSV.parse_line(""))  # to signal eof
    #assert_equal(Array.new, FastestCSV.parse_line("\n1,2,3"))
    assert_equal([nil], FastestCSV.parse_line("\n1,2,3"))
  end


  def test_read_and_readlines

    assert_equal( @expected,
                  FastestCSV.read(@path_basic) )
    assert_equal( @expected,
                  FastestCSV.readlines(@path_basic))
    assert_equal( @expected,
                  FastestCSV.read(@path_crlf, row_sep: "\r\n") )
    assert_equal( @expected,
                  FastestCSV.readlines(@path_crlf, row_sep: "\r\n"))
    assert_equal( @expected,
                  FastestCSV.read(@path_cr, row_sep: "\r") )
    assert_equal( @expected,
                  FastestCSV.readlines(@path_cr, row_sep: "\r"))

    data = FastestCSV.read(@path_basic)
    assert_equal(@expected, data)
    data = FastestCSV.readlines(@path_basic)
    assert_equal(@expected, data)

    data = FastestCSV.read(@path_crlf, row_sep: "\r\n")
    assert_equal(@expected, data)
    data = FastestCSV.readlines(@path_crlf, row_sep: "\r\n")
    assert_equal(@expected, data)

    data = FastestCSV.read(@path_cr, row_sep: "\r")
    assert_equal(@expected, data)
    data = FastestCSV.readlines(@path_cr, row_sep: "\r")
    assert_equal(@expected, data)

  end

  def test_shift

    expected = Array.new(@expected)
    FastestCSV.open(@path_basic, "r+") do |csv|
      assert_equal(expected.shift, csv.shift)
      assert_equal(expected.shift, csv.shift)
      assert_equal(nil, csv.shift)
    end

    expected = Array.new(@expected)
    FastestCSV.open(@path_crlf, "r+", row_sep: "\r\n") do |csv|
      assert_equal(expected.shift, csv.shift)
      assert_equal(expected.shift, csv.shift)
      assert_equal(nil, csv.shift)
    end

    expected = Array.new(@expected)
    FastestCSV.open(@path_cr, "r+", row_sep: "\r") do |csv|
      assert_equal(expected.shift, csv.shift)
      assert_equal(expected.shift, csv.shift)
      assert_equal(nil, csv.shift)
    end

  end

  def test_long_line

    long_field_length = 2800

    File.unlink(@path_basic)
    File.open(@path_basic, "w") do |file|
      file << "1,2,#{'3' * long_field_length}\n"
    end

    File.unlink(@path_crlf)
    File.open(@path_crlf, "w") do |file|
      file << "1,2,#{'3' * long_field_length}\r\n"
    end

    File.unlink(@path_cr)
    File.open(@path_cr, "w") do |file|
      file << "1,2,#{'3' * long_field_length}\r"
    end

    @expected = [%w{1 2} + ['3' * long_field_length]]
    test_shift

  end

end
