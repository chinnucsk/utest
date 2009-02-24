%% Part of 'utest' Unit Testing Framework
%% Copyright (c) 2009 Steve Davis <steve@simulacity.com>
%% See MIT License

-module(utest_html).
-vsn("0.3"). 
-author('steve@simulacity.com').

-include_lib("xmerl/include/xmerl.hrl").

-export([transform/1]).
-export(['#xml-inheritance#'/0]).
-export(['#root#'/4, '#element#'/5, '#text#'/1]).
-export([cleanup/1]).

-define(INDENT, "  ").

%%
transform(Xml) ->
	lists:flatten(template(Xml)).

%% NOTE: I am really not really proud of this code. It's really written this way
%% to avoid dependencies outside the report file. However, I hope that in the 
%% future xmerl_xs will allow us to read in and apply an external XSLT 
%% stylesheet programmatically.

template(E = #xmlElement{name='suite'})->
	Cases = xmerl_xs:select("results/result/test-cases/test-case/output/text()", E),
	Total = length(Cases),
	Pass = length([X || X <- Cases, xmerl_xs:value_of(X) == ["true"]]),
	Fail = length([X || X <- Cases, xmerl_xs:value_of(X) == ["false"]]),
	Skipped = Total - Pass - Fail,
	["<\?xml version=\"1.0\" encoding=\"utf-8\"\?>",
    doctype(),
	"<html>",
	"<head>",
	"<title>Unit Tests - ", appname(E), "</title>",
	css(),
	"</head>"
	"<body>"
	"<h1>",
	appname(E),
	"</h1>",
	io_lib:format("<table cellpadding=\"6\" cellspacing=\"0\" border=\"1\"><tr>"
		"<td class=\"bold total\">TESTS: ~p</td>"
		"<td class=\"bold pass\">PASS: ~p</td>"
		"<td class=\"bold fail\">FAIL: ~p</td>"
		"<td class=\"bold skip\">SKIP: ~p</td>"
		"</tr></table><br/>", [Total, Pass, Fail, Skipped]),
	table_start("Application"),
	attribute_row("Application", "application", E),
	attribute_row("Version", "version", E),
	attribute_row("Status", "status", E),
	attribute_row("Description", "description", E),
	attribute_row("Modules", "modules", E),
	attribute_row("Depends on", "depends", E),
	table_end(),
	table_start("Test Suite"),
	attribute_row("Timestamp", "timestamp", E),		
	attribute_row("Host", "host", E),		
	attribute_row("Local Path", "local-path", E),		
	attribute_row("Environment", "env", E),		
	attribute_row("Case Files", "tests", E),		

	table_end(),
	table_start("Results"),
    xmerl_xs:xslapply( fun template/1, E),
    table_end(),
	"<p id=\"tagline\">Generated by <a href=\"http://www.github.com/komone/utest\">UTEST</a> - Simple Unit Testing for Erlang</p>",
	"</body></html>"
];

template(_E = #xmlElement{ parents=[{'suite',_}|_], name='application'}) -> [];
template(_E = #xmlElement{ parents=[{'suite',_}|_], name='version'}) -> [];
template(_E = #xmlElement{ parents=[{'suite',_}|_], name='status'}) -> [];
template(_E = #xmlElement{ parents=[{'suite',_}|_], name='description'}) -> [];
template(_E = #xmlElement{ parents=[{'suite',_}|_], name='modules'}) -> [];
template(_E = #xmlElement{ parents=[{'suite',_}|_], name='depends'}) -> [];
template(_E = #xmlElement{ parents=[{'suite',_}|_], name='timestamp'}) -> [];
template(_E = #xmlElement{ parents=[{'suite',_}|_], name='host'}) ->[];
template(_E = #xmlElement{ parents=[{'suite',_}|_], name='invoke'}) -> [];
template(_E = #xmlElement{ parents=[{'suite',_}|_], name='local-path'}) -> [];
template(_E = #xmlElement{ parents=[{'suite',_}|_], name='env'}) -> [];
template(_E = #xmlElement{ parents=[{'suite',_}|_], name='tests'})  -> [];
template(_E = #xmlElement{ parents=[{'tests',_}|_], name='file'})  -> [];
template(_E = #xmlElement{ parents=[{'result',_}|_], name='module'}) -> [];
template(_E = #xmlElement{ parents=[{'result',_}|_], name='number'}) -> [];
template(_E = #xmlElement{ parents=[{'result',_}|_], name='test-file'}) -> [];
template(_E = #xmlElement{ parents=[{'test-case',_}|_], name='input'}) -> [];
template(_E = #xmlElement{ parents=[{'test-case',_}|_], name='output'}) -> [];

template(E = #xmlElement{ parents=[{'suite',_}|_], name='results'}) ->
    [ xmerl_xs:xslapply(fun template/1, E) ];

template(E = #xmlElement{ parents=[{'results',_}|_], name='result'}) ->
    [ "<tr class=\"module\"><td class=\"bold\" colspan=\"2\">", 
	xmerl_xs:value_of(xmerl_xs:select("module", E)), 
	" - ",
	xmerl_xs:value_of(xmerl_xs:select("number", E)), 
	" tests - (<em>",
	xmerl_xs:value_of(xmerl_xs:select("test-file", E)), 
	"</em>)</td></tr>",
    xmerl_xs:xslapply(fun template/1, E)
    ];

template(E = #xmlElement{ parents=[{'result',_}|_], name='test-cases'}) ->
	[xmerl_xs:xslapply(fun template/1, E)];
    
template(E = #xmlElement{ parents=[{'test-cases',_}|_], name='test-case'}) ->
	[ "<tr>",
	case xmerl_xs:value_of(xmerl_xs:select("output/text()", E)) of
		["true"] -> "<td class=\"pass\">PASS</td>";
		["false"] -> "<td class=\"fail\">FAIL</td>";
		_ -> "<td class=\"skip\">SKIP</td>"
	end,
	"<td>",
	case xmerl_xs:value_of(xmerl_xs:select("output/error/text()", E)) of 
		[] -> "";
		Text -> ["<span class=\"error\">REASON: ", Text, "</span> "]
	end,
	xmerl_xs:value_of(xmerl_xs:select("input", E)),
	"</td></tr>",
	xmerl_xs:xslapply(fun template/1, E)
];

template(E)->
 	%io:format("TEMPLATE: ~p~n", [E]),	
    xmerl_xs:built_in_rules(fun template/1, E).


doctype() ->
	"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\"\n"
    "  \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n".

appname(E) ->
	[xmerl_xs:value_of(xmerl_xs:select("/suite/application", E)),
	" v", xmerl_xs:value_of(xmerl_xs:select("/suite/version", E))].
	
table_start(Heading) ->
	["<table cellpadding=\"4\" cellspacing=\"0\" border=\"1\">",
	"<thead><tr><th colspan=\"2\">", Heading, "</th></tr></thead>",
	"<tbody>"].

table_end() ->
	["</tbody>", "</table>", "<br/>"].

attribute_row(Name, Value, E) ->
	Content = xmerl_xs:value_of(xmerl_xs:select(Value, E)),
	case length(Content) > 1 of
	true -> Content1 = [X ++ " " || X <- Content];
	false -> Content1 = Content
	end,
	["<tr><td>", Name, "</td><td>", Content1, "</td></tr>"].

css() ->
	"<style type=\"text/css\">
	body {
		margin: 40px;
	}
	
	table {
		width:100%;
		border-collapse: collapse;
		border-color: #bbb;
	}
	
	thead {
		background-color: #eee;
	}
	
	th {
		text-align: left;
		font-family: Verdana, sans-serif;
		font-size: 10pt;
	}
	
	td {
		text-align: left;
		font-family: \"Bitstream Vera Sans Mono\", Monaco, Courier,  monospace;
		font-size: 10pt;
		font-weight: normal;
	}

	.bold {
		font-weight: bold;
	}

	tr.module {
		background-color:#ddd;
		border: solid 1px #444;
	}

	td.total {
		background-color: #ddd;
		color: black;
	}
	
	td.pass {
		background-color: green;
		color: white;
	}
	
	td.fail {
		background-color: red;
		color: white;
	}
	
	td.skip {
		background-color: orange;
		color: white;
	}
	
	.error {
		background-color: orange;
		color: black;
		padding: 4px;
	}
	
	#tagline {
		font-size: 9pt;
		text-align: center;
	}
    </style>".

%%
%% Xmerl Callbacks
%%

'#xml-inheritance#'() -> [].

'#root#'(Data, [#xmlAttribute{name=prolog,value=V}], [], _E) ->
    [V ++ "\n",Data];
'#root#'(Data, _Attrs, [], _E) ->
	["<?xml version=\"1.0\" encoding=\"utf-8\"?>\n",
	"<!DOCTYPE html PUBLIC \"-//W3C//DTD XHTML 1.1//EN\"\n",
    "  \"http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd\">\n",
	Data].

'#element#'(Tag, [], Attrs, Parents, _E) ->
	case inline(Tag) of 
	true ->
		xmerl_lib:empty_tag(Tag, Attrs);
	false ->
		Level = length(Parents),
		lists:flatten([indent(Level), 
			xmerl_lib:empty_tag(Tag, Attrs), 
			indent(Level - 1)])
	end;
'#element#'(Tag, Data, Attrs, Parents, _E) ->
	case inline(Tag) of 
	true ->
		xmerl_lib:markup(Tag, Attrs, Data);		
	false ->
		Level = length(Parents),
		lists:flatten([indent(Level), 
			xmerl_lib:markup(Tag, Attrs, Data), 
			indent(Level - 1)])
	end.
	
'#text#'(Text) ->
	xmerl_lib:export_text(Text).

 
%%
indent(Level) when Level > 0 ->
	["\n", lists:duplicate(Level, ?INDENT)];
indent(_) ->
	["\n"].
	
%% ok, this is an ugly hack...
cleanup(Text) ->
	re:replace(Text, "[\t\r\n ]*\n", "\n", [global, {return, list}]).

inline(span) -> true;
inline(a) -> true;
inline(em) -> true;
inline(_) -> false.
