%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Dictionary API.
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%_* Module declaration ===============================================
-module(eon).
-compile({no_auto_import, [size/1]}).

%%%_* Exports ==========================================================
%% Constructors
-export([new/0]).
-export([new/1]).
-export([new/2]).

%% Basics
-export([del/2]).
-export([ddel/2]).
-export([equal/2]).
-export([get/2]).
-export([get/3]).
-export([get_/2]).
-export([dget/2]).
-export([dget/3]).
-export([dget_/2]).
-export([is_empty/1]).
-export([is_key/2]).
-export([keys/1]).
-export([set/3]).
-export([dset/3]).
-export([rename/3]).
-export([size/1]).
-export([vals/1]).
-export([with/2]).
-export([without/2]).
-export([zip/2]).

%% Conversion
-export([from_map/1]).
-export([from_dmap/1]).
-export([to_map/1]).
-export([to_dmap/1]).

%% Higher-order
-export([all/2]).
-export([any/2]).
-export([filter/2]).
-export([fold/3]).
-export([map/2]).

%% Sets
-export([difference/2]).
-export([intersection/2]).
-export([union/2]).

%% Iterators
-export([done/1]).
-export([make/1]).
-export([next/1]).

%% Types
-export_type([literal/2]).
-export_type([object/0]).
-export_type([object/2]).

%%%_* Includes =========================================================
-include("eon.hrl").
-include_lib("stdlib/include/assert.hrl").
-include_lib("stdlib2/include/prelude.hrl").

%%%_* Macros ===========================================================
-define(assertObjEq(Obj1, Obj2), ?assertEqual( lists:sort(dsort(new(Obj1)))
                                             , lists:sort(dsort(new(Obj2))) )).

%%%_* Code =============================================================
%%%_ * Types -----------------------------------------------------------
-type kv_list(A, B) :: [{A, B}].
-type object()      :: orddict:orddict().
-type object(A, B)  :: orddict:orddict()
                     | kv_list(A, B)
                     | literal(A, B)
                     | dict:dict()
                     | map(A, B).

-type literal(A, B) :: [A | B].
-type deep_key()    :: binary() | list().
-type map(A, B)     :: #{A := B}.

-type func(A)       :: fun((_, _) -> A)
                     | fun((_)    -> A).

%%%_ * Constructors ----------------------------------------------------
-spec new() -> object(_, _).
%% @doc new() is a fresh object.
new() -> orddict:new().

-spec new(object(A, B) | map(A, B)) -> object(A, B).
%% @doc new(Obj) is the canonical representation of Obj.
new([{}])                        -> [];
new([X|_] = Xs) when is_tuple(X) -> Xs;
new(Map) when is_map(Map)        -> from_map(Map);
new(Xs) when is_list(Xs)         -> orddict:from_list(partition(Xs));
new(Xs)                          -> orddict:from_list(dict:to_list(Xs)).

partition(KVs) ->
  ?assert(0 =:= length(KVs) rem 2),
  [{K, V} || [K, V] <- s2_lists:partition(2, KVs)].

-spec new(object(A, B), func(boolean())) -> object(A, B).
%% @doc new(Obj, Pred) is the canonical representation of Obj if Pred
%% returns true for all entries.
new(X, Pred) ->
  orddict:map(
    fun(K, V) ->
      if is_function(Pred, 1) -> Pred(V);
         is_function(Pred, 2) -> Pred(K, V)
      end orelse throw({error, {validator, K, V}}),
      V
    end, new(X)).

%%%_ * Basics ----------------------------------------------------------
-spec del(object(A, B), A) -> object(A, B).
%% @doc del(Obj, Key) is Obj with the entry for Key removed.
del(Obj, Key) -> lists:keydelete(Key, 1, new(Obj)).

