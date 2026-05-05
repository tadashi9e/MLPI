#!/usr/bin/env swipl
% -*- mode: prolog; coding:utf-8 -*-

:- initialization(main, main).

:- use_module(library(chr)).

main(Argv) :-
    % debug(main),
    % debug(mlpi),
    debug(main, '~p: ~p', [main/1, 'Argv' = Argv]),
    debug(main, '~p: ~p', [main/1, parse_args(Argv)]),
    ( parse_args(Argv, SourceFiles, Args)
    ; format(user_error, 'invalid arguments: ~w~n', [Argv]), fail), !,
    debug(main, '~p: ~p', [main/1, 'SourceFiles' = SourceFiles]),
    debug(main, '~p: ~p', [main/1, 'Args' = Args]),
    debug(main, '~p: ~p', [main/1, load_terms(SourceFiles)]),
    load_terms(SourceFiles, TDList-[]), !,
    debug(main, '~p: ~p', [main/1, mlpi(Args)]),
    mlpi(TDList, ['mlpi.pl'|Args]).

writeall([]).
writeall([T|Ts]) :- writeln(T), writeall(Ts).

parse_args(['-h' | _], _, _) :-
    !, format(user_error, 'usage: mlpi <SourceFile..> [-- <Args>]', []), halt.
parse_args(['-d' | Argv], SourceFiles, Args) :-
    !, debug(main), debug(mlpi),
    parse_args(Argv, SourceFiles, Args).
parse_args(['-d_main' | Argv], SourceFiles, Args) :-
    !, debug(main),
    parse_args(Argv, SourceFiles, Args).
parse_args(['-d_mlpi' | Argv], SourceFiles, Args) :-
    !, debug(mlpi),
    parse_args(Argv, SourceFiles, Args).
parse_args(['--' | Argv], [], Args) :-
    !, debug(main, '~p: ~p', [parse_args/3, 'Argv' = Argv]),
    Args = Argv.
parse_args([SourceFile | Argv], [SourceFile|SourceFiles], Args) :-
    !, parse_args(Argv, SourceFiles, Args).
parse_args([], [], []) :- !.

% ----------------------------------------------------------------------
% load source files
% ----------------------------------------------------------------------
load_terms([], TDList-TDList) :- !.
load_terms([SourceFile|SourceFiles], TDList-TDList2) :-
    open(SourceFile, read, Stream, [encoding(utf8)]),
    read_all_terms(SourceFile, Stream, TDList-TDList1, 0),
    close(Stream),
    load_terms(SourceFiles, TDList1-TDList2).
read_all_terms(SourceFile, Stream, TDList-TDList2, LineNo) :-
    stream_property(Stream, position(StartPos)),
    read_single_term(SourceFile, Stream, Term, NameVars, Singletons, LineNo),
    stream_property(Stream, position(EndPos)),
    read_source_span(SourceFile, StartPos, EndPos, Text),
    report_singletons(SourceFile, LineNo, Text, Singletons),
    ( Term = end_of_file -> TDList = TDList2
    ; Term = otherwise ->
      get_line_count(EndPos, LineNo2),
      read_all_terms(SourceFile, Stream, TDList-TDList2, LineNo2)
    ; TermData = term_data(Term, NameVars, Text, SourceFile, LineNo),
      debug(main, '~p [~a:~d]: ~p',
            [read_all_terms/4, SourceFile, LineNo, read_term(TermData)]),
      preprocess_term(TermData, PreprocessedTermData),
      TDList = [PreprocessedTermData|TDList1],
      get_line_count(EndPos, LineNo2),
      read_all_terms(SourceFile, Stream, TDList1-TDList2, LineNo2) ).

read_single_term(SourceFile, Stream, Term, NameVars, Singletons, LineNo) :-
    ( read_term(Stream, Term,
                [variable_names(NameVars),
                 singletons(Singletons)]) -> true
    ; format(user_error, '[mlpi] ~a:~d: failed to read term~n',
             [SourceFile, LineNo]) ).

read_source_span(SourceFile, StartPos, EndPos, SourceText) :-
    stream_position_data(char_count, StartPos, StartChar),
    stream_position_data(char_count, EndPos, EndChar),
    Length is EndChar - StartChar,
    open(SourceFile, read, Stream2, [encoding(utf8)]),
    seek(Stream2, StartChar, bof, _),
    read_string(Stream2, Length, SourceText),
    close(Stream2).

get_line_count(Pos, LineCountOfPos) :-
    stream_position_data(line_count, Pos, Lines),
    LineCountOfPos is Lines + 1.

report_singletons(SourceFile, LineNo, Text, Singletons) :-
    filter_singletons(Singletons, Singletons2-[]),
    report_singletons_aux(SourceFile, LineNo, Singletons2, Text).
