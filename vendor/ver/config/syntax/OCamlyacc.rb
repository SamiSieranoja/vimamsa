# Encoding: UTF-8

{fileTypes: ["mly"],
 foldingStartMarker: /%{|%%/,
 foldingStopMarker: /%}|%%/,
 keyEquivalent: "^~O",
 name: "OCamlyacc",
 patterns: 
  [{begin: /(?<_1>%{)\s*$/,
    beginCaptures: {1 => {name: "punctuation.section.header.begin.ocamlyacc"}},
    end: "^\\s*(%})",
    endCaptures: {1 => {name: "punctuation.section.header.end.ocamlyacc"}},
    name: "meta.header.ocamlyacc",
    patterns: [{include: "source.ocaml"}]},
   {begin: /(?<=%})\s*$/,
    end: "(?:^)(?=%%)",
    name: "meta.declarations.ocamlyacc",
    patterns: [{include: "#comments"}, {include: "#declaration-matches"}]},
   {begin: /(?<_1>%%)\s*$/,
    beginCaptures: {1 => {name: "punctuation.section.rules.begin.ocamlyacc"}},
    end: "^\\s*(%%)",
    endCaptures: {1 => {name: "punctuation.section.rules.end.ocamlyacc"}},
    name: "meta.rules.ocamlyacc",
    patterns: [{include: "#comments"}, {include: "#rules"}]},
   {include: "source.ocaml"},
   {include: "#comments"},
   {match: /(?<_1>’|‘|“|”)/,
    name: "invalid.illegal.unrecognized-character.ocaml"}],
 repository: 
  {comments: 
    {patterns: 
      [{begin: /\/\*/,
        end: "\\*/",
        name: "comment.block.ocamlyacc",
        patterns: [{include: "#comments"}]},
       {begin: /(?=[^\\])(?<_1>")/,
        end: "\"",
        name: "comment.block.string.quoted.double.ocamlyacc",
        patterns: 
         [{match: /\\(?<_1>x[a-fA-F0-9][a-fA-F0-9]|[0-2]\d\d|[bnrt'"\\])/,
           name: 
            "comment.block.string.constant.character.escape.ocamlyacc"}]}]},
   :"declaration-matches" => 
    {patterns: 
      [{begin: /(?<_1>%)(?<_2>token)/,
        beginCaptures: 
         {1 => {name: "keyword.other.decorator.token.ocamlyacc"},
          2 => {name: "keyword.other.token.ocamlyacc"}},
        end: "^\\s*($|(^\\s*(?=%)))",
        name: "meta.token.declaration.ocamlyacc",
        patterns: 
         [{include: "#symbol-types"},
          {match: /[A-Z][A-Za-z0-9_]*/,
           name: "entity.name.type.token.ocamlyacc"},
          {include: "#comments"}]},
       {begin: /(?<_1>%)(?<_2>left|right|nonassoc)/,
        beginCaptures: 
         {1 => {name: "keyword.other.decorator.token.associativity.ocamlyacc"},
          2 => {name: "keyword.other.token.associativity.ocamlyacc"}},
        end: "(^\\s*$)|(^\\s*(?=%))",
        name: "meta.token.associativity.ocamlyacc",
        patterns: 
         [{match: /[A-Z][A-Za-z0-9_]*/,
           name: "entity.name.type.token.ocamlyacc"},
          {match: /[a-z][A-Za-z0-9_]*/,
           name: "entity.name.function.non-terminal.reference.ocamlyacc"},
          {include: "#comments"}]},
       {begin: /(?<_1>%)(?<_2>start)/,
        beginCaptures: 
         {1 => {name: "keyword.other.decorator.start-symbol.ocamlyacc"},
          2 => {name: "keyword.other.start-symbol.ocamlyacc"}},
        end: "(^\\s*$)|(^\\s*(?=%))",
        name: "meta.start-symbol.ocamlyacc",
        patterns: 
         [{match: /[a-z][A-Za-z0-9_]*/,
           name: "entity.name.function.non-terminal.reference.ocamlyacc"},
          {include: "#comments"}]},
       {begin: /(?<_1>%)(?<_2>type)/,
        beginCaptures: 
         {1 => {name: "keyword.other.decorator.symbol-type.ocamlyacc"},
          2 => {name: "keyword.other.symbol-type.ocamlyacc"}},
        end: "$\\s*(?!%)",
        name: "meta.symbol-type.ocamlyacc",
        patterns: 
         [{include: "#symbol-types"},
          {match: /[A-Z][A-Za-z0-9_]*/,
           name: "entity.name.type.token.reference.ocamlyacc"},
          {match: /[a-z][A-Za-z0-9_]*/,
           name: "entity.name.function.non-terminal.reference.ocamlyacc"},
          {include: "#comments"}]}]},
   precs: 
    {patterns: 
      [{captures: 
         {1 => {name: "keyword.other.decorator.precedence.ocamlyacc"},
          2 => {name: "keyword.other.precedence.ocamlyacc"},
          4 => {name: "entity.name.function.non-terminal.reference.ocamlyacc"},
          5 => {name: "entity.name.type.token.reference.ocamlyacc"}},
        match: 
         /(?<_1>%)(?<_2>prec)\s+(?<_3>(?<_4>[a-z][a-zA-Z0-9_]*)|(?<_5>(?<_6>[A-Z][a-zA-Z0-9_]*)))/,
        name: "meta.precidence.declaration"}]},
   references: 
    {patterns: 
      [{match: /[a-z][a-zA-Z0-9_]*/,
        name: "entity.name.function.non-terminal.reference.ocamlyacc"},
       {match: /[A-Z][a-zA-Z0-9_]*/,
        name: "entity.name.type.token.reference.ocamlyacc"}]},
   :"rule-patterns" => 
    {patterns: 
      [{begin: /(?<_1>(?<!\||:)(?<_2>\||:)(?!\||:))/,
        beginCaptures: {0 => {name: "punctuation.separator.rule.ocamlyacc"}},
        end: "\\s*(?=\\||;)",
        name: "meta.rule-match.ocaml",
        patterns: 
         [{include: "#precs"},
          {include: "#semantic-actions"},
          {include: "#references"},
          {include: "#comments"}]}]},
   rules: 
    {patterns: 
      [{begin: /[a-z][a-zA-Z_]*/,
        beginCaptures: 
         {0 => {name: "entity.name.function.non-terminal.ocamlyacc"}},
        end: ";",
        endCaptures: {0 => {name: "punctuation.separator.rule.ocamlyacc"}},
        name: "meta.non-terminal.ocamlyacc",
        patterns: [{include: "#rule-patterns"}]}]},
   :"semantic-actions" => 
    {patterns: 
      [{begin: /[^\'](?<_1>{)/,
        beginCaptures: 
         {1 => {name: "punctuation.definition.action.semantic.ocamlyacc"}},
        end: "(})",
        endCaptures: 
         {1 => {name: "punctuation.definition.action.semantic.ocamlyacc"}},
        name: "meta.action.semantic.ocamlyacc",
        patterns: [{include: "source.ocaml"}]}]},
   :"symbol-types" => 
    {patterns: 
      [{begin: /</,
        beginCaptures: 
         {0 => 
           {name: "punctuation.definition.type-declaration.begin.ocamlyacc"}},
        end: ">",
        endCaptures: 
         {0 => 
           {name: "punctuation.definition.type-declaration.end.ocamlyacc"}},
        name: "meta.token.type-declaration.ocamlyacc",
        patterns: [{include: "source.ocaml"}]}]}},
 scopeName: "source.ocamlyacc",
 uuid: "1B59327E-9B82-4B78-9411-BC02067DBDF9"}