-spec ddel(object(deep_key(), B), deep_key()) -> object(deep_key(), B).
%% @doc ddel(Obj, Key) is Obj with the entry for the deep Key removed.
%%  A deep key is a `.`-delimetered key.
ddel(O, K) when is_binary(K)         -> ddel(O, normalize_deep_key(K));
ddel(Obj, [H|T]=K) when is_list(K) ->
    case get(Obj, H) of
        {error, notfound}            -> Obj;
        {ok, _} when length(T) =:= 0 -> del(Obj, H);
        {ok, O} when is_list(O)      -> set(Obj, H, ddel(O, T))
    end.


-spec equal(object(_, _), object(_, _)) -> boolean().
%% @doc equal(Obj1, Obj2) is true iff Obj1 matches Obj2.
equal(Obj, Obj)   -> true;
equal(Obj1, Obj2) ->
  try ?assertObjEq(Obj1, Obj2) of
    ok -> true
  catch
    error:{assertEqual, _} -> false
  end.

-spec get(object(A, B), A) -> 'maybe'(B, notfound).
%% @doc get(Obj, Key) is the value associated with Key in Obj,
%% or an error if no such value exists.
get(Obj, Key) ->
  case lists:keyfind(Key, 1, new(Obj)) of
    {Key, Val} -> {ok, Val};
    false      -> {error, notfound}
  end.

-spec get(object(A, B), A, B) -> B.
%% @doc get(Obj, Key, Default) is the value associated with Key in Obj,
%% or Default if no such value exists.
get(Obj, Key, Default) ->
  case get(Obj, Key) of
    {ok, Res}         -> Res;
    {error, notfound} -> Default
  end.

-spec get_(object(A, B), A) -> B | no_return().
%% @doc get(Obj, Key) is the value associated with Key in Obj,
%% or an exception if no such value exists.
get_(Obj, Key) ->
  {ok, Res} = get(Obj, Key),
  Res.

-spec dget(object(deep_key(), B), deep_key()) -> 'maybe'(B, notfound).
%% @doc dget(Obj, Key) is the value associated with the deep Key in Obj,
%% or an error if no such value exists. A deep key is a `.`-delimetered key.
dget(Obj, Key) ->
    lists:foldl(fun(_, {error, notfound}=E)         -> E;
                   (K, {ok, Acc}) when is_list(Acc) -> eon:get(Acc, K);
                   (_, {ok, _})                     -> {error, notfound}
                end, {ok, new(Obj)}, normalize_deep_key(Key)).

-spec dget(object(deep_key(), B), deep_key(), B) -> B.
%% @doc dget(Obj, Key) is the value associated with the deep Key in Obj,
%% or Default if no such value exists. A deep key is a `.`-delimetered key.
dget(Obj, Key, Default) ->
  case dget(Obj, Key) of
    {ok, Res}         -> Res;
    {error, notfound} -> Default
  end.

-spec dget_(object(deep_key(), B), deep_key()) -> B | no_return().
%% @doc dget(Obj, Key) is the value associated with the deep Key in Obj,
%% or an exception if no such value exists. A deep key is a `.`-delimetered key.
dget_(Obj, Key) ->
  {ok, Res} = dget(Obj, Key),
  Res.

-spec is_empty(object(_, _)) -> boolean().
%% @doc is_empty(Obj) is true iff Obj is empty.
is_empty(Obj) -> 0 =:= size(new(Obj)).


-spec is_key(object(A, _), A) -> boolean().
%% @doc is_key(Obj, Key) is true iff there is a value associated with
%% Key in Obj.
is_key(Obj, Key) -> lists:keymember(Key, 1, new(Obj)).


-spec keys(object(A, _)) -> [A].
%% @doc keys(Obj) is a list of all keys in Obj.
keys(Obj) -> [K || {K, _} <- new(Obj)].


-spec set(object(A, B), A, B) -> object(A, B).
%% @doc set(Obj, Key, Val) is an object which is identical to Obj
%% execept that it maps Key to Val.
set(Obj, Key, Val) -> lists:keystore(Key, 1, new(Obj), {Key, Val}).

