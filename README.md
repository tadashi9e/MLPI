# MLP — Minimal Logic Programming

MLP (Minimal Logic Programming) is a small logic programming language and toolchain built on top of SWI-Prolog.

It provides:

A simple interpreter
A compiler that generates SWI-Prolog code
A faster compiler variant with reduced runtime checks
Support for DCG-style rules
Support for `freeze`/2-based coroutining
A syntax inspired by GHC-style guarded clauses (without wait)

MLP is designed to be minimal, readable, and easy to experiment with, while still allowing efficient execution through compilation to Prolog.

---

## Overview

MLP programs (.mlp) are translated into SWI-Prolog programs.

Execution paths:

```
.mlp source
   |
   +-- Interpreter (mlpi.pl)
   |
   +-- Compiler (mlpc.pl)
   |        ↓
   |      Prolog (.pl)
   |        ↓
   |      Execution
   |
   +-- Optimizing Compiler (mlpc_opt.pl)

All generated programs run on the standard SWI-Prolog runtime.
```

--

## Features

- Minimal syntax
- Guarded clauses (GHC-inspired)
- DCG support
- `freeze`/2 support for delayed execution
- Stream-style I/O
- Pure Prolog backend

MLP removes wait from traditional GHC-style languages to keep the runtime simple and compilation predictable.

--

## Example

### Interpreter

```
$ ./mlpi.pl samples/primes.mlp builtin.mlp -- 100
2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97
```

---

### Compiler

```
$ ./mlpc.pl samples/primes.mlp builtin.mlp > samples/primes.pl
$ swipl samples/primes.pl -- 100
2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97
```

---

### Faster Compiler (Optimized)

```
$ ./mlpc_opt.pl samples/primes.mlp builtin.mlp > samples/primes.pl
$ swipl samples/primes.pl -- 100
2,3,5,7,11,13,17,19,23,29,31,37,41,43,47,53,59,61,67,71,73,79,83,89,97
```

The optimized compiler removes runtime checks where possible to improve performance.

### Sample Source

`samples/hello.mlp`:

```
main([_|Args]) :-
    prints(Stream, ['Hello,'| Args], []),
    iostream(Stream).
otherwise.
main([Program|_]) :-
    iostream([write('usage: '), write(Program), write(' messages...'), nl]).

prints(Stream) --> [] | Stream = [nl].
prints(Stream) -->
    [Word], {Stream = [write(Word), write(' ')|Stream2]}, prints(Stream2) | true.
```

Run:

```
$ ./mlpi.pl samples/hello.mlp builtin.mlp -- world.
Hello, world.
```

## Language Notes
### Guarded Clauses

MLP supports guarded clauses inspired by GHC:

```
Head :-
    Guard
    | Body.
```

The otherwise. clauses are simply ignored.

### DCG Support

MLP supports DCG-style rules:

```
prints(Stream) -->
    [Word],
    {Stream = [write(Word)|Stream2]},
    prints(Stream2)
    | true.
```

--

### freeze Support

MLP includes `freeze`/2 support for delayed execution.

This allows suspension of goals until variables become instantiated.

--

## Philosophy

MLP aims to be:

- Minimal
- Predictable
- Hackable
- Easy to compile
- Compatible with Prolog

Rather than introducing complex runtime mechanisms, MLP keeps the execution model simple and relies on Prolog as the execution engine.

--

## Why "Minimal Logic Programming"?

MLP focuses on:

- A minimal core language
- Minimal runtime mechanisms
- Minimal surprises in compilation

while still supporting practical features such as DCG and coroutining.

--

## License

MIT License