report_singletons_aux(_, _, [], _) :- !.
report_singletons_aux(SourceFile, LineNo, Singletons, Text) :-
    format(user_error, '[mlpi] ~a:~d: warning: Singletons ~w in "~w".~n',
           [SourceFile, LineNo, Singletons, Text]).

filter_singletons([], Singletons-Singletons2) :-
    Singletons = Singletons2.
filter_singletons([Name=_|Ss], Singletons-Singletons2) :-
    atom_chars(Name, SCs),
    ( SCs = ['_'|_]  -> filter_singletons(Ss, Singletons-Singletons2)
    ; Singletons = [Name|Singletons1],
      filter_singletons(Ss, Singletons1-Singletons2) ).
% ----------------------------------------------------------------------
% preprocessing for DCG
% ----------------------------------------------------------------------
preprocess_term(
    term_data((Head --> Guard | Body), _, Text, SourceFile, LineNo),
    _) :-
    may_be_stream(Guard), may_be_stream(Body),
    !,
    format(user_error, '[mlpi] ~a:~d: invalid predicate: "~a".~n',
           [SourceFile, LineNo, Text]),
    Pred = (Head --> Guard | Body),
    throw(error(invalid_predicate(Pred))).
preprocess_term(
    term_data((Head --> Guard | Body), NameVars, Text, SourceFile, LineNo),
    term_data((Head2 :- Guard2 | Body2), NameVars, Text, SourceFile, LineNo)) :-
    may_be_stream(Guard), !,
    debug(mlpi, '~p: ~p', [preprocess_term/2, may_be_stream('Guard' = Guard)]),
    Pred = (Head --> Guard | Body),
    preprocess_stream(Pred, Guard, In1-In2, Guard2),
    Head =.. [F|Args], append(Args, [In1,In2], Args2),
    Head2 =.. [F|Args2],
    Body2 = Body.
preprocess_term(
    term_data((Head --> Guard | Body), NameVars, Text, SourceFile, LineNo),
    term_data((Head2 :- Guard2 | Body2), NameVars, Text, SourceFile, LineNo)) :-
    may_be_stream(Body), !,
    debug(mlpi, '~p: ~p', [preprocess_term/2, may_be_stream('Body' = Body)]),
    Pred = (Head --> Guard | Body),
    preprocess_stream(Pred, Body, Out1-Out2, Body2),
    Head =.. [F|Args], append(Args, [Out1,Out2], Args2),
    Head2 =.. [F|Args2],
    Guard2 = Guard.
preprocess_term(
    term_data((Head --> Body), NameVars, Text, SourceFile, LineNo),
    term_data((Head2 :- Body2), NameVars, Text, SourceFile, LineNo)) :-
    may_be_stream(Body), !,
    debug(mlpi, '~p: ~p', [preprocess_term/2, may_be_stream('Body' = Body)]),
    Pred = (Head --> Body),
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
mlpi(TDList, Args) :-
    setup_mlpi_clauses(TDList),
    mlpi_lookup_and_call(main(Args)).

setup_mlpi_clauses([]).
setup_mlpi_clauses(
    [TermData|TDList]) :-
    ( mlpi_assertz(TermData), !
    ; assertz(mlpi_clauses(TermData, true)) ),
    setup_mlpi_clauses(TDList).

mlpi_asserta(TermData) :-
    ( TermData = term_data((_ :- _), _, _, _, _)
    -> asserta('$__mlpi_clauses__'(TermData))
    ; TermData = term_data(Term, NameVars, Text, SourceFile, LineNo),
      TermData2 = term_data(Term :- true, NameVars, Text, SourceFile, LineNo),
      asserta('$__mlpi_clauses__'(TermData2)) ).
mlpi_assertz(TermData) :-
    ( TermData = term_data((_ :- _), _, _, _, _)
    -> assertz('$__mlpi_clauses__'(TermData))
    ; TermData = term_data(Term, NameVars, Text, SourceFile, LineNo),
      TermData2 = term_data(Term :- true, NameVars, Text, SourceFile, LineNo),
      assertz('$__mlpi_clauses__'(TermData2)) ).

mlpi_abolish(Name, Arity) :-
    findall(Term,
            '$__mlpi_clauses__'(term_data(Term, _, _, _, _)), TDList),
    remove_clause(TDList, Name, Arity, TDList2),
    abolish('$__mlpi_clauses__', 2),
    setup_mlpi_clauses(TDList2).
remove_clause([], _, _, []).
remove_clause([TermData|TDList], Name, Arity, TDList2) :-
    ( TermData = term_data(Head :- _, _, _, _), functor(Head, Name, Arity)
    -> TDList2 = TDList
    ; TDList2 = [TermData|TDList3],
      remove_clause(TDList, Name, Arity, TDList3) ).

mlpi_lookup_and_call(Head) :-
    functor(Head, F, N), functor(Copy, F, N),
    TermData = term_data(Copy :- GuardBody, _, _, _, _),
    '$__mlpi_clauses__'(TermData),
    ( GuardBody = (Guard | Body)
    -> Head = Copy,
       mlpi_call_guard(TermData, Guard),
       mlpi_call_body(TermData, Body)
    ; Head = Copy,
      mlpi_call_body(TermData, GuardBody) ).
get_td_func_arity(term_data(Head :- _, _, _, _, _), Name, Arity) :-
    functor(Head, Name, Arity).
get_td_text(term_data(_, _, Text, _, _), Text).
get_td_position(term_data(_, _, _, SourceFile, LineNo), SourceFile, LineNo).

mlpi_call_guard(TermData, (P, Q)) :-
    mlpi_call_guard(TermData, P),
    mlpi_call_guard(TermData, Q).
mlpi_call_guard(TermData, Head) :-
    Head = (_ -> _), !,
    get_td_func_arity(TermData, Name, Arity),
    get_td_position(TermData, SourceFile, LineNo),
    throw(error(
              mlp_error('"->" not allowed'),
              context(Name/Arity, source(SourceFile, LineNo)))).
mlpi_call_guard(TermData, Head) :-
    Head = (_ ; _), !,
    get_td_func_arity(TermData, Name, Arity),
    get_td_position(TermData, SourceFile, LineNo),
    throw(error(
              mlp_error('";" not allowed'),
              context(Name/Arity, source(SourceFile, LineNo)))).
mlpi_call_guard(TermData, Head) :-
    Head = (_, !, _), !,
    get_td_func_arity(TermData, Name, Arity),
    get_td_position(TermData, SourceFile, LineNo),
    throw(error(
              mlp_error('"!" not allowed'),
              context(Name/Arity, source(SourceFile, LineNo)))).
% built-in predicates
mlpi_call_guard(_, true).
mlpi_call_guard(TermData, var(A)) :- !, call_(TermData, var(A)).
mlpi_call_guard(TermData, nonvar(A)) :- !, call_(TermData, nonvar(A)).
mlpi_call_guard(TermData, integer(I)) :- !, call_(TermData, integer(I)).
mlpi_call_guard(TermData, A is B) :- !, call_(TermData, A is B).
mlpi_call_guard(TermData, A = B) :- !, call_(TermData, A = B).
mlpi_call_guard(TermData, A =\= B) :- !, call_(TermData, A =\= B).
mlpi_call_guard(TermData, A =:= B) :- !, call_(TermData, A =:= B).
mlpi_call_guard(TermData, A < B) :- !, call_(TermData, A < B).
mlpi_call_guard(TermData, A > B) :- !, call_(TermData, A > B).
mlpi_call_guard(TermData, A =< B) :- !, call_(TermData, A =< B).
mlpi_call_guard(TermData, A >= B) :- !, call_(TermData, A >= B).
mlpi_call_guard(TermData, F =.. L) :- !, call_(TermData, F =.. L).
mlpi_call_guard(TermData, append(A, B, C)) :- !, call_(TermData, append(A, B, C)).
mlpi_call_guard(TermData, term_to_atom(T, A)) :- !, call_(TermData, term_to_atom(T, A)).
mlpi_call_guard(TermData, atom_chars(A, Cs)) :- !, call_(TermData, atom_chars(A, Cs)).
mlpi_call_guard(TermData, atom_concat(A, B, C)) :- !, call_(TermData, atom_concat(A, B, C)).
mlpi_call_guard(TermData, atom_number(A, N)) :- !, call_(TermData, atom_number(A, N)).
mlpi_call_guard(TermData, term_string(T, S, Opts)) :-
    !, call_(TermData, term_string(T, S, Opts)).
mlpi_call_guard(TermData, functor(Func, Name, Arity)) :-
    !, call_(TermData, functor(Func, Name, Arity)).
mlpi_call_guard(TermData, phrase(P, A, B)) :-
    !,
    P =.. [F|Args],
    append(Args, [A, B], Args2),
    P2 =.. [F|Args2],
    mlpi_call_guard(TermData, P2).
mlpi_call_guard(TermData, debug(Topic)) :- !, call_(TermData, debug(Topic)).
mlpi_call_guard(TermData, debug(Topic, Format, Args)) :-
    !, call_(TermData, debug(Topic, Format, Args)).
mlpi_call_guard(TermData, nodebug(Topic)) :- !, call_(TermData, nodebug(Topic)).
mlpi_call_guard(TermData, open(F, M, S, Opt)) :- !, call_(TermData, open(F, M, S, Opt)).
mlpi_call_guard(TermData, close(S)) :- !, call_(TermData, close(S)).
mlpi_call_guard(TermData, stream_property(S, P)) :- !, call_(TermData, stream_property(S, P)).
mlpi_call_guard(TermData, stream_position_data(Type, Pos, Val)) :-
    !, call_(TermData, stream_position_data(Type, Pos, Val)).
