# Tests adapted from faster_csv:
# https://github.com/JEG2/faster_csv/blob/master/test/tc_speed.rb
#
# copyright notice included from that file:
#
#  Created by James Edward Gray II on 2005-11-14.
#  Copyright 2012 Gray Productions. All rights reserved.

require 'minitest/autorun'
require 'fastest_csv'
require 'timeout'
require 'csv'

class TestCSVSpeed < Minitest::Test

  PATH     = File.join(File.dirname(__FILE__), "test_data.csv")
  BIG_DATA = "123456789\n" * 1024

  def test_that_we_are_doing_the_same_work
    FastestCSV.open(PATH) do |csv|
      CSV.foreach(PATH) do |row|
        assert_equal(row, csv.shift)
      end
    end
  end

  def test_read_speed_vs_csv
    csv_time = Time.now
    CSV.foreach(PATH) do |row|
      # do nothing, we're just timing a read...
    end
    csv_time = Time.now - csv_time

    fastest_csv_time = Time.now
    FastestCSV.foreach(PATH) do |row|
      # do nothing, we're just timing a read...
    end
    fastest_csv_time = Time.now - fastest_csv_time

    puts "CSV read: #{csv_time}"
    puts "FastestCSV read: #{fastest_csv_time}"

    assert(fastest_csv_time < csv_time / 3)

  end

  # We don't have bad CSV error checking in this gem as it currently stands

  # def test_the_parse_fails_fast_when_it_can_for_unquoted_fields
  #   assert_parse_errors_out('valid,fields,bad start"' + BIG_DATA)
  # end

  # def test_the_parse_fails_fast_when_it_can_for_unescaped_quotes
  #   assert_parse_errors_out('valid,fields,"bad start"unescaped' + BIG_DATA)
  # end

  # def test_field_size_limit_controls_lookahead
  #   assert_parse_errors_out( 'valid,fields,"' + BIG_DATA + '"',
  #                            :field_size_limit => 2048 )
  # end

  # private

  # def assert_parse_errors_out(*args)
  #   assert_raise(FasterCSV::MalformedCSVError) do
  #     Timeout.timeout(0.2) do
  #       FasterCSV.parse(*args)
  #       fail("Parse didn't error out")
  #     end
  #   end
  # end

end