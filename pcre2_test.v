module pcre2

import strings

fn test_compile() {
	mut r := compile(r'foo')?
	defer {
		r.free() // Only necessary if autofree is not enabled.
	}
	assert r.subpattern_count == 0

	r = compile(r'a(b)c(d)')?
	assert r.subpattern_count == 2

	r = compile(r'^\\?\.((?:\s*[a-zA-Z][\w\-]*)+)*(?:\s*)?(#[a-zA-Z][\w\-]*\s*)?(?:\s*)?(?:"(.+?)")?(?:\s*)?(\[.+])?(?:\s*)?([+-][ \w+-]+)?$')?
	assert r.subpattern_count == 5

	if _ := compile(r'\') {
		assert false, 'should have returned an error'
	} else {
		assert err.msg() == 'compilation failed at offset 1: \\ at end of pattern'
	}
}

fn test_must_compile() {
	must_compile(r'x')
	must_compile(r'^\\?\.((?:\s*[a-zA-Z][\w\-]*)+)*(?:\s*)?(#[a-zA-Z][\w\-]*\s*)?(?:\s*)?(?:"(.+?)")?(?:\s*)?(\[.+])?(?:\s*)?([+-][ \w+-]+)?$')
}

fn test_escape_meta() {
	assert escape_meta(r'\.+*?()|[]{}^$') == r'\\\.\+\*\?\(\)\|\[\]\{\}\^\$'
	assert escape_meta(r'(🚀)') == r'\(🚀\)'
}

fn test_substitute() {
	mut r := compile(r'baz')?
	mut s := r.substitute('', 0, 'foo', 0)?
	assert s == ''

	s = r.substitute('baz bar', 0, 'foo', 0)?
	assert s == 'foo bar'

	s = r.substitute('foobar', 0, 'foo', 0)?
	assert s == 'foobar'

	s = r.substitute('baz baz', 0, 'foo', 0)?
	assert s == 'foo baz'

	s = r.substitute('baz baz', 0, 'foo', C.PCRE2_SUBSTITUTE_GLOBAL)?
	assert s == 'foo foo'

	s = r.substitute(strings.repeat_string('foo', 1024) + 'baz', 0, 'foo', 0)?
	assert s == strings.repeat_string('foo', 1025)

	if _ := r.substitute('baz bar', 0, '$', 0) {
		assert false, 'should have returned an error'
	} else {
		assert err.msg() == 'replacement failed at offset 1: invalid replacement string'
	}
}

fn test_extended() {
	mut r := compile(r'baz')?
	mut subject := 'baz baz'
	mut s := r.replace_all_extended(subject, 'foo')
	assert s == 'foo foo'
	s = r.replace_one_extended(subject, 'foo')
	assert s == 'foo baz'
	subject = 'qux'
	s = r.replace_one_extended(subject, 'foo')
	assert s == 'qux'
	s = r.replace_all_extended(subject, 'foo')
	assert s == 'qux'

	r = must_compile(r'\b([dn].*?)\b')
	subject = 'Lorem nisi dis diam a cras placerat natoque'
	s = r.replace_all_extended(subject, r'\U$1')
	assert s == 'Lorem NISI DIS DIAM a cras placerat NATOQUE'
	s = r.replace_one_extended(subject, r'\U$1')
	assert s == 'Lorem NISI dis diam a cras placerat natoque'
}

fn test_find_match() {
	mut r := compile(r'foo')?
	mut m := r.find_match('baz foo bar', 0)?
	assert m.ovector.len == 1 * 2
	assert m.ovector == [4, 7]

	if _ := r.find_match('', 0) {
		assert false, 'should have returned an error'
	} else {
		assert err.msg() == 'search pos index out of bounds: 0'
	}

	if _ := r.find_match('baz foo bar', 5) {
		assert false, 'should have returned an error'
	} else {
		assert err.msg() == 'no match'
	}

	m = r.find_match('baz foo bar', 4)?
	assert m.ovector.len == 1 * 2
	assert m.ovector == [4, 7]

	r = compile(r'x|(y)|(z)')?
	m = r.find_match('az', 0)?
	assert m.ovector.len == 3 * 2
	assert m.ovector == [1, 2, -1, -1, 1, 2]

	r = compile(r'x|(y)|(?<foo>z)')? // Named groups are included in the ovector.
	m = r.find_match('az', 0)?
	assert m.ovector.len == 3 * 2
	assert m.ovector == [1, 2, -1, -1, 1, 2]

	r = compile('\x00')?
	m = r.find_match('x\x00z', 0)?
	assert m.ovector.len == 1 * 2
	assert m.ovector == [1, 2]
}

fn test_get_and_get_all() {
	mut r := compile(r'x|(y)|(z)')?
	mut m := r.find_match('az', 0)?
	assert m.get(0)? == 'z'
	assert m.get(1)? == ''
	assert m.get(2)? == 'z'
	assert m.get(-1) or { 'ERR' } == 'ERR'
	assert m.get(3) or { 'ERR' } == 'ERR'
	assert m.get_all() == ['z', '', 'z']
}

