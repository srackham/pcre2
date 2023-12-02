module pcre2

#flag windows -I C:\msys64\mingw64\include
#flag windows -L C:\msys64\mingw64\bin
#flag windows -lpcre2-8-0

#flag linux -lpcre2-8

#flag darwin -lpcre2-8
#flag darwin -I /opt/homebrew/include/
#flag darwin -L /opt/homebrew/lib

#define PCRE2_CODE_UNIT_WIDTH 8
#include "pcre2.h"

@[typedef]
struct C.pcre2_code {}

@[typedef]
struct C.pcre2_match_data {}

@[typedef]
struct C.pcre2_match_context {}

@[typedef]
struct C.pcre2_compile_context {}

fn C.pcre2_code_free(code &C.pcre2_code)
fn C.pcre2_compile(pattern &u8, length usize, options u32, errorcode &int, erroroffset &usize, ccontext &pcre2_compile_context) &C.pcre2_code
fn C.pcre2_get_error_message(errorcode int, buffer &u8, bufflen usize) int
fn C.pcre2_get_ovector_pointer(match_data &C.pcre2_match_data) &usize
fn C.pcre2_match(code &C.pcre2_code, subject &u8, length usize, startoffset usize, options u32, match_data &C.pcre2_match_data, mcontext &C.pcre2_match_context) int
fn C.pcre2_match_context_create(gcontext &C.pcre2_general_context) &C.pcre2_match_context
fn C.pcre2_match_data_create_from_pattern(code &C.pcre2_code, gcontext &pcre2_general_context) &C.pcre2_match_data
fn C.pcre2_match_data_free(match_data &C.pcre2_match_data)
fn C.pcre2_pattern_info(code &C.pcre2_code, what u32, where voidptr) int
fn C.pcre2_set_depth_limit(mcontext &C.pcre2_match_context, value u32) int
fn C.pcre2_set_match_limit(mcontext &C.pcre2_match_context, value u32) int
fn C.pcre2_substitute(code &C.pcre2_code, subject &u8, length usize, startoffset usize, options i32, match_data &C.pcre2_match_data, mcontext &C.pcre2_match_context, replacement &u8, rlength usize, outputbuffer &u8, outlengthptr &usize) int
