
# 0.7

- Replace positional arguments in `parse_line` and `generate_line` and also `open, `foreach`, etc. with options hash in a manner similar to Ruby's CSV
- Explicitly define supported CSV grammar, do more careful checking for validity
- `shift` and `<<` now respect user-specified field separator and quote characters
- Removed `to_csv` and its helpers `escapable_chars_including_comma` and `escapable_chars_not_comma`
- Add options `check_field_count` and `field_count` to catch CSV files with unequal numbers of fields
- Permit NUL char to be output by `generate_line`
- Tidied up tests

# 0.6.4

- Wrote `generate_line`, intended to eventually replace `to_csv`, `<<` now uses it instead of `to_csv`, provides speed improvements and fixes incorrect double quoting bug
- Tweaked `parse_line` to use heap allocation, should allow very large rows to be read or will at least fail more gracefully
- Updated tests, added `rake test`, and integrated Travis
- `foreach` now defaults second argument to `{}`
- Removed the `parse_csv` method added to String

# < 0.6.4

Not tracked in this changelog (0.6.3 was the original fork).