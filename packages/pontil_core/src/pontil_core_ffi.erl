-module(pontil_core_ffi).
-export([
    set_exit_code/1,
    get_output_mode/0,
    set_output_mode/1,
    add_secrets/1,
    get_secrets/0,
    clear_secrets/0
]).

set_exit_code(ExitCode) ->
    Code =
        case ExitCode of
            failure -> 1;
            success -> 0;
            {exit, N} -> N
        end,
    erlang:put(pontil_process_exit_code, Code),
    nil.

get_output_mode() ->
    case persistent_term:get(pontil_output_mode, undefined) of
        undefined ->
            Mode = pontil@core:action_mode(),
            persistent_term:put(pontil_output_mode, Mode),
            Mode;
        Mode ->
            Mode
    end.

set_output_mode(Mode) ->
    persistent_term:put(pontil_output_mode, Mode),
    nil.

add_secrets(NewSecrets) ->
    Existing = persistent_term:get(pontil_secrets, []),
    Updated = lists:usort(NewSecrets ++ Existing),
    persistent_term:put(pontil_secrets, Updated),
    nil.

get_secrets() ->
    persistent_term:get(pontil_secrets, []).

clear_secrets() ->
    persistent_term:put(pontil_secrets, []),
    nil.
