# Bullseye
Bullseye is a pure functional language that compiles to Dart.

## Getting started
The `examples/` directory in the project root contains several examples of
Bullseye code.

## Why a *pure* functional language?
Many Dart programmers are already familiar with functional programming. For
example, the `List` API has several methods, like `map`, `fold`, and `where`,
which are also present in languages like Haskell or OCaml.

Flutter is a major reason many people are adopting Dart. Because of how Flutter
handles state, I believe that a language that handles state in the same way is
a nice fit.

Pure functional languages, most notably Haskell, force you to separate code with
side effects from code that only performs computations. In addition, a language
like Haskell has several features (most notably, pattern matching) that make
dealing with pure data very simple.

## Why compile to Dart?
Dart is awesome. It has a fast VM, multiple compile targets, an expansive
standard library (with excellent options for working with collections),
concurrency support, and the backing of a major company.

Dart also already supports first-class functions, which makes it a good target
for a language that heavily relies on them.

## Why Haskell syntax?
Ultimately, it comes down to personal preference. Though introducing significant
whitespace complicates parsing, it removes the need for most delimiters in the
grammar. For example, Bullseye does not require wrapping blocks with `{ }`, nor
does it require `begin ... end` blocks (which are often used in OCaml to
disambiguate certain types of expressions.

Some people believe that significant whitespace improves readability, but your
mileage may vary.