-spec dset(object(A, B), A, B) -> object(A, B).
%% @doc dset(Obj, Key, Val) is an object which is identical to Obj
%% execept that it maps s deep Key to Val. A deep key is a `.`-delimetered key.
dset(O, K, V) when is_binary(K)         -> dset(O, normalize_deep_key(K), V);
dset(_, [], Val)                        -> Val;
dset(Obj, [H|T]=K, Val) when is_list(K) ->
    case get(Obj, H) of
        {error, notfound}       -> set(Obj, H, dset(new(), T, Val));
        {ok, O} when is_list(O) -> set(Obj, H, dset(O, T, Val));
        {ok, _}                 -> set(Obj, H, dset(new(), T, Val))
    end.

-spec rename(object(A, B), A, A) -> object(A, B).
%% @doc rename(Obj, OldKey, NewKey) renames OldKey to NewKey.
rename(O, K0, K1) -> eon:set(eon:del(O, K0), K1, eon:get_(O, K0)).

-spec size(object(_, _)) -> non_neg_integer().
%% @doc size(Obj) is the number of mappings in Obj.
size(Obj) -> orddict:size(new(Obj)).


-spec vals(object(A, _)) -> [A].
%% @doc vals(Obj) is a list of all values in Obj.
vals(Obj) -> [V || {_, V} <- new(Obj)].


-spec with(object(A, _), [A]) -> object(A, _).
%% @doc Returns an object with the keys specified in `Keys`. Any key in `Keys`
%% that does not exist in `Obj` is ignored.
with(Obj, Keys) ->
  filter(fun(Key, _V) -> lists:member(Key, Keys) end, Obj).


-spec without(object(A, _), [A]) -> object(A, _).
%% @doc Returns an object without the keys specified in `Keys`. Any key in
%% `Keys` that does not exist in `Obj` is ignored.
without(Obj, Keys) ->
  filter(fun(Key, _V) -> not lists:member(Key, Keys) end, Obj).


-spec zip(object(A, B), object(A, C)) -> object(A, {B, C}).
%% @doc zip(Obj1, Obj2) is an object which maps keys from Obj1 to values
%% from both Obj1 and Obj2.
%% Obj1 and Obj2 must have the same set of keys.
zip(Obj1, Obj2) ->
  ?assertEqual(lists:sort(keys(Obj1)), lists:sort(keys(Obj2))),
  orddict:merge( fun(_K, V1, V2) -> {V1, V2} end
               , lists:sort(new(Obj1)), lists:sort(new(Obj2)) ).

%%%_ * Conversion ------------------------------------------------------
-spec to_map(object(A, B)) -> map(A, B).
%% @doc to_map(Obj) returns a map representing the key-value associations of
%% Obj.
to_map(Obj) -> maps:from_list(to_list(Obj)).

-spec to_dmap(object(A, B | object(C, D))) -> map(A, B | map(C, D)).
%% @doc to_map(Obj) returns a map representing the key-value associations of
%% Obj. For deeply nested objects, values are converted to maps recursively.
to_dmap(Obj) -> maps:map(fun maybe_obj_to_map/2, to_map(Obj)).

-spec from_map(map(A, B)) -> object(A, B).
%% @doc from_map(Obj) returns an object representing the key-value
%% associations of Map.
from_map(Map) -> new(maps:to_list(Map)).

-spec from_dmap(map(A, B | map(C, D))) -> object(A, B | object(C, D)).
%% @doc from_dmap(Obj) returns an eon object representing the key-value
%% associations of Map. For deeply nested maps, values are converted to
%% objects recursively.
from_dmap(Map) -> map(fun maybe_map_to_obj/1, from_map(Map)).

%%%_ * Higher-order ----------------------------------------------------
-spec all(func(boolean()), object(_, _)) -> boolean().
%% @doc all(F, Obj) returns `true` if `F` evaluates to `true` for all
%% entries in Obj.
all(F, Obj) when is_function(F, 1) ->
  foldl_while(fun(V, _Acc) -> format_all(F(V)) end, true, Obj);
all(F, Obj) when is_function(F, 2) ->
  foldl_while(fun(K, V, _Acc) -> format_all(F(K, V)) end, true, Obj).


-spec any(func(boolean()), object(_, _)) -> boolean().
%% @doc any(F, Obj) returns `true` if `F` evaluates to `true` for any
%% entry in Obj.
any(F, Obj) when is_function(F, 1) ->
  foldl_while(fun(V, _Acc) -> format_any(F(V)) end, false, Obj);
any(F, Obj) when is_function(F, 2) -> 
  foldl_while(fun(K, V, _Acc) -> format_any(F(K, V)) end, false, Obj).


foldl_while(F, Acc, [{_K, V} | Tail]) when is_function(F, 2) ->
  continue_or_acc(F, F(V, Acc), Tail);
foldl_while(F, Acc, [{K, V} | Tail]) when is_function(F, 3) ->
  continue_or_acc(F, F(K, V, Acc), Tail);
foldl_while(_F, Acc, []) -> Acc.

continue_or_acc(F, {ok, Acc}, Obj) -> foldl_while(F, Acc, Obj);
continue_or_acc(_, {stop, Acc}, _) -> Acc.

format_all(true)  -> {ok, true};
format_all(false) -> {stop, false}.

format_any(false) -> {ok, false};
format_any(true)  -> {stop, true}.

-spec map(func(C), object(A, _)) -> object(A, C).
%% @doc map(F, Obj) is the result of mapping F over Obj's entries.
map(F, Obj) ->
  orddict:map(
    fun(K, V) ->
      if is_function(F, 1) -> F(V);
         is_function(F, 2) -> F(K, V)
      end
    end, new(Obj)).


-spec filter(func(boolean()), object(_, _)) -> object(_, _).
%% @doc filter(F, Obj) is the subset of entries in Obj for which Pred
%% returns true.
filter(Pred, Obj) ->
  orddict:filter(
    fun(K, V) ->
      if is_function(Pred, 1) -> Pred(V);
         is_function(Pred, 2) -> Pred(K, V)
      end
    end, new(Obj)).


-spec fold(fun(), A, object(_, _)) -> A.
%% @doc fold(F, Acc0, Obj) is Obj reduced to Acc0 via F.
fold(F, Acc0, Obj) ->
  lists:foldl(
    fun({K, V}, Acc) ->
      if is_function(F, 2) -> F(V, Acc);
         is_function(F, 3) -> F(K, V, Acc)
      end
    end, Acc0, new(Obj)).

%%%_ * Sets ------------------------------------------------------------
-spec union(object(_, _), object(_, _)) -> object(_, _).
%% @doc union(Obj1, Obj2) is Obj1 plus any entries from Obj2 whose keys
%% do not occur in Obj1.
union(Obj1, Obj2) ->
  lists:ukeymerge(1, lists:ukeysort(1,new(Obj1)), lists:ukeysort(1,new(Obj2))).


-spec difference(object(_, _), object(_, _)) -> object(_, _).
%% @doc difference(Obj1, Obj2) is Obj1 with all entries whose keys occur
%% in Obj2 removed.
difference(Obj1, Obj2) ->
  orddict:filter(fun(K, _V) -> not is_key(new(Obj2), K) end, new(Obj1)).

-spec intersection(object(_, _), object(_, _)) -> object(_, _).
%% @doc intersection(Obj1, Obj2) is Obj1 with all entries whose keys do
%% not occur in Obj2 removed.
intersection(Obj1, Obj2) ->
  orddict:filter(fun(K, _V) -> is_key(new(Obj2), K) end, new(Obj1)).

%%%_ * Iterators -------------------------------------------------------
-type iterator()         :: [{_, _}].

-spec make(object(_, _)) -> iterator().
%% @doc make(Obj) is an iterator for Obj.
make(Obj)                -> new(Obj).

-spec next(iterator())   -> {_, iterator()}.
%% @doc next(It0) is the next entry in iterator It0 and the updated
%% iterator It.
next([X|Xs])             -> {X, Xs}.

-spec done(iterator())   -> boolean().
%% @doc done(It) is true iff iterator it is empty.
done([])                 -> true;
done([_|_])              -> false.

