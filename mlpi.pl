#!/usr/bin/env swipl
% -*- mode: prolog; coding:utf-8 -*-
% Monotonic Logic Programming Language Interpreter
:- initialization(main, main).

main(Argv) :-
    ( parse_args(Argv, SourceFiles, Args)
    ; format(user_error, 'invalid arguments: ~w~n', [Argv]), fail), !,
    load_terms(SourceFiles, Terms-[]), !,
    mlp(Terms, Args).

parse_args(Argv, SourceFiles, Args) :-
    phrase(opt_parse_dcg(SourceFiles, Args), Argv, []).
opt_parse_dcg([], []) --> [].
opt_parse_dcg([], _) -->
    ['-h'], !,
    { format(user_error, 'usage: mlpi <SourceFile..> [-- <Args>]', []), halt }.
opt_parse_dcg([], Args) -->
    ['--'], !,
    opt_parse_dcg2(Args).
opt_parse_dcg([SourceFile | SourceFiles], Args) -->
    [SourceFile], !,
    opt_parse_dcg(SourceFiles, Args).
opt_parse_dcg2([]) -->
    [].
opt_parse_dcg2([Arg | Args]) -->
    [Arg], !,
    opt_parse_dcg2(Args).

load_terms([], Terms-Terms) :- !.
load_terms([SourceFile|SourceFiles], Terms-Terms2) :-
    open(SourceFile, read, Stream, [encoding(utf8)]),
    read_all_terms(Stream, Terms-Terms1),
    load_terms(SourceFiles, Terms1-Terms2).
read_all_terms(Stream, Terms-Terms2) :-
    read_term(Stream, Term,
              [variable_names(NameVars),
               singletons(Singletons)]),
    report_singletons(Term, NameVars, Singletons),
    ( Term = end_of_file -> Terms = Terms2
    ; Terms = [Term|Terms1],
      read_all_terms(Stream, Terms1-Terms2) ).
report_singletons(_, _, []) :- !.
report_singletons(Term, Vars,
                  Singletons) :-
    Singletons = [Name=_ | RestSingletons],
    atom_chars(Name, SCs),
    ( SCs = ['_'|_] -> true
    ; term_string(Term, Str, [variable_names(Vars)]),
      format(user_error, 'warning: Singleton ~w in ~s.~n',
             [Name, Str]) ),
    report_singletons(Term, Vars, RestSingletons).

mlp(Terms, Args) :-
    setup_mlp_clauses(Terms),
    deterministic_prolog(main(Args)).

setup_mlp_clauses([]).
setup_mlp_clauses([Term|Terms]) :-
    ( Term = (Head :- Body) -> assertz(mlp_clauses(Head, Body))
    ; assertz(mlp_clauses(Term, true)) ),
    setup_mlp_clauses(Terms).

deterministic_prolog(P) :- deterministic_call(P).

deterministic_call((A, B)) :- !, deterministic_call(A), deterministic_call(B).
% builtin predicates
deterministic_call(true) :- !.
deterministic_call(var(A)) :- !, var(A).
deterministic_call(nonvar(A)) :- !, nonvar(A).
deterministic_call(A is B) :- !, A is B.
deterministic_call(A = B) :- !, A = B.
deterministic_call(A =\= B) :- !, A =\= B.
deterministic_call(A =:= B) :- !, A =:= B.
deterministic_call(A < B) :- !, A < B.
deterministic_call(A =< B) :- !, A =< B.
deterministic_call(A > B) :- !, A > B.
deterministic_call(A >= B) :- !, A >= B.
deterministic_call(integer(I)) :- !, integer(I).
deterministic_call(term_to_atom(T, A)) :- !, term_to_atom(T, A).
deterministic_call(prolog(P)) :- !, call(P).
% compound predicate
deterministic_call(Head) :-
    functor(Head, F, N), functor(Copy, F, N),
    mlp_clauses(Copy, Body),
    check_guard_and_execute(Head, Copy, Body), !.

check_guard_and_execute(Head, Copy, GuardBody) :-
    Head = Copy,
    ( GuardBody = (Guard | Body) ->
      check(Guard)
      -> trust(Body, Head)
    ;
    trust(GuardBody, Head) ).

check(true) :- !.
check((A, B)) :- !, deterministic_call(A), check(B).
check(A) :- deterministic_call(A).

trust((A, B), H) :-
    !,
    ( deterministic_call(A) -> trust(B, H)
    ; throw(error(failed_to_execute(H, A),
                  context(H, A)))).
trust(A, H) :-
    !,
    ( deterministic_call(A)
    ; throw(error(failed_to_execute(H, A),
                  context(H, A)))).
