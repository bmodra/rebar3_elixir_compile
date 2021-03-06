 -module(rebar3_elixir_compile_resource).

-behaviour(rebar_resource).

-export([lock/2
        ,download/3
        ,needs_update/2
        ,make_vsn/1]).

lock(_Dir, Source) ->
    Source.

download(Dir, {elixir, Name, Vsn}, State) ->

    Pkg = {elixir, Name, Vsn},
    {ok, Config} = file:consult(filename:join([rebar_dir:root_dir(State), "rebar.config"])),
    {deps, Deps} = lists:keyfind(deps, 1 , Config),
    case isDepThere(Deps, Name, rebar_dir:deps_dir(State)) of 
        false -> 
            fetch_and_compile(State, Dir, Pkg);
        true ->
            rebar3_elixir_compile_util:maybe_copy_dir(rebar3_elixir_compile_util:fetch_mix_app_from_dep(State, Name), Dir, false),
            rebar3_elixir_compile_util:maybe_copy_dir(filename:join([rebar_dir:deps_dir(State), Name]), Dir, false)
    end,
    {ok, true}.

isDepThere(Deps, Name, Dir) ->
    InConfig = lists:filter(fun 
                            ({D, _}) -> rebar3_elixir_compile_util:to_binary(D) == rebar3_elixir_compile_util:to_binary(Name); 
                            (_) -> false
                            end, Deps),
    InDir = filelib:is_dir(filename:join([Dir, Name, "ebin"])),
    case {InConfig, InDir} of
        {[], true} ->
            true;
         {_, true} ->
             false;
        {[], false} ->
             true;          
         {_, false} ->
             false
    end.

needs_update(Dir, {elixir, _Name, Vsn}) ->
    rebar_api:console("Checking for update, ~p", _Name),
    [AppInfo] = rebar_app_discover:find_apps([Dir], all),
    case rebar_app_info:original_vsn(AppInfo) =:= ec_cnv:to_list(Vsn) of
        true ->
            false;
        false ->
            true
    end.

make_vsn(_) ->
    {error, "Replacing version of type elixir not supported."}.

fetch_and_compile(State, Dir, Pkg = {elixir, Name, _Vsn}) ->
    fetch(Pkg, State),
    State1 = rebar3_elixir_compile_util:add_elixir(State),
    State2 = rebar_state:set(State1, libs_target_dir, default),
    BaseDir = filename:join(rebar_dir:root_dir(State2), "_elixir_build/"),
    BaseDirState = rebar_state:set(State2, elixir_base_dir, BaseDir),
    Env = rebar_state:get(BaseDirState, mix_env),
    AppDir = filename:join(BaseDir, Name),
    rebar3_elixir_compile_util:compile_libs(BaseDirState),
    LibsDir = rebar3_elixir_compile_util:libs_dir(AppDir, Env),
    rebar3_elixir_compile_util:transfer_libs(rebar_state:set(BaseDirState, libs_target_dir, Dir), [Name], LibsDir).

fetch({elixir, Name_, {_,_,_} = Source}, State) ->
    Dir = filename:join([filename:absname("_elixir_build"), Name_]),
    Name = rebar3_elixir_compile_util:to_binary(Name_), 
    case filelib:is_dir(Dir) of
        false ->
            rebar_fetch:download_source(Dir, Source, State);
        true ->
            rebar_api:console("Dependency ~s already exists~n", [Name])
    end;
fetch({elixir, Name_, Vsn_}, _State) ->
    Dir = filename:join([filename:absname("_elixir_build"), Name_]),
    Name = rebar3_elixir_compile_util:to_binary(Name_), 
    Vsn  = rebar3_elixir_compile_util:to_binary(Vsn_),
    case filelib:is_dir(Dir) of
        false ->
            CDN = "https://repo.hex.pm/tarballs",
            Package = binary_to_list(<<Name/binary, "-", Vsn/binary, ".tar">>),
            Url = string:join([CDN, Package], "/"),
            case request(Url) of
                {ok, Binary} ->
                    {ok, Contents} = extract(Binary),
                    ok = erl_tar:extract({binary, Contents}, [{cwd, Dir}, compressed]);
                _ ->
                    rebar_api:console("Error: Unable to fetch package ~p ~p~n", [Name, Vsn])
            end;
        true ->
            rebar_api:console("Dependency ~s already exists~n", [Name])
    end.

extract(Binary) ->
    {ok, Files} = erl_tar:extract({binary, Binary}, [memory]),
    {"contents.tar.gz", Contents} = lists:keyfind("contents.tar.gz", 1, Files),
    {ok, Contents}.

request(Url) ->
    case httpc:request(get, {Url, []},
                       [{relaxed, true}],
                       [{body_format, binary}],
                       rebar) of
        {ok, {{_Version, 200, _Reason}, _Headers, Body}} ->
            {ok, Body};
        Error ->
            Error
    end.
