# pcre2

A V library module for processing [Perl Compatible Regular Expressions (PCRE)](https://en.wikipedia.org/wiki/Perl_Compatible_Regular_Expressions) using the [PCRE2 library](https://www.pcre.org/).

- The `pcre2` module is a thin wrapper for the PCRE2 8-bit runtime library.
- Currently there are no extraction methods for named subpatterns.
- The [pcre module](https://github.com/vlang/pcre) (which uses the older PCRE library) was the leading light for this project.
- Many of the methods and functions were inspired by the [Go regex ppackage](https://pkg.go.dev/regexp).

## Documentation
- [pcre2 module documentation](https://srackham.github.io/pcre2/pcre2.html).
- [PCRE regular expressions syntax](https://www.pcre.org/current/doc/html/pcre2syntax.html).

## Example
```v
import pcre2

fn main() {
	// Match words starting with `d` or `n`.
	r := pcre2.must_compile(r'\b([dn].*?)\b')

	subject := 'Lorem nisi dis diam a cras placerat natoque'

	// Extract array of all matched strings.
	a := r.find(subject, -1)
	println(a) // ['nisi', 'dis', 'diam', 'natoque']

	// Quote matched words.
	s1 := r.replace(subject, '"$0"', -1)
	println(s1) // 'Lorem "nisi" "dis" "diam" a cras placerat "natoque"'

	// Replace all matched strings with upper case.
	s2 := r.replace_fn(subject, fn (m string) string {
		return m.to_upper()
	}, -1)
	println(s2) // 'Lorem NISI DIS DIAM a cras placerat NATOQUE'
}
```
For more examples see inside the [examples directory](examples) and take a look at the [module tests](pcre2_test.v).

## Dependencies
Install the PCRE2 library:

**Arch Linux**: `pacman -S pcre2`

**Debian**: `apt install libpcre2-dev`

**Fedora**: `yum install pcre2-devel`

**macOS**: `brew install pcre2`

## Installation

    v install --git https://github.com/srackham/pcre2

Test the installation by running:

    v test $HOME/.vmodules/pcre2