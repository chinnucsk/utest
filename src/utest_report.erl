%% Part of 'utest' Unit Testing Framework
%% Copyright (c) 2009 Steve Davis <steve@simulacity.com>
%% See MIT License

-module(utest_report).
-vsn("0.2").
-author('<steve@simulacity.com>').

-include("../include/utest.hrl").

-export([format/3, timestamp/0]).

%% Exports test suite output appropriately by 'Target'
format(Suite, Target, Path) ->
	Suite1 = Suite#suite{timestamp=timestamp(), host=node()},
	case Target of 
	nul		-> {ok, no_output};
	none 	-> {ok, no_output};
	tty 	-> to_console(Suite1);
	console -> to_console(Suite1);
	raw 	-> to_file(Suite1, Path);
	text 	-> to_file(Suite1, Path); %% may change
	xml	 	-> to_xml(Suite1, Path);
	html 	-> to_html(Suite1, Path)
	end.

%% creates a valid, printable RFC 3339 (ISO 8601) timestamp
timestamp() ->
	{{Y, M, D}, {H, M1, S}} = calendar:universal_time(),
	L = io_lib:format(
		"~4.10.0B-~2.10.0B-~2.10.0BT~2.10.0B:~2.10.0B:~2.10.0B.0Z", 
		[Y, M, D, H, M1, S]),
	lists:flatten(L).

%%
%% Internal API
%%

%%
to_console(Suite) ->
	io:format("~p~n", [Suite]),
	ok.

%%
to_file(Suite, Path) ->
	Text = io_lib:format("~p.~n", [Suite]),
	write_file(Suite, Text, Path, ".raw").

%% reorganizes the #suite tuple so that xmerl:export can process it
to_xml(Suite, Path) ->
	T = {suite, [
		{application, [as_xml_tree(Suite#suite.application)]},
		{version, [as_xml_tree(Suite#suite.version)]},
		{status, [as_xml_tree(Suite#suite.state)]},
		{description, [Suite#suite.desc]},
		{'local-path', [Suite#suite.path]},
		{timestamp, [as_xml_tree(Suite#suite.timestamp)]},
		{host, [as_xml_tree(Suite#suite.host)]},
		{invoke, [as_xml_tree(Suite#suite.invoke)]},
		{modules, as_xml_tree(module, Suite#suite.modules)},
		{depends, as_xml_tree(library, Suite#suite.depends)},
		{registered, as_xml_tree(atom, Suite#suite.registered)},
		{env, as_xml_tree(variable, Suite#suite.env)},
		{tests, as_xml_tree(file, Suite#suite.tests)},
		{results, results_to_xml_tree(Suite#suite.results, [])}
	]},
	
	Xml = xmerl:export_simple([T], utest_xml),
	Text = lists:flatten(Xml),
	write_file(Suite, Text, Path, ".xml").

%% reorganizes the #results tuple so that xmerl:export can process it
results_to_xml_tree([H|T], Acc) ->
	X = {result, [
		{module, [as_xml_tree(H#results.module)]},
		{number, [as_xml_tree(H#results.number)]},
		{'test-file', [as_xml_tree(H#results.file)]},
		{'test-cases', as_xml_tree('test-case', H#results.cases)}
	]},
	results_to_xml_tree(T, [X|Acc]);
%%
results_to_xml_tree([], Acc) ->
	lists:reverse(Acc).
	
%%
to_html(_Suite, _Path) ->
	{error, to_html, not_implemented}.

%%
write_file(Suite, Text, Path, FileExt) ->
	T = integer_to_list(calendar:time_to_seconds(now())),
	Name = filename:flatten([Suite#suite.application, "-result-", T, FileExt]),
	Filename = filename:join([Suite#suite.path, Path, Name]),
	ok = file:write_file(Filename, Text),
	{ok, Filename}.


%% as_xml_tree/1
%% reorganize #suite values so that xmerl:export can process them
as_xml_tree({M, A}) when is_atom(M), is_list(A) ->
	case A of 
	[] -> atom_to_list(M);
	_  -> {atom_to_list(M), as_xml_tree(arg, A, [])}
	end;
%
as_xml_tree({E, X}) when is_atom(E) ->
	as_xml_tree(E, [X]);
%
as_xml_tree(X) when is_atom(X) ->
	atom_to_list(X);
%
as_xml_tree(X) when is_integer(X) ->
	integer_to_list(X);
%
as_xml_tree(X) ->
	X.

%% as_xml_tree/2
%% deals with lists
as_xml_tree(E, [{_K, _V} = H|T]) ->
	as_xml_tree(E, [H|T], []);
%
as_xml_tree(E, L) when is_atom(E), is_list(L) ->
	as_xml_tree(E, L, []).

%% as_xml_tree/3
%% should only be used by as_xml_tree/1 or xml_tree/2
as_xml_tree(E, [{K, V}|T], Acc) ->
	case is_list(V) andalso not is_string(V) of
	true -> 
		Tag = {E, [{key, [as_xml_tree(K)]}, {values, as_xml_tree(value, V)}]};
	false -> 
		case E of 
		'test-case' when is_atom(V) -> 
			Tag = {E, [{input, [K]}, {output, [as_xml_tree(V)]}]};
		'test-case' -> 
			Tag = {E, [{input, [K]}, {output, as_xml_tree(V)}]};
		_ -> 
			Tag = {E, [{key, [as_xml_tree(K)]}, {value, [as_xml_tree(V)]}]}
		end
	end,
	as_xml_tree(E, T, [Tag|Acc]);
%
as_xml_tree(E, [H|T], Acc) ->
	Tag = {E, [as_xml_tree(H)]},
	as_xml_tree(E, T, [Tag|Acc]);
%
as_xml_tree(_, [], Acc) ->
	lists:reverse(Acc).

%% an incomplete but usable hack!
is_string([H|T]) when is_integer(H), H > 0 -> is_string(T);
is_string([_|_]) -> false;
is_string([]) -> true;
is_string(_) -> false.