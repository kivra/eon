-module(test_rec_extra).
-behaviour(eon_type_rec).
-include_lib("stdlib2/include/prelude.hrl").
-export([name/0, parameters/0, decl/2, extra_validation/2]).

name() -> some_obj.

parameters() -> [].

decl(_Obj, _Params) ->
    [ <<"foo">>, {test_prim, [min,0, max,100]}
    ].

extra_validation(_Term, _Params) ->
    {error, nope}.
