
require 'minitest/autorun'
require 'fastest_csv'
require 'csv'

class TestCSVRelaxed < Minitest::Test

  # Unlike FasterCSV, we are not doing much in the way of error checking,
  # and so we don't have malformed CSV checks. But perhaps we should, if we
  # can trade it off for speed?

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

    # TODO: test if we now read files in properly

  end

end