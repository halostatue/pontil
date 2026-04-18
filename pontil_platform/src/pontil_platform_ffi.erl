%% Platform detection FFI for Erlang.
%%
%% Portions of the runtime FFI are adapted from https://github.com/DitherWither/platform,
%% licensed under Apache-2.0.

-module(pontil_platform_ffi).
-export([runtime/0, os/0, arch/0, runtime_version/0]).

runtime() ->
    erlang.

runtime_version() ->
    list_to_binary(erlang:system_info(otp_release)).

os() ->
    case os:type() of
        {win32, _} -> win32;
        {unix, aix} -> aix;
        {unix, darwin} -> darwin;
        {unix, freebsd} -> free_bsd;
        {unix, linux} -> linux;
        {unix, openbsd} -> open_bsd;
        {unix, sunos} -> sun_os;
        {unix, Other} -> {other_os, atom_to_binary(Other, utf8)};
        _ -> {other_os, <<"unknown">>}
    end.

arch() ->
    Raw =
        case erlang:system_info(os_type) of
            {unix, _} ->
                [A | _] = string:split(
                    erlang:system_info(system_architecture), "-"
                ),
                unicode:characters_to_binary(A);
            {win32, _} ->
                case erlang:system_info(wordsize) of
                    4 -> <<"ia32">>;
                    8 -> <<"x64">>
                end
        end,
    case Raw of
        <<"arm">> -> arm;
        <<"aarch64">> -> arm64;
        <<"arm64">> -> arm64;
        <<"x86">> -> x86;
        <<"ia32">> -> x86;
        <<"x64">> -> x64;
        <<"x86_64">> -> x64;
        <<"amd64">> -> x64;
        <<"loong64">> -> loong64;
        <<"mips">> -> mips;
        <<"mipsel">> -> mips_little_endian;
        <<"ppc">> -> ppc;
        <<"ppc64">> -> ppc64;
        <<"riscv64">> -> risc_v64;
        <<"s390">> -> s390;
        <<"s390x">> -> s390x;
        Other -> {other_arch, Other}
    end.
