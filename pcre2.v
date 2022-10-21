module pcre2

import strings

// `Regex` contains the compiled regular expression.
// * `pattern` is the regular expression pattern.
// * `subpattern_count` is the number of capturing subpatterns.
// * `re` is a pointer to the compiled PCRE2 regular expression.
pub struct Regex {
	pattern          string
	subpattern_count int
mut:
	re &C.pcre2_code
}

// `str` returns a human readable representation of a `Regex`.
pub fn (r Regex) str() string {
	return 'RegEx{ pattern: $r.pattern, subpattern_count: $r.subpattern_count, re: 0x${u64(r.re).hex()} }'
}

// `MatchData` an struct containing match results; it is returned by the `Regex.find_match` method.
// * `subject` is the searched string.
// * `ovector` is an array of start/end index pairs specifying the byte offsets of the match and submatches in the `subject` string.
//	`ovector[0]` and `ovector[1]` are the start and end indexes of the entire match.
//	`ovector[2*N]` and `ovector[2*N+1]` are the start and end indexes of the Nth submatch
// * If a subpattern did not participate in the match the start and end indexes will be `-1`.
struct MatchData {
	subject string
	ovector []int
}

// `get` returns captured match and submatch strings by `number`. The number zero refers to the entire match, with numbers 1.. referring to parenthesized subpatterns.
// * Returns '' if the subpattern did not participate in the match.
// * Returns an error if `number` is less than zero or greater than the total number of subpatterns.
fn (m MatchData) get(number int) ?string {
	if number < 0 || number >= m.ovector.len / 2 {
		return error('number $number is out of bounds')
	}
	if m.ovector[number * 2] < 0 {
		return ''
	}
	start := m.ovector[number * 2]
	end := m.ovector[number * 2 + 1]
	return m.subject.substr(start, end)
}

// `get_all` returns an array containing match an submatch strings:
// * The first element (at index 0) contains the the entire matched text.
// * Subsequent elements (indexes 1..) contain corresponding matched subpatterns
// * If a subpattern did not participate in the match the corresponding array element is set to ''.
fn (m MatchData) get_all() []string {
	match_count := m.ovector.len / 2
	mut matches := []string{len: match_count}
	for i in 0 .. match_count {
		matches[i] = m.get(i) or { '' }
	}
	return matches
}

// `compile` parses a regular expression `pattern` and returns the corresponding `Regexp` struct.
// If the pattern fails to parse an error is returned.
pub fn compile(pattern string) ?Regex {
	mut error_code := int(0)
	mut error_offset := usize(0)
	r := C.pcre2_compile(pattern.str, pattern.len, 0, &error_code, &error_offset, 0)
	if isnil(r) {
		buffer := []u8{len: 256}
		C.pcre2_get_error_message(error_code, buffer.data, buffer.len)
		err_msg := unsafe { cstring_to_vstring(buffer.data) }
		return error('compilation failed at offset $error_offset: $err_msg')
	}
	mut capture_count := 0
	error_code = C.pcre2_pattern_info(r, C.PCRE2_INFO_CAPTURECOUNT, &capture_count)
	if error_code != 0 {
		panic('pcre2_pattern_info() returned error code $error_code')
	}
	return Regex{pattern, capture_count, r}
}

// `must_compile` is like `compile` but panics if the regex `pattern` cannot be parsed.
pub fn must_compile(pattern string) Regex {
	r := compile(pattern) or { panic(err) }
	return r
}

// `free` disposes memory allocated to the PCRE2 compiled regex.
// If V's `-autofree` option is enabled V's autofree engine calls `free` automatically when it disposes the `Regex` struct.
pub fn (r &Regex) free() {
	C.pcre2_code_free(r.re)
	unsafe {
		r.re = nil
	}
}

// `has_match` return `true` if the `subject` string contains a match for the regular expression; if no then `false` is returned.
pub fn (r &Regex) has_match(subject string) bool {
	if _ := r.find_match(subject, 0) {
		return true
	} else {
		return false
	}
}

// `find_match` searches the `subject` string starting at index `pos` and returns a `MatchData` struct.
// If no match is found an error is returned.
fn (r &Regex) find_match(subject string, pos int) ?MatchData {
	if pos < 0 || pos >= subject.len {
		return error('search pos index out of bounds: $pos')
	}
	match_data := C.pcre2_match_data_create_from_pattern(r.re, 0)
	defer {
		C.pcre2_match_data_free(match_data)
	}
	count := C.pcre2_match(r.re, subject.str, subject.len, pos, 0, match_data, 0)
	if count < 0 {
		match count {
			C.PCRE2_ERROR_NOMATCH { return error('no match') }
			else { panic('pcre2_match() returned error code $count') }
		}
	}
	if count == 0 {
		panic('pcre2_match(): ovector was not big enough for all the subexpressions')
	}
	ovector_ptr := C.pcre2_get_ovector_pointer(match_data)
	ovector_size := (r.subpattern_count + 1) * 2
	ovector := []int{len: ovector_size}
	for i in 0 .. ovector_size {
		unsafe {
			ovector[i] = int(ovector_ptr[i])
		}
	}
	return MatchData{
		subject: subject
		ovector: ovector
	}
}

