# FastestCSV

[![Build Status](https://travis-ci.org/custora/fastest-csv.svg?branch=unit-testing)](https://travis-ci.org/custora/fastest-csv)

Fastest CSV class for MRI Ruby. Faster than faster_csv and fasterer-csv. On par with csvscan, but supports any delimiter and fast ((buffered) writing of CSVs. Uses native C code to parse CSV lines in MRI Ruby. Java support is de facto deprecated as we don't use it and don't keep it updated.

Supports standard CSV according to [RFC4180](https://tools.ietf.org/html/rfc4180), with the exception that it permits the delimiter and field separators to be redefined (COMMA and DQUOTE in the RFC4180 grammar). Does not support Excel CSVs.

The interface is a subset of the CSV interface in Ruby 1.9.3. The options parameter only accepts col_sep and write_buffer_lines.

Originally developed to parse large CSV log files from PowerMTA.  Extended to parse large log files at Custora (that were not always comma delimited).

## Usage

Parse single line

    FastestCSV.parse_line("one,two,three")
     => ["one", "two", "three"]

    "one,two,three".parse_csv
     => ["one", "two", "three"]

Parse file without header

    FastestCSV.foreach("path/to/file.csv") do |row|
      while row = csv.shift
        #
      end
    end

Parse file with header

    FastestCSV.open("path/to/file.csv") do |csv|
      fields = csv.shift
      while values = csv.shift
        #
      end
    end

Parse file in array of arrays

    rows = FastestCSV.read("path/to/file.csv")

Parse string in array of arrays

    rows = FastestCSV.parse(csv_data)

Write array to CSV

    FastestCSV.open("path/to/file.csv", "wb") do |csv|
      csv << ["1", "2", "3"]
    end

## Tests

`rake test`

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
