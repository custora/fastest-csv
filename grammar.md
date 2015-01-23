
# CSV grammar

## Strict

[RFC 4180](https://tools.ietf.org/html/rfc4180) defines a standard and a grammar for CSVs. This gem implements an extended version of RFC 4180 that permits certain characters to be changed. For example, the user can configure which characters separate or enclose fields.

The RFC 4180 ABNF grammar, using the syntax in [RFC 5234](https://tools.ietf.org/html/rfc5234), is reproduced below:

    file = [header CRLF] record *(CRLF record) [CRLF]

    header = name *(COMMA name)

    record = field *(COMMA field)

    name = field

    field = (escaped / non-escaped)

    escaped = DQUOTE *(TEXTDATA / COMMA / CR / LF / 2DQUOTE) DQUOTE

    non-escaped = *TEXTDATA

    COMMA = %x2C

    CR = %x0D

    DQUOTE =  %x22

    LF = %x0A

    CRLF = CR LF

    TEXTDATA =  %x20-21 / %x23-2B / %x2D-7E


We extend it to a family of grammars as follows:

  - To avoid confusion, rename:
    - COMMA as FIELDSEP
    - DQUOTE as FIELDQUOTE
    - CRLF as LINEBREAK

  - Users can specify their own value for FIELDSEP that can fall in the range %x20-7E.

  - Users can specify their own value for FIELDQUOTE that can fall in the range %x20-7E but may not be equal to FIELDSEP.

  - TEXTDATA is redefined to be any character except for FIELDSEP and FIELDQUOTE. (As of right now any character is supported, instead of the more strictly defined range of characters in RFC 4180).

  - Users can specify their own value for LINEBREAK, but it must be either CR, LF, or CR LF.


This is the grammar that is used when 'strict' grammar is specified. Note that the default is 'relaxed', which will be explained further below. The gem uses the following default values:

  - FIELDSEP: `,`
  - FIELDQUOTE: `"`
  - LINEBREAK: `\n`

Note that the default value for LINEBREAK is just LF and not CR LF (which is the linebreak value in RFC 4180).


## Relaxed

The default option in this package is actually 'relaxed' grammar, which will attempt to make some unambiguous interpretations of inputs that are technically syntactically incorrect under the strict grammar above. Under relaxed grammar:

  - if FIELDQUOTE is encountered in the middle of a non-escaped TEXTDATA, it will be interpreted as a regular character

  - if FIELDQUOTE is encountered in the middle of an escaped TEXTDATA but is not followed by another FIELDQUOTE, it will be interpreted as a regular character

These departures from the fairly clean CSV grammar defined above are to help deal with common malformations in CSV that are still accepted by MySQL's `LOAD DATA INFILE`.