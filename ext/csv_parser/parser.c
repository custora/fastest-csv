/*
 * Copyright (c) Maarten Oelering, BrightCode BV
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

/*
static VALUE cFastestCSV;
*/
static VALUE mCsvParser;

static VALUE parse_line(VALUE self, VALUE str, VALUE sep, VALUE quote_char)
{
    if (NIL_P(str))
        return Qnil;

    const char *sepc = RSTRING_PTR(sep);
    if (NIL_P(sepc))
        return Qnil;

    const char *quotec = RSTRING_PTR(quote_char);
    if (NIL_P(quotec))
        return Qnil;

    const char *ptr = RSTRING_PTR(str);
    int len = (int) RSTRING_LEN(str);  /* cast to prevent warning in 64-bit OS */
    if (len == 0)
        return Qnil;

    VALUE array = rb_ary_new2(DEF_ARRAY_LEN);
    char value[len];  /* field value, no longer than line */
    int state = 0;
    int index = 0;
    int i;
    char c;

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
    return array;
}

static VALUE generate_line(VALUE self, VALUE array, VALUE sep, VALUE quote_char, VALUE force_quote) {

    const char *sepc = RSTRING_PTR(sep);
    if (NIL_P(sepc))
        return Qnil;

    const char *quotec = RSTRING_PTR(quote_char);
    if (NIL_P(quotec))
        return Qnil;

    if (TYPE(array) != T_ARRAY)
        rb_raise(rb_eTypeError, "first argument must be an array");

    int force_q;
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

    char *line = (char *)malloc(100 * sizeof(char)); /* fix this */
    if (line == NULL)
        rb_raise(rb_eNoMemError, "could not allocate memory for new line");

    char *c, *array_str_val, *unquoted_val;
    int quoting;
    long i, len, unquoted_len;
    VALUE array_val, result;

    len = 0;
    for (i = 0; i < RARRAY_LEN(array); i++) {

        if (i > 0) {
            line[len] = sepc[0];
            len += 1;
        }

        quoting = force_q;
        array_val = rb_ary_entry(array, i);

        if (TYPE(array_val) == T_STRING) {

            array_str_val = StringValueCStr(array_val);
            unquoted_val = (char *)malloc(sizeof(array_str_val) * 2 + 1);  /* at most 2*length (every character doubled) + 2 (delims) - 1 (null terminator not duped) */
            unquoted_len = 0;
            c = array_str_val;

            while (*c) {
                /* if not quoting and quote_char or sep, need to start quoting */
                if (!quoting && (*c == quotec[0] || *c == sepc[0])) {
                    quoting = 1;
                }
                /* if quote_char, dupe it */
                if (*c == quotec[0]) {
                    unquoted_val[unquoted_len] = *c;
                    unquoted_val[unquoted_len+1] = *c;
                    unquoted_len += 2;
                }
                /* else just add it */
                else {
                    unquoted_val[unquoted_len] = *c;
                    unquoted_len += 1;
                }
                c++;
            }
            unquoted_val[unquoted_len] = '\0';

            if (quoting) {
                line[len] = quotec[0];
                strcpy(&line[len+1], unquoted_val);
                line[len+unquoted_len+1] = quotec[0];
                len += unquoted_len+2;
            }
            else {
                strcpy(&line[len], unquoted_val);
                len += unquoted_len;
            }

            free(unquoted_val);

        }

        else if (TYPE(array_val) == T_NIL) {
            /* output either nothing or just the separators */
            if (quoting) {
                line[len] = quote_char;
                line[len+1] = quote_char;
                len += 2;
            }
        }
        else {
            rb_raise(rb_eTypeError, "array should only contain strings or nil");
        }

    }

    line[len] = '\0';
    result = rb_str_new(line, len);
    free(line);

    return result;

}

static VALUE escapable_chars_including_comma(VALUE self, VALUE str)
{
    if (NIL_P(str))
        return Qnil;

    const char *ptr = RSTRING_PTR(str);
    const char *e = RSTRING_END(str);

    while (ptr < e) {
        if(*ptr == ',' || *ptr == '"' || *ptr == '\\' || *ptr == '\n' || *ptr == '\r')
            return Qtrue;

        ptr++;
    }

    return Qfalse;
}

static VALUE escapable_chars_not_comma(VALUE self, VALUE str)
{
    if (NIL_P(str))
        return Qnil;

    const char *ptr = RSTRING_PTR(str);
    const char *e = RSTRING_END(str);

    while (ptr < e) {
        if(*ptr == '"' || *ptr == '\\' || *ptr == '\n' || *ptr == '\r')
            return Qtrue;

        ptr++;
    }

    return Qfalse;
}

void Init_csv_parser()
{
    /*
    cFastestCSV = rb_define_class("FastestCSV", rb_cObject);
    rb_define_singleton_method(cFastestCSV, "parse_line", parse_line, 1);
    */
    mCsvParser = rb_define_module("CsvParser");
    rb_define_module_function(mCsvParser, "parse_line", parse_line, 3);
    rb_define_module_function(mCsvParser, "generate_line", generate_line, 4);
    rb_define_module_function(mCsvParser, "escapable_chars_including_comma?", escapable_chars_including_comma, 1);
    rb_define_module_function(mCsvParser, "escapable_chars_not_comma?", escapable_chars_not_comma, 1);
}
