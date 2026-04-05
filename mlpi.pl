#!/usr/bin/env swipl
% -*- mode: prolog; coding:utf-8 -*-
:- initialization(main, main).

main(Argv) :-
    % debug(main),
    % debug(mlpi),
    debug(main, ':Argv = ~p', [Argv]),
    debug(main, ':~p', [parse_args(Argv)]),
    ( parse_args(Argv, SourceFiles, Args)
    ; format(user_error, 'invalid arguments: ~w~n', [Argv]), fail), !,
    debug(main, ':SourceFiles = ~p', [SourceFiles]),
    debug(main, ':Args = ~p', [Args]),
    debug(main, ':~p', [load_terms(SourceFiles)]),
    load_terms(SourceFiles, Terms-[]), !,
    debug(main, ':~p', [mlpi]),
    mlpi(Terms, ['mlpi.pl'|Args]).

writeall([]).
writeall([T|Ts]) :- writeln(T), writeall(Ts).

parse_args(['-h' | _], _, _) :-
    !, format(user_error, 'usage: mlpi <SourceFile..> [-- <Args>]', []), halt.
parse_args(['-d' | Argv], SourceFiles, Args) :-
    !, debug(mlpi),
    parse_args(Argv, SourceFiles, Args).
parse_args(['--' | Argv], [], Args) :-
    !, debug(main, 'parse_args(Args=~w)~n', [Argv]), Args = Argv.
parse_args([SourceFile | Argv], [SourceFile|SourceFiles], Args) :-
    !, parse_args(Argv, SourceFiles, Args).
parse_args([], [], []) :- !.

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
preprocess_term((Head --> Guard | Body), _) :-
    Pred = (Head --> Guard | Body),
    may_be_stream(Guard), may_be_stream(Body),
    throw(error(invalid_predicate(Pred))).
preprocess_term((Head --> Guard | Body), (Head2 :- Guard2 | Body2)) :-
    Pred = (Head --> Guard | Body),
    may_be_stream(Guard), !,
    preprocess_stream(Pred, Guard, In1-In2, Guard2),
    Head =.. [F|Args], append(Args, [In1,In2], Args2),
    Head2 =.. [F|Args2],
    Body2 = Body.
preprocess_term((Head --> Guard | Body), (Head2 :- Guard2 | Body2)) :-
    Pred = (Head --> Guard | Body),
    may_be_stream(Body), !,
    preprocess_stream(Pred, Body, Out1-Out2, Body2),
    Head =.. [F|Args], append(Args, [Out1,Out2], Args2),
    Head2 =.. [F|Args2],
    Guard2 = Guard.
preprocess_term((Head --> Body), (Head2 :- Body2)) :-
    Pred = (Head --> Body),
    may_be_stream(Body), !,
    preprocess_stream(Pred, Body, Out1-Out2, Body2),
    Head =.. [F|Args], append(Args, [Out1,Out2], Args2),
    Head2 =.. [F|Args2].
preprocess_term(Term, Term).

may_be_stream(Gs) :- may_be_stream(Gs, false, true), !.
may_be_stream(({_},   _), _, Flag2) :- Flag2 = true.
may_be_stream(([],    _), _, Flag2) :- Flag2 = true.
may_be_stream(([_|_], _), _, Flag2) :- Flag2 = true.
may_be_stream((_, Gs), Flag, Flag2) :- may_be_stream(Gs, Flag, Flag2).
may_be_stream({_},   _, Flag2) :- Flag2 = true.
may_be_stream([],    _, Flag2) :- Flag2 = true.
may_be_stream([_|_], _, Flag2) :- Flag2 = true.
may_be_stream(_, Flag, Flag2) :- Flag2 = Flag.

preprocess_stream(Pred, (G,Gs), IO-IO2, Gs2) :-
    G = [],
    preprocess_stream(Pred, Gs, IO-IO2, Gs2).
preprocess_stream(Pred, (G,Gs), IO-IO3, (G2,Gs2)) :-
    G = [_|_],
    extend_list(G, IO1-IO2), G2 = (IO = IO1),
    preprocess_stream(Pred, Gs, IO2-IO3, Gs2).
preprocess_stream(Pred, (G,Gs), IO-IO2, (G2,Gs2)) :-
    G = {G0},
    G2 = G0, preprocess_stream(Pred, Gs, IO-IO2, Gs2).
preprocess_stream(Pred, (G,Gs), IO-IO2, (G2,Gs2)) :-
    G =.. [F|Args],
    append(Args, [IO,IO1], Args2),
    G2 =.. [F|Args2], preprocess_stream(Pred, Gs, IO1-IO2, Gs2).
