#!/usr/bin/env swipl
% -*- mode: prolog; coding:utf-8 -*-
:- initialization(main, main).

main(Argv) :-
    ( parse_args(Argv, SourceFiles, Args)
    ; format(user_error, 'invalid arguments: ~w~n', [Argv]), fail), !,
    load_terms(SourceFiles, Terms-[]), !,
    mlpi(Terms, Args).

writeall([]).
writeall([T|Ts]) :- writeln(T), writeall(Ts).

dwriteln(_).

parse_args([Argv0 | Argv], SourceFiles, [Argv0 | Args]) :-
    phrase(opt_parse_dcg(SourceFiles, Args), [Argv0 | Argv], []).
opt_parse_dcg([], []) --> [].
opt_parse_dcg([], _) -->
    ['-h'], !,
    { format(user_error, 'usage: mlpi <SourceFile..> [-- <Args>]', []), halt }.
opt_parse_dcg(SourceFiles, Args) -->
    ['-d'], !,
    { abolish(dwriteln, 1), assert(dwriteln(X) :- writeln(X)) },
    opt_parse_dcg(SourceFiles, Args).
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
% ----------------------------------------------------------------------
% load source files
% ----------------------------------------------------------------------
load_terms([], Terms-Terms) :- !.
load_terms([SourceFile|SourceFiles], Terms-Terms2) :-
    open(SourceFile, read, Stream, [encoding(utf8)]),
    read_all_terms(Stream, Terms-Terms1),
    close(Stream),
    load_terms(SourceFiles, Terms1-Terms2).
read_all_terms(Stream, Terms-Terms2) :-
    read_term(Stream, Term,
              [variable_names(NameVars),
               singletons(Singletons)]),
    report_singletons(Term, NameVars, Singletons),
    ( Term = end_of_file -> Terms = Terms2
    ; Term = otherwise -> read_all_terms(Stream, Terms-Terms2)
    ; preprocess_term(Term, PreprocessedTerm),
      Terms = [PreprocessedTerm|Terms1],
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
% ----------------------------------------------------------------------
% preprocessing for DCG
% ----------------------------------------------------------------------
preprocess_term((Head --> Guard | Body), (Head2 :- Guard2 | Body2)) :-
    Pred = (Head --> Guard | Body),
    ( may_be_stream(Guard), may_be_stream(Body)
    -> throw(error(invalid_predicate(Pred)))
    ; may_be_stream(Guard)
    -> preprocess_stream(Pred, Guard, In1-In2, Guard2),
       Head =.. [F|Args], append(Args, [In1,In2], Args2),
       Head2 =.. [F|Args2],
       Body2 = Body, !
    ; may_be_stream(Body)
    -> preprocess_stream(Pred, Body, Out1-Out2, Body2),
       Head =.. [F|Args], append(Args, [Out1,Out2], Args2),
       Head2 =.. [F|Args2],
       Guard2 = Guard, ! ).
preprocess_term((Head --> Body), (Head2 :- Body2)) :-
    Pred = (Head --> Body),
    ( may_be_stream(Body)
    -> preprocess_stream(Pred, Body, Out1-Out2, Body2),
       Head =.. [F|Args], append(Args, [Out1,Out2], Args2),
       Head2 =.. [F|Args2], ! ).
preprocess_term(Term, Term) :- !.

may_be_stream(Gs) :- may_be_stream(Gs, false, true).
may_be_stream((G,Gs), Flag, Flag2) :-
    ( (G = {_} ; G = [] ; G = [_|_] ) -> may_be_stream(Gs, true, Flag2)
    ; may_be_stream(Gs, Flag, Flag2) ).
may_be_stream(G, _, true) :- ( G = {_} ; G = [] ; G = [_|_] ), !.
may_be_stream(_, Flag, Flag).

preprocess_stream(Pred, (G,Gs), IO-IO3, (G2,Gs2)) :-
    ( extend_list(G, IO1-IO2)
    -> G2 = (IO = IO1),
       preprocess_stream(Pred, Gs, IO2-IO3, Gs2), !
    ; G = {G0}
    -> G2 = G0,
       preprocess_stream(Pred, Gs, IO-IO3, Gs2), !
    ; G =.. [F|Args], append(Args, [IO,IO1], Args2), G2 =.. [F|Args2],
      preprocess_stream(Pred, Gs, IO1-IO3, Gs2), !
    ; throw(error(invalid_predicate(Pred, G))) ).
preprocess_stream(Pred, G, IO-IO2, G2) :-
    ( extend_list(G, IO1-IO2) -> G2 = (IO = IO1)
    ; G = {G0} -> G2 = G0, IO = IO2
    ; G =.. [F|Args], append(Args, [IO,IO2], Args2), G2 =.. [F|Args2]
    ; throw(error(invalid_predicate(Pred, G))) ).

extend_list([], List-List).
extend_list([V|Values], List-List2) :-
    List = [V|List1], extend_list(Values, List1-List2).
% ----------------------------------------------------------------------
% Interpreter
% ----------------------------------------------------------------------
mlpi(Terms, Args) :-
    setup_mlpi_clauses(Terms),
    mlpi_call(main(Args), main(Args)).

setup_mlpi_clauses([]).
setup_mlpi_clauses([Term|Terms]) :-
    ( Term = (Head :- Body) -> assertz(mlpi_clauses(Head, Body))
    ; assertz(mlpi_clauses(Term, true)) ),
    setup_mlpi_clauses(Terms).

mlpi_call(Head, (P, Q)) :-
    mlpi_call(Head, P),
    mlpi_call(Head, Q).
% built-in predicates
mlpi_call(_, true).
mlpi_call(Head, var(A)) :- !, call_(Head, var(A)).
mlpi_call(Head, nonvar(A)) :- !, call_(Head, nonvar(A)).
mlpi_call(Head, integer(I)) :- !, call_(Head, integer(I)).
mlpi_call(Head, A is B) :- !, call_(Head, A is B).
mlpi_call(Head, A = B) :- !, call_(Head, A = B).
mlpi_call(Head, A =\= B) :- !, call_(Head, A =\= B).
mlpi_call(Head, A =:= B) :- !, call_(Head, A =:= B).
mlpi_call(Head, A < B) :- !, call_(Head, A < B).
mlpi_call(Head, A > B) :- !, call_(Head, A > B).
mlpi_call(Head, A =< B) :- !, call_(Head, A =< B).
mlpi_call(Head, A >= B) :- !, call_(Head, A >= B).
mlpi_call(Head, prolog(P)) :- call_(Head, P).
mlpi_call(Head, call(P)) :- call_(Head, mlpi_call(call(P), P)).
mlpi_call(Head, freeze(X, P)) :-
    call_(Head, freeze(X, mlpi_call(freeze(X, P), P))).
mlpi_call(_, Goal) :-
    functor(Goal, F, N), functor(Copy, F, N),
    mlpi_clauses(Copy, GuardBody),
    ( GuardBody = (Guard | Body)
    -> Goal = Copy, mlpi_call(Goal, Guard), trust(Goal, Body)
    ; Goal = Copy, trust(Goal, GuardBody) ).
call_(Head, Goal) :-
    ( call(Goal) -> dwriteln(success(Head, Goal))
    ; dwriteln(fail(Head, Goal)), !, fail ).
trust(Head, (P, Q)) :- trust(Head, P), trust(Head, Q).
trust(_, true).
trust(Head, P) :-
    ( mlpi_call(Head, P) -> true
    ; throw(error(failed_to_execute(Head, P),
                  context(Head, P))) ).
