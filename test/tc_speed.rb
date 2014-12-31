# Tests adapted from faster_csv:
# https://github.com/JEG2/faster_csv/blob/master/test/tc_speed.rb
#
# copyright notice included from that file:
#
#  Created by James Edward Gray II on 2005-11-14.
#  Copyright 2012 Gray Productions. All rights reserved.

require 'minitest/autorun'
require 'minitest/benchmark'
require 'fastest_csv'
require 'timeout'
require 'csv'

class TestCSVSpeed < Minitest::Test

  PATH = File.join(File.dirname(__FILE__), "test_data.csv")

  def test_that_we_are_doing_the_same_work

    FastestCSV.open(PATH) do |csv|
      CSV.foreach(PATH) do |row|
        fastest_row = csv.shift
        assert_equal(row, fastest_row)
        nilled_row = row.map{|x| x == '' ? nil : x }  # FastestCSV does not quote empty elements, need to do this to force CSV to do the same
        assert_equal(CSV.generate_line(nilled_row), FastestCSV.to_csv(fastest_row))
      end
    end

  end

  def test_read_and_parse_speed_vs_csv

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

    puts
    puts "CSV read and parse: #{csv_time}"
    puts "FastestCSV read and parse: #{fastest_csv_time}"
    puts

    assert(fastest_csv_time < csv_time / 3)

  end

  def test_generate_speed_vs_csv

    csv_data = []
    fastest_csv_data = []

    CSV.foreach(PATH) do |row|
      csv_data << row.map{|x| x == '' ? nil : x }  # don't include this conversion in the timing
      fastest_csv_data << row
    end

    csv_time = Time.now
    csv_data.each do |row|
      CSV.generate_line(row)
    end
    csv_time = Time.now - csv_time

    fastest_csv_to_csv_time = Time.now
    fastest_csv_data.each do |row|
      FastestCSV.to_csv(row)
    end
    fastest_csv_to_csv_time = Time.now - fastest_csv_to_csv_time

    fastest_csv_time = Time.now
    fastest_csv_data.each do |row|
      FastestCSV.generate_line(row)
    end
    fastest_csv_time = Time.now - fastest_csv_time

    puts
    puts "CSV generate: #{csv_time}"
    puts "FastestCSV generate (to_csv): #{fastest_csv_to_csv_time}"
    puts "FastestCSV generate (generate_line): #{fastest_csv_time}"
    puts

    assert(fastest_csv_time < csv_time / 3)

  end

  # BIG_DATA = "123456789\n" * 1024

  # We don't have bad CSV error checking in this gem as it currently stands, so
  # this part is commented out

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