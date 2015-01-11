
require 'minitest/autorun'
require 'fastest_csv'

# These tests invert the tests in tc_csv_parsing.rb, with a few modifications
# that are clearly noted. See comments in that file..

class TestCSVGenerating < Minitest::Test

  # You can see all the to_csv versions of the tests commented out for now,
  # because to_csv will _not_ pass some tests. I'm planning on phasing it out
  # in favor of generate_line anyway.
  #
  # Note to_csv attaches a newline, generate_line does not.

  def test_mastering_regex_example
    line = [ "Ten Thousand", "10000", " 2710 ", nil, "10,000",
             "It's \"10 Grand\", baby", "10K" ]
    assert_equal( FastestCSV.generate_line(line),
                  %Q{Ten Thousand,10000, 2710 ,,"10,000","It's ""10 Grand"", baby",10K\n} )
  end

  def test_std_lib_csv
    [ ["\t", ["\t"]],
      ["foo,\"\"\"\"\"\",baz", ["foo", "\"\"", "baz"]],
      ["foo,\"\"\"bar\"\"\",baz", ["foo", "\"bar\"", "baz"]],
      ["\"\"\"\n\",\"\"\"\n\"", ["\"\n", "\"\n"]],
      ["foo,\"\r\n\",baz", ["foo", "\r\n", "baz"]],
      # In the other direction this tests if a field "" is properly read as
      # empty. This is modified to not expect quoting, since default is false.
      # ["\"\"", [""]],
      ["", [""]],
      ["foo,\"\"\"\",baz", ["foo", "\"", "baz"]],
      ["foo,\"\r.\n\",baz", ["foo", "\r.\n", "baz"]],
      ["foo,\"\r\",baz", ["foo", "\r", "baz"]],
      # Similar issue as above re "" and empty fields
      # ["foo,\"\",baz", ["foo", "", "baz"]],
      ["foo,,baz", ["foo", "", "baz"]],
      ["\",\"", [","]],
      ["foo", ["foo"]],
      [",,", [nil, nil, nil]],
      [",", [nil, nil]],
      ["foo,\"\n\",baz", ["foo", "\n", "baz"]],
      ["foo,,baz", ["foo", nil, "baz"]],
      ["\"\"\"\r\",\"\"\"\r\"", ["\"\r", "\"\r"]],
      ["\",\",\",\"", [",", ","]],
      ["foo,bar,", ["foo", "bar", nil]],
      [",foo,bar", [nil, "foo", "bar"]],
      ["foo,bar", ["foo", "bar"]],
      [";", [";"]],
      ["\t,\t", ["\t", "\t"]],
      ["foo,\"\r\n\r\",baz", ["foo", "\r\n\r", "baz"]],
      ["foo,\"\r\n\n\",baz", ["foo", "\r\n\n", "baz"]],
      ["foo,\"foo,bar\",baz", ["foo", "foo,bar", "baz"]],
      [";,;", [";", ";"]]
    ].each do |csv_test|
      assert_equal(csv_test.first + "\n", FastestCSV.generate_line(csv_test.last))
    end

    # A lot of these appear to be dupes, sort them out at some point

    [ ["foo,\"\"\"\"\"\",baz", ["foo", "\"\"", "baz"]],
      ["foo,\"\"\"bar\"\"\",baz", ["foo", "\"bar\"", "baz"]],
      ["foo,\"\r\n\",baz", ["foo", "\r\n", "baz"]],
      # dupe?
      # ["\"\"", [""]],
      ["foo,\"\"\"\",baz", ["foo", "\"", "baz"]],
      ["foo,\"\r.\n\",baz", ["foo", "\r.\n", "baz"]],
      ["foo,\"\r\",baz", ["foo", "\r", "baz"]],
      # dupe?
      # ["foo,\"\",baz", ["foo", "", "baz"]],
      ["foo", ["foo"]],
      [",,", [nil, nil, nil]],
      [",", [nil, nil]],
      ["foo,\"\n\",baz", ["foo", "\n", "baz"]],
      ["foo,,baz", ["foo", nil, "baz"]],
      ["foo,bar", ["foo", "bar"]],
      ["foo,\"\r\n\n\",baz", ["foo", "\r\n\n", "baz"]],
      ["foo,\"foo,bar\",baz", ["foo", "foo,bar", "baz"]]
    ].each do |csv_test|
      assert_equal(csv_test.first + "\n", FastestCSV.generate_line(csv_test.last))
     end
  end

  def test_aras_edge_cases
    [ [%Q{a,b},               ["a", "b"]],
      [%Q{a,"""b"""},         ["a", "\"b\""]],
      [%Q{a,"""b"},           ["a", "\"b"]],
      [%Q{a,"b"""},           ["a", "b\""]],
      [%Q{a,"\nb"""},         ["a", "\nb\""]],
      [%Q{a,"""\nb"},         ["a", "\"\nb"]],
      [%Q{a,"""\nb\n"""},     ["a", "\"\nb\n\""]],
      # In the parsing tests, this tests if the c after the \n is ignored, so we can skip it here
      # [%Q{a,"""\nb\n""",\nc}, ["a", "\"\nb\n\"", nil]],
      [%Q{a,,,},              ["a", nil, nil, nil]],
      [%Q{,},                 [nil, nil]],
      # Similar issue re "" and empty fields
      # [%Q{"",""},             ["", ""]],
      [%Q{,},                 ["", ""]],
      [%Q{""""},              ["\""]],
      # Similar issue re "" and empty fields
      # [%Q{"""",""},           ["\"",""]],
      [%Q{"""",},             ["\"",""]],
      # Similar issue re "" and empty fields
      # [%Q{,""},               [nil,""]],
      [%Q{,},                 [nil,""]],
      [%Q{,"\r"},             [nil,"\r"]],
      [%Q{"\r\n,"},           ["\r\n,"]],
      [%Q{"\r\n,",},          ["\r\n,", nil]]
    ].each do |edge_case|
      assert_equal(edge_case.first + "\n", FastestCSV.generate_line(edge_case.last))
    end
  end

  def test_james_edge_cases
    assert_equal("\n", FastestCSV.generate_line([]))
  end

  def test_rob_edge_cases
    [ [%Q{"a\nb"},                         ["a\nb"]],
      [%Q{"\n\n\n"},                       ["\n\n\n"]],
      [%Q{a,"b\n\nc"},                     ['a', "b\n\nc"]],
      [%Q{,"\r\n"},                        [nil,"\r\n"]],
      [%Q{,"\r\n."},                       [nil,"\r\n."]],
      # These tests have been adjusted to reflect the non-force-quote default
      # [%Q{"a\na","one newline"},           ["a\na", 'one newline']],
      # [%Q{"a\n\na","two newlines"},        ["a\n\na", 'two newlines']],
      # [%Q{"a\r\na","one CRLF"},            ["a\r\na", 'one CRLF']],
      # [%Q{"a\r\n\r\na","two CRLFs"},       ["a\r\n\r\na", 'two CRLFs']],
      # [%Q{with blank,"start\n\nfinish"\n}, ['with blank', "start\n\nfinish"]],
      [%Q{"a\na",one newline},           ["a\na", 'one newline']],
      [%Q{"a\n\na",two newlines},        ["a\n\na", 'two newlines']],
      [%Q{"a\r\na",one CRLF},            ["a\r\na", 'one CRLF']],
      [%Q{"a\r\n\r\na",two CRLFs},       ["a\r\n\r\na", 'two CRLFs']],
      # Next one adjusted to have blank string in array corresponding to empty
      # field in output string. This test makes more sense the other way as a
      # way of testing end-of-line detection
      # [%Q{with blank,"start\n\nfinish"\n}, ['with blank', "start\n\nfinish"]],
      [%Q{with blank,"start\n\nfinish",}, ['with blank', "start\n\nfinish", ""]],
    ].each do |edge_case|
      assert_equal(edge_case.first + "\n", FastestCSV.generate_line(edge_case.last))
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