# MLP Interpreter (mlpi.pl)

`mlpi.pl` is a reference interpreter for **MLP (Monotonic Logic Programming)** — a deterministic logic programming language without backtracking.

MLP is based on Guarded Horn Clauses and adopts a **single-assignment, monotonic execution model**, making programs easier to reason about, debug, and extend toward concurrency.

---

## Overview

In MLP:

* Execution is **deterministic** (no backtracking)
* Logical variables are **bound at most once**
* State evolves **monotonically** (no rollback)
* Clause selection is based on **guards**
* `fail` is restricted to guards; failures in the body are treated as errors

---

## Usage

```bash
./mlpi.pl <SourceFile...> [-- <Args>]
```

### Example

```bash
./mlpi.pl builtin.mlp primes.mlp -- 1000
```

The program must define:

```prolog
main(Args)
```

which serves as the entry point.

---

## Syntax

```prolog
Head :- Guard | Body.
```

* `Head` : predicate definition
* `Guard`: condition for clause selection
* `Body` : sequence of goals to execute

---

## Execution Model

When a predicate is called:

1. Clauses with matching head are tried **top-to-bottom**
2. The head is unified with the call
3. The guard is evaluated

   * If it succeeds, the clause is **committed**
   * If it fails, the next clause is tried
4. The body is executed
5. If the body fails, an **exception is raised**

If no clause matches, the call fails.

---

## Guard Semantics (Important)

Guards are executed as **normal predicate calls**.

### Rules

* Variable bindings in guards are **allowed**
* Bindings are **not rolled back**, even if the guard fails
* Guards may have **side effects on variable bindings**
* No backtracking occurs

### Example

```prolog
p(X) :- X = 1, q(X) | r(X).
p(X) :- X = 2 | s(X).
```

If `q(X)` fails, the binding `X = 1` remains in effect when evaluating the next clause.

---

## Failure Semantics

* **Guard failure**

  * Clause is rejected, next clause is tried
* **Body failure**

  * Raises an exception (`failed_to_execute/2`)

---

## Built-in Predicates

### Core

```prolog
true
X = Y
A is B
```

### Comparison

```prolog
A =:= B
A =\= B
A < B
A =< B
A > B
A >= B
```

### Type / Term

```prolog
var(X)
nonvar(X)
integer(X)
term_to_atom(T, A)
```

### Escape to Prolog

```prolog
prolog(P)
```

Executes arbitrary Prolog code.

**Warning**: ⚠️ `prolog/1` is unsafe and may violate monotonic semantics. ⚠️

---

## Program Structure

Source files are loaded as Prolog terms.

* Facts:

  ```prolog
  p(a).
  ```

  are treated as:

  ```prolog
  p(a) :- true.
  ```

* Rules:

  ```prolog
  p(X) :- Guard | Body.
  ```

---

## Operator

The guard separator `|` is used as an infix operator:

```prolog
:- op(950, xfx, '|').
```

---

## Design Principles

MLP is built on the following ideas:

* **Monotonic state**: information is only added, never removed
* **No rollback**: failure does not revert state
* **Determinism**: execution path is predictable
* **Explicit control**: guards control clause selection

---

## Differences from Prolog

| Feature          | Prolog            | MLP           |
| ---------------- | ----------------- | ------------- |
| Backtracking     | Yes               | No            |
| Variable binding | Reversible        | Irreversible  |
| Fail usage       | Control + logic   | Guard only    |
| Execution        | Non-deterministic | Deterministic |

---

## Limitations

* No occurs check (cyclic terms may be created)
* Clause order may affect results due to guard side effects
* No suspension (unbound variables do not block execution)
* No concurrency (yet)

---

## Future Work

* Suspension / dataflow execution
* Parallel evaluation model
* Improved error reporting and tracing
* Optimized clause indexing
* Garbage collection strategies

---

## Summary

MLP provides:

> **Deterministic logic programming with monotonic state transitions**

This interpreter serves as a simple and extensible foundation for exploring a new class of logic programming systems without backtracking.
