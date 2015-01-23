
require 'minitest/autorun'
require 'fastest_csv'
require 'csv'

class TestCSVRelaxed < Minitest::Test

  PATH = File.join(File.dirname(__FILE__), "test_data_relaxed.csv")

  def test_basic_strict
    assert_raises RuntimeError do
      FastestCSV.parse_line(%Q{a,b"}, grammar: "strict")
    end
    assert_raises RuntimeError do
      FastestCSV.parse_line(%Q{a,"b"c}, grammar: "strict")
    end
    assert_raises RuntimeError do
      FastestCSV.parse_line(%Q{a,""b}, grammar: "strict")
    end
    assert_raises RuntimeError do
      FastestCSV.parse_line(%Q{a,b""}, grammar: "strict")
    end
  end

  def test_relaxed_and_strict_parsing

    [ [%Q{a,b,c"},     ['a', 'b', 'c"']],
      [%Q{a,b,c"d},    ['a', 'b', 'c"d']],
      [%Q{a,b,c""},    ['a', 'b', 'c""']],
      [%Q{a,b,c"d"},   ['a', 'b', 'c"d"']],
      [%Q{a,b,c""d"},  ['a', 'b', 'c""d"']],
      [%Q{a,b,c"d""},  ['a', 'b', 'c"d""']],
      [%Q{a,b,c""d""}, ['a', 'b', 'c""d""']],
      [%Q{a,b",c"},    ['a', 'b"', 'c"']],
      [%Q{a,b","c"},   ['a', 'b"', 'c']],
      [%Q{a,b",",c"},  ['a', 'b"', ',c']],
      [%Q{a,"b,",c"},  ['a', 'b,', 'c"']],
      [%Q{a,b",c"},    ['a', 'b"', 'c"']],
      # [%Q{a,b,"c},     ['a', 'b"', 'c"']],   # We don't handle this case yet in relaxed, we raise an exception; revisit this
    ].each do |csv_test|
      assert_equal(csv_test.last,
                   FastestCSV.parse_line(csv_test.first))  # default: relaxed grammar
      assert_raises RuntimeError do
        FastestCSV.parse_line(csv_test.first, grammar: "strict")
      end
    end

  end

  def test_relaxed_io_parsing

    expected_output = [
      ["a","b","c\""],
      ["a","b,fakec\nthis is a very long field\nit still hasn't ended\nok it will now end here","c"],
      ["a","b","c\"","d"],
      ["a","b","c\"","don't lose me"],
      ["a","b","c\"","don't lose me either"],
    ]

    parsed_output = FastestCSV.read(PATH)

    assert_equal(expected_output, parsed_output)

  end

end