fn test_has_match() {
	mut r := compile(r'foo')?
	assert !r.has_match('')
	assert !r.has_match('bar')
	assert r.has_match('foo')
	assert r.has_match('baz foo')

	r = compile(r'x|(y)|(z)')?
	assert !r.has_match('u')
	assert r.has_match('x')
	assert r.has_match('y')
	assert r.has_match('z')
}

fn test_find_index() {
	mut r := must_compile(r'x([yz])')
	assert r.find_n_index('', 1).len == 0
	assert r.find_n_index('an xyz', 1) == [[3, 5, 4, 5]]
	assert r.find_n_index('an xyz', 2) == [[3, 5, 4, 5]]
	assert r.find_n_index('an xy and xz', 2) == [[3, 5, 4, 5],
		[10, 12, 11, 12]]

	assert r.find_all_index('an xy') == [[3, 5, 4, 5]]
	assert r.find_all_index('an xy and xz') == [[3, 5, 4, 5],
		[10, 12, 11, 12]]

	if _ := r.find_one_index('') {
		assert false, 'should have returned an error'
	} else {
		assert err.msg() == 'no match'
	}
	assert r.find_one_index('an xy and xz')? == [3, 5, 4, 5]

	r = must_compile(r'x((\d+)|(\w+))')
	assert r.find_one_index('x123 xABC')? == [0, 4, 1, 4, 1, 4, -1, -1]
	assert r.find_all_index('x123 xABC') == [[0, 4, 1, 4, 1, 4, -1, -1],
		[5, 9, 6, 9, -1, -1, 6, 9]]
}

fn test_find_submatch() {
	mut r := must_compile(r'x([yz])')
	assert r.find_n_submatch('', 1).len == 0
	assert r.find_n_submatch('an xyz', 1) == [['xy', 'y']]
	assert r.find_n_submatch('an xyz', 2) == [['xy', 'y']]
	assert r.find_n_submatch('an xy and xz', 2) == [['xy', 'y'],
		['xz', 'z']]

	assert r.find_all_submatch('an xy') == [['xy', 'y']]
	assert r.find_all_submatch('an xy and xz') == [['xy', 'y'],
		['xz', 'z']]

	if _ := r.find_one_submatch('') {
		assert false, 'should have returned an error'
	} else {
		assert err.msg() == 'no match'
	}
	assert r.find_one_submatch('an xy and xz')? == ['xy', 'y']

	r = must_compile('(.*?)((foo)+)')
	mut submatches := []string{}
	for subject in ['My name is foo', 'Mine is foofoo', 'Mine is baz'] {
		if m := r.find_one_submatch(subject) {
			submatches << m
		} else {
			submatches << 'No match'
		}
	}
	assert submatches == ['My name is foo', 'My name is ', 'foo', 'foo', 'Mine is foofoo', 'Mine is ',
		'foofoo', 'foo', 'No match']
}

fn test_replace_submatch_fn() {
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

fn test_find() {
	mut r := must_compile(r'\d')
	assert r.find_n('abcdeg', -1) == []
	if _ := r.find_one('abcdeg') {
		assert false, 'should have returned an error'
	} else {
		assert err.msg() == 'no match'
	}
	assert r.find_n('abcde5g', -1) == ['5']
	assert r.find_n('1 abc 9 de 5 g', -1) == ['1', '9', '5']
	assert r.find_all('1 abc 9 de 5 g') == ['1', '9', '5']
	assert r.find_n('1 abc 9 de 5 g', -1)[0] == '1'
	assert r.find_n('1 abc 9 de 5 g', -1)[1] == '9'
	assert r.find_n('1 abc 9 de 5 g', -1)[2] == '5'
	assert r.find_n('1 abc 9 de 5 g', 0) == []
	assert r.find_n('1 abc 9 de 5 g', 1) == ['1']
	assert r.find_one('1 abc 9 de 5 g')? == '1'
	assert r.find_n('1 abc 9 de 5 g', 2) == ['1', '9']
	assert r.find_n('1 abc 9 de 5 g', 3) == ['1', '9', '5']
	assert r.find_n('1 abc 9 de 5 g', 4) == ['1', '9', '5']
	assert must_compile(r'\d').find_n('1 abc 9 de 5 g', -1) == ['1', '9', '5']
}

fn test_replace_fn() {
	mut r := must_compile(r'(x|y|z)')
	assert r.replace_n_fn('z yx', fn (m string) string {
		return '<$m>'
	}, -1) == '<z> <y><x>'
}

fn test_replace() {
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

fn test_replace_matches() {
	assert replace_matches('$$ $0 $99', []) == '$ $0 $99'
	assert replace_matches('$$ $$0 $0 $1 $2 $100', ['x', 'y']) == '$ $0 x y $2 $100'
}
