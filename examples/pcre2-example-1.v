import pcre2

fn main() {
	// Match words starting with `d` or `n`.
	r := pcre2.must_compile(r'\b([dn].*?)\b')

	subject := 'Lorem nisi dis diam a cras placerat natoque'

	// Extract array of all matched strings.
	a := r.find(subject, -1)
	println(a) // ['nisi', 'dis', 'diam', 'natoque']

	// Quote matched words.
	s1 := r.replace(subject, '"$1"', -1)
	println(s1) // 'Lorem "nisi" "dis" "diam" a cras placerat "natoque"'

	// Replace all matched strings with upper case.
	s2 := r.replace_fn(subject, fn (m string) string {
		return m.to_upper()
	}, -1)
	println(s2) // 'Lorem NISI DIS DIAM a cras placerat NATOQUE'
}
