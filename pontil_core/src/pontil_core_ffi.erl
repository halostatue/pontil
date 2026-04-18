-module(pontil_core_ffi).
-export([set_exit_code/1]).

set_exit_code(ExitCode) ->
    Code =
        case ExitCode of
            failure -> 1;
            success -> 0
        end,
    erlang:put(pontil_process_exit_code, Code),
    nil.
