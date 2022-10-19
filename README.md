# pcre2

## Overview
A V library module for processing [Perl Compatible Regular Expressions (PCRE)](https://en.wikipedia.org/wiki/Perl_Compatible_Regular_Expressions) using the [PCRE2 library](https://www.pcre.org/).

- The `pcre2` module is a wrapper for the PCRE2 8-bit runtime library.
- Regex `find_*` methods search a `subject` string for regular expression matches.
- Regex `replace_*` methods return a string in which matches in the `subject`
  string are replaced by a replacement string or the result of a replacement function.
- The Regex `replace_*_extended` methods support the PCRE2 extended replacements string syntax (see `PCRE2_SUBSTITUTE_EXTENDED` in the [pcre2api](https://www.pcre.org/current/doc/html/pcre2api.html) man page).
- Currently there are no extraction methods for named subpatterns.
- The [pcre module](https://github.com/vlang/pcre) (which uses the older PCRE library) was the leading light for this project.
- Many of the methods and functions were inspired by the [Go regex package](https://pkg.go.dev/regexp).

## Documentation
- [pcre2 module documentation](https://srackham.github.io/pcre2/pcre2.html).
- [PCRE regular expressions syntax](https://www.pcre.org/current/doc/html/pcre2syntax.html).
- [Github repository](https://github.com/srackham/pcre2)

## Examples
```v
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
```
For more examples see inside the [examples directory](https://github.com/srackham/pcre2/tree/master/examples) and take a look at the [module tests](https://github.com/srackham/pcre2/blob/master/pcre2_test.v).

## Dependencies
Install the PCRE2 library:

**Arch Linux and Manjaro**: `pacman -S pcre2`

**Debian and Ubuntu**: `apt install libpcre2-dev`

**Fedora**: `yum install pcre2-devel`

**macOS**: `brew install pcre2`

**Windows** †: `pacman.exe -S mingw-w64-x86_64-pcre2`

† Uses the [MSYS2](https://www.msys2.org/) package management tools.

## Installation

    v install --git https://github.com/srackham/pcre2

Test the installation by running:

    v test $HOME/.vmodules/pcre2

Example installation and test workflows for Ubuntu, macOS and Windows can be found in the Github Actions [workflow file](https://github.com/srackham/pcre2/blob/master/.github/workflows/ci.yml).