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

static VALUE parse_line(VALUE self, VALUE str, VALUE sep)
{
    const char *sepc = RSTRING_PTR(sep);
    if (NIL_P(str))
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
        } else if (c == '"') {
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

static VALUE escapable_chars(VALUE self, VALUE str)
{
    if (NIL_P(str))
        return Qnil;
    
    const char *ptr = RSTRING_PTR(str);
    int len = (int) RSTRING_LEN(str);  /* cast to prevent warning in 64-bit OS */

    if (len == 0)
        return Qnil;

    char c;

    for (int i = 0; i < len; i++)
    {
        c = ptr[i];
        //,|\"|\\|\n|\r
        if(c == ',' || c == '"' || c == '\\' || c == '\n' || c == '\r')
        {
            return Qtrue;
        }
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
    rb_define_module_function(mCsvParser, "parse_line", parse_line, 2);
    rb_define_module_function(mCsvParser, "escapable_chars", escapable_chars, 1);
}
