module pcre2_tests

import pcre2

fn test_compile() {
	mut r := pcre2.compile(r'foo')!
	defer {
		r.free() // Only necessary if autofree is not enabled.
	}
	assert r.pattern == r'foo'
	assert r.subpattern_count == 0
	assert r.str().starts_with(r'RegEx{ pattern: foo, subpattern_count: 0,')

	r = pcre2.compile(r'a(b)c(d)')!
	assert r.pattern == r'a(b)c(d)'
	assert r.subpattern_count == 2

	r = pcre2.compile(r'^\\?\.((?:\s*[a-zA-Z][\w\-]*)+)*(?:\s*)?(#[a-zA-Z][\w\-]*\s*)?(?:\s*)?(?:"(.+?)")?(?:\s*)?(\[.+])?(?:\s*)?([+-][ \w+-]+)?$')!
	assert r.pattern == r'^\\?\.((?:\s*[a-zA-Z][\w\-]*)+)*(?:\s*)?(#[a-zA-Z][\w\-]*\s*)?(?:\s*)?(?:"(.+?)")?(?:\s*)?(\[.+])?(?:\s*)?([+-][ \w+-]+)?$'
	assert r.subpattern_count == 5
	assert r.str().starts_with(r'RegEx{ pattern: ^\\?\.((?:\s*[a-zA-Z][\w\-]*)+)*(?:\s*)?(#[a-zA-Z][\w\-]*\s*)?(?:\s*)?(?:"(.+?)")?(?:\s*)?(\[.+])?(?:\s*)?([+-][ \w+-]+)?$, subpattern_count: 5,')

	if _ := pcre2.compile(r'\') {
		assert false, 'should have returned an error'
	} else {
		assert err.msg() == 'pcre2_compile(): pattern: "\\": error 101 "\\ at end of pattern" at offset 1'
	}
}

fn test_must_compile() {
	pcre2.must_compile(r'x')
	pcre2.must_compile(r'^\\?\.((?:\s*[a-zA-Z][\w\-]*)+)*(?:\s*)?(#[a-zA-Z][\w\-]*\s*)?(?:\s*)?(?:"(.+?)")?(?:\s*)?(\[.+])?(?:\s*)?([+-][ \w+-]+)!$')
}

fn test_escape_meta() {
	assert pcre2.escape_meta(r'\.+*?()|[]{}^$') == r'\\\.\+\*\?\(\)\|\[\]\{\}\^\$'
	assert pcre2.escape_meta(r'(🚀)') == r'\(🚀\)'
}

fn test_extended() {
	mut r := pcre2.compile(r'baz')!
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

	r = pcre2.must_compile(r'\b([dn].*?)\b')
	subject = 'Lorem nisi dis diam a cras placerat natoque'
	s = r.replace_all_extended(subject, r'\U$1')
	assert s == 'Lorem NISI DIS DIAM a cras placerat NATOQUE'
	s = r.replace_one_extended(subject, r'\U$1')
	assert s == 'Lorem NISI dis diam a cras placerat natoque'
}

fn test_is_match() {
	mut r := pcre2.compile(r'foo')!
	assert !r.is_match('')
	assert !r.is_match('bar')
	assert r.is_match('foo')
	assert r.is_match('baz foo')

	r = pcre2.compile(r'x|(y)|(z)')!
	assert !r.is_match('u')
	assert r.is_match('x')
	assert r.is_match('y')
	assert r.is_match('z')
}

fn test_find_index() {
	mut r := pcre2.must_compile(r'x([yz])')

	assert r.find_all_index('an xy') == [[3, 5, 4, 5]]
	assert r.find_all_index('an xy and xz') == [[3, 5, 4, 5],
		[10, 12, 11, 12]]

	if _ := r.find_one_index('') {
		assert false, 'should have returned none'
	}
	assert r.find_one_index('an xy and xz')? == [3, 5, 4, 5]

	r = pcre2.must_compile(r'x((\d+)|(\w+))')
	assert r.find_one_index('x123 xABC')? == [0, 4, 1, 4, 1, 4, -1, -1]
	assert r.find_all_index('x123 xABC') == [[0, 4, 1, 4, 1, 4, -1, -1],
		[5, 9, 6, 9, -1, -1, 6, 9]]
}

fn test_find_submatch() {
	mut r := pcre2.must_compile(r'x([yz])')

	assert r.find_all_submatch('an xy') == [['xy', 'y']]
	assert r.find_all_submatch('an xy and xz') == [['xy', 'y'],
		['xz', 'z']]

	if _ := r.find_one_submatch('') {
		assert false, 'should have returned none'
	}
	assert r.find_one_submatch('an xy and xz')? == ['xy', 'y']

	r = pcre2.must_compile('^x$')
	assert r.find_one_submatch('x')? == ['x']

	// r = pcre2.must_compile('^(?!.+)$')
	r = pcre2.must_compile('^$')
	assert r.is_match('')
	assert r.find_one_submatch('')? == ['']

	r = pcre2.must_compile('(.*?)((foo)+)')
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

fn test_find() {
	mut r := pcre2.must_compile(r'\d')
	if _ := r.find_one('abcdeg') {
		assert false, 'should have returned none'
	} else {
		assert err is none, 'should have returned none'
	}
	assert r.find_all('1 abc 9 de 5 g') == ['1', '9', '5']
	assert r.find_one('1 abc 9 de 5 g')? == '1'
}

fn test_split() {
	r := pcre2.compile(r'foo|bar')!
	mut subject := 'foobar boo steelbar toolbox foot tooooot'
	assert r.split_all(subject) == ['', '', ' boo steel', ' toolbox ', 't tooooot']
	assert r.split_one(subject)? == ['', 'bar boo steelbar toolbox foot tooooot']

	subject = ''
	assert r.split_all(subject) == ['']
	if _ := r.split_one(subject) {
		assert false, 'should have returned none'
	}

	subject = 'qux'
	assert r.split_all(subject) == ['qux']
}
