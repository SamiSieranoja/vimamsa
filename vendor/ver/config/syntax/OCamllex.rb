# Encoding: UTF-8

{fileTypes: ["mll"],
 foldingStartMarker: /{/,
 foldingStopMarker: /}/,
 keyEquivalent: "^~O",
 name: "OCamllex",
 patterns: 
  [{begin: /^\s*(?<_1>{)/,
    beginCaptures: 
     {1 => {name: "punctuation.section.embedded.ocaml.begin.ocamllex"}},
    end: "^\\s*(})",
    endCaptures: 
     {1 => {name: "punctuation.section.embedded.ocaml.end.ocamllex"}},
    name: "meta.embedded.ocaml",
    patterns: [{include: "source.ocaml"}]},
   {begin: /\b(?<_1>let)\s+(?<_2>[a-z][a-zA-Z0-9'_]*)\s+=/,
    beginCaptures: 
     {1 => {name: "keyword.other.pattern-definition.ocamllex"},
      2 => {name: "entity.name.type.pattern.stupid-goddamn-hack.ocamllex"}},
    end: "^(?:\\s*let)|(?:\\s*(rule|$))",
    name: "meta.pattern-definition.ocaml",
    patterns: [{include: "#match-patterns"}]},
   {begin: 
     /(?<_1>rule|and)\s+(?<_2>[a-z][a-zA-Z0-9_]*)\s+(?<_3>=)\s+(?<_4>parse)(?=\s*$)|(?<_5>(?<!\|)(?<_6>\|)(?!\|))/,
    beginCaptures: 
     {1 => {name: "keyword.other.ocamllex"},
      2 => {name: "entity.name.function.entrypoint.ocamllex"},
      3 => {name: "keyword.operator.ocamllex"},
      4 => {name: "keyword.other.ocamllex"},
      5 => {name: "punctuation.separator.match-pattern.ocamllex"}},
    end: "(?:^\\s*((and)\\b|(?=\\|)|$))",
    endCaptures: {3 => {name: "keyword.other.entry-definition.ocamllex"}},
    name: "meta.pattern-match.ocaml",
    patterns: [{include: "#match-patterns"}, {include: "#actions"}]},
   {include: "#strings"},
   {include: "#comments"},
   {match: /=/, name: "keyword.operator.symbol.ocamllex"},
   {begin: /\(/,
    end: "\\)",
    name: "meta.paren-group.ocamllex",
    patterns: [{include: "$self"}]},
   {match: /(?<_1>’|‘|“|”)/,
    name: "invalid.illegal.unrecognized-character.ocamllex"}],
 repository: 
  {actions: 
    {patterns: 
      [{begin: /[^\'](?<_1>{)/,
        beginCaptures: 
         {1 => {name: "punctuation.definition.action.begin.ocamllex"}},
        end: "(})",
        endCaptures: 
         {1 => {name: "punctuation.definition.action.end.ocamllex"}},
        name: "meta.action.ocamllex",
        patterns: [{include: "source.ocaml"}]}]},
   chars: 
    {patterns: 
      [{captures: 
         {1 => {name: "punctuation.definition.char.begin.ocamllex"},
          4 => {name: "punctuation.definition.char.end.ocamllex"}},
        match: 
         /(?<_1>')(?<_2>[^\\]|\\(?<_3>x[a-fA-F0-9][a-fA-F0-9]|[0-2]\d\d|[bnrt'"\\]))(?<_4>')/,
        name: "constant.character.ocamllex"}]},
   comments: 
    {patterns: 
      [{captures: 
         {1 => {name: "comment.block.empty.ocaml"},
          2 => {name: "comment.block.empty.ocaml"}},
        match: /\(\*(?:(?<_1>\*)| (?<_2> )\*)\)/,
        name: "comment.block.ocaml"},
       {begin: /\(\*/,
        end: "\\*\\)",
        name: "comment.block.ocaml",
        patterns: [{include: "#comments"}]},
       {begin: /(?=[^\\])(?<_1>")/,
        end: "\"",
        name: "comment.block.string.quoted.double.ocaml",
        patterns: 
         [{match: /\\(?<_1>x[a-fA-F0-9][a-fA-F0-9]|[0-2]\d\d|[bnrt'"\\])/,
           name: "comment.block.string.constant.character.escape.ocaml"}]}]},
   :"match-patterns" => 
    {patterns: 
      [{begin: /(?<_1>\()/,
        beginCaptures: 
         {1 => {name: "punctuation.definition.sub-pattern.begin.ocamllex"}},
        end: "(\\))",
        endCaptures: 
         {1 => {name: "punctuation.definition.sub-pattern.end.ocamllex"}},
        name: "meta.pattern.sub-pattern.ocamllex",
        patterns: [{include: "#match-patterns"}]},
       {match: /[a-z][a-zA-Z0-9'_]/,
        name: 
         "entity.name.type.pattern.reference.stupid-goddamn-hack.ocamllex"},
       {match: /\bas\b/, name: "keyword.other.pattern.ocamllex"},
       {match: /eof/, name: "constant.language.eof.ocamllex"},
       {match: /_/, name: "constant.language.universal-match.ocamllex"},
       {begin: /(?<_1>\[)(?<_2>\^?)/,
        beginCaptures: 
         {1 => {name: "punctuation.definition.character-class.begin.ocamllex"},
          2 => 
           {name: "punctuation.definition.character-class.negation.ocamllex"}},
        end: "(])(?!\\')",
        endCaptures: 
         {1 => {name: "punctuation.definition.character-class.end.ocamllex"}},
        name: "meta.pattern.character-class.ocamllex",
        patterns: 
         [{match: /-/,
           name: "punctuation.separator.character-class.range.ocamllex"},
          {include: "#chars"}]},
       {match: /\*|\+|\?/, name: "keyword.operator.pattern.modifier.ocamllex"},
       {match: /\|/, name: "keyword.operator.pattern.alternation.ocamllex"},
       {include: "#chars"},
       {include: "#strings"}]},
   strings: 
    {patterns: 
      [{begin: /(?=[^\\])(?<_1>")/,
        beginCaptures: 
         {1 => {name: "punctuation.definition.string.begin.ocaml"}},
        end: "(\")",
        endCaptures: {1 => {name: "punctuation.definition.string.end.ocaml"}},
        name: "string.quoted.double.ocamllex",
        patterns: 
         [{match: /\\$[ \t]*/,
           name: "punctuation.separator.string.ignore-eol.ocaml"},
          {match: /\\(?<_1>x[a-fA-F0-9][a-fA-F0-9]|[0-2]\d\d|[bnrt'"\\])/,
           name: "constant.character.string.escape.ocaml"},
          {match: /\\[\|\(\)1-9$^.*+?\[\]]/,
           name: "constant.character.regexp.escape.ocaml"},
          {match: 
            /\\(?!(?<_1>x[a-fA-F0-9][a-fA-F0-9]|[0-2]\d\d|[bnrt'"\\]|[\|\(\)1-9$^.*+?\[\]]|$[ \t]*))(?:.)/,
           name: "invalid.illegal.character.string.escape"}]}]}},
 scopeName: "source.ocamllex",
 uuid: "007E5263-8E0D-4BEF-B0E1-F01AE32590E8"}
