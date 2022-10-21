module pcre2

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

fn test_replace_matches() {
	assert replace_matches('$$ $0 $99', []) == '$ $0 $99'
	assert replace_matches('$$ $$0 $0 $1 $2 $100', ['x', 'y']) == '$ $0 x y $2 $100'
}
