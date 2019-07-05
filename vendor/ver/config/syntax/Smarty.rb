# Encoding: UTF-8

{fileTypes: [],
 foldingStartMarker: 
  /(?<_1><(?i:(?<_2>head|table|tr|div|style|script|ul|ol|form|dl))\b.*?>|\{\{?(?<_3>if|foreach|capture|literal|foreach|php|section|strip)|\{\s*$)/,
 foldingStopMarker: 
  /(?<_1><\/(?i:(?<_2>head|table|tr|div|style|script|ul|ol|form|dl))>|\{\{?\/(?<_3>if|foreach|capture|literal|foreach|php|section|strip)|(?<_4>^|\s)\})/,
 name: "Smarty",
 patterns: 
  [{begin: /(?<=\{)\*/,
    captures: {0 => {name: "punctuation.definition.comment.smarty"}},
    end: "\\*(?=\\})",
    name: "comment.block.smarty"},
   {match: /\b(?<_1>if|else|elseif|foreach|foreachelse|section)\b/,
    name: "keyword.control.smarty"},
   {match: 
     /\b(?<_1>capture|config_load|counter|cycle|debug|eval|fetch|include_php|include|insert|literal|math|strip|rdelim|ldelim|assign|html_[a-z_]*)\b/,
    name: "support.function.built-in.smarty"},
   {match: /\b(?<_1>and|or)\b/, name: "keyword.operator.smarty"},
   {match: /\b(?<_1>eq|neq|gt|lt|gte|lte|is|not|even|odd|not|mod|div|by)\b/,
    name: "keyword.operator.other.smarty"},
   {match: 
     /\|(?<_1>capitalize|cat|count_characters|count_paragraphs|count_sentences|count_words|date_format|default|escape|indent|lower|nl2br|regex_replace|replace|spacify|string_format|strip_tags|strip|truncate|upper|wordwrap)/,
    name: "support.function.variable-modifier.smarty"},
   {match: /\b[a-zA-Z]+=/, name: "meta.attribute.smarty"},
   {begin: /'/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.smarty"}},
    end: "'",
    endCaptures: {0 => {name: "punctuation.definition.string.end.smarty"}},
    name: "string.quoted.single.smarty",
    patterns: [{match: /\\./, name: "constant.character.escape.smarty"}]},
   {begin: /"/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.smarty"}},
    end: "\"",
    endCaptures: {0 => {name: "punctuation.definition.string.end.smarty"}},
    name: "string.quoted.double.smarty",
    patterns: [{match: /\\./, name: "constant.character.escape.smarty"}]},
   {captures: {1 => {name: "punctuation.definition.variable.smarty"}},
    match: /\b(?<_1>\$)Smarty\./,
    name: "variable.other.global.smarty"},
   {captures: {1 => {name: "punctuation.definition.variable.smarty"}},
    match: /(?<_1>\$)\w\w*?\b/,
    name: "variable.other.smarty"},
   {match: /\b(?<_1>TRUE|FALSE|true|false)\b/,
    name: "constant.language.smarty"}],
 scopeName: "source.smarty",
 uuid: "4D6BBA54-E3FC-4296-9CA1-662B2AD537C6"}
