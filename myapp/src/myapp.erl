-module(myapp).

-export([main/1]).

main(_Args) ->
	io:format("HelloWorld! 2 ~p~n", [jsone:encode(hej)]).
