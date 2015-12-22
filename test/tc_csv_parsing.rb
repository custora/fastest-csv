# Tests adapted from faster_csv:
# https://github.com/JEG2/faster_csv/blob/master/test/tc_csv_parsing.rb
# See LICENSE file for full license details.

require 'minitest/autorun'
require 'fastest_csv'
require 'csv'

class TestCSVParsing < Minitest::Test

  def test_basic
    case_basic = [
      %(Ten Thousand,10000, 2710 ,,"10,000","It's ""10 Grand"", baby",10K\n),
      [ "Ten Thousand", "10000", " 2710 ", nil, "10,000", "It's \"10 Grand\", baby", "10K" ],
    ]
    case_sep = [
      %(Ten Thousand;10000; 2710 ;;"10,000";"It's ""10 Grand"", baby";10K\n),
      [ "Ten Thousand", "10000", " 2710 ", nil, "10,000", "It's \"10 Grand\", baby", "10K" ],
    ]
    case_quote = [
      %(Ten Thousand,10000, 2710 ,,'10,000','It''s "10 Grand", baby',10K\n),
      [ "Ten Thousand", "10000", " 2710 ", nil, "10,000", "It's \"10 Grand\", baby", "10K" ],
    ]
    case_linebreak1 = [
      %(Ten Thousand,10000, 2710 ,,"10,000","It's ""10 Grand"", baby",10K\r\n),
      [ "Ten Thousand", "10000", " 2710 ", nil, "10,000", "It's \"10 Grand\", baby", "10K" ],
    ]
    case_linebreak2 = [
      %(Ten Thousand,10000, 2710 ,,"10,000","It's ""10 Grand"", baby",10K\r),
      [ "Ten Thousand", "10000", " 2710 ", nil, "10,000", "It's \"10 Grand\", baby", "10K" ],
    ]

    assert_equal(case_basic.last,
                 FastestCSV.parse_line(case_basic.first))
    assert_equal(case_sep.last,
                 FastestCSV.parse_line(case_sep.first, col_sep: ";"))
    assert_equal(case_quote.last,
                 FastestCSV.parse_line(case_quote.first, quote_char: "'"))
    assert_equal(case_linebreak1.last,
                 FastestCSV.parse_line(case_linebreak1.first, row_sep: "\r\n"))
    assert_equal(case_linebreak2.last,
                 FastestCSV.parse_line(case_linebreak1.first, row_sep: "\r"))

    assert_equal(CSV.parse_line(case_basic.first),
                 FastestCSV.parse_line(case_basic.first))
    assert_equal(CSV.parse_line(case_sep.first, col_sep: ";"),
                 FastestCSV.parse_line(case_sep.first, col_sep: ";"))
    assert_equal(CSV.parse_line(case_quote.first, quote_char: "'"),
                 FastestCSV.parse_line(case_quote.first, quote_char: "'"))
    assert_equal(CSV.parse_line(case_linebreak1.first, row_sep: "\r\n"),
                 FastestCSV.parse_line(case_linebreak1.first, row_sep: "\r\n"))
    assert_equal(CSV.parse_line(case_linebreak2.first, row_sep: "\r"),
                 FastestCSV.parse_line(case_linebreak2.first, row_sep: "\r"))

    assert_equal(FastestCSV.parse_line(case_basic.first),
                 FastestCSV.parse_line(case_basic.first.chomp))

    # A read at eof? should return nil.
    assert_equal(nil, FastestCSV.parse_line(""))

    # With CSV it's impossible to tell an empty line from a line containing a
    # single nil field. The standard CSV library returns [nil]. We also do here,
    # though FasterCSV and some other libraries return Array.new. Maybe make
    # this a flag?
    assert_equal([nil], FastestCSV.parse_line("\n1,2,3\n"))
  end

  # See ruby csv test suite:
  # https://github.com/ruby/ruby/blob/trunk/test/csv/test_csv_parsing.rb

  def test_std_lib_csv
    [ ["\t",                      ["\t"]],
      ["foo,\"\"\"\"\"\",baz",    ["foo", "\"\"", "baz"]],
      ["foo,\"\"\"bar\"\"\",baz", ["foo", "\"bar\"", "baz"]],
      ["\"\"\"\n\",\"\"\"\n\"",   ["\"\n", "\"\n"]],
      ["foo,\"\r\n\",baz",        ["foo", "\r\n", "baz"]],
      ["\"\"",                    [""]],
      ["foo,\"\"\"\",baz",        ["foo", "\"", "baz"]],
      ["foo,\"\r.\n\",baz",       ["foo", "\r.\n", "baz"]],
      ["foo,\"\r\",baz",          ["foo", "\r", "baz"]],
      ["foo,\"\",baz",            ["foo", "", "baz"]],
      ["\",\"",                   [","]],
      ["foo",                     ["foo"]],
      [",,",                      [nil, nil, nil]],
      [",",                       [nil, nil]],
      ["foo,\"\n\",baz",          ["foo", "\n", "baz"]],
      ["foo,,baz",                ["foo", nil, "baz"]],
      ["\"\"\"\r\",\"\"\"\r\"",   ["\"\r", "\"\r"]],
      ["\",\",\",\"",             [",", ","]],
      ["foo,bar,",                ["foo", "bar", nil]],
      [",foo,bar",                [nil, "foo", "bar"]],
      ["foo,bar",                 ["foo", "bar"]],
      [";",                       [";"]],
      ["\t,\t",                   ["\t", "\t"]],
      ["foo,\"\r\n\r\",baz",      ["foo", "\r\n\r", "baz"]],
      ["foo,\"\r\n\n\",baz",      ["foo", "\r\n\n", "baz"]],
      ["foo,\"foo,bar\",baz",     ["foo", "foo,bar", "baz"]],
      [";,;",                     [";", ";"]],
      ["foo,\"foo,bar,baz,foo\",\"foo\"", ["foo", "foo,bar,baz,foo", "foo"]],
    ].each do |csv_test|
      assert_equal(csv_test.last,
                   FastestCSV.parse_line(csv_test.first))
      assert_equal(csv_test.last,
                   FastestCSV.parse_line(csv_test.first, grammar: "strict"))
    end
  end

  # From: http://ruby-talk.org/cgi-bin/scat.rb/ruby/ruby-core/6496 (URL now dead)

  def test_edge_cases
    [ [%(a,b),               ["a", "b"]],
      [%(a,"""b"""),         ["a", "\"b\""]],
      [%(a,"""b"),           ["a", "\"b"]],
      [%(a,"b"""),           ["a", "b\""]],
      [%(a,"\nb"""),         ["a", "\nb\""]],
      [%(a,"""\nb"),         ["a", "\"\nb"]],
      [%(a,"""\nb\n"""),     ["a", "\"\nb\n\""]],
      [%(a,"""\nb\n""",\nc), ["a", "\"\nb\n\"", nil]],
      [%(a,,,),              ["a", nil, nil, nil]],
      [%(,),                 [nil, nil]],
      [%("",""),             ["", ""]],
      [%(""""),              ["\""]],
      [%("""",""),           ["\"", ""]],
      [%(,""),               [nil, ""]],
      [%(,"\r"),             [nil, "\r"]],
      [%("\r\n,"),           ["\r\n,"]],
      [%("\r\n,",),          ["\r\n,", nil]],
      [%("a\nb"),                         ["a\nb"]],
      [%("\n\n\n"),                       ["\n\n\n"]],
      [%(a,"b\n\nc"),                     ['a', "b\n\nc"]],
      [%(,"\r\n"),                        [nil, "\r\n"]],
      [%(,"\r\n."),                       [nil, "\r\n."]],
      [%("a\na","one newline"),           ["a\na", 'one newline']],
      [%("a\n\na","two newlines"),        ["a\n\na", 'two newlines']],
      [%("a\r\na","one CRLF"),            ["a\r\na", 'one CRLF']],
      [%("a\r\n\r\na","two CRLFs"),       ["a\r\n\r\na", 'two CRLFs']],
      [%(with blank,"start\n\nfinish"\n), ['with blank', "start\n\nfinish"]],
      [%(wiggle,"waggle""this",another'thing),      ["wiggle", "waggle\"this", "another'thing"]],
      [%(wiggle,"waggle""this",another''thing),     ["wiggle", "waggle\"this", "another''thing"]],
      [%(wiggle,"""waggle""this,another''thing"),   ["wiggle", "\"waggle\"this,another''thing"]],
      [%(wiggle,"""waggle""this,another''thing"""), ["wiggle", "\"waggle\"this,another''thing\""]],
      [%(wiggle,"""waggle""this""""","""""""another''thing"""), ["wiggle", "\"waggle\"this\"\"", "\"\"\"another''thing\""]],
      [%(wiggle,"""waggle""this"""""",""""""another''thing"""), ["wiggle", "\"waggle\"this\"\"\",\"\"\"another''thing\""]],
      [%(wiggle,"""waggle""this""""""","""""another''thing"""), ["wiggle", "\"waggle\"this\"\"\"", "\"\"another''thing\""]],
      [%(wiggle,"""""""waggle""""""""this"""""""""""""""),      ["wiggle", "\"\"\"waggle\"\"\"\"this\"\"\"\"\"\"\""]],
    ].each do |csv_test|
      assert_equal(csv_test.last,
                   FastestCSV.parse_line(csv_test.first))
      assert_equal(csv_test.last,
                   FastestCSV.parse_line(csv_test.first, grammar: "strict"))
    end
  end

  def test_null_edge_cases
    # Technically not valid CSV to have a null character - review this in the
    # next version. Just trying to match old to_csv functionality for now, which
    # does accept and process it.
    [ [ %(\x00,a), ["\x00", "a"] ],
      [ %(a,\x00,b,,c), ["a", "\x00", "b", nil, "c"] ],
    ].each do |csv_test|
      assert_equal(csv_test.last,
                   FastestCSV.parse_line(csv_test.first))
      assert_equal(csv_test.last,
                   FastestCSV.parse_line(csv_test.first, grammar: "strict"))
    end
  end

  def test_nil_quote_char_cases
    [ [%(a,b),      ['a', 'b'],          ['a', 'b']],
      [%(a,"b"),    ['a', '"b"'],        ['a', 'b']],
      [%("a,b"),    ['"a', 'b"'],        ['a,b']],
      [%("a,",b"),  ['"a', '"', 'b"'],   ['a,', 'b"']], # this will only work with a quote char if grammar is relaxed
      [%("a,"",b"), ['"a', '""', 'b"'],  ['a,",b']],
    ].each do |csv_test|
      assert_equal(csv_test[1],
                   FastestCSV.parse_line(csv_test.first, quote_char: nil))
      assert_equal(csv_test[2],
                   FastestCSV.parse_line(csv_test.first, quote_char: '"'))
    end
  end

  def test_header_skipping
    path = "test/test_data_relaxed.csv"
    rows_with_header = []
    rows_without_header = []
    FastestCSV.foreach(path) { |row| rows_with_header << row }
    FastestCSV.foreach(path, skip_header: true) { |row| rows_without_header << row }
    refute_equal(rows_with_header, rows_without_header)
    assert_equal(rows_with_header[1..-1], rows_without_header)

    rows_with_header = []
    rows_without_header = []
    FastestCSV.foreach_raw_line(path) { |row| rows_with_header << row }
    FastestCSV.foreach_raw_line(path, skip_header: true) { |row| rows_without_header << row }
    refute_equal(rows_with_header, rows_without_header)
    assert_equal(rows_with_header[1..-1], rows_without_header)
  end

end
