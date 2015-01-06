# FastestCSV

[![Build Status](https://travis-ci.org/custora/fastest-csv.svg?branch=0.7)](https://travis-ci.org/custora/fastest-csv)

Fastest CSV class for MRI Ruby. Faster than faster_csv and fasterer-csv. On par with csvscan, but supports any delimiter and fast (buffered) writing of CSVs. Uses native C code to parse CSV lines in MRI Ruby. Java support is de facto deprecated as we don't use it and don't keep it updated.

Supports an extension of the CSV grammar defined in [RFC4180](https://tools.ietf.org/html/rfc4180). See `grammar.md` for the full details. Not designed to support Excel CSVs.

The interface is a subset of the CSV interface in Ruby 1.9.3. The options parameter only accepts `col_sep` and `write_buffer_lines`.

## Usage

Parse single line (anything after a newline is ignored)

    FastestCSV.parse_line("one,two,three")
    => ["one", "two", "three"]
    FastestCSV.parse_line("a,b,c\nd,e,f")  # d,e,f ignored
    => ["a", "b", "c"]
    FastestCSV.parse_line("a,b,\"c\nd\",e,f")
    => ["a", "b", "c\nd", "e", "f"]

Parse a string into an array of arrays

    FastestCSV.parse("a,b,\"c\nd\",e,f")
    => [["a", "b", "c\nd", "e", "f"]]
    FastestCSV.parse("a,b,c\nd,e,f")
    => [["a", "b", "c", "d", "e", "f"]]

Parse file one row at a time

    FastestCSV.foreach("path/to/file.csv") do |row|
      #
    end

Parse entire file

    data = FastestCSV.read("path/to/file.csv")

Convert array to CSV

    FastestCSV.generate_line([1, 2, "\n", 3])  # tries to make arguments into strings
    => "1,2,\"\n\",3"
    FastestCSV.generate_line([1, 2, nil, 3])   # nil becomes an empty field (and no quoting by default unless needed)
    => "1,2,,3"

Write array to CSV

    FastestCSV.open("path/to/file.csv", "wb") do |csv|
      csv << ["1", "2", "3"]
    end

## Tests

`rake test`