preprocess_stream(_, G, IO-IO2, G2) :-
    G = [], G2 = (IO = IO2).
preprocess_stream(_, G, IO-IO2, G2) :-
    G = [_|_],
    extend_list(G, IO1-IO2), G2 = (IO = IO1).
preprocess_stream(_, G, IO-IO2, G2) :-
    G = {G0}, G2 = G0, IO = IO2.
preprocess_stream(_, G, IO-IO2, G2) :-
    G =.. [F|Args],
    append(Args, [IO,IO2], Args2),
    G2 =.. [F|Args2].
preprocess_stream(Pred, (G,_), _, _) :-
    throw(error(invalid_predicate(Pred, G))).
preprocess_stream(Pred, G, _, _) :-
    throw(error(invalid_predicate(Pred, G))).

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
    ( mlpi_assertz(Term), !
    ; assertz(mlpi_clauses(Term, true)) ),
    % debug(mlpi, ':~p', [assertz(Term)]),
    setup_mlpi_clauses(Terms).

mlpi_asserta(Term) :-
    Term = (Head :- Body), asserta(mlpi_clauses(Head, Body)), !.
mlpi_asserta(Term) :-
    asserta(mlpi_clauses(Term, true)).
mlpi_assertz(Term) :-
    Term = (Head :- Body), assertz(mlpi_clauses(Head, Body)), !.
mlpi_assertz(Term) :-
    assertz(mlpi_clauses(Term, true)).

mlpi_abolish(Func, Arity) :-
    findall((Head :- Body), mlpi_clauses(Head, Body), Clauses),
    remove_clause(Clauses, Func, Arity, Clauses2),
    abolish(mlpi_clauses, 2),
    setup_mlpi_clauses(Clauses2).
remove_clause([], _, _, []).
remove_clause([Clause|Clauses], Func, Arity, Clauses2) :-
    ( Clause = (Head :- _), functor(Head, Func, Arity) -> Clauses2 = Clauses
    ; Clauses2 = [Clause|Clauses3], remove_clause(Clauses, Func, Arity, Clauses3) ).

mlpi_call(Head, (P, Q)) :-
    mlpi_call(Head, P), mlpi_call(Head, Q).
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
mlpi_call(Head, F =.. L) :- !, call_(Head, F =.. L).
mlpi_call(Head, prolog(P)) :- call_(Head, P).
mlpi_call(Head, call(P)) :- call_(Head, mlpi_call(call(P), P)).
mlpi_call(Head, freeze(X, P)) :-
    call_(Head, freeze(X, mlpi_call(freeze(X, P), P))).
mlpi_call(Head, catch(G, Error, Recover)) :-
    call_(Head, catch(mlpi_call(catch(G, Error, Recover), G), Error,
                      mlpi_call(catch(G, Error, Recover), Recover))).
mlpi_call(Head, abolish(Func, Arity)) :-
    call_(Head, abolish(Func, Arity), mlpi_abolish(Func, Arity)).
mlpi_call(Head, asserta(Term)) :-
    call_(Head, asserta(Term), mlpi_asserta(Term)).
mlpi_call(Head, assertz(Term)) :-
    call_(Head, assertz(Term), mlpi_assertz(Term)).
mlpi_call(_, Goal) :-
    functor(Goal, F, N), functor(Copy, F, N),
    mlpi_clauses(Copy, GuardBody),
    ( GuardBody = (Guard | Body)
    -> Goal = Copy,
       mlpi_call(Goal, Guard),
       trust(Goal, Body)
    ; Goal = Copy,
      trust(Goal, GuardBody) ).
call_(Head, DispGoal, RealGoal) :-
    functor(Head, Name, Arity),
    ( call(RealGoal) -> debug(mlpi, '~p', [success(Name/Arity, guard, DispGoal)])
    ; debug(mlpi, '~p', [fail(Name/Arity, guard, DispGoal)]), !, fail ).
call_(Head, Goal) :-
    functor(Head, Name, Arity),
    ( call(Goal) -> debug(mlpi, '~p', [success(Name/Arity, guard, Goal)])
    ; debug(mlpi, '~p', [fail(Name/Arity, guard, Goal)]), !, fail ).
trust(Head, (P, Q)) :- trust(Head, P), trust(Head, Q).
trust(_, true).
trust(Head, P) :-
    functor(Head, Name, Arity),
    ( mlpi_call(Head, P) -> debug(mlpi, '~p', [success(Name/Arity, body, P)])
    ; throw(error(crash(Name/Arity, body, P),
                  context(Head, P))) ).
