import pcre2

fn main() {
	// Match words starting with `d` or `n`.
	r := pcre2.must_compile(r'\b([dn].*?)\b')

	subject := 'Lorem nisi dis diam a cras placerat natoque'

	// Extract array of all matched strings.
	println(r.find(subject, -1)) // ['nisi', 'dis', 'diam', 'natoque']

	// Replace all matched strings with upper case.
	s := r.replace_fn(subject, fn (m string) string {
		return m.to_upper()
	}, -1)
	println(s) // 'Lorem NISI DIS DIAM a cras placerat NATOQUE'
}
