# Encoding: UTF-8

{fileTypes: ["lhs"],
 keyEquivalent: "^~H",
 name: "Literate Haskell",
 patterns: 
  [{begin: /^(?<_1>(?<_2>\\)begin)(?<_3>{)code(?<_4>})(?<_5>\s*\n)?/,
    captures: 
     {1 => {name: "support.function.be.latex"},
      2 => {name: "punctuation.definition.function.latex"},
      3 => {name: "punctuation.definition.arguments.begin.latex"},
      4 => {name: "punctuation.definition.arguments.end.latex"}},
    contentName: "source.haskell.embedded.latex",
    end: "^((\\\\)end)({)code(})",
    name: "meta.function.embedded.haskell.latex",
    patterns: [{include: "source.haskell"}]},
   {begin: /^(?<_1>> )/,
    beginCaptures: {1 => {name: "punctuation.definition.bird-track.haskell"}},
    comment: 
     "This breaks type signature detection for now, but it's better than having no highlighting whatsoever.",
    end: "$",
    name: "meta.embedded.haskell",
    patterns: [{include: "source.haskell"}]},
   {include: "text.tex.latex"}],
 scopeName: "text.tex.latex.haskell",
 uuid: "439807F5-7129-487D-B5DC-95D5272B43DD"}
