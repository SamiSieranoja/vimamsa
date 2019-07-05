# Encoding: UTF-8

{foldingStartMarker: /(?<_1>\bEXTEND\B)/,
 foldingStopMarker: /(?<_1>\bEND\b)/,
 name: "camlp4",
 patterns: 
  [{begin: /(?<_1>\[<)(?=.*?>])/,
    beginCaptures: {1 => {name: "punctuation.definition.camlp4-stream.ocaml"}},
    end: "(?=>])",
    endCaptures: {1 => {name: "punctuation.definition.camlp4-stream.ocaml"}},
    name: "meta.camlp4-stream.ocaml",
    patterns: [{include: "#camlpppp-streams"}]},
   {match: /\[<|>\]/, name: "punctuation.definition.camlp4-stream.ocaml"},
   {match: /\bparser\b|<(?<_1><|:)|>>|\$(?<_2>:|\${0,1})/,
    name: "keyword.other.camlp4.ocaml"}],
 repository: 
  {:"camlpppp-streams" => 
    {patterns: 
      [{begin: /(?<_1>')/,
        beginCaptures: 
         {1 => {name: "punctuation.definition.camlp4.simple-element.ocaml"}},
        end: "(;)(?=\\s*')|(?=\\s*>])",
        endCaptures: {1 => {name: "punctuation.separator.camlp4.ocaml"}},
        name: "meta.camlp4-stream.element.ocaml",
        patterns: [{include: "source.ocaml"}]}]}},
 scopeName: "source.camlp4.ocaml",
 uuid: "37538B6B-CEFA-4DAE-B1E4-1218DB82B37F"}
