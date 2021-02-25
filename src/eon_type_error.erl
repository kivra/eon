%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Extract type checking error information
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%_* Module declaration ===============================================
-module(eon_type_error).

%%%_* Includes =========================================================

%%%_* Exports ==========================================================
-export([get_error_name/1]).
-export([get_full_key/1]).
-export([get_root_cause/1]).

%%%_* Code =============================================================
%%%_* Types ============================================================

%%%_ * API -------------------------------------------------------------
get_error_name({untypable, [Rsn|_]}) ->
  eon_type:get_error(name, Rsn).

get_full_key(Rsn) -> binary_join(get_error_key_list(Rsn), <<".">>).

get_root_cause({untypable, [Rsn|_]}) ->
  case eon_type:get_error(rsn, Rsn) of
    {untypable, _} = E ->
      get_root_cause(E);
    _ ->
      Term = eon_type:get_error(term, Rsn),
      Type = eon_type:get_error(type, Rsn),
      {Term, Type}
  end.

%%%_ * Internals -------------------------------------------------------
%% @doc get_error_key_list(Rsn) is the keys in the chain of untypable reasons
get_error_key_list(Rsn) -> get_error_key_list(Rsn, []).

get_error_key_list({untypable, [Rsn|_]}, Acc) ->
  case eon_type:get_error(key, Rsn) of
    term -> lists:reverse(Acc); %% Base case for JSON lists
    Value -> ChildRsn = eon_type:get_error(rsn, Rsn),
      get_error_key_list(ChildRsn, [Value|Acc])
  end;
get_error_key_list(_, Acc) -> lists:reverse(Acc). %% Base case for JSON objects

-spec binary_join([binary()], binary()) -> binary().
binary_join(List, Sep) ->
  list_to_binary(lists:join(Sep, List)).

%%%_* Tests ============================================================
-ifdef(TEST).
-ifdef(kivra_nova).
-include_lib("eunit/include/eunit.hrl").

get_full_key_test() ->
  Rsn = { untypable
        , [ { <<"contact_info">>, type_contact_info, contact_info, the_term
            , { untypable
              , [{<<"email">>, type_email, email, the_term, validate}]}}]},
  [<<"contact_info">>, <<"email">>] = get_error_key_list(Rsn),
  <<"contact_info.email">>          = get_full_key(Rsn).

get_root_cause__primitive_type__test() ->
  {error, Rsn} = eon_type:check_term(42, type_string),
  {42, type_string} = get_root_cause(Rsn).

get_root_cause__recursive_type_wrong_nested_type__test() ->
  Term =
    [ {<<"orgnr">>, <<"SE1234">>}
    , {<<"name">>, <<"Test">>}
    ],
  {error, Rsn} = eon_type:check_term(Term, type_company_id_item),
  {<<"SE1234">>, type_orgnr} = get_root_cause(Rsn).

get_root_cause__recursive_type_missing_field__test() ->
  Term =
    [ {<<"name">>, <<"Test">>}
    ],
  {error, Rsn} = eon_type:check_term(Term, type_company_id_item),
  {Term, type_company_id_item} = get_root_cause(Rsn).

get_root_cause__list_type__test() ->
  {error, Rsn} = eon_type:check_term([<<"foo">>, 42], type_strings),
  {42, type_string} = get_root_cause(Rsn).

-endif.
-endif.
