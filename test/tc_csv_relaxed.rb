
require 'minitest/autorun'
require 'fastest_csv'
require 'csv'

class TestCSVRelaxed < Minitest::Test

  def test_parsing

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
      [%Q{a,"b,",c"},  ['a', 'b,', ',c"']],
      [%Q{a,b",c"},    ['a', 'b"', 'c"']],
    ].each do |csv_test|
      assert_equal(csv_test.last,
                   FastestCSV.parse_line(csv_test.first))  # default: relaxed grammar
      assert_raises RuntimeError do
        FastestCSV.parse_line(csv_test.first, grammar: "strict")
      end
    end

  end

end