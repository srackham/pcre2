# pcre2

**NOTE**: This release is graded alpha and is likely to experience API
changes up until the 1.0 release.
## Overview
A V library module for processing [Perl Compatible Regular Expressions (PCRE)](https://en.wikipedia.org/wiki/Perl_Compatible_Regular_Expressions) using the [PCRE2 library](https://www.pcre.org/).

- The `pcre2` module is a wrapper for the PCRE2 8-bit runtime library.
- Regex `find_*` methods search a `subject` string for regular expression matches.
- Regex `replace_*` methods return a string in which matches in the `subject`
  string are replaced by a replacement string or the result of a replacement function.
- Regex `*_all_*` methods process all matches; `*_one_*` methods process the first match.
- The Regex `replace_*_extended` methods support the PCRE2 extended replacements string syntax (see `PCRE2_SUBSTITUTE_EXTENDED` in the [pcre2api](https://www.pcre.org/current/doc/html/pcre2api.html) man page).
- Currently there are no extraction methods for named subpatterns.
- The [pcre module](https://github.com/vlang/pcre) (which uses the older PCRE library) was the inspiration and starting point for this project;
the [Go regex package](https://pkg.go.dev/regexp) also influenced the project.

## Documentation
- [pcre2 module documentation](https://srackham.github.io/pcre2/pcre2.html).
- [PCRE regular expressions syntax](https://www.pcre.org/current/doc/html/pcre2syntax.html).
- [Github repository](https://github.com/srackham/pcre2)

## Examples
```v
import srackham.pcre2

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
	s3 := r.replace_all_extended(subject, r'\U$1')
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

    v install srackham.pcre2

Test the installation by running:

    v test $HOME/.vmodules/srackham/pcre2

Example installation and test workflows for Ubuntu, macOS and Windows can be found in the Github Actions [workflow file](https://github.com/srackham/pcre2/blob/master/.github/workflows/ci.yml).

## Performance
Complex patterns can cause PCRE2 resource exhaustion. `find_*` library functions respond to such errors by raising a panic. The solution is to simplify the offending pattern.  Unlike, for example, the Go regexp package, PCRE2 does not have linear-time performance and while they may not trigger a panic, pathalogical patterns can exhibit slow performance. See the PCRE2 [pcre2perform man page](https://www.pcre.org/current/doc/html/pcre2perform.html).