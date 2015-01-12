
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


The gem uses the following default values:

  - FIELDSEP: `,`
  - FIELDQUOTE: `"`
  - LINEBREAK: `\n`

Note importantly that the default value for LINEBREAK is just LF and not CR LF (which is the value in RFC 4180).