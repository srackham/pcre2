import pcre2

fn main() {
	r := pcre2.must_compile('(.*?)((foo)+)')
	for subject in ['My name is foo', 'Mine is foofoo', 'Mine is baz'] {
		if m := r.find_match(subject, 0) {
			g := m.get_all()
			println('Entire match: "${g[0]}"')
			println('Subpattern 1 match: "${g[1]}"')
			println('Subpattern 2 match: "${g[2]}"')
			println('Subpattern 3 match: "${g[3]}"')
			println('')
		} else {
			println('No match')
		}
	}
}