mlpi_call_guard(TermData, seek(A,B,C,D)) :- !, call_(TermData, seek(A,B,C,D)).
mlpi_call_guard(TermData, read_term(S, T, Opt)) :- !, call_(TermData, read_term(S, T, Opt)).
mlpi_call_guard(TermData, read_string(S, Len, Text)) :- !, call_(TermData, read_string(S, Len, Text)).
mlpi_call_guard(TermData, write(X)) :- !, call_(TermData, write(X)).
mlpi_call_guard(TermData, write(Stream, X)) :- !, call_(TermData, write(Stream, X)).
mlpi_call_guard(TermData, writeln(X)) :- !, call_(TermData, writeln(X)).
mlpi_call_guard(TermData, writeln(Stream, X)) :- !, call_(TermData, writeln(Stream, X)).
mlpi_call_guard(TermData, nl) :- !, call_(TermData, nl).
mlpi_call_guard(TermData, nl(Stream)) :- !, call_(TermData, nl(Stream)).
mlpi_call_guard(TermData, format(Stream, Format, Args)) :-
    !, call_(TermData, format(Stream, Format, Args)).
mlpi_call_guard(TermData, prolog(P)) :- !, call_(TermData, P).
mlpi_call_guard(TermData, call(P)) :- !, call_(TermData, mlpi_call_guard(call(P), P)).
mlpi_call_guard(TermData, freeze(X, P)) :-
    !, call_(TermData, freeze(X, mlpi_call_guard(freeze(X, P), P))).
mlpi_call_guard(TermData, catch(G, Error, Recover)) :-
    !, call_(TermData, catch(mlpi_call_guard(catch(G, Error, Recover), G), Error,
                         mlpi_call_guard(catch(G, Error, Recover), Recover))).
mlpi_call_guard(TermData, abolish(Name, Arity)) :-
    call_(TermData, abolish(Name, Arity), mlpi_abolish(Name, Arity)).
mlpi_call_guard(TermData, asserta(Term)) :-
    call_(TermData, asserta(Term), mlpi_asserta(Term)).
mlpi_call_guard(TermData, assertz(Term)) :-
    call_(TermData, assertz(Term), mlpi_assertz(Term)).
mlpi_call_guard(_, Goal) :-
    mlpi_lookup_and_call(Goal).
call_(Head, Goal) :-
    call_(Head, Goal, Goal).
call_(TermData, DispGoal, RealGoal) :-
    get_td_func_arity(TermData, Name, Arity),
    get_td_position(TermData, SourceFile, LineNo),
    ( call(RealGoal)
    -> debug(mlpi, '[mlpi] ~a:~d: ~p: ~p',
             [SourceFile, LineNo, call_/3,
              success(Name/Arity, guard, DispGoal)])
    ; debug(mlpi, '[mlpi] ~a:~d: ~p: ~p',
            [SourceFile, LineNo, call/3,
             fail(Name/Arity, guard, DispGoal)]),
      !, fail ).
mlpi_call_body(TermData, (P, Q)) :-
    mlpi_call_body(TermData, P),
    mlpi_call_body(TermData, Q).
mlpi_call_body(TermData, Head) :-
    Head = (_ -> _), !,
    get_td_func_arity(TermData, Name, Arity),
    get_td_position(TermData, SourceFile, LineNo),
    throw(error(
              mlp_error('"->" not allowed'),
              context(Name/Arity, source(SourceFile, LineNo)))).
mlpi_call_body(TermData, Head) :-
    Head = (_ ; _), !,
    get_td_func_arity(TermData, Name, Arity),
    get_td_position(TermData, SourceFile, LineNo),
    throw(error(
              mlp_error('";" not allowed'),
              context(Name/Arity, source(SourceFile, LineNo)))).
mlpi_call_body(TermData, Head) :-
    Head = (_, !, _), !,
    get_td_func_arity(TermData, Name, Arity),
    get_td_position(TermData, SourceFile, LineNo),
    throw(error(
              mlp_error('"!" not allowed'),
              context(Name/Arity, source(SourceFile, LineNo)))).
mlpi_call_body(_, true).
mlpi_call_body(TermData, P) :-
    get_td_func_arity(TermData, Name, Arity),
    get_td_position(TermData, SourceFile, LineNo),
    ( mlpi_call_guard(TermData, P) ->
      debug(mlpi, '[mlpi] ~a:~d: ~p: ~p',
            [SourceFile, LineNo, mlpi_call_body/2, success(Name/Arity, body, P)])
    ; throw(error(
                mlp_error(body_failed(P)),
                context(Name/Arity, source(SourceFile, LineNo)))) ).
