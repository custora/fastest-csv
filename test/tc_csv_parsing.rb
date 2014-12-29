# Tests adapted from faster_csv:
# https://github.com/JEG2/faster_csv/blob/master/test/tc_csv_parsing.rb
# 
# copyright notice included from that file:
#
#  Created by James Edward Gray II on 2005-10-31.
#  Copyright 2012 Gray Productions. All rights reserved.

require 'minitest/autorun'
require 'fastest_csv'

# 
# Following tests are my interpretation of the 
# {CSV RCF}[http://www.ietf.org/rfc/rfc4180.txt].  I only deviate from that 
# document in one place (intentionally) and that is to make the default row
# separator <tt>$/</tt>.
# 

class TestCSVParsing < Minitest::Test

  def test_mastering_regex_example
    ex = %Q{Ten Thousand,10000, 2710 ,,"10,000","It's ""10 Grand"", baby",10K}
    assert_equal( [ "Ten Thousand", "10000", " 2710 ", nil, "10,000",
                    "It's \"10 Grand\", baby", "10K" ],
                  FastestCSV.parse_line(ex) )
  end

  # See ruby csv test suite: 
  # https://github.com/ruby/ruby/blob/trunk/test/csv/test_csv_parsing.rb

  def test_std_lib_csv
    [ ["\t", ["\t"]],
      ["foo,\"\"\"\"\"\",baz", ["foo", "\"\"", "baz"]],
      ["foo,\"\"\"bar\"\"\",baz", ["foo", "\"bar\"", "baz"]],
      ["\"\"\"\n\",\"\"\"\n\"", ["\"\n", "\"\n"]],
      ["foo,\"\r\n\",baz", ["foo", "\r\n", "baz"]],
      ["\"\"", [""]],
      ["foo,\"\"\"\",baz", ["foo", "\"", "baz"]],
      ["foo,\"\r.\n\",baz", ["foo", "\r.\n", "baz"]],
      ["foo,\"\r\",baz", ["foo", "\r", "baz"]],
      ["foo,\"\",baz", ["foo", "", "baz"]],
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
      [";,;", [";", ";"]] ].each do |csv_test|
      assert_equal(csv_test.last, FastestCSV.parse_line(csv_test.first))
    end
    
    [ ["foo,\"\"\"\"\"\",baz", ["foo", "\"\"", "baz"]],
      ["foo,\"\"\"bar\"\"\",baz", ["foo", "\"bar\"", "baz"]],
      ["foo,\"\r\n\",baz", ["foo", "\r\n", "baz"]],
      ["\"\"", [""]],
      ["foo,\"\"\"\",baz", ["foo", "\"", "baz"]],
      ["foo,\"\r.\n\",baz", ["foo", "\r.\n", "baz"]],
      ["foo,\"\r\",baz", ["foo", "\r", "baz"]],
      ["foo,\"\",baz", ["foo", "", "baz"]],
      ["foo", ["foo"]],
      [",,", [nil, nil, nil]],
      [",", [nil, nil]],
      ["foo,\"\n\",baz", ["foo", "\n", "baz"]],
      ["foo,,baz", ["foo", nil, "baz"]],
      ["foo,bar", ["foo", "bar"]],
      ["foo,\"\r\n\n\",baz", ["foo", "\r\n\n", "baz"]],
      ["foo,\"foo,bar\",baz", ["foo", "foo,bar", "baz"]] ].each do |csv_test|
      assert_equal(csv_test.last, FastestCSV.parse_line(csv_test.first))
     end
  end

  # From:  http://ruby-talk.org/cgi-bin/scat.rb/ruby/ruby-core/6496
  def test_aras_edge_cases
    [ [%Q{a,b},               ["a", "b"]],
      [%Q{a,"""b"""},         ["a", "\"b\""]],
      [%Q{a,"""b"},           ["a", "\"b"]],
      [%Q{a,"b"""},           ["a", "b\""]],
      [%Q{a,"\nb"""},         ["a", "\nb\""]],
      [%Q{a,"""\nb"},         ["a", "\"\nb"]],
      [%Q{a,"""\nb\n"""},     ["a", "\"\nb\n\""]],
      [%Q{a,"""\nb\n""",\nc}, ["a", "\"\nb\n\"", nil]],
      [%Q{a,,,},              ["a", nil, nil, nil]],
      [%Q{,},                 [nil, nil]],
      [%Q{"",""},             ["", ""]],
      [%Q{""""},              ["\""]],
      [%Q{"""",""},           ["\"",""]],
      [%Q{,""},               [nil,""]],
      [%Q{,"\r"},             [nil,"\r"]],
      [%Q{"\r\n,"},           ["\r\n,"]],
      [%Q{"\r\n,",},          ["\r\n,", nil]] ].each do |edge_case|
        assert_equal(edge_case.last, FastestCSV.parse_line(edge_case.first))
      end
  end

  def test_james_edge_cases
    # A read at eof? should return nil.
    assert_equal(nil, FastestCSV.parse_line(""))
    # 
    # With CSV it's impossible to tell an empty line from a line containing a
    # single +nil+ field.  The standard CSV library returns <tt>[nil]</tt>
    # in these cases, but <tt>Array.new</tt> makes more sense to me.
    # 
    #assert_equal(Array.new, FastestCSV.parse_line("\n1,2,3\n"))
    assert_equal([nil], FastestCSV.parse_line("\n1,2,3\n"))
  end

  def test_rob_edge_cases
    [ [%Q{"a\nb"},                         ["a\nb"]],
      [%Q{"\n\n\n"},                       ["\n\n\n"]],
      [%Q{a,"b\n\nc"},                     ['a', "b\n\nc"]],
      [%Q{,"\r\n"},                        [nil,"\r\n"]],
      [%Q{,"\r\n."},                       [nil,"\r\n."]],
      [%Q{"a\na","one newline"},           ["a\na", 'one newline']],
      [%Q{"a\n\na","two newlines"},        ["a\n\na", 'two newlines']],
      [%Q{"a\r\na","one CRLF"},            ["a\r\na", 'one CRLF']],
      [%Q{"a\r\n\r\na","two CRLFs"},       ["a\r\n\r\na", 'two CRLFs']],
      [%Q{with blank,"start\n\nfinish"\n}, ['with blank', "start\n\nfinish"]],
    ].each do |edge_case|
      assert_equal(edge_case.last, FastestCSV.parse_line(edge_case.first))
    end
  end

  def test_non_regex_edge_cases
    
    [["foo,\"foo,bar,baz,foo\",\"foo\"", ["foo", "foo,bar,baz,foo", "foo"]]].each do |edge_case|
      assert_equal(edge_case.last, FastestCSV.parse_line(edge_case.first))
    end

    # Unlike FasterCSV, we are not doing much in the way of error checking, 
    # and so we don't have malformed CSV checks. But perhaps we should, if we 
    # can trade it off for speed? 

    # assert_raise(FastestCSV::MalformedCSVError) do
    #   FastestCSV.parse_line("1,\"23\"4\"5\", 6")
    # end

  end

end
