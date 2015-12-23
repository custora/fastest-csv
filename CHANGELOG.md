# 0.8.1
- Added `c_escaped_relaxed` grammar option

# 0.8
- Added `c_escaped` grammar option to handle C-style escape sequences
- Renamed the gem 'fastest_csv', in accordance with [Rubygems guidelines](http://guides.rubygems.org/name-your-gem/)
- Cleaned up tests, imposed Rubocop

# 0.7.6
- Speed improvements to `parse_line`, removed `parse_line_no_check`

# 0.7.5
- `quote_char` parameter can be nil, which permits calling `parse_line` without any quote char at all. Running `generate_line` this way will result in an exception though.

# 0.7.4
- Make use of rb:bom mode so that we ignore UTF-8 byte order marks if they are present.

# 0.7.3
- `foreach_raw_line` to get unparsed semantic lines from file.

# 0.7.2

- `parse_line` and `generate_line` output UTF-8-encoded text
- Permit users to supply a list of encodings for `<<` that are tried in sequence so that proper UTF-8 gets written out. Note that `shift` will not do this right now, it'll read in a UTF-8 encoded string but if the input stream is not UTF-8 then you'll just have a string with invalid encoding

# 0.7.1

- Change `parse_line` to also return true/false depending on if the last field was a complete record (i.e. no runaway quote) or not; allow `parse_line` to parse partial lines and start off in IN_QUOTED state
- Change shift to just `gets` up to the next row separator and have `parse_line` concatenate together lines with incomplete fields until a line is completed

# 0.7

- Replace positional arguments in `parse_line` and `generate_line` and also `open, `foreach`, etc. with options hash in a manner similar to Ruby's CSV
- Permit a grammar flag 'strict' vs. 'relaxed'. The former raises exceptions on incorrect CSV syntax, the latter accepts some syntactically incorrect CSV in a similar manner to MySQL's LOAD INFILE
- Explicitly define supported CSV grammar, do more careful checking for validity
- `shift` and `<<` now respect user-specified field separator and quote characters
- Removed `to_csv` and its helpers `escapable_chars_including_comma` and `escapable_chars_not_comma`
- Add options `check_field_count` and `field_count` to catch CSV files with unequal numbers of fields
- Permit NUL char to be output by `generate_line`
- Java support removed, we don't use it and do not want to need to spend on its upkeep for now
- Tidied up tests

# 0.6.4

- Wrote `generate_line`, intended to eventually replace `to_csv`, `<<` now uses it instead of `to_csv`, provides speed improvements and fixes incorrect double quoting bug
- Tweaked `parse_line` to use heap allocation, should allow very large rows to be read or will at least fail more gracefully
- Updated tests, added `rake test`, and integrated Travis
- `foreach` now defaults second argument to `{}`
- Removed the `parse_csv` method added to String

# < 0.6.4

Not tracked in this changelog (0.6.3 was the original fork).
