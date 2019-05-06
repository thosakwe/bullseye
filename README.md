# bullseye
[![Pub](https://img.shields.io/pub/v/bullseye_lang.svg)](https://pub.dartlang.org/packages/bullseye_lang)
[![travis ci](https://travis-ci.org/thosakwe/bullseye.svg)](https://travis-ci.org/thosakwe/bullseye)

A functional language frontend for the Dart VM.

## About
Bullseye is greatly inspired by OCaml, and thus much
of its syntax derives from that language.

It is mostly an educational/for-fun project, but is also
a playground to try out features that don't yet exist
in Dart.

## Features
Fully or partially implemented features include:
* Record types

Planned features that are not yet implemented include:
* Value classes
* Pattern matching
* NNBD
* Flutter shorthand syntax
* Cast functions to Flutter widgets
* Spread operator

## Installation
If you just want to use the current version:

```bash
pub global activate bullseye_lang
```

This will install the `bullseye` and `blsc` executables.

## Example
Note: Bullseye is still in its very early stages, so don't be surprised if things break.

In a file, `hello.bls`, write:

```ocaml
let main() =
    print "Hello, Bullseye!"
```

To compile and run it immediately, run
`bullseye hello.bls`. Any other arguments will be
forwarded to the Dart VM.

You can also compile it to a `*.dill` file by calling
`blsc -o hello.dill hello.bls`.

Alternatively, you can print a text representation of the
compiled kernel file by calling `blsc -f text hello.bls`.

For other information, run `blsc --help`.

## More Examples
The `testcases/` directory contains sample files that
are used to test the Bullseye compiler. Relevant
sources can be found in:
* `testcases/test/cases`
* `testcases/test/output`