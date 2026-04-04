-module(pontil_ffi).
-export([
    is_linux/0,
    is_macos/0,
    is_windows/0,
    os_arch/0,
    os_type/0,
    set_exit_code/1,
    stop/0
]).

set_exit_code(ExitCode) ->
    Code =
        case ExitCode of
            failure -> 1;
            success -> 0
        end,
    erlang:put(pontil_process_exit_code, Code),
    nil.

stop() ->
    Code =
        case erlang:get(pontil_process_exit_code) of
            undefined -> 0;
            V -> V
        end,
    erlang:halt(Code).

is_windows() ->
    case os:type() of
        {win32, _} -> true;
        _ -> false
    end.

is_macos() ->
    case os:type() of
        {unix, darwin} -> true;
        _ -> false
    end.

is_linux() ->
    case os:type() of
        {unix, linux} -> true;
        _ -> false
    end.

os_type() ->
    case os:type() of
        {win32, _} -> windows;
        {unix, darwin} -> mac_o_s;
        {unix, linux} -> linux;
        {unix, Other} -> {other, atom_to_binary(Other, utf8)};
        _ -> {other, <<"unknown">>}
    end.

os_arch() ->
    list_to_binary(erlang:system_info(system_architecture)).
