-module(pontil_core_test_ffi).
-export([get_exit_code/0, clear_exit_code/0]).

get_exit_code() ->
    case erlang:get(pontil_process_exit_code) of
        undefined -> {error, nil};
        Code -> {ok, Code}
    end.

clear_exit_code() ->
    erlang:erase(pontil_process_exit_code),
    nil.
