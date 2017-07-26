-module(rebar3_elixir_compile_util_test).

-include_lib("eunit/include/eunit.hrl").

escape_path_test_() ->
    [
     { "escape_path() with a normal path should pass it unchanged",
       [fun() ->
                NormalPath = "/a/b/c/d",
                EscapedPath = rebar3_elixir_compile_util:escape_path(NormalPath),
                io:format("~p~n", [EscapedPath]),
                ?assert(EscapedPath == NormalPath)
        end
       ]
     },
     { "escape_path() with a space should escape it",
       [fun() ->
                EscapedPath = rebar3_elixir_compile_util:escape_path("/a/ b/c/d"),
                io:format("~p~n", [EscapedPath]),
                ?assert(EscapedPath == "/a/\" b\"/c/d")
        end
       ]
     },
     { "escape_path() with a windows path should escape it",
       [fun() ->
                EscapedPath = rebar3_elixir_compile_util:escape_path("c:/Program Files (x86)/blah"),
                io:format("~p~n", [EscapedPath]),
                ?assert(EscapedPath == "c:/\"Program Files (x86)\"/blah")
        end
       ]
     }
    ].
