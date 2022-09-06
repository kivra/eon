%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% @doc Recursive type.
%%% @end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%_* Module declaration ===============================================
-module(eon_type_rec).

%%%_* Callbacks ========================================================
-callback name()                                    -> eon_type:name().
-callback parameters()                              -> eon_type:params().
-callback decl(eon:object(A, _), eon_type:params()) -> eon_type:decl(A).
-callback extra_validation(eon:object(), eon_type:params()) -> ok | {error, term}.

-optional_callbacks([extra_validation/2]).

%%%_* Emacs ============================================================
%%% Local Variables:
%%% allout-layout: t
%%% erlang-indent-level: 2
%%% End:
