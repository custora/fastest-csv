
require 'minitest/autorun'
require 'fastest_csv'

# These tests invert the tests in tc_csv_parsing.rb, with a few modifications
# that are clearly noted. See comments in that file.

class TestCSVGenerating < Minitest::Test

  def test_basic

    case_basic = [
      %Q{Ten Thousand,10000, 2710 ,,"10,000","It's ""10 Grand"", baby",10K\n},
      [ "Ten Thousand", "10000", " 2710 ", nil, "10,000", "It's \"10 Grand\", baby", "10K" ]
    ]
    case_sep = [
      %Q{Ten Thousand;10000; 2710 ;;10,000;"It's ""10 Grand"", baby";10K\n},
      [ "Ten Thousand", "10000", " 2710 ", nil, "10,000", "It's \"10 Grand\", baby", "10K" ]
    ]
    case_quote = [
      %Q{Ten Thousand,10000, 2710 ,,'10,000','It''s "10 Grand", baby',10K\n},
      [ "Ten Thousand", "10000", " 2710 ", nil, "10,000", "It's \"10 Grand\", baby", "10K" ]
    ]
    case_linebreak1 = [
      %Q{Ten Thousand,10000, 2710 ,,"10,000","It's ""10 Grand"", baby",10K\r\n},
      [ "Ten Thousand", "10000", " 2710 ", nil, "10,000", "It's \"10 Grand\", baby", "10K" ]
    ]
    case_linebreak2 = [
      %Q{Ten Thousand,10000, 2710 ,,"10,000","It's ""10 Grand"", baby",10K\r},
      [ "Ten Thousand", "10000", " 2710 ", nil, "10,000", "It's \"10 Grand\", baby", "10K" ]
    ]

    assert_equal(case_basic.first,
                 FastestCSV.generate_line(case_basic.last))
    assert_equal(case_sep.first,
                 FastestCSV.generate_line(case_sep.last, col_sep: ";"))
    assert_equal(case_quote.first,
                 FastestCSV.generate_line(case_quote.last, quote_char: "'"))
    assert_equal(case_linebreak1.first,
                 FastestCSV.generate_line(case_linebreak1.last, row_sep: "\r\n"))
    assert_equal(case_linebreak2.first,
                 FastestCSV.generate_line(case_linebreak1.last, row_sep: "\r"))

    assert_equal(CSV.generate_line(case_basic.last),
                 FastestCSV.generate_line(case_basic.last))
    assert_equal(CSV.generate_line(case_sep.last, col_sep: ";"),
                 FastestCSV.generate_line(case_sep.last, col_sep: ";"))
    assert_equal(CSV.generate_line(case_quote.last, quote_char: "'"),
                 FastestCSV.generate_line(case_quote.last, quote_char: "'"))
    assert_equal(CSV.generate_line(case_linebreak1.last, row_sep: "\r\n"),
                 FastestCSV.generate_line(case_linebreak1.last, row_sep: "\r\n"))
    assert_equal(CSV.generate_line(case_linebreak2.last, row_sep: "\r"),
                 FastestCSV.generate_line(case_linebreak1.last, row_sep: "\r"))

  end

  def test_std_lib_csv

    # with no force quote - mostly the same as parsing tests

    [ ["\t",                      ["\t"]],
      ["foo,\"\"\"\"\"\",baz",    ["foo", "\"\"", "baz"]],
      ["foo,\"\"\"bar\"\"\",baz", ["foo", "\"bar\"", "baz"]],
      ["\"\"\"\n\",\"\"\"\n\"",   ["\"\n", "\"\n"]],
      ["foo,\"\r\n\",baz",        ["foo", "\r\n", "baz"]],
      ["",                        [""]],
      ["foo,\"\"\"\",baz",        ["foo", "\"", "baz"]],
      ["foo,\"\r.\n\",baz",       ["foo", "\r.\n", "baz"]],
      ["foo,\"\r\",baz",          ["foo", "\r", "baz"]],
      ["foo,,baz",                ["foo", "", "baz"]],
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
      ["foo,\"foo,bar,baz,foo\",foo", ["foo", "foo,bar,baz,foo", "foo"]],
    ].each do |csv_test|
      assert_equal(csv_test.first + "\n",
                   FastestCSV.generate_line(csv_test.last))
    end

    # with force quote

    [ ["\"\"",                    [""]],
      ["\"foo\",\"\",\"baz\"",    ["foo", "", "baz"]],
      ["\"foo\",\"foo,bar,baz,foo\",\"foo\"", ["foo", "foo,bar,baz,foo", "foo"]],
    ].each do |csv_test|
      assert_equal(csv_test.first + "\n",
                   FastestCSV.generate_line(csv_test.last, force_quotes: true))
    end

  end

  def test_aras_edge_cases

    # with no force quote - mostly the same as parsing tests

    [ [%Q{a,b},               ["a", "b"]],
      [%Q{a,"""b"""},         ["a", "\"b\""]],
      [%Q{a,"""b"},           ["a", "\"b"]],
      [%Q{a,"b"""},           ["a", "b\""]],
      [%Q{a,"\nb"""},         ["a", "\nb\""]],
      [%Q{a,"""\nb"},         ["a", "\"\nb"]],
      [%Q{a,"""\nb\n"""},     ["a", "\"\nb\n\""]],
      [%Q{a,,,},              ["a", nil, nil, nil]],
      [%Q{,},                 [nil, nil]],
      [%Q{,},                 ["", ""]],
      [%Q{""""},              ["\""]],
      [%Q{"""",},             ["\"",""]],
      [%Q{,},                 [nil,""]],
      [%Q{,"\r"},             [nil,"\r"]],
      [%Q{"\r\n,"},           ["\r\n,"]],
      [%Q{"\r\n,",},          ["\r\n,", nil]]
    ].each do |csv_test|
      assert_equal(csv_test.first + "\n",
                   FastestCSV.generate_line(csv_test.last))
    end

    # with force quote

    [ [%Q{"",""},             ["", ""]],
      [%Q{"""",""},           ["\"",""]],
      [%Q{"",""},             [nil,""]],
    ].each do |csv_test|
      assert_equal(csv_test.first + "\n",
                   FastestCSV.generate_line(csv_test.last, force_quotes: true))
    end

  end

  def test_james_edge_cases
    assert_equal("\n", FastestCSV.generate_line([]))
  end

  def test_rob_edge_cases

    # with no force quote - mostly the same as parsing tests

    [ [%Q{"a\nb"},                         ["a\nb"]],
      [%Q{"\n\n\n"},                       ["\n\n\n"]],
      [%Q{a,"b\n\nc"},                     ['a', "b\n\nc"]],
      [%Q{,"\r\n"},                        [nil,"\r\n"]],
      [%Q{,"\r\n."},                       [nil,"\r\n."]],
      [%Q{"a\na",one newline},             ["a\na", 'one newline']],
      [%Q{"a\n\na",two newlines},          ["a\n\na", 'two newlines']],
      [%Q{"a\r\na",one CRLF},              ["a\r\na", 'one CRLF']],
      [%Q{"a\r\n\r\na",two CRLFs},         ["a\r\n\r\na", 'two CRLFs']],
      [%Q{with blank,"start\n\nfinish",},  ['with blank', "start\n\nfinish", ""]],
    ].each do |csv_test|
      assert_equal(csv_test.first + "\n",
                   FastestCSV.generate_line(csv_test.last))
    end

    # with force quote

    [ [%Q{"a\na","one newline"},           ["a\na", 'one newline']],
      [%Q{"a\n\na","two newlines"},        ["a\n\na", 'two newlines']],
      [%Q{"a\r\na","one CRLF"},            ["a\r\na", 'one CRLF']],
      [%Q{"a\r\n\r\na","two CRLFs"},       ["a\r\n\r\na", 'two CRLFs']],
      [%Q{"with blank","start\n\nfinish"}, ['with blank', "start\n\nfinish"]],
      [%Q{"with blank","start\n\nfinish",""}, ['with blank', "start\n\nfinish", ""]],
    ].each do |csv_test|
      assert_equal(csv_test.first + "\n",
                   FastestCSV.generate_line(csv_test.last, force_quotes: true))
    end

  end

  def test_jon_edge_cases
    [ [%Q{wiggle,"waggle""this",another'thing},      ["wiggle", "waggle\"this", "another'thing"]],
      [%Q{wiggle,"waggle""this",another''thing},     ["wiggle", "waggle\"this", "another''thing"]],
      [%Q{wiggle,"""waggle""this,another''thing"},   ["wiggle", "\"waggle\"this,another''thing"]],
      [%Q{wiggle,"""waggle""this,another''thing"""}, ["wiggle", "\"waggle\"this,another''thing\""]],
      [%Q{wiggle,"""waggle""this""""","""""""another''thing"""}, ["wiggle", "\"waggle\"this\"\"", "\"\"\"another''thing\""]],
      [%Q{wiggle,"""waggle""this"""""",""""""another''thing"""}, ["wiggle", "\"waggle\"this\"\"\",\"\"\"another''thing\""]],
      [%Q{wiggle,"""waggle""this""""""","""""another''thing"""}, ["wiggle", "\"waggle\"this\"\"\"", "\"\"another''thing\""]],
      [%Q{wiggle,"""""""waggle""""""""this"""""""""""""""},      ["wiggle", "\"\"\"waggle\"\"\"\"this\"\"\"\"\"\"\""]],
    ].each do |csv_test|
      assert_equal(csv_test.first + "\n", FastestCSV.generate_line(csv_test.last))
    end
  end

  def test_null_edge_cases
    # Technically not valid CSV to have a null character - review this in the 
    # next version. Just trying to match old to_csv functionality for now, which
    # does accept and process it. 
    [ [ %Q{\x00,a}, ["\x00", "a"] ],
      [ %Q{a,\x00,b,,c} , ["a", "\x00", "b", nil, "c"] ],
    ].each do |csv_test|
      assert_equal(csv_test.first + "\n", FastestCSV.generate_line(csv_test.last))
    end
  end


end