module pcre2

import strings

// `Regex`is an opaque struct containing the regular expression state.
// * `pattern` is the regular expression pattern.
// * `subpattern_count` is the number of capturing subpatterns.
// * `re` is a pointer to the compiled PCRE2 regular expression.
struct Regex {
	pattern          string
	subpattern_count int
mut:
	re &C.pcre2_code
}

// `MatchData` an struct containing match results; it is returned by the `Regex.find_match` method.
// * `subject` is the searched string.
// * `ovector` is an array of start/end index pairs specifying the byte offsets of the match and submatches in the `subject` string.
//	`ovector[0]` and `ovector[1]` are the start and end indexes of the entire match.
//	`ovector[2*N]` and `ovector[2*N+1]` are the start and end indexes of the Nth submatch
// * If a subpattern did not participate in the match the start and end indexes will be `-1`.
pub struct MatchData {
	subject string
	ovector []int
}

// `compile` parses a regular expression `pattern` and returns the corresponding `Regexp` struct.
pub fn compile(pattern string) ?Regex {
	mut error_code := int(0)
	mut error_offset := usize(0)
	r := C.pcre2_compile(pattern.str, pattern.len, 0, &error_code, &error_offset, 0)
	if isnil(r) {
		buffer := []u8{len: 256}
		C.pcre2_get_error_message(error_code, &buffer[0], buffer.len)
		err_msg := unsafe { cstring_to_vstring(&char(&buffer[0])) }
		return error('PCRE2 compilation failed at offset $error_offset: $err_msg')
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

// `find_match` searches the `subject` string starting at index `pos` and returns a `MatchData` struct.
// If no match is found an error is returned.
pub fn (r &Regex) find_match(subject string, pos int) ?MatchData {
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

// `find` returns an array containing matched strings from the `subject` string.
// * If `n >= 0`, then at most `n` matches are returned; otherwise, all matches are returned.
// Example: assert must_compile(r'\d').find('1 abc 9 de 5 g', -1) == ['1', '9', '5']
pub fn (r &Regex) find(subject string, n int) []string {
	mut res := []string{}
	mut pos := 0
	for n < 0 || res.len != n {
		mut m := r.find_match(subject, pos) or { break }
		res << m.get(0) or { '' }
		pos = m.ovector[1]
	}
	return res
}

// `matches` return `true` if the `subject` string contains a match for the regular expression; if no then `false` is returned.
pub fn (r &Regex) matches(subject string) bool {
	if _ := r.find_match(subject, 0) {
		return true
	} else {
		return false
	}
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

// `get` returns captured match and submatch strings by `number`. The number zero refers to the entire match, with numbers 1.. referring to parenthesized subpatterns.
// * Returns '' if the subpattern was not captured.
// * Returns an error if `number` is less than zero or greater than the total number of subpatterns.
pub fn (m MatchData) get(number int) ?string {
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
// * If a subpattern is not matched the corresponding array element is set to ''.
pub fn (m MatchData) get_all() []string {
	match_count := m.ovector.len / 2
	mut matches := []string{len: match_count}
	for i in 0 .. match_count {
		matches[i] = m.get(i) or { '' }
	}
	return matches
}

// `replace_submatches_fn` returns a copy of the `subject` string with regular expression matches replaced by the return value of the `repl` callback function.
// * The `repl` function is passed a `matches` array containing the matched text (`matches[0]`) and any submatches (`matches[1..]`).
// * If a subpattern is not matched the corresponding `matches` element is set to ''.
// * If `n >= 0`, then at most `n` matches are replaced; otherwise, all matches are replaced.
pub fn (r &Regex) replace_submatches_fn(subject string, repl fn (matches []string) string, n int) string {
	mut b := strings.new_builder(1000)
	mut pos := 0
	mut count := 0
	for count < n || n < 0 {
		mut m := r.find_match(subject, pos) or { break }
		b.write_string(subject[pos..m.ovector[0]])
		b.write_string(repl(m.get_all()))
		pos = m.ovector[1]
		count++
	}
	if count == 0 {
		b.write_string(subject)
	} else {
		b.write_string(subject[pos..])
	}
	return b.str()
}

// `replace_fn` returns a copy of the `subject` string with regular expression matches replaced by the return value of the `repl` callback function.
// * The `repl` function is passed a string containing the matched text.
// * If `n >= 0`, then at most `n` matches are replaced; otherwise, all matches are replaced.
pub fn (r &Regex) replace_fn(subject string, repl fn (string) string, n int) string {
	return r.replace_submatches_fn(subject, fn [repl] (matches []string) string {
		return repl(matches[0])
	}, n)
}

// `replace` returns a copy of the `subject` string in which matches of the regular expression are replaced by the `repl` string.
// * `$0`...`$99` in the `repl` string are replaced by matching text; the number zero refers to the entire matched substring; higher numbers refer to substrings captured by parenthesized subpatterns e.g. `$1` refers to the first submatch.
// * References to undefined subpatterns are not replaced.
// * Subpatterns that did not participate in the match replaced with ''.
// * To insert a literal `$` in the output, use `$$`.
// * If `n >= 0`, then at most `n` matches are replaced; otherwise, all matches are replaced.
pub fn (r &Regex) replace(subject string, repl string, n int) string {
	return r.replace_submatches_fn(subject, fn [repl] (matches []string) string {
		return replace_matches(repl, matches)
	}, n)
}

// `replace_matches` returns a copy of the `subject` in which `$0`...`$99` are replaced by elements with the corresponding index from matches; out of bounds matches indexes are skipped. `$$` is replaced by `$`.
fn replace_matches(subject string, matches []string) string {
	return must_compile(r'\$(\d+|\$)').replace_submatches_fn(subject, fn [matches] (m []string) string {
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
