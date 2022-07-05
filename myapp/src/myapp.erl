-module(myapp).

-export([main/1]).

main(_Args) ->
	io:format("HelloWorld! ~p~n", [jsone:encode(hej)]).
