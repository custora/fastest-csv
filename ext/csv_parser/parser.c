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

typedef enum modes {STRICT, RELAXED} grammar_mode_t;

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
 *   grammar_code: if 0, strict CSV syntax rules are followed; if 1, single
 *     occurrences of quote_char in unquoted fields are interpreted as ordinary
 *     characters
 *   start_in_quoted: if nonzero, will start reading the line as if it were
 *     quoted; used to read lines whose contents are continuations of previous
 *     lines (due to linebreaks in the middle of a quoted field)
 */

static VALUE parse_line(VALUE self, VALUE str,
                        VALUE sep_char, VALUE quote_char, VALUE linebreak_char,
                        VALUE grammar_code, VALUE start_in_quoted) {

    VALUE output = rb_ary_new2(2);
    VALUE array = rb_ary_new2(DEF_ARRAY_LEN);

    int state = UNQUOTED;
    int index = 0;
    int i;
    char c;

    const char *sepc       = RSTRING_PTR(sep_char);
    const char *quotec     = RSTRING_PTR(quote_char);
    const char *linebreakc = RSTRING_PTR(linebreak_char);
    const char *ptr        = RSTRING_PTR(str);

    grammar_mode_t mode;

    if (!FIXNUM_P(grammar_code))
        rb_raise(rb_eArgError, "grammar_code must be 0 or 1");

    switch(FIX2INT(grammar_code)) {
        case 0:
            mode = STRICT;
            break;
        case 1:
            mode = RELAXED;
            break;
    }

    int crlf = strcmp(linebreakc, "\r\n") == 0 ? 1 : 0;

    int len = (int) RSTRING_LEN(str);  /* cast to prevent warning in 64-bit OS */
    char *value = (char *)malloc(len * sizeof(char) + 1);
    if (value == NULL)
        rb_raise(rb_eNoMemError, "could not allocate memory for parsed field value");

    if (NIL_P(str) || NIL_P(sepc) || NIL_P(quotec) || len == 0) {
        rb_ary_push(output, Qnil);
        rb_ary_push(output, Qtrue);
        return output;
    }

    if (FIX2INT(start_in_quoted) != 0)
        state = IN_QUOTED;

    for (i = 0; i < len; i++)
    {
        c = ptr[i];

        /* if encounter a separator */
        if (c == sepc[0]) {
            if (state == UNQUOTED) {
                /* start new field */
                rb_ary_push(array, (index == 0 ? Qnil: rb_str_new(value, index)));
                index = 0;
            }
            else if (state == IN_QUOTED) {
                value[index++] = c;
            }
            else if (state == QUOTE_IN_QUOTED) {
                /* start new field */
                rb_ary_push(array, rb_str_new(value, index));
                index = 0;
                state = UNQUOTED;
            }
        }

        /* if encounter a quote */
        else if (c == quotec[0]) {
            if (state == UNQUOTED && index == 0) {
                /* opening quote */
                state = IN_QUOTED;
            }
            else if (state == UNQUOTED && mode == RELAXED) {
                /* incorrectly placed quote in unquoted field, but in relaxed mode */
                value[index++] = c;
            }
            else if (state == IN_QUOTED) {
                /* start of possible quote termination or escape */
                state = QUOTE_IN_QUOTED;
            }
            else if (state == QUOTE_IN_QUOTED) {
                /* quote escape completed */
                value[index++] = c;
                state = IN_QUOTED;
            }
            else {
                rb_raise(rb_eRuntimeError, "CSV syntax error (strict grammar): %s", ptr);
            }
        }

        /* if encounter a single-char line break (CR or LF) */
        else if ((c == 13 && linebreakc[0] == 13) || (!crlf && c == 10 && linebreakc[0] == 10)) {
            if (state == IN_QUOTED) {
                value[index++] = c;
            }
            else {
                /* only parse up to the first linebreak, rest is silently ignored
                 * maybe make this an exception in the future? */
                i = len;
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
                i = len;
            }
        }

        /* if we are quote in quoted, but the next character was not a quote,
         * separator, or line break (which is a syntax error, but we'll let
         * slide if we're being relaxed) */
        else if (state == QUOTE_IN_QUOTED) {
            if (mode == RELAXED) {
                value[index++] = quotec[0];
                value[index++] = c;
            }
            else {
                rb_raise(rb_eRuntimeError, "CSV syntax error (strict grammar): %s", ptr);
            }
        }

        else {
            value[index++] = c;
        }

    }

    if (state == UNQUOTED) {
        rb_ary_push(array, (index == 0 ? Qnil: rb_str_new(value, index)));
        rb_ary_push(output, array);
        rb_ary_push(output, Qtrue);
    }
    else if (state == QUOTE_IN_QUOTED) {
        rb_ary_push(array, rb_str_new(value, index));
        rb_ary_push(output, array);
        rb_ary_push(output, Qtrue);
    }
    else {
        rb_ary_push(array, rb_str_new(value, index));
        rb_ary_push(output, array);
        rb_ary_push(output, Qfalse);
    }

    free(value);
    return output;
}

static VALUE generate_line(VALUE self, VALUE array,
                           VALUE sep_char, VALUE quote_char, VALUE linebreak_char,
                           VALUE force_quotes) {

    char c;
    char *array_str_val, *converted_val;
    int quoting;
    long array_i, raw_i, converted_i, array_str_val_len;
    VALUE array_val, result;

    const char *sepc       = RSTRING_PTR(sep_char);
    const char *quotec     = RSTRING_PTR(quote_char);
    const char *linebreakc = RSTRING_PTR(linebreak_char);

    int crlf = strcmp(linebreakc, "\r\n") == 0 ? 1 : 0;
    int force_q;

    if (NIL_P(sepc))
        return Qnil;
    if (NIL_P(quotec))
        return Qnil;

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

        if (TYPE(array_val) == T_STRING || TYPE(array_val) == T_NIL) {

            if (TYPE(array_val) == T_STRING) {
                array_str_val = StringValuePtr(array_val);
                array_str_val_len = RSTRING_LEN(array_val);
            }
            else {
                array_str_val = "";
                array_str_val_len = 0;
            }

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
                /* if quote_char, dupe it */
                if (c == quotec[0]) {
                    converted_val[converted_i] = c;
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

        else {
            rb_raise(rb_eTypeError, "array should only contain strings or nil");
        }

    }

    result = rb_str_cat2(result, linebreakc);
    return result;

}

void Init_csv_parser()
{
    mCsvParser = rb_define_module("CsvParser");
    rb_define_module_function(mCsvParser, "parse_line", parse_line, 6);
    rb_define_module_function(mCsvParser, "generate_line", generate_line, 5);
}