// `find_n_matchdata` returns an array of `MatchData` values from the first `n` matches in the `subject` string.
// * If `n >= 0`, then at most `n` matched indexes are returned; otherwise, all matched indexes are returned.
fn (r &Regex) find_n_matchdata(subject string, n int) []MatchData {
	mut res := []MatchData{}
	mut pos := 0
	mut count := 0
	for count < n || n < 0 {
		mut m := r.find_match(subject, pos) or { break }
		res << m
		pos = m.ovector[1]
		count++
	}
	return res
}

// `find_n` returns an array containing matched strings from the `subject` string.
// * If `n >= 0`, then at most `n` matches are returned; otherwise, all matches are returned.
// Example: assert must_compile(r'\d').find_n('1 abc 9 de 5 g', -1) == ['1', '9', '5']
fn (r &Regex) find_n(subject string, n int) []string {
	mut res := []string{}
	for m in r.find_n_matchdata(subject, n) {
		res << m.get(0) or { '' }
	}
	return res
}

// `find_all` returns an array containing all matched strings from the `subject` string.
// Example: assert must_compile(r'\d').find_all('1 abc 9 de 5 g') == ['1', '9', '5']
pub fn (r &Regex) find_all(subject string) []string {
	return r.find_n(subject, -1)
}

// `find_one` returns the first matched string from the `subject` string.
// If a match is not found an error is returned.
// Example: assert must_compile(r'\d').find_one('1 abc 9 de 5 g') == '1'
pub fn (r &Regex) find_one(subject string) ?string {
	matches := r.find_n(subject, 1)
	if matches.len == 0 {
		return error('no match')
	}
	return matches[0]
}

// `find_n_index` returns an array of `MatchData.ovector` values from the first `n` matches in the `subject` string.
// * If `n >= 0`, then at most `n` matched indexes are returned; otherwise, all matched indexes are returned.
fn (r &Regex) find_n_index(subject string, n int) [][]int {
	mut res := [][]int{}
	for m in r.find_n_matchdata(subject, n) {
		res << m.ovector
	}
	return res
}

// `find_all_index` searches `subject` for all matches and returns an array; each element of the array is an array of byte indexes identifying the match and submatches within the `subject` (see `find_one_index` for details).
pub fn (r &Regex) find_all_index(subject string) [][]int {
	return r.find_n_index(subject, -1)
}

// `find_one_index` searches `subject` for the first match and returns an array of `subject` byte indexes identifying the match and submatches.
// * `result[0]..result[1]` is the entire match.
// * `result[2*N..2*N+2]` is the Nth submatch (N = 1...).
// * If a subpattern did not participate in the match its indexes will be `-1`.
// * If no match is found an error is returned.
pub fn (r &Regex) find_one_index(subject string) ?[]int {
	m := r.find_n_index(subject, 1)
	if m.len == 0 {
		return error('no match')
	}
	return m[0]
}

// `find_n_submatch` searchs the `subject` string for regular expression matches and returns an array containing match and submatches text.
// * Each match contributes an element to the result array.
// * Each result array element is an array containing the matched text (at index 0) plus any submatches (at indexes 1..).
// * If a subpattern did not participate in the match the corresponding element is set to ''.
// * If `n >= 0`, then at most `n` matches are returned; otherwise, all matches are returned.
fn (r &Regex) find_n_submatch(subject string, n int) [][]string {
	mut res := [][]string{}
	for m in r.find_n_matchdata(subject, n) {
		res << m.get_all()
	}
	return res
}

// `find_all_submatch` searchs the `subject` string for all regular expression matches and returns an array containing match and submatches text.
// * Each match contributes an element to the result array.
// * Each result array element is an array containing the matched text (at index 0) plus any submatches (at indexes 1..).
// * If a subpattern did not participate in the match the corresponding element is set to ''.
pub fn (r &Regex) find_all_submatch(subject string) [][]string {
	return r.find_n_submatch(subject, -1)
}

// `find_one_submatch` searchs the `subject` string for the first regular expression match and returns an array containing match and submatches text.
// * The first element (at index 0) contains the the entire matched text.
// * Subsequent elements (indexes 1..) contain corresponding matched subpatterns
// * If a subpattern did not participate in the match the corresponding array element is set to ''.
// * If a match is not found an error is returned.
pub fn (r &Regex) find_one_submatch(subject string) ?[]string {
	m := r.find_n_submatch(subject, 1)
	if m.len == 0 {
		return error('no match')
	}
	return m[0]
}

