# Encoding: UTF-8

{comment: "Roughed out by Paul Bissex <http://e-scribe.com/news/>",
 fileTypes: [],
 foldingStartMarker: /^to \w+/,
 foldingStopMarker: /^end$/,
 keyEquivalent: "^~L",
 name: "Logo",
 patterns: 
  [{match: /^to [\w.]+/, name: "entity.name.function.logo"},
   {match: 
     /continue|do\.until|do\.while|end|for(?<_1>each)?|if(?<_2>else|falsetrue|)|repeat|stop|until/,
    name: "keyword.control.logo"},
   {match: 
     /\b(?<_1>\.defmacro|\.eq|\.macro|\.maybeoutput|\.setbf|\.setfirst|\.setitem|\.setsegmentsize|allopen|allowgetset|and|apply|arc|arctan|arity|array|arrayp|arraytolist|ascii|ashift|back|background|backslashedp|beforep|bitand|bitnot|bitor|bitxor|buried|buriedp|bury|buryall|buryname|butfirst|butfirsts|butlast|bye|cascade|case|caseignoredp|catch|char|clean|clearscreen|cleartext|close|closeall|combine|cond|contents|copydef|cos|count|crossmap|cursor|define|definedp|dequeue|difference|dribble|edall|edit|editfile|edn|edns|edpl|edpls|edps|emptyp|eofp|epspict|equalp|erall|erase|erasefile|ern|erns|erpl|erpls|erps|erract|error|exp|fence|filep|fill|filter|find|first|firsts|forever|form|forward|fput|fullprintp|fullscreen|fulltext|gc|gensym|global|goto|gprop|greaterp|heading|help|hideturtle|home|ignore|int|invoke|iseq|item|keyp|label|last|left|lessp|list|listp|listtoarray|ln|load|loadnoisily|loadpict|local|localmake|log10|lowercase|lput|lshift|macroexpand|macrop|make|map|map.se|mdarray|mditem|mdsetitem|member|memberp|minus|modulo|name|namelist|namep|names|nodes|nodribble|norefresh|not|numberp|openappend|openread|openupdate|openwrite|or|output|palette|parse|pause|pen|pencolor|pendown|pendownp|penerase|penmode|penpaint|penreverse|pensize|penup|pick|plist|plistp|plists|pllist|po|poall|pon|pons|pop|popl|popls|pops|pos|pot|pots|power|pprop|prefix|primitivep|print|printdepthlimit|printwidthlimit|procedurep|procedures|product|push|queue|quoted|quotient|radarctan|radcos|radsin|random|rawascii|readchar|readchars|reader|readlist|readpos|readrawline|readword|redefp|reduce|refresh|remainder|remdup|remove|remprop|repcount|rerandom|reverse|right|round|rseq|run|runparse|runresult|save|savel|savepict|screenmode|scrunch|sentence|setbackground|setcursor|seteditor|setheading|sethelploc|setitem|setlibloc|setmargins|setpalette|setpen|setpencolor|setpensize|setpos|setprefix|setread|setreadpos|setscrunch|settemploc|settextcolor|setwrite|setwritepos|setx|setxy|sety|shell|show|shownp|showturtle|sin|splitscreen|sqrt|standout|startup|step|stepped|steppedp|substringp|sum|tag|test|text|textscreen|thing|throw|towards|trace|traced|tracedp|transfer|turtlemode|type|unbury|unburyall|unburyname|unburyonedit|unstep|untrace|uppercase|usealternatenam|wait|while|window|word|wordp|wrap|writepos|writer|xcor|ycor)\b/,
    name: "keyword.other.logo"},
   {captures: {1 => {name: "punctuation.definition.variable.logo"}},
    match: /(?<_1>\:)(?:\|[^|]*\||[-\w.]*)+/,
    name: "variable.parameter.logo"},
   {match: /"(?:\|[^|]*\||[-\w.]*)+/, name: "string.other.word.logo"},
   {captures: {1 => {name: "punctuation.definition.comment.logo"}},
    match: /(?<_1>;).*$\n?/,
    name: "comment.line.semicolon.logo"}],
 scopeName: "source.logo",
 uuid: "7613EC24-B0F9-4D01-8706-1D54098BFFD8"}