%%%_* Private functions ================================================
normalize_deep_key(K) when is_binary(K) -> binary:split(K, <<".">>, [global]);
normalize_deep_key(K) when is_list(K), not is_integer(hd(K)) -> K;
normalize_deep_key(K) when is_list(K)   -> string:tokens(K, ".").

dsort([])                            -> [];
dsort([{K, V} | T]) when is_list(V)  -> [{K, lists:sort(dsort(V))} | dsort(T)];
dsort([H | T]) when is_list(H)       -> [lists:sort(dsort(H)) | dsort(T)];
dsort([H | T])                       -> [H | dsort(T)].

maybe_obj_to_map(_Key, Val) -> maybe_apply(fun to_dmap/1, Val).

maybe_map_to_obj(Val) -> maybe_apply(fun from_dmap/1, Val).

to_list(Obj) -> Obj.

maybe_apply(F, Any) ->
  try
    F(Any)
  catch
    _:_ -> Any
  end.

%%%_* Tests ============================================================
-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

new_test() ->
  _           = new(),
  _           = new(dict:new()),
  _           = new(orddict:store( foo
                                 , 42
                                 , orddict:store(bar, 666, orddict:new())) ),
  _           = new([{foo, 42}, {bar, 666}]),
  _           = new([{foo, bar},baz]),
  _           = new([foo,42, bar,666]),
  _           = new(#{}),
  _           = new(#{foo => 42, bar => 666}),
  {'EXIT', _} = (catch new([foo,bar, baz])),
  {'EXIT', _} = (catch new(42)),

  _           = new([foo,bar], fun(K, V) -> K =:= foo andalso V =:= bar end),
  {error, _}  = (catch new([foo,bar], fun(V) -> V =:= baz end)).

del_test() ->
  Nil = new(),
  Nil = del(Nil, foo),
  Nil = del(set(Nil, foo, bar), foo).

ddel_test() ->
  P = [ {<<"one">>,   1}
      , {<<"two">>,   [ {<<"two_one">>,   21}
                      , {<<"two_two">>,   [{<<"two_two">>, 22}]}
                      , {<<"two_three">>, [{ <<"two_three_one">>
                                           , [{<<"two_three_one">>, 231}]
                                           }]}
                      ]}
      , {"three",     3} ],

  ?assertObjEq(new([{<<"one">>, 1}, {"three", 3}]), ddel(P, <<"two">>)),
  ?assertObjEq(P, ddel(P, <<"blahblah">>)),
  ?assertObjEq(set( P, <<"two">>
                  , new([ {<<"two_two">>,   [{<<"two_two">>,22}]}
                        , {<<"two_three">>, [{ <<"two_three_one">>
                                             , [{<<"two_three_one">>,231}]}
                                            ]}
                        ])), ddel(P, <<"two.two_one">>)).

equal_test() ->
  true  = equal(new(), new()),
  false = equal([foo,bar], [foo,baz]).

get_test() ->
  {error, notfound} = get(new(), foo),
  bar               = get(new(), foo, bar),
  {ok, bar}         = get(set(new(), foo, bar), foo),
  bar               = get(set(new(), foo, bar), foo, baz),
  1                 = get_([foo, 1], foo),
  {error, {lifted_exn, {badmatch, {error, notfound}}, _}}
                    = ?lift(get_(new(), foo)).

is_empty_test() ->
  true  = is_empty(new()),
  false = is_empty([foo,bar]).

is_key_test() ->
  false = is_key(new(), foo),
  true  = is_key(set(new(), foo, bar), foo).

keys_test() ->
  [] = keys(new()).

set_test() ->
  ?assertObjEq(set(new(), foo, bar),
               set(new(), foo, bar)).

dset_test() ->
  P = [ {<<"one">>,   1}
      , {<<"two">>,   [ {<<"two_one">>,   21}
                      , {<<"two_two">>,   [{<<"two_two">>, 22}]}
                      , {<<"two_three">>, [{ <<"two_three_one">>
                                           , [{<<"two_three_one">>, 231}]
                                           }]}
                      ]}
      , {"three",     3} ],

  ?assertObjEq(union(new([{<<"non">>, [{<<"existent">>, <<"val">>}]}]), P),
               dset(P, <<"non.existent">>, <<"val">>)),
  ?assertObjEq(union(new([{<<"non">>, [{<<"existent">>, <<"val">>}]}]), P),
               dset(P, [<<"non">>, <<"existent">>], <<"val">>)),
  ?assertObjEq(set(P, <<"one">>, 1), dset(P, <<"one">>, 1)),
  ?assertObjEq(set(P, <<"one">>, 3), dset(P, <<"one">>, 3)),
  ?assertObjEq(set(P, <<"two">>, 2), dset(P, <<"two">>, 2)),
  ?assertObjEq(set( P, <<"two">>
                  , new([ {<<"two_one">>,   666}
                        , {<<"two_two">>,   [{<<"two_two">>,22}]}
                        , {<<"two_three">>, [{ <<"two_three_one">>
                                             , [{<<"two_three_one">>,231}]}
                                            ]}
                        ])), dset(P, <<"two.two_one">>, 666)).

dget_test() ->
  P = [ {<<"one">>,   1}
      , {<<"two">>,   [ {<<"two_one">>,   21}
                      , {<<"two_two">>,   [{<<"two_two">>, 22}]}
                      , {<<"two_three">>, [{ <<"two_three_one">>
                                           , [{<<"two_three_one">>, 231}]
                                           }]}
                      ]}
      , {"three",     3}
      , {<<"four">>,      null}],
  {error, notfound} = dget(P, <<"non.existent">>),
  blarg             = dget(P, <<"non.existent">>, blarg),
  {ok, 1}           = dget(P, <<"one">>),
  {ok, 3}           = dget(P, "three"),
  true              = equal(get(P, <<"two">>), dget(P, <<"two">>)),
  {ok, 21}          = dget(P, <<"two.two_one">>),
  {ok, 22}          = dget(P, <<"two.two_two.two_two">>),
  {ok, 231}         = dget(P, <<"two.two_three.two_three_one.two_three_one">>),
  {ok, 231}         = dget(P, [<<"two">>, <<"two_three">>, <<"two_three_one">>, <<"two_three_one">>]),
  {ok, null}        = dget(P, <<"four">>),
  {error, notfound} = dget(P, <<"four.five">>),
  {error, {lifted_exn, {badmatch, {error, notfound}}, _}}
                    = ?lift(dget_(new(), "foo")).

rename_test() ->
  Obj0 = eon:new([{foo, 1}, {bar, 2}]),
  Obj1 = eon:rename(Obj0, bar, baz),
  ?assertObjEq(eon:new([{foo, 1}, {baz, 2}]), Obj1).

size_test() ->
  0 = size(new()),
  1 = size([foo,bar]).

vals_test() ->
  Vs   = vals([foo,1, bar,2]),
  true = lists:member(1, Vs),
  true = lists:member(2, Vs).

from_to_map_test() ->
  Obj     = eon:new([{foo, 1}, {bar, 2}]),
  SubObj  = eon:new([{baz, 2},
                     {hello, eon:new([{hi, 3},
                                      {hej, eon:new()}])}]),
  DeepObj = eon:new([{foo, 1}, {bar, SubObj}]),

  Map     = #{foo => 1, bar => 2},
  SubMap  = #{baz => 2,
              hello => #{hi => 3,
                         hej => #{}}},
  DeepMap = #{foo => 1, bar => SubMap},

  %% from_map
  ?assertObjEq(eon:new(), eon:from_map(#{})),
  ?assertObjEq(Obj, eon:from_map(Map)),
  ?assertObjEq(Obj, eon:from_dmap(Map)),
  ?assertEqual(SubMap, eon:get_(eon:from_map(DeepMap), bar)),
  ?assertEqual(SubMap, eon:get_(eon:new(DeepMap), bar)),
  ?assertObjEq(DeepObj, eon:from_dmap(DeepMap)),
  ?assertObjEq(DeepObj, eon:from_dmap(eon:to_dmap(DeepObj))),

  % %% to_map
  ?assertEqual(Map, eon:to_map(Obj)),
  ?assertEqual(Map, eon:to_dmap(Obj)),
  ?assertObjEq(SubObj, maps:get(bar, eon:to_map(DeepObj))),
  ?assertEqual(DeepMap, eon:to_dmap(DeepObj)),
  ?assertEqual(DeepMap, eon:to_dmap(eon:from_dmap(DeepMap))).

with_test() ->
  ?assertObjEq(eon:new([foo,1, bar,2]),
               with(eon:new([foo,1, bar,2, baz,3]), [foo, bar])),
  ?assertObjEq(eon:new([foo,1, bar,2]),
               with(eon:new([foo,1, bar,2, baz,3]), [foo, bar, hello])).

without_test() ->
  ?assertObjEq(eon:new([baz,3]),
               without(eon:new([foo,1, bar,2, baz,3]), [foo, bar])),
  ?assertObjEq(eon:new([baz,3]),
               without(eon:new([foo,1, bar,2, baz,3]), [foo, bar, hello])).

zip_test() ->
  ?assertObjEq([foo,{bar, baz}],
               zip([foo,bar], [foo,baz])).

all_test() ->
  ?assert(all(fun(V)        -> V < 3       end, eon:new([]))),
  ?assert(all(fun(V)        -> V < 3       end, eon:new([a,1, b,2]))),
  ?assertNot(all(fun(V)     -> V < 3       end, eon:new([a,1, b,4]))),
  ?assert(all(fun(K, _V)    -> K < <<"c">> end, eon:new([<<"a">>,1, <<"b">>,2]))),
  ?assertNot(all(fun(K, _V) -> K < <<"c">> end, eon:new([<<"a">>,1, <<"d">>,2]))).

any_test() ->
  ?assertNot(any(fun(V)     -> V < 3       end, eon:new([]))),
  ?assert(any(fun(V)        -> V < 3       end, eon:new([a,1, b,4]))),
  ?assertNot(any(fun(V)     -> V < 3       end, eon:new([a,3, b,4]))),
  ?assert(any(fun(K, _V)    -> K < <<"c">> end, eon:new([<<"a">>,1, <<"d">>,2]))),
  ?assertNot(any(fun(K, _V) -> K < <<"c">> end, eon:new([<<"c">>,1, <<"d">>,2]))).

map_test() ->
  ?assertObjEq([foo,1],
               map(fun(V) -> V+1 end, [foo,0])),
  ?assertObjEq([foo,1],
               map(fun(_K, V) -> V+1 end, [foo,0])).

filter_test() ->
  ?assertObjEq(new(),
               filter(fun(V) -> V =/= 42 end, [foo, 42])),
  ?assertObjEq(new(),
               filter(fun(K, _V) -> K =/= foo end, [foo, 42])).

fold_test() ->
  6  = fold(fun(V, Sum)    -> V+Sum end,   0, [1,2, 3,4]),
  10 = fold(fun(K, V, Sum) -> K+V+Sum end, 0, [1,2, 3,4]).

union_test() ->
  ?assertObjEq([foo,1, bar,2, baz,3],
               union([foo,1, bar,2], [bar,3, baz,3])).

intersection_test() ->
  ?assertObjEq([bar,2],
               intersection([foo,1, bar,2], [bar,2, baz,2])).

difference_test() ->
  ?assertObjEq(new(),
               difference([foo,1], [foo, 2])).

iterator_test() ->
 It0         = make([foo,1, bar,2]),
 {Elt1, It1} = next(It0),
 true        = Elt1 =:= {foo,1} orelse Elt1 =:= {bar,2},
 false       = done(It1),
 {Elt2, It}  = next(It1),
 true        = Elt2 =:= {foo,1} orelse Elt2 =:= {bar,2},
 true        = Elt1 =/= Elt2,
 true        = done(It).

-endif.

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