// `escape_meta` returns a string that escapes all regular expression metacharacters inside the argument text. The returned string is a regular expression matching the literal text.
// Example: assert escape_meta(r'\.+*?()|[]{}^$') == r'\\\.\+\*\?\(\)\|\[\]\{\}\^\$'
pub fn escape_meta(s string) string {
	specials := r'\.+*?()|[]{}^$'.runes()
	mut b := strings.new_builder(1000)
	for c in s.runes() {
		if c in specials {
			b.write_rune(`\\`)
		}
		b.write_rune(c)
	}
	return b.str()
}

// `replace_n` returns a copy of the `subject` string in which matches of the regular expression are replaced by the `repl` string.
// * `$0`...`$99` in the `repl` string are replaced by matching text; the number zero refers to the entire matched substring; higher numbers refer to substrings captured by parenthesized subpatterns e.g. `$1` refers to the first submatch.
// * References to undefined subpatterns are not replaced.
// * Subpatterns that did not participate in the match replaced with ''.
// * To insert a literal `$` in the output, use `$$`.
// * If `n >= 0`, then at most `n` matches are replaced; otherwise, all matches are replaced.
fn (r &Regex) replace_n(subject string, repl string, n int) string {
	return r.replace_n_submatch_fn(subject, fn [repl] (matches []string) string {
		return replace_matches(repl, matches)
	}, n)
}

// `replace_all` returns a copy of the `subject` string with all matches of the regular expression replaced by the `repl` string.
// * `$0`...`$99` in the `repl` string are replaced by matching text; the number zero refers to the entire matched substring; higher numbers refer to substrings captured by parenthesized subpatterns e.g. `$1` refers to the first submatch.
// * References to undefined subpatterns are not replaced.
// * Subpatterns that did not participate in the match replaced with ''.
// * To insert a literal `$` in the output, use `$$`.
pub fn (r &Regex) replace_all(subject string, repl string) string {
	return r.replace_n(subject, repl, -1)
}

// `replace_one` returns a copy of the `subject` string in with the first match of the regular expression replaced by the `repl` string.
// In all other respects behaves like the `replace_all` method.
pub fn (r &Regex) replace_one(subject string, repl string) string {
	return r.replace_n(subject, repl, 1)
}

// `replace_n_fn` returns a copy of the `subject` string with regular expression matches replaced by the return value of the `repl` callback function.
// * The `repl` function is passed a string containing the matched text.
// * If `n >= 0`, then at most `n` matches are replaced; otherwise, all matches are replaced.
fn (r &Regex) replace_n_fn(subject string, repl fn (string) string, n int) string {
	return r.replace_n_submatch_fn(subject, fn [repl] (matches []string) string {
		return repl(matches[0])
	}, n)
}

// `replace_all_fn` returns a copy of the `subject` string with all regular expression matches replaced by the return value of the `repl` callback function.
// * The `repl` function is passed a string containing the matched text.
pub fn (r &Regex) replace_all_fn(subject string, repl fn (string) string) string {
	return r.replace_n_fn(subject, repl, -1)
}

// `replace_one_fn` returns a copy of the `subject` string with the first regular expression match replaced by the return value of the `repl` callback function.
// * The `repl` function is passed a string containing the matched text.
pub fn (r &Regex) replace_one_fn(subject string, repl fn (string) string) string {
	return r.replace_n_fn(subject, repl, 1)
}

// `replace_n_matchdata_fn` returns a copy of the `subject` string with regular expression matches replaced by the return value of the `repl` callback function.
// * The `repl` function is passed the `MatchData` struct resulting from the match.
// * If `n >= 0`, then at most `n` matches are replaced; otherwise, all matches are replaced.
fn (r &Regex) replace_n_matchdata_fn(subject string, repl fn (matchdata MatchData) string, n int) string {
	matches := r.find_n_matchdata(subject, n)
	if matches.len == 0 {
		return subject
	}
	mut b := strings.new_builder(1000)
	mut pos := 0
	for m in matches {
		b.write_string(subject[pos..m.ovector[0]])
		b.write_string(repl(m))
		pos = m.ovector[1]
	}
	b.write_string(subject[pos..])
	return b.str()
}

// `replace_n_submatch_fn` returns a copy of the `subject` string with regular expression matches replaced by the return value of the `repl` callback function.
// * The `repl` function is passed a `matches` array containing the matched text (`matches[0]`) and any submatches (`matches[1..]`).
// * If a subpattern did not participate in the match the corresponding `matches` element is set to ''.
// * If `n >= 0`, then at most `n` matches are replaced; otherwise, all matches are replaced.
fn (r &Regex) replace_n_submatch_fn(subject string, repl fn (matches []string) string, n int) string {
	return r.replace_n_matchdata_fn(subject, fn [repl] (m MatchData) string {
		return repl(m.get_all())
	}, n)
}

// `replace_all_submatch_fn` returns a copy of the `subject` string with all regular expression matches replaced by the return value of the `repl` callback function.
// * The `repl` function is passed a `matches` array containing the matched text (`matches[0]`) and any submatches (`matches[1..]`).
// * If a subpattern did not participate in the match the corresponding `matches` element is set to ''.
pub fn (r &Regex) replace_all_submatch_fn(subject string, repl fn (matches []string) string) string {
	return r.replace_n_submatch_fn(subject, repl, -1)
}

// `replace_one_submatch_fn` returns a copy of the `subject` string with the first regular expression match replaced by the return value of the `repl` callback function.
// * The `repl` function is passed a `matches` array containing the matched text (`matches[0]`) and any submatches (`matches[1..]`).
// * If a subpattern did not participate in the match the corresponding `matches` element is set to ''.
pub fn (r &Regex) replace_one_submatch_fn(subject string, repl fn (matches []string) string) string {
	return r.replace_n_submatch_fn(subject, repl, 1)
}

// `replace_matches` returns a copy of the `subject` in which `$0`...`$99` are replaced by elements with the corresponding index from matches; out of bounds matches indexes are skipped. `$$` is replaced by `$`.
fn replace_matches(subject string, matches []string) string {
	return must_compile(r'\$(\d+|\$)').replace_n_submatch_fn(subject, fn [matches] (m []string) string {
		if m[1] == '$' {
			return '$'
		} else {
			i := m[1].int()
			if i >= matches.len {
				return '$$i'
			}
			return matches[i]
		}
	}, -1)
}

// `substitute` is a wrapper for the PCRE2 `pcre2_substitute` API.
// It returns a copy of the `subject` string in which matches of the regular expression after index `pos` are replaced by the `repl` string.
// `options` is passed to the PCRE2 `pcre2_substitute` API.
// By default only the first match is replaced, use the `C.PCRE2_SUBSTITUTE_GLOBAL` option to replace all matches.
// If no matches are found the unmodified `subject` is returned.
fn (r &Regex) substitute(subject string, pos int, repl string, options int) ?string {
	mut outbuffer := []u8{len: 1024}
	outlen := usize(outbuffer.len)
	mut count := C.pcre2_substitute(r.re, subject.str, subject.len, pos, C.PCRE2_SUBSTITUTE_OVERFLOW_LENGTH | options,
		0, 0, repl.str, repl.len, outbuffer.data, &outlen)
	if count == C.PCRE2_ERROR_NOMEMORY {
		outbuffer = []u8{len: int(outlen)} // Resize the output buffer
		count = C.pcre2_substitute(r.re, subject.str, subject.len, pos, C.PCRE2_SUBSTITUTE_OVERFLOW_LENGTH | options,
			0, 0, repl.str, repl.len, outbuffer.data, &outlen)
	}
	if count < 0 {
		buffer := []u8{len: 256}
		C.pcre2_get_error_message(count, buffer.data, buffer.len)
		err_msg := unsafe { cstring_to_vstring(buffer.data) }
		if outlen == usize(C.PCRE2_UNSET) {
			return error('replacement failed: $err_msg')
		} else {
			return error('replacement failed at offset $outlen: $err_msg')
		}
	}
	if count == 0 {
		return subject
	}
	return (unsafe { byteptr(outbuffer.data).vstring_with_len(int(outlen)) }).clone()
}

// `replace_all_extended` returns a copy of the `subject` string with all matches of the regular expression replaced by the `repl` string.
// The `repl` string supports the PCRE2 extended replacements string syntax (see `PCRE2_SUBSTITUTE_EXTENDED` in the [pcre2api](https://www.pcre.org/current/doc/html/pcre2api.html) man page).
pub fn (r &Regex) replace_all_extended(subject string, repl string) string {
	return r.substitute(subject, 0, repl, C.PCRE2_SUBSTITUTE_EXTENDED | C.PCRE2_SUBSTITUTE_GLOBAL) or {
		subject
	}
}

// `replace_one_extended` returns a copy of the `subject` string with the first match of the regular expression replaced by the `repl` string.
// The `repl` string supports the PCRE2 extended replacements string syntax (see `PCRE2_SUBSTITUTE_EXTENDED` in the [pcre2api](https://www.pcre.org/current/doc/html/pcre2api.html) man page).
pub fn (r &Regex) replace_one_extended(subject string, repl string) string {
	return r.substitute(subject, 0, repl, C.PCRE2_SUBSTITUTE_EXTENDED) or { subject }
}
