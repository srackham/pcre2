import pcre2

fn main() {
	// Match words starting with `d` or `n`.
	r := pcre2.must_compile(r'\b([dn].*?)\b')

	subject := 'Lorem nisi dis diam a cras placerat natoque'

	// Extract array of all matched strings.
	a := r.find_all(subject)
	println(a) // ['nisi', 'dis', 'diam', 'natoque']

	// Quote matched words.
	s1 := r.replace_all(subject, '"$1"')
	println(s1) // 'Lorem "nisi" "dis" "diam" a cras placerat "natoque"'

	// Replace all matched strings with upper case.
	s2 := r.replace_all_fn(subject, fn (m string) string {
		return m.to_upper()
	})
	println(s2) // 'Lorem NISI DIS DIAM a cras placerat NATOQUE'

	// Replace all matched strings with upper case (PCRE2 extended replacement syntax).
	s3 := r.replace_all_extended(subject, r'\U$1')?
	println(s3) // 'Lorem NISI DIS DIAM a cras placerat NATOQUE'
}
