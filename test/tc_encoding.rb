require 'minitest/autorun'
require 'fastest_csv'
require 'stringio'

class TestEncoding < Minitest::Test

  def test_encoding

    # see http://w3techs.com/technologies/overview/character_encoding/all

    good_utf8_input    = StringIO.new("\xE2\x88\x80,a,b,c")  # the "for all" math symbol
    good_iso_input     = StringIO.new("\xE2,a,b,c")          # a with a circumflex, but not valid UTF-8 - would be U+00E2
    good_iso_input2    = StringIO.new("\xE2,a,b,c")          # copy
    good_win1251_input = StringIO.new("\xDF,a,b,c")          # the Cyrillic ya (backwards R) - would be U+042F

    output = ''
    StringIO.open(output, "w") do |io|
      writer = FastestCSV.new(io)
      writer << FastestCSV.new(good_utf8_input).read.first
      writer.close
    end
    assert_equal("\xE2\x88\x80,a,b,c" + "\n", output)

    output = ''
    StringIO.open(output, "w") do |io|
      writer = FastestCSV.new(io)
      writer << FastestCSV.new(good_iso_input).read.first
      writer.close
    end
    assert_equal("\u00E2,a,b,c" + "\n", output)

    output = ''
    StringIO.open(output, "w") do |io|
      writer = FastestCSV.new(io, non_utf8_encodings: ["Windows-1251"])
      writer << FastestCSV.new(good_win1251_input).read.first
      writer.close
    end
    assert_equal("\u042F,a,b,c" + "\n", output)

    # fails, because we forced it not to try any other encodings

    output = ''
    StringIO.open(output, "w") do |io|
      writer = FastestCSV.new(io, non_utf8_encodings: [])
      assert_raises RuntimeError do
        writer << FastestCSV.new(good_iso_input2, non_utf8_encodings: []).read.first
      end
      writer.close
    end

  end

end