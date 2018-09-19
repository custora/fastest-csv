/*
 * See LICENSE file for full copyright info
 */

#include "ruby.h"
#ifdef RUBY_18
  #include "rubyio.h"
#else
  #include "ruby/io.h"
#endif

/* default allocated size is 16 */
#define DEF_ARRAY_LEN 32

#define UNQUOTED 0
#define IN_QUOTED 1
#define QUOTE_IN_QUOTED 2
#define IN_QUOTED_ESCAPING 3
#define COMPLETED_C_ESCAPED_QUOTE 4

#define C_ESCAPE_CHAR '\\'

/* http://tenderlovemaking.com/2009/06/26/string-encoding-in-ruby-1-9-c-extensions.html */
#define DEFAULT_STRING_ENCODING "UTF-8"

typedef enum modes {STRICT, RELAXED, C_ESCAPED, C_ESCAPED_RELAXED} grammar_mode_t;

static VALUE mCsvParser;

/* parse_line
 * Parses a CSV-formatted string into a list of strings. Returns a two-element
 * array whose first element is the list of strings and whose second element is
 * true if the line was complete and false otherwise.
 *
 *   str - the string to parse
 *   sep_char - the character that separates fields, assumed to be a string of
 *     length 1
 *   quote_char: the character that encloses quoted fields, assumed to be a
 *     string of length 1
 *   linebreak_char: the string that separates rows, assumed to be either \r,
 *     \n, or \r\n
 *   grammar_code:
 *     0 - strict CSV syntax rules are followed
 *     1 - single occurrences of quote_char in unquoted fields are interpreted
 *         as ordinary characters
 *     2 - quoted fields will be treated as strings supporting a limited set of
 *         C-like escape sequences: \\, \', \", \?, \n, \r, \t, and also \
 *         followed by whatever your quote character is. A backslash followed by
 *         any other character will be interpreted as that literal set of two
 *         characters. The entire field must be quoted, a la strict CSV syntax.
 *   start_in_quoted: if nonzero, will start reading the line as if it were
 *     quoted; used to read lines whose contents are continuations of previous
 *     lines (due to linebreaks in the middle of a quoted field)
 */

static VALUE parse_line(VALUE self, VALUE str,
                        VALUE sep_char, VALUE quote_char, VALUE linebreak_char,
                        VALUE grammar_code, VALUE start_in_quoted) {

    VALUE output = rb_ary_new2(2);
    VALUE array = rb_ary_new2(DEF_ARRAY_LEN);
    VALUE field;

    int state = UNQUOTED;
    int index = 0;
    int crlf;
    int nil_quote_char = 0;   /* if true, we will not regard any char as a quoter */

    int i;
    int default_encoding = rb_enc_find_index(DEFAULT_STRING_ENCODING);
    char c;

    const char *sepc;
    const char *quotec;
    const char *linebreakc;
    const char *ptr;

    grammar_mode_t mode;

    if (!FIXNUM_P(grammar_code))
        rb_raise(rb_eArgError, "grammar_code must be 0, 1, or 2");

    switch(FIX2INT(grammar_code)) {
        case 0:
            mode = STRICT;
            break;
        case 1:
            mode = RELAXED;
            break;
        case 2:
            mode = C_ESCAPED;
            break;
        case 3:
            mode = C_ESCAPED_RELAXED;
            break;
        default:
            rb_raise(rb_eArgError, "grammar_code must be 0, 1, 2, or 3");
    }

    int len = (int) RSTRING_LEN(str);  /* cast to prevent warning in 64-bit OS */
    char *value = (char *)malloc(len * sizeof(char) + 1);
    if (value == NULL)
        rb_raise(rb_eNoMemError, "could not allocate memory for parsed field value");

    /* input verification */

    if (NIL_P(sep_char))
        rb_raise(rb_eArgError, "sep_char may not be nil");
    sepc = RSTRING_PTR(sep_char);

    if (NIL_P(quote_char)) {
        if (FIX2INT(start_in_quoted) != 0)
            rb_raise(rb_eArgError, "quote_char may not be nil if starting in quoted (start_in_quoted = 0)");
        else
            nil_quote_char = 1;
    }
    else {
        quotec = RSTRING_PTR(quote_char);
    }

    linebreakc = RSTRING_PTR(linebreak_char);
    crlf = strcmp(linebreakc, "\r\n") == 0 ? 1 : 0;

    if (NIL_P(str) || len == 0) {
        rb_ary_push(output, Qnil);
        rb_ary_push(output, Qtrue);
        return output;
    }
    else {
        ptr = RSTRING_PTR(str);
    }

    if (FIX2INT(start_in_quoted) != 0)
        state = IN_QUOTED;

    /* parsing starts here */

    for (i = 0; i < len; i++)
    {
        c = ptr[i];

        /* if encounter a separator */
        if (c == sepc[0]) {
            if (state == UNQUOTED) {
                /* start new field */
                if (index == 0) {
                    rb_ary_push(array, Qnil);
                }
                else {
                    field = rb_str_new(value, index);
                    rb_enc_associate_index(field, default_encoding);
                    rb_ary_push(array, field);
                }
                index = 0;
            }
            else if (state == IN_QUOTED) {
                value[index++] = c;
            }
            else if (state == QUOTE_IN_QUOTED || state == COMPLETED_C_ESCAPED_QUOTE) {
                /* start new field */
                field = rb_str_new(value, index);
                rb_enc_associate_index(field, default_encoding);
                rb_ary_push(array, field);
                index = 0;
                state = UNQUOTED;
            }
        }

        /* if we're in COMPLETED_C_ESCAPED_QUOTE and the next character isn't
         * the separator or the end of line, there is a problem */
        else if (state == COMPLETED_C_ESCAPED_QUOTE) {
            rb_raise(rb_eRuntimeError, "CSV syntax error, unescaped quote does not terminate field: %s", ptr);
        }

        /* if encounter a possible C escaped sequence, in C_ESCAPED mode */
        else if ((mode == C_ESCAPED || mode == C_ESCAPED_RELAXED) &&
                 c == C_ESCAPE_CHAR && state == IN_QUOTED) {
            state = IN_QUOTED_ESCAPING;
        }

        /* if encounter a quote */
        else if (!nil_quote_char && c == quotec[0]) {
            if (state == UNQUOTED && index == 0) {
                /* opening quote */
                state = IN_QUOTED;
            }
            else if (state == UNQUOTED && (mode == RELAXED || mode == C_ESCAPED_RELAXED)) {
                /* incorrectly placed quote in unquoted field, but in relaxed mode */
                value[index++] = c;
            }
            else if (state == IN_QUOTED_ESCAPING) {
                /* escaped quote */
                value[index++] = c;
                state = IN_QUOTED;
            }
            else if (state == QUOTE_IN_QUOTED && mode == C_ESCAPED_RELAXED) {
                /* in relaxed C-escaped, we allow quote characters to appear in
                 * the middle of quoted fields - we read them as regular
                 * characters */
                value[index++] = quotec[0];
            }
            else if (state == QUOTE_IN_QUOTED) {
                /* quote escape completed */
                value[index++] = c;
                state = IN_QUOTED;
            }
            else if (state == IN_QUOTED && mode == C_ESCAPED) {
                /* in C_ESCAPED, a quote while IN_QUOTED is supposed to always
                 * denote the end of the quoted string */
                state = COMPLETED_C_ESCAPED_QUOTE;
            }
            else if (state == IN_QUOTED) {
                /* start of possible quote termination or escape */
                state = QUOTE_IN_QUOTED;
            }
            else {
                rb_raise(rb_eRuntimeError, "CSV syntax error, stray quote character: %s", ptr);
            }
        }

        /* if encounter a single-char line break (CR or LF) */
        else if ((c == 13 && linebreakc[0] == 13) || (!crlf && c == 10 && linebreakc[0] == 10)) {
            if (state == IN_QUOTED_ESCAPING) {
                value[index++] = c;
                state = IN_QUOTED;
            }
            if (state == IN_QUOTED) {
                value[index++] = c;
            }
            else {
                /* only parse up to the first linebreak, rest is silently ignored
                 * maybe make this an exception in the future? */
                break;
            }
        }

        /* if encounter a CRLF line break */
        else if (crlf && i < len-1 && c == 10 && ptr[i+1] == 13) {
            if (state == IN_QUOTED) {
                value[index] = c;
                value[index+1] = ptr[i+1];
                index += 2;
            }
            else {
                /* only parse up to the first linebreak, rest is silently ignored
                 * maybe make this an exception in the future? */
                break;
            }
        }

        /* if we are quote in quoted, but the next character was not a quote,
         * separator, or line break (which is a syntax error, but we'll let
         * slide if we're being relaxed) */
        else if (state == QUOTE_IN_QUOTED) {
            if (mode == RELAXED || mode == C_ESCAPED_RELAXED) {
                if (!nil_quote_char) value[index++] = quotec[0];
                value[index++] = c;
                state = IN_QUOTED;
            }
            else {
                rb_raise(rb_eRuntimeError, "CSV syntax error, improperly escaped quote: %s", ptr);
            }
        }

        /* regular escape sequences */
        else if (state == IN_QUOTED_ESCAPING) {
            switch(c) {
                case 'n':
                    value[index++] = '\n';
                    break;
                case 'r':
                    value[index++] = '\r';
                    break;
                case 't':
                    value[index++] = '\t';
                    break;
                case '\'':
                case '"':
                case '?':
                case '\\':
                    value[index++] = c;
                    break;
                default:
                    value[index++] = C_ESCAPE_CHAR;
                    value[index++] = c;
            }
            state = IN_QUOTED;
        }

        /* regular characters */
        else {
            value[index++] = c;
        }

    }

    /* last field in the input */
    if (state == IN_QUOTED_ESCAPING) {
        rb_raise(rb_eRuntimeError, "CSV syntax error, cannot end line on an incomplete escape: %s", ptr);
    }
    else if (state == UNQUOTED) {
        if (index == 0) {
            rb_ary_push(array, Qnil);
        }
        else {
            field = rb_str_new(value, index);
            rb_enc_associate_index(field, default_encoding);
            rb_ary_push(array, field);
        }
    }
    else {
        field = rb_str_new(value, index);
        rb_enc_associate_index(field, default_encoding);
        rb_ary_push(array, field);
    }

    free(value);
    rb_ary_push(output, array);

    /* we have an incomplete row if we're IN_QUOTED */
    if (state == IN_QUOTED) {
        rb_ary_push(output, Qfalse);
    }
    else {
        rb_ary_push(output, Qtrue);
    }

    return output;
}

static VALUE generate_line(VALUE self, VALUE array,
                           VALUE sep_char, VALUE quote_char, VALUE linebreak_char,
                           VALUE force_quotes, VALUE escape_char) {

    char c;
    char *array_str_val, *converted_val;
    int quoting;
    long array_i, raw_i, converted_i, array_str_val_len;
    VALUE array_val, result;
    ID to_s = rb_intern("to_s");

    const char *sepc;
    const char *quotec;
    const char *escapec;
    const char *linebreakc;

    int crlf;
    int force_q;
    int default_encoding = rb_enc_find_index(DEFAULT_STRING_ENCODING);

    /* input verification */

    if (NIL_P(sep_char))
        rb_raise(rb_eArgError, "sep_char may not be nil");
    sepc = RSTRING_PTR(sep_char);

    if (NIL_P(quote_char))
        rb_raise(rb_eArgError, "quote_char may not be nil");
    quotec = RSTRING_PTR(quote_char);

    if (NIL_P(escape_char))
        rb_raise(rb_eArgError, "escape_char may not be nil");
    escapec = RSTRING_PTR(escape_char);

    linebreakc = RSTRING_PTR(linebreak_char);
    crlf = strcmp(linebreakc, "\r\n") == 0 ? 1 : 0;

    if (TYPE(array) != T_ARRAY)
        rb_raise(rb_eTypeError, "first argument must be an array");

    switch (force_quotes) {
        case Qtrue:
            force_q = 1;
            break;
        case Qfalse:
            force_q = 0;
            break;
        default:
            rb_raise(rb_eTypeError, "force_quotes should be true or false");
            break;
    }

    result = rb_str_new_cstr("");
    for (array_i = 0; array_i < RARRAY_LEN(array); array_i++) {

        quoting = force_q;
        array_val = rb_ary_entry(array, array_i);

        if (TYPE(array_val) != T_STRING) {
            array_val = rb_funcall(array_val, to_s, 0);
        }

        array_str_val = StringValuePtr(array_val);
        array_str_val_len = RSTRING_LEN(array_val);

        /* malloc: at most
         *   2*length (every character doubled)
         *   + 2 (delims)
         *   + 1 (possible leading separator char)
         */

        converted_val = (char *)malloc(array_str_val_len * sizeof(char) * 2 + 1);
        if (converted_val == NULL)
            rb_raise(rb_eNoMemError, "could not allocate memory for converted field value");

        converted_i = 2;
        raw_i = 0;

        while (raw_i < array_str_val_len) {
            c = array_str_val[raw_i];
            /* if not quoting and quote_char, sep, or line break, we need to
             * start quoting
             */
            if (!quoting && (c == quotec[0] || c == sepc[0] || c == 13 || c == 10)) {
                quoting = 1;
            }
            /* if quote_char, escape it */
            if (c == quotec[0]) {
                converted_val[converted_i] = escapec[0];
                converted_val[converted_i+1] = c;
                converted_i += 2;
            }
            /* else just add it */
            else {
                converted_val[converted_i] = c;
                converted_i += 1;
            }
            raw_i++;
        }

        /* depending on quoting and whether or not we need to append the
         * leading separator, strcpy from different points in converted_val
         */

        if (quoting) {
            converted_val[1] = quotec[0];
            converted_val[converted_i] = quotec[0];
            if (array_i > 0) {
                converted_val[0] = sepc[0];
                result = rb_str_cat(result, converted_val, converted_i+1);
            }
            else {
                result = rb_str_cat(result, &converted_val[1], converted_i);
            }

        }
        else {
            if (array_i > 0) {
                converted_val[1] = sepc[0];
                result = rb_str_cat(result, &converted_val[1], converted_i-1);
            }
            else {
                result = rb_str_cat(result, &converted_val[2], converted_i-2);
            }
        }

        free(converted_val);
    }

    result = rb_str_cat2(result, linebreakc);
    rb_enc_associate_index(result, default_encoding);
    return result;

}

void Init_csv_parser()
{
    mCsvParser = rb_define_module("CsvParser");
    rb_define_module_function(mCsvParser, "parse_line", parse_line, 6);
    rb_define_module_function(mCsvParser, "generate_line", generate_line, 6);
}
