#!/usr/bin/ruby -w

require 'mkmf'
extension_name = 'csv_parser'

# rubocop:disable Style/GlobalVars
if RUBY_VERSION =~ /^1.8/
  $CPPFLAGS += " -DRUBY_18"
end
# rubocop:enable Style/GlobalVars

create_makefile(extension_name)
