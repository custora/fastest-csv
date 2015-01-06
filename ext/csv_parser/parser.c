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

static VALUE mCsvParser;

static VALUE parse_line(VALUE self, VALUE str, VALUE sep, VALUE quote_char) {

    VALUE array = rb_ary_new2(DEF_ARRAY_LEN);
    int state = 0;
    int index = 0;
    int i;
    char c;

    const char *sepc = RSTRING_PTR(sep);
    const char *quotec = RSTRING_PTR(quote_char);
    const char *ptr = RSTRING_PTR(str);

    int len = (int) RSTRING_LEN(str);  /* cast to prevent warning in 64-bit OS */
    char *value = (char *)malloc(len * sizeof(char) + 1);
    if (value == NULL)
        rb_raise(rb_eNoMemError, "could not allocate memory for parsed field value");

    if (NIL_P(str))
        return Qnil;
    if (NIL_P(sepc))
        return Qnil;
    if (NIL_P(quotec))
        return Qnil;

    if (len == 0)
        return Qnil;

    for (i = 0; i < len; i++)
    {
        c = ptr[i];
        /* if separator */
        if(c == sepc[0])
        {
            if (state == UNQUOTED) {
                rb_ary_push(array, (index == 0 ? Qnil: rb_str_new(value, index)));
                index = 0;
            }
            else if (state == IN_QUOTED) {
                value[index++] = c;
            }
            else if (state == QUOTE_IN_QUOTED) {
                rb_ary_push(array, rb_str_new(value, index));
                index = 0;
                state = UNQUOTED;
            }
        /* if encounter a quote */
        } else if (c == quotec[0]) {
            if (state == UNQUOTED) {
                state = IN_QUOTED;
            }
            else if (state == 1) {
                state = QUOTE_IN_QUOTED;
            }
            else if (state == QUOTE_IN_QUOTED) {
                value[index++] = c;  /* escaped quote */
                state = IN_QUOTED;
            }
        /* if encounter a line break */
        } else if (c == 13 || c == 10) {
            if (state == IN_QUOTED) {
                value[index++] = c;
            }
            else {
                i = len;  /* only parse first line if multiline */
            }
        /* not a special character */
        } else {
            value[index++] = c;
        }
    }

    if (state == UNQUOTED) {
        rb_ary_push(array, (index == 0 ? Qnil: rb_str_new(value, index)));
    }
    else if (state == QUOTE_IN_QUOTED) {
        rb_ary_push(array, rb_str_new(value, index));
    }

    free(value);
    return array;
}

static VALUE generate_line(VALUE self, VALUE array, VALUE sep, VALUE quote_char, VALUE force_quote) {

    char *c, *array_str_val, *converted_val;
    int quoting;
    long array_i, converted_i, array_str_val_len;
    VALUE array_val, result;

    const char *sepc = RSTRING_PTR(sep);
    const char *quotec = RSTRING_PTR(quote_char);

    int force_q;

    if (NIL_P(sepc))
        return Qnil;
    if (NIL_P(quotec))
        return Qnil;

    if (TYPE(array) != T_ARRAY)
        rb_raise(rb_eTypeError, "first argument must be an array");


    switch (force_quote) {
        case Qtrue:
            force_q = 1;
            break;
        case Qfalse:
            force_q = 0;
            break;
        default:
            rb_raise(rb_eTypeError, "force_quote should be true or false");
            break;
    }

    result = rb_str_new_cstr("");
    for (array_i = 0; array_i < RARRAY_LEN(array); array_i++) {

        quoting = force_q;
        array_val = rb_ary_entry(array, array_i);

        if (TYPE(array_val) == T_STRING || TYPE(array_val) == T_NIL) {

            if (TYPE(array_val) == T_STRING) {
                array_str_val = StringValueCStr(array_val);
                array_str_val_len = RSTRING_LEN(array_val) + 1;
            }
            else {
                array_str_val = "";
                array_str_val_len = 1;
            }

            /* malloc: at most
             *   2*(length-1) (every character doubled except null terminator)
             *   + 2 (delims)
             *   + 1 (possible leading separator char)
             */

            converted_val = (char *)malloc(array_str_val_len * sizeof(char) * 2 + 1);
            if (converted_val == NULL)
                rb_raise(rb_eNoMemError, "could not allocate memory for converted field value");

            converted_i = 2;

            c = array_str_val;
            while (*c) {
                /* if not quoting and quote_char, sep, or line break, we need to
                 * start quoting 
                 */
                if (!quoting && (*c == quotec[0] || *c == sepc[0] || *c == 13 || *c == 10)) {
                    quoting = 1;
                }
                /* if quote_char, dupe it */
                if (*c == quotec[0]) {
                    converted_val[converted_i] = *c;
                    converted_val[converted_i+1] = *c;
                    converted_i += 2;
                }
                /* else just add it */
                else {
                    converted_val[converted_i] = *c;
                    converted_i += 1;
                }
                c++;
            }
            converted_val[converted_i] = '\0';

            /* depending on quoting and whether or not we need to append the
             * leading separator, strcpy from different points in converted_val
             */

            if (quoting) {
                converted_val[1] = quotec[0];
                converted_val[converted_i] = quotec[0];
                converted_val[converted_i+1] = '\0';
                if (array_i > 0) {
                    converted_val[0] = sepc[0];
                    result = rb_str_cat2(result, converted_val);
                }
                else {
                    result = rb_str_cat2(result, &converted_val[1]);
                }

            }
            else {
                converted_val[converted_i] = '\0';
                if (array_i > 0) {
                    converted_val[1] = sepc[0];
                    result = rb_str_cat2(result, &converted_val[1]);
                }
                else {
                    result = rb_str_cat2(result, &converted_val[2]);
                }
            }

            free(converted_val);

        }

        else {
            rb_raise(rb_eTypeError, "array should only contain strings or nil");
        }

    }

    return result;

}

void Init_csv_parser()
{
    mCsvParser = rb_define_module("CsvParser");
    rb_define_module_function(mCsvParser, "parse_line", parse_line, 3);
    rb_define_module_function(mCsvParser, "generate_line", generate_line, 4);
}
