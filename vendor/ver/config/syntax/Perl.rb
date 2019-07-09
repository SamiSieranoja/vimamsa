# Encoding: UTF-8

{comment: "\n\tTODO:\tInclude RegExp syntax\n",
 fileTypes: ["pl", "pm", "pod", "t", "PL"],
 firstLineMatch: "^#!.*\\bperl\\b",
 foldingStartMarker: /(?<_1>\/\*|(?<_2>\{|\[|\()\s*$)/,
 foldingStopMarker: /(?<_1>\*\/|^\s*(?<_2>\}|\]|\)))/,
 keyEquivalent: "^~P",
 name: "Perl",
 patterns: 
  [{include: "#line_comment"},
   {begin: /^=/,
    captures: {0 => {name: "punctuation.definition.comment.perl"}},
    end: "^=cut",
    name: "comment.block.documentation.perl"},
   {include: "#variable"},
   {applyEndPatternLast: 1,
    begin: /\b(?=qr\s*[^\s\w])/,
    comment: "string.regexp.compile.perl",
    end: "((([egimosx]*)))(?=(\\s+\\S|\\s*[;\\,\\#\\{\\}\\)]|$))",
    endCaptures: 
     {1 => {name: "string.regexp.compile.perl"},
      2 => {name: "punctuation.definition.string.perl"},
      3 => {name: "keyword.control.regexp-option.perl"}},
    patterns: 
     [{begin: /(?<_1>qr)\s*\{/,
       captures: 
        {0 => {name: "punctuation.definition.string.perl"},
         1 => {name: "support.function.perl"}},
       end: "\\}",
       name: "string.regexp.compile.nested_braces.perl",
       patterns: 
        [{include: "#escaped_char"},
         {include: "#variable"},
         {include: "#nested_braces_interpolated"}]},
      {begin: /(?<_1>qr)\s*\[/,
       captures: 
        {0 => {name: "punctuation.definition.string.perl"},
         1 => {name: "support.function.perl"}},
       end: "\\]",
       name: "string.regexp.compile.nested_brackets.perl",
       patterns: 
        [{include: "#escaped_char"},
         {include: "#variable"},
         {include: "#nested_brackets_interpolated"}]},
      {begin: /(?<_1>qr)\s*</,
       captures: 
        {0 => {name: "punctuation.definition.string.perl"},
         1 => {name: "support.function.perl"}},
       end: ">",
       name: "string.regexp.compile.nested_ltgt.perl",
       patterns: 
        [{include: "#escaped_char"},
         {include: "#variable"},
         {include: "#nested_ltgt_interpolated"}]},
      {begin: /(?<_1>qr)\s*\(/,
       captures: 
        {0 => {name: "punctuation.definition.string.perl"},
         1 => {name: "support.function.perl"}},
       end: "\\)",
       name: "string.regexp.compile.nested_parens.perl",
       patterns: 
        [{include: "#escaped_char"},
         {include: "#variable"},
         {include: "#nested_parens_interpolated"}]},
      {begin: /(?<_1>qr)\s*\'/,
       captures: 
        {0 => {name: "punctuation.definition.string.perl"},
         1 => {name: "support.function.perl"}},
       end: "\\'",
       name: "string.regexp.compile.single-quote.perl",
       patterns: [{include: "#escaped_char"}]},
      {begin: /(?<_1>qr)\s*(?<_2>[^\s\w\'\{\[\(\<])/,
       captures: 
        {0 => {name: "punctuation.definition.string.perl"},
         1 => {name: "support.function.perl"}},
       end: "\\2",
       name: "string.regexp.compile.simple-delimiter.perl",
       patterns: 
        [{comment: 
           "This is to prevent thinks like qr/foo$/ to treat $/ as a variable",
          match: /\$(?=[^\s\w\'\{\[\(\<])/,
          name: "keyword.control.anchor.perl"},
         {include: "#escaped_char"},
         {include: "#variable"},
         {include: "#nested_parens_interpolated"}]}]},
   {applyEndPatternLast: 1,
    begin: /\b(?=(?<!\&)(?<_1>s)(?<_2>\s+\S|\s*[;\,\#\{\}\(\)\[<]|$))/,
    comment: "string.regexp.replace.perl",
    end: "((([egimosx]*)))(?=(\\s+\\S|\\s*[;\\,\\#\\{\\}\\)\\]>]|$))",
    endCaptures: 
     {1 => {name: "string.regexp.replace.perl"},
      2 => {name: "punctuation.definition.string.perl"},
      3 => {name: "keyword.control.regexp-option.perl"}},
    patterns: 
     [{begin: /(?<_1>s)\s*\{/,
       captures: 
        {0 => {name: "punctuation.definition.string.perl"},
         1 => {name: "support.function.perl"}},
       end: "\\}",
       name: "string.regexp.nested_braces.perl",
       patterns: [{include: "#escaped_char"}, {include: "#nested_braces"}]},
      {begin: /(?<_1>s)\s*\[/,
       captures: 
        {0 => {name: "punctuation.definition.string.perl"},
         1 => {name: "support.function.perl"}},
       end: "\\]",
       name: "string.regexp.nested_brackets.perl",
       patterns: [{include: "#escaped_char"}, {include: "#nested_brackets"}]},
      {begin: /(?<_1>s)\s*</,
       captures: 
        {0 => {name: "punctuation.definition.string.perl"},
         1 => {name: "support.function.perl"}},
       end: ">",
       name: "string.regexp.nested_ltgt.perl",
       patterns: [{include: "#escaped_char"}, {include: "#nested_ltgt"}]},
      {begin: /(?<_1>s)\s*\(/,
       captures: 
        {0 => {name: "punctuation.definition.string.perl"},
         1 => {name: "support.function.perl"}},
       end: "\\)",
       name: "string.regexp.nested_parens.perl",
       patterns: [{include: "#escaped_char"}, {include: "#nested_parens"}]},
      {begin: /\{/,
       captures: {0 => {name: "punctuation.definition.string.perl"}},
       end: "\\}",
       name: "string.regexp.format.nested_braces.perl",
       patterns: 
        [{include: "#escaped_char"},
         {include: "#variable"},
         {include: "#nested_braces_interpolated"}]},
      {begin: /\[/,
       captures: {0 => {name: "punctuation.definition.string.perl"}},
       end: "\\]",
       name: "string.regexp.format.nested_brackets.perl",
       patterns: 
        [{include: "#escaped_char"},
         {include: "#variable"},
         {include: "#nested_brackets_interpolated"}]},
      {begin: /</,
       captures: {0 => {name: "punctuation.definition.string.perl"}},
       end: ">",
       name: "string.regexp.format.nested_ltgt.perl",
       patterns: 
        [{include: "#escaped_char"},
         {include: "#variable"},
         {include: "#nested_ltgt_interpolated"}]},
      {begin: /\(/,
       captures: {0 => {name: "punctuation.definition.string.perl"}},
       end: "\\)",
       name: "string.regexp.format.nested_parens.perl",
       patterns: 
        [{include: "#escaped_char"},
         {include: "#variable"},
         {include: "#nested_parens_interpolated"}]},
      {begin: /'/,
       captures: {0 => {name: "punctuation.definition.string.perl"}},
       end: "'",
       name: "string.regexp.format.single_quote.perl",
       patterns: [{match: /\\['\\]/, name: "constant.character.escape.perl"}]},
      {begin: /(?<_1>[^\s\w\[(?<_2>{<;])/,
       captures: {0 => {name: "punctuation.definition.string.perl"}},
       end: "\\1",
       name: "string.regexp.format.simple_delimiter.perl",
       patterns: [{include: "#escaped_char"}, {include: "#variable"}]},
      {match: /\s+/}]},
   {begin: 
     /\b(?=s(?<_1>[^\s\w\[(?<_2>{<]).*\k<_1>(?<_3>[egimos]*)(?<_4>[\}\)\;\,]|\s+))/,
    comment: "string.regexp.replaceXXX",
    end: "((([egimos]*)))(?=([\\}\\)\\;\\,]|\\s+|$))",
    endCaptures: 
     {1 => {name: "string.regexp.replace.perl"},
      2 => {name: "punctuation.definition.string.perl"},
      3 => {name: "keyword.control.regexp-option.perl"}},
    patterns: 
     [{begin: /(?<_1>s\s*)(?<_2>[^\s\w\[(?<_3>{<])/,
       captures: 
        {0 => {name: "punctuation.definition.string.perl"},
         1 => {name: "support.function.perl"}},
       end: "(?=\\2)",
       name: "string.regexp.replaceXXX.simple_delimiter.perl",
       patterns: [{include: "#escaped_char"}]},
      {begin: /'/,
       captures: {0 => {name: "punctuation.definition.string.perl"}},
       end: "'",
       name: "string.regexp.replaceXXX.format.single_quote.perl",
       patterns: 
        [{match: /\\['\\]/, name: "constant.character.escape.perl.perl"}]},
      {begin: /(?<_1>[^\s\w\[(?<_2>{<])/,
       captures: {0 => {name: "punctuation.definition.string.perl"}},
       end: "\\1",
       name: "string.regexp.replaceXXX.format.simple_delimiter.perl",
       patterns: [{include: "#escaped_char"}, {include: "#variable"}]}]},
   {begin: /\b(?=(?<!\\)s\s*(?<_1>[^\s\w\[(?<_2>{<]))/,
    comment: "string.regexp.replace.extended",
    end: "\\2((([egimos]*x[egimos]*)))\\b",
    endCaptures: 
     {1 => {name: "string.regexp.replace.perl"},
      2 => {name: "punctuation.definition.string.perl"},
      3 => {name: "keyword.control.regexp-option.perl"}},
    patterns: 
     [{begin: /(?<_1>s)\s*(?<_2>.)/,
       captures: 
        {0 => {name: "punctuation.definition.string.perl"},
         1 => {name: "support.function.perl"}},
       end: "(?=\\2)",
       name: "string.regexp.replace.extended.simple_delimiter.perl",
       patterns: [{include: "#escaped_char"}]},
      {begin: /'/,
       captures: {0 => {name: "punctuation.definition.string.perl"}},
       end: "'(?=[egimos]*x[egimos]*)\\b",
       name: "string.regexp.replace.extended.simple_delimiter.perl",
       patterns: [{include: "#escaped_char"}]},
      {begin: /(?<_1>.)/,
       captures: {0 => {name: "punctuation.definition.string.perl"}},
       end: "\\1(?=[egimos]*x[egimos]*)\\b",
       name: "string.regexp.replace.extended.simple_delimiter.perl",
       patterns: [{include: "#escaped_char"}, {include: "#variable"}]}]},
   {match: /\b\w+\s*(?==>)/, name: "constant.other.key.perl"},
   {match: /(?<={)\s*\w+\s*(?=})/, name: "constant.other.bareword.perl"},
   {captures: 
     {1 => {name: "punctuation.definition.string.perl"},
      5 => {name: "punctuation.definition.string.perl"}},
    match: 
     /(?<!\\)(?<_1>(?<_2>~\s*)?\/)(?<_3>\S.*?)(?<!\\)(?<_4>\\{2})*(?<_5>\/)/,
    name: "string.regexp.find.perl"},
   {begin: /(?<!\\)(?<_1>\~\s*\/)/,
    captures: {0 => {name: "punctuation.definition.string.perl"}},
    end: "\\/([cgimos]*x[cgimos]*)\\b",
    endCaptures: {1 => {name: "keyword.control.regexp-option.perl"}},
    name: "string.regexp.find.extended.perl",
    patterns: [{include: "#escaped_char"}, {include: "#variable"}]},
   {captures: 
     {1 => {name: "keyword.control.perl"},
      2 => {name: "entity.name.type.class.perl"},
      3 => {name: "comment.line.number-sign.perl"},
      4 => {name: "punctuation.definition.comment.perl"}},
    match: /^\s*(?<_1>package)\s+(?<_2>\S+)\s*(?<_3>(?<_4>#).*)?$\n?/,
    name: "meta.class.perl"},
   {captures: 
     {1 => {name: "storage.type.sub.perl"},
      2 => {name: "entity.name.function.perl"},
      3 => {name: "storage.type.method.perl"}},
    match: /^\s*(?<_1>sub)\s+(?<_2>[-a-zA-Z0-9_]+)\s*(?<_3>\([\$\@\*;]*\))?/,
    name: "meta.function.perl"},
   {captures: 
     {1 => {name: "entity.name.function.perl"},
      2 => {name: "punctuation.definition.parameters.perl"},
      3 => {name: "variable.parameter.function.perl"}},
    match: /^\s*(?<_1>BEGIN|END|DESTROY)\b/,
    name: "meta.function.perl"},
   {begin: /^(?=(?<_1>\t| {4}))/,
    end: "(?=[^\\t\\s])",
    name: "meta.leading-tabs",
    patterns: 
     [{captures: {1 => {name: "meta.odd-tab"}, 2 => {name: "meta.even-tab"}},
       match: /(?<_1>\t| {4})(?<_2>\t| {4})?/}]},
   {captures: 
     {1 => {name: "support.function.perl"},
      2 => {name: "punctuation.definition.string.perl"},
      5 => {name: "punctuation.definition.string.perl"}},
    match: 
     /\b(?<_1>m)\s*(?<!\\)(?<_2>[^\[\{\(A-Za-z0-9\s])(?<_3>.*?)(?<!\\)(?<_4>\\{2})*(?<_5>\k<_2>)/,
    name: "string.regexp.find-m.perl"},
   {begin: /\b(?<_1>m)\s*(?<!\\)\(/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\)",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.regexp.find-m-paren.perl",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#nested_parens_interpolated"},
      {include: "#variable"}]},
   {begin: /\b(?<_1>m)\s*(?<!\\)\{/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\}",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.regexp.find-m-brace.perl",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#nested_braces_interpolated"},
      {include: "#variable"}]},
   {begin: /\b(?<_1>m)\s*(?<!\\)\[/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\]",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.regexp.find-m-bracket.perl",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#nested_brackets_interpolated"},
      {include: "#variable"}]},
   {begin: /\b(?<_1>m)\s*(?<!\\)\</,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\>",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.regexp.find-m-ltgt.perl",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#nested_ltgt_interpolated"},
      {include: "#variable"}]},
   {captures: 
     {1 => {name: "support.function.perl"},
      2 => {name: "punctuation.definition.string.perl"},
      5 => {name: "punctuation.definition.string.perl"},
      8 => {name: "punctuation.definition.string.perl"}},
    match: 
     /\b(?<_1>s|tr|y)\s*(?<_2>[^A-Za-z0-9\s])(?<_3>.*?)(?<!\\)(?<_4>\\{2})*(?<_5>\k<_2>)(?<_6>.*?)(?<!\\)(?<_7>\\{2})*(?<_8>\k<_2>)/,
    name: "string.regexp.replace.perl"},
   {match: /\b(?<_1>__FILE__|__LINE__|__PACKAGE__)\b/,
    name: "constant.language.perl"},
   {match: 
     /(?<!->)\b(?<_1>continue|die|do|else|elsif|exit|for|foreach|goto|if|last|next|redo|return|select|unless|until|wait|while|switch|case|package|require|use|eval)\b/,
    name: "keyword.control.perl"},
   {match: /\b(?<_1>my|our|local)\b/, name: "storage.modifier.perl"},
   {match: /(?<!\w)\-[rwx0RWXOezsfdlpSbctugkTBMAC]\b/,
    name: "keyword.operator.filetest.perl"},
   {match: /\b(?<_1>and|or|xor|as)\b/, name: "keyword.operator.logical.perl"},
   {match: /(?<_1><=>| =>|->)/, name: "keyword.operator.comparison.perl"},
   {begin: /(?<_1>(?<_2><<) *"HTML").*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.doublequote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "text.html.embedded.perl",
    end: "(^HTML$)",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#variable"},
      {include: "text.html.basic"}]},
   {begin: /(?<_1>(?<_2><<) *"XML").*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.doublequote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "text.xml.embedded.perl",
    end: "(^XML$)",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#variable"},
      {include: "text.xml"}]},
   {begin: /(?<_1>(?<_2><<) *"CSS").*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.doublequote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "text.css.embedded.perl",
    end: "(^CSS$)",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#variable"},
      {include: "source.css"}]},
   {begin: /(?<_1>(?<_2><<) *"JAVASCRIPT").*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.doublequote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "text.js.embedded.perl",
    end: "(^JAVASCRIPT$)",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#variable"},
      {include: "source.js"}]},
   {begin: /(?<_1>(?<_2><<) *"SQL").*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.doublequote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "source.sql.embedded.perl",
    end: "(^SQL$)",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#variable"},
      {include: "source.sql"}]},
   {begin: /(?<_1>(?<_2><<) *"POSTSCRIPT").*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.doublequote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "text.postscript.embedded.perl",
    end: "(^POSTSCRIPT$)",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#variable"},
      {include: "source.postscript"}]},
   {begin: /(?<_1>(?<_2><<) *"(?<_3>[^"]*)").*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.doublequote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "string.unquoted.heredoc.doublequote.perl",
    end: "(^\\3$)",
    patterns: [{include: "#escaped_char"}, {include: "#variable"}]},
   {begin: /(?<_1>(?<_2><<) *'HTML').*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.quote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "text.html.embedded.perl",
    end: "(^HTML$)",
    patterns: [{include: "text.html.basic"}]},
   {begin: /(?<_1>(?<_2><<) *'XML').*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.quote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "text.xml.embedded.perl",
    end: "(^XML$)",
    patterns: [{include: "text.xml"}]},
   {begin: /(?<_1>(?<_2><<) *'CSS').*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.quote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "text.css.embedded.perl",
    end: "(^CSS$)",
    patterns: [{include: "source.css"}]},
   {begin: /(?<_1>(?<_2><<) *'JAVASCRIPT').*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.quote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "text.js.embedded.perl",
    end: "(^JAVASCRIPT$)",
    patterns: [{include: "source.js"}]},
   {begin: /(?<_1>(?<_2><<) *'SQL').*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.quote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "source.sql.embedded.perl",
    end: "(^SQL$)",
    patterns: [{include: "source.sql"}]},
   {begin: /(?<_1>(?<_2><<) *'POSTSCRIPT').*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.quote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "source.postscript.embedded.perl",
    end: "(^POSTSCRIPT)",
    patterns: [{include: "source.postscript"}]},
   {begin: /(?<_1>(?<_2><<) *'(?<_3>[^']*)').*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.quote.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "string.unquoted.heredoc.quote.perl",
    end: "(^\\3$)"},
   {begin: /(?<_1>(?<_2><<) *`(?<_3>[^`]*)`).*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.backtick.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "string.unquoted.heredoc.backtick.perl",
    end: "(^\\3$)",
    patterns: [{include: "#escaped_char"}, {include: "#variable"}]},
   {begin: /(?<_1>(?<_2><<) *HTML\b).*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "text.html.embedded.perl",
    end: "(^HTML$)",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#variable"},
      {include: "text.html.basic"}]},
   {begin: /(?<_1>(?<_2><<) *XML\b).*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "text.xml.embedded.perl",
    end: "(^XML$)",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#variable"},
      {include: "text.xml"}]},
   {begin: /(?<_1>(?<_2><<) *SQL\b).*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "source.sql.embedded.perl",
    end: "(^SQL$)",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#variable"},
      {include: "source.sql"}]},
   {begin: /(?<_1>(?<_2><<) *POSTSCRIPT\b).*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "source.postscript.embedded.perl",
    end: "(^POSTSCRIPT)",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#variable"},
      {include: "source.postscript"}]},
   {begin: /(?<_1>(?<_2><<) *(?<_3>(?![=\d\$ ])[^;,'"`\s)]*)).*\n?/,
    captures: 
     {0 => {name: "punctuation.definition.string.perl"},
      1 => {name: "string.unquoted.heredoc.perl"},
      2 => {name: "punctuation.definition.heredoc.perl"}},
    contentName: "string.unquoted.heredoc.perl",
    end: "(^\\3$)",
    patterns: [{include: "#escaped_char"}, {include: "#variable"}]},
   {begin: /\bqq\s*(?<_1>[^\(\{\[\<\w\s])/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\1",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.quoted.other.qq.perl",
    patterns: [{include: "#escaped_char"}, {include: "#variable"}]},
   {begin: /\bqx\s*(?<_1>[^'\(\{\[\<\w\s])/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\1",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.interpolated.qx.perl",
    patterns: [{include: "#escaped_char"}, {include: "#variable"}]},
   {begin: /\bqx\s*'/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "'",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.interpolated.qx.single-quote.perl",
    patterns: [{include: "#escaped_char"}]},
   {begin: /"/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\"",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.quoted.double.perl",
    patterns: [{include: "#escaped_char"}, {include: "#variable"}]},
   {begin: /\bqw?\s*(?<_1>[^\(\{\[\<\w\s])/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\1",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.quoted.other.q.perl",
    patterns: [{include: "#escaped_char"}]},
   {begin: /'/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "'",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.quoted.single.perl",
    patterns: [{match: /\\['\\]/, name: "constant.character.escape.perl"}]},
   {begin: /`/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "`",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.interpolated.perl",
    patterns: [{include: "#escaped_char"}, {include: "#variable"}]},
   {begin: /\bqq\s*\(/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\)",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.quoted.other.qq-paren.perl",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#nested_parens_interpolated"},
      {include: "#variable"}]},
   {begin: /\bqq\s*\{/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\}",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.quoted.other.qq-brace.perl",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#nested_braces_interpolated"},
      {include: "#variable"}]},
   {begin: /\bqq\s*\[/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\]",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.quoted.other.qq-bracket.perl",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#nested_brackets_interpolated"},
      {include: "#variable"}]},
   {begin: /\bqq\s*\</,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\>",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.quoted.other.qq-ltgt.perl",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#nested_ltgt_interpolated"},
      {include: "#variable"}]},
   {begin: /\bqx\s*\(/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\)",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.interpolated.qx-paren.perl",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#nested_parens_interpolated"},
      {include: "#variable"}]},
   {begin: /\bqx\s*\{/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\}",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.interpolated.qx-brace.perl",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#nested_braces_interpolated"},
      {include: "#variable"}]},
   {begin: /\bqx\s*\[/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\]",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.interpolated.qx-bracket.perl",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#nested_brackets_interpolated"},
      {include: "#variable"}]},
   {begin: /\bqx\s*\</,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\>",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.interpolated.qx-ltgt.perl",
    patterns: 
     [{include: "#escaped_char"},
      {include: "#nested_ltgt_interpolated"},
      {include: "#variable"}]},
   {begin: /\bqw?\s*\(/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\)",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.quoted.other.q-paren.perl",
    patterns: [{include: "#escaped_char"}, {include: "#nested_parens"}]},
   {begin: /\bqw?\s*\{/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\}",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.quoted.other.q-brace.perl",
    patterns: [{include: "#escaped_char"}, {include: "#nested_braces"}]},
   {begin: /\bqw?\s*\[/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\]",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.quoted.other.q-bracket.perl",
    patterns: [{include: "#escaped_char"}, {include: "#nested_brackets"}]},
   {begin: /\bqw?\s*\</,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "\\>",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.quoted.other.q-ltgt.perl",
    patterns: [{include: "#escaped_char"}, {include: "#nested_ltgt"}]},
   {begin: /^__\w+__/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.perl"}},
    end: "$",
    endCaptures: {0 => {name: "punctuation.definition.string.end.perl"}},
    name: "string.unquoted.program-block.perl"},
   {begin: /\b(?<_1>format)\s+(?<_2>[A-Za-z]+)\s*=/,
    beginCaptures: 
     {1 => {name: "support.function.perl"},
      2 => {name: "entity.name.function.format.perl"}},
    end: "^\\.\\s*$",
    name: "meta.format.perl",
    patterns: [{include: "#line_comment"}, {include: "#variable"}]},
   {match: 
     /\b(?<_1>ARGV|DATA|ENV|SIG|STDERR|STDIN|STDOUT|atan2|bind|binmode|bless|caller|chdir|chmod|chomp|chop|chown|chr|chroot|close|closedir|cmp|connect|cos|crypt|dbmclose|dbmopen|defined|delete|dump|each|endgrent|endhostent|endnetent|endprotoent|endpwent|endservent|eof|eq|eval|exec|exists|exp|fcntl|fileno|flock|fork|format|formline|ge|getc|getgrent|getgrgid|getgrnam|gethostbyaddr|gethostbyname|gethostent|getlogin|getnetbyaddr|getnetbyname|getnetent|getpeername|getpgrp|getppid|getpriority|getprotobyname|getprotobynumber|getprotoent|getpwent|getpwnam|getpwuid|getservbyname|getservbyport|getservent|getsockname|getsockopt|glob|gmtime|grep|gt|hex|import|index|int|ioctl|join|keys|kill|lc|lcfirst|le|length|link|listen|local|localtime|log|lstat|lt|m|map|mkdir|msgctl|msgget|msgrcv|msgsnd|ne|no|oct|open|opendir|ord|pack|pipe|pop|pos|print|printf|push|q|qq|quotemeta|qw|qx|rand|read|readdir|readlink|recv|ref|rename|reset|reverse|rewinddir|rindex|rmdir|s|scalar|seek|seekdir|semctl|semget|semop|send|setgrent|sethostent|setnetent|setpgrp|setpriority|setprotoent|setpwent|setservent|setsockopt|shift|shmctl|shmget|shmread|shmwrite|shutdown|sin|sleep|socket|socketpair|sort|splice|split|sprintf|sqrt|srand|stat|study|substr|symlink|syscall|sysopen|sysread|system|syswrite|tell|telldir|tie|tied|time|times|tr|truncate|uc|ucfirst|umask|undef|unlink|unpack|unshift|untie|utime|values|vec|waitpid|wantarray|warn|write|y|q|qw|qq|qx)\b/,
    name: "support.function.perl"}],
 repository: 
  {escaped_char: {match: /\\./, name: "constant.character.escape.perl"},
   line_comment: 
    {patterns: 
      [{captures: 
         {1 => {name: "comment.line.number-sign.perl"},
          2 => {name: "punctuation.definition.comment.perl"}},
        match: /^(?<_1>(?<_2>#).*$\n?)/,
        name: "meta.comment.full-line.perl"},
       {captures: {1 => {name: "punctuation.definition.comment.perl"}},
        match: /(?<_1>#).*$\n?/,
        name: "comment.line.number-sign.perl"}]},
   nested_braces: 
    {begin: /\{/,
     captures: {1 => {name: "punctuation.section.scope.perl"}},
     end: "\\}",
     patterns: [{include: "#escaped_char"}, {include: "#nested_braces"}]},
   nested_braces_interpolated: 
    {begin: /\{/,
     captures: {1 => {name: "punctuation.section.scope.perl"}},
     end: "\\}",
     patterns: 
      [{include: "#escaped_char"},
       {include: "#variable"},
       {include: "#nested_braces_interpolated"}]},
   nested_brackets: 
    {begin: /\[/,
     captures: {1 => {name: "punctuation.section.scope.perl"}},
     end: "\\]",
     patterns: [{include: "#escaped_char"}, {include: "#nested_brackets"}]},
   nested_brackets_interpolated: 
    {begin: /\[/,
     captures: {1 => {name: "punctuation.section.scope.perl"}},
     end: "\\]",
     patterns: 
      [{include: "#escaped_char"},
       {include: "#variable"},
       {include: "#nested_brackets_interpolated"}]},
   nested_ltgt: 
    {begin: /</,
     captures: {1 => {name: "punctuation.section.scope.perl"}},
     end: ">",
     patterns: [{include: "#nested_ltgt"}]},
   nested_ltgt_interpolated: 
    {begin: /</,
     captures: {1 => {name: "punctuation.section.scope.perl"}},
     end: ">",
     patterns: 
      [{include: "#variable"}, {include: "#nested_ltgt_interpolated"}]},
   nested_parens: 
    {begin: /\(/,
     captures: {1 => {name: "punctuation.section.scope.perl"}},
     end: "\\)",
     patterns: [{include: "#escaped_char"}, {include: "#nested_parens"}]},
   nested_parens_interpolated: 
    {begin: /\(/,
     captures: {1 => {name: "punctuation.section.scope.perl"}},
     end: "\\)",
     patterns: 
      [{comment: 
         "This is to prevent thinks like qr/foo$/ to treat $/ as a variable",
        match: /\$(?=[^\s\w\'\{\[\(\<])/,
        name: "keyword.control.anchor.perl"},
       {include: "#escaped_char"},
       {include: "#variable"},
       {include: "#nested_parens_interpolated"}]},
   variable: 
    {patterns: 
      [{captures: {1 => {name: "punctuation.definition.variable.perl"}},
        match: /(?<_1>\$)&(?![A-Za-z0-9_])/,
        name: "variable.other.regexp.match.perl"},
       {captures: {1 => {name: "punctuation.definition.variable.perl"}},
        match: /(?<_1>\$)`(?![A-Za-z0-9_])/,
        name: "variable.other.regexp.pre-match.perl"},
       {captures: {1 => {name: "punctuation.definition.variable.perl"}},
        match: /(?<_1>\$)'(?![A-Za-z0-9_])/,
        name: "variable.other.regexp.post-match.perl"},
       {captures: {1 => {name: "punctuation.definition.variable.perl"}},
        match: /(?<_1>\$)\+(?![A-Za-z0-9_])/,
        name: "variable.other.regexp.last-paren-match.perl"},
       {captures: {1 => {name: "punctuation.definition.variable.perl"}},
        match: /(?<_1>\$)"(?![A-Za-z0-9_])/,
        name: "variable.other.readwrite.list-separator.perl"},
       {captures: {1 => {name: "punctuation.definition.variable.perl"}},
        match: /(?<_1>\$)0(?![A-Za-z0-9_])/,
        name: "variable.other.predefined.program-name.perl"},
       {captures: {1 => {name: "punctuation.definition.variable.perl"}},
        match: 
         /(?<_1>\$)[_ab\*\.\/\|,\\;#%=\-~^:?!\$<>\(\)\[\]@](?![A-Za-z0-9_])/,
        name: "variable.other.predefined.perl"},
       {captures: {1 => {name: "punctuation.definition.variable.perl"}},
        match: /(?<_1>\$)[0-9]+(?![A-Za-z0-9_])/,
        name: "variable.other.subpattern.perl"},
       {captures: {1 => {name: "punctuation.definition.variable.perl"}},
        match: 
         /(?<_1>[\$\@\%](?<_2>#)?)(?<_3>[a-zA-Zx7f-xff\$]|::)(?<_4>[a-zA-Z0-9_x7f-xff\$]|::)*\b/,
        name: "variable.other.readwrite.global.perl"},
       {captures: 
         {1 => {name: "punctuation.definition.variable.perl"},
          2 => {name: "punctuation.definition.variable.perl"}},
        match: 
         /(?<_1>\$\{)(?:[a-zA-Zx7f-xff\$]|::)(?:[a-zA-Z0-9_x7f-xff\$]|::)*(?<_2>\})/,
        name: "variable.other.readwrite.global.perl"},
       {captures: {1 => {name: "punctuation.definition.variable.perl"}},
        match: /(?<_1>[\$\@\%](?<_2>#)?)[0-9_]\b/,
        name: "variable.other.readwrite.global.special.perl"}]}},
 scopeName: "source.perl",
 uuid: "EDBFE125-6B1C-11D9-9189-000D93589AF6"}