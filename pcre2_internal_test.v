module pcre2

import strings

fn test_find_match() {
	mut r := compile(r'foo')!
	mut m := r.find_match('baz foo bar', 0)?
	assert m.ovector.len == 1 * 2
	assert m.ovector == [4, 7]

	if _ := r.find_match('', 1) {
		assert false, 'should have returned none'
	}

	if _ := r.find_match('', 0) {
		assert false, 'should have returned none'
	}

	if _ := r.find_match('baz foo bar', 5) {
		assert false, 'should have returned none'
	}

	m = r.find_match('baz foo bar', 4)?
	assert m.ovector.len == 1 * 2
	assert m.ovector == [4, 7]

	r = compile(r'x|(y)|(z)')!
	m = r.find_match('az', 0)?
	assert m.ovector.len == 3 * 2
	assert m.ovector == [1, 2, -1, -1, 1, 2]

	r = compile(r'x|(y)|(?<foo>z)')! // Named groups are included in the ovector.
	m = r.find_match('az', 0)?
	assert m.ovector.len == 3 * 2
	assert m.ovector == [1, 2, -1, -1, 1, 2]

	r = compile('\x00')!
	m = r.find_match('x\x00z', 0)?
	assert m.ovector.len == 1 * 2
	assert m.ovector == [1, 2]

	/*
	This pattern generates a `match limit exceeded` error (-47) when searching a string starting with `.`
	The exact same pattern works in Go and TypeScript/JavaScript.
	Looks like a PCRE2 bug as it's unlikely the match limit has been exceeded (see https://stackoverflow.com/a/33928343/1136455).
	*/
	r = compile(r'^\\?\.((?:\s*[a-zA-Z][\w\-]*)+)*(?:\s*)?(#[a-zA-Z][\w\-]*\s*)?(?:\s*)?(?:"(.+?)")?(?:\s*)?(\[.+])?(?:\s*)?([+-][ \w+-]+)?$')!
	_ := r.find_match('.x', 0)? // Valid match

	/*
	This triggers a PCRE2 error -47 but V can't recover from (catch) panics so we can't test it.
	if _ := r.find_match('.xxxxxxxxxxxxx = ', 0) { // Triggers PCRE2 error -47
		assert false, 'should have returned error'
	} else {
		assert err !is none, 'should not have returned none'
		assert err.msg() == r'pcre2_match(): pattern: "^\\?\.((?:\s*[a-zA-Z][\w\-]*)+)*(?:\s*)?(#[a-zA-Z][\w\-]*\s*)?(?:\s*)?(?:"(.+?)")?(?:\s*)?(\[.+])?(?:\s*)?([+-][ \w+-]+)?$": error -47 "match limit exceeded"'
	}
	*/

	if _ := r.find_match('.x = ', 0) { // Does not match (returns none)
		assert false, 'should have returned none'
	} else {
		assert err is none, 'should have returned none'
	}
}

fn test_get_and_get_all() {
	mut r := compile(r'x|(y)|(z)')!
	mut m := r.find_match('az', 0)?
	assert m.get(0)? == 'z'
	assert m.get(1)? == ''
	assert m.get(2)? == 'z'
	assert m.get(-1) or { 'ERR' } == 'ERR'
	assert m.get(3) or { 'ERR' } == 'ERR'
	assert m.get_all() == ['z', '', 'z']
}

fn test_replace_matches() {
	assert replace_matches('$$ $0 $99', []) == '$ $0 $99'
	assert replace_matches('$$ $$0 $0 $1 $2 $100', ['x', 'y']) == '$ $0 x y $2 $100'
}

/*
Tests for Regex methods that have been retired as private (they may be exposed in the future)
*/

fn test_substitute() {
	mut r := compile(r'baz')!
	mut s := r.substitute('', 0, 'foo', 0)!
	assert s == ''

	s = r.substitute('baz bar', 0, 'foo', 0)!
	assert s == 'foo bar'

	s = r.substitute('foobar', 0, 'foo', 0)!
	assert s == 'foobar'

	s = r.substitute('baz baz', 0, 'foo', 0)!
	assert s == 'foo baz'

	s = r.substitute('baz baz', 0, 'foo', C.PCRE2_SUBSTITUTE_GLOBAL)!
	assert s == 'foo foo'

	s = r.substitute(strings.repeat_string('foo', 1024) + 'baz', 0, 'foo', 0)!
	assert s == strings.repeat_string('foo', 1025)

	if _ := r.substitute('baz bar', 0, '$', 0) {
		assert false, 'should have returned an error'
	} else {
		assert err.msg() == 'pcre2_substitute(): pattern: "baz": error -35 "invalid replacement string" at offset 1'
	}
}

fn test_find_n_index() {
	mut r := must_compile(r'x([yz])')
	assert r.find_n_index('', 1).len == 0
	assert r.find_n_index('an xyz', 1) == [[3, 5, 4, 5]]
	assert r.find_n_index('an xyz', 2) == [[3, 5, 4, 5]]
	assert r.find_n_index('an xy and xz', 2) == [[3, 5, 4, 5],
		[10, 12, 11, 12]]
}

fn test_find_n_submatch() {
	mut r := must_compile(r'x([yz])')
	assert r.find_n_submatch('', 1).len == 0
	assert r.find_n_submatch('an xyz', 1) == [['xy', 'y']]
	assert r.find_n_submatch('an xyz', 2) == [['xy', 'y']]
	assert r.find_n_submatch('an xy and xz', 2) == [['xy', 'y'],
		['xz', 'z']]
}

fn test_find_n() {
	mut r := must_compile(r'\d')
	assert r.find_n('abcdeg', -1) == []
	assert r.find_n('abcde5g', -1) == ['5']
	assert r.find_n('1 abc 9 de 5 g', -1) == ['1', '9', '5']
	assert r.find_n('1 abc 9 de 5 g', -1)[0] == '1'
	assert r.find_n('1 abc 9 de 5 g', -1)[1] == '9'
	assert r.find_n('1 abc 9 de 5 g', -1)[2] == '5'
	assert r.find_n('1 abc 9 de 5 g', 0) == []
	assert r.find_n('1 abc 9 de 5 g', 1) == ['1']
	assert r.find_n('1 abc 9 de 5 g', 2) == ['1', '9']
	assert r.find_n('1 abc 9 de 5 g', 3) == ['1', '9', '5']
	assert r.find_n('1 abc 9 de 5 g', 4) == ['1', '9', '5']
	assert must_compile(r'\d').find_n('1 abc 9 de 5 g', -1) == ['1', '9', '5']
}

fn test_replace_n_submatch_fn() {
	mut r := must_compile(r'x')

	assert r.replace_n_submatch_fn('', fn (m []string) string {
		return m[0] + 'yz'
	}, -1) == ''

	assert r.replace_n_submatch_fn('x', fn (_ []string) string {
		return 'foo✅'
	}, -1) == 'foo✅'

	assert r.replace_n_submatch_fn('y', fn (_ []string) string {
		return 'foo'
	}, -1) == 'y'

	assert r.replace_n_submatch_fn('xz', fn (m []string) string {
		return m[0] + 'y'
	}, -1) == 'xyz'

	r = must_compile(r'(([a-z]+)(\d+))')
	assert r.replace_n_submatch_fn('456 xyz123', fn (m []string) string {
		return '${m[2]} ${m[3]} ${m[1]}'
	}, -1) == '456 xyz 123 xyz123'

	assert r.replace_n_submatch_fn('xyz123 ab98', fn (m []string) string {
		return '${m[1]} ${m[3]} ${m[2]}'
	}, -1) == 'xyz123 123 xyz ab98 98 ab'

	r = must_compile(r'x|(y)|(z)')
	assert r.replace_n_submatch_fn('x', fn (m []string) string {
		return '${m[1]}'
	}, -1) == ''

	assert r.replace_n_submatch_fn('y', fn (m []string) string {
		return '${m[1]}'
	}, -1) == 'y'

	assert r.replace_n_submatch_fn('z', fn (m []string) string {
		return '${m[2]}'
	}, -1) == 'z'
}

fn test_replace_n_fn() {
	mut r := must_compile(r'(x|y|z)')
	assert r.replace_n_fn('z yx', fn (m string) string {
		return '<${m}>'
	}, -1) == '<z> <y><x>'
}

fn test_replace_n() {
	mut r := must_compile(r'(x|y|z)')
	assert r.replace_n('z y x', '"$1"', -1) == '"z" "y" "x"'
	assert r.replace_n('z y x', '"$1"', 0) == 'z y x'
	assert r.replace_n('z y x', '"$1"', 1) == '"z" y x'
	assert r.replace_n('z y x', '"$1"', 2) == '"z" "y" x'
	assert r.replace_n('z y x', '"$1"', 3) == '"z" "y" "x"'
	assert r.replace_n('z y x', '"$1"', 4) == '"z" "y" "x"'
	r = must_compile(r'x|(y)|(z)')
	assert r.replace_n('z yx', '$$$1 $2$$', -1) == '$ z$ \$y $$ $'
	r = must_compile(r'✅')
	assert r.replace_n('✅ ✅✅', '🚀', 2) == '🚀 🚀✅'
}
