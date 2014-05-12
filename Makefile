PROJECT   = eon

# Options
ERLC_OPTS = +debug_info +nowarn_shadow_vars +warnings_as_errors
DEPS      = stdlib2

# Dependencies
dep_stdlib2 = git://github.com/kivra/stdlib2.git master

# Standard targets
include erlang.mk

.PHONY: eunit
eunit:
	erl -noshell -pa ebin -eval 'eunit:test("ebin", [verbose])' -s init stop

# eof