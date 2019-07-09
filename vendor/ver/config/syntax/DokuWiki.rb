# Encoding: UTF-8

{fileTypes: [],
 firstLineMatch: "^\\s*={2,}(.*)={2,}\\s*$",
 foldingStartMarker: 
  /(?<_1><(?<_2>php|html|file|nowiki)>|<code(?<_3>\s*.*)?>)|\/\*\*|\{\s*$/,
 foldingStopMarker: 
  /(?<_1><\/(?<_2>code|php|html|file|nowiki)>)|\*\*\/|^\s*\}/,
 keyEquivalent: "^~D",
 name: "DokuWiki",
 patterns: 
  [{include: "#php"},
   {include: "#inline"},
   {begin: /"/,
    beginCaptures: 
     {0 => {name: "punctuation.definition.string.begin.dokuwiki"}},
    end: "\"",
    endCaptures: {0 => {name: "punctuation.definition.string.end.dokuwiki"}},
    name: "string.quoted.double.dokuwiki",
    patterns: [{match: /\\./, name: "constant.character.escape.dokuwiki"}]},
   {begin: /\(\(/,
    captures: {0 => {name: "punctuation.definition.comment.dokuwiki"}},
    end: "\\)\\)",
    name: "comment.block.documentation.dokuwiki"},
   {captures: 
     {1 => {name: "punctuation.definition.heading.dokuwiki"},
      3 => {name: "punctuation.definition.heading.dokuwiki"}},
    match: /^\s*(?<_1>={2,})(?<_2>.*)(?<_3>={2,})\s*$\n?/,
    name: "markup.heading.dokuwiki"},
   {match: /~~NOTOC~~/, name: "keyword.other.notoc.dokuwiki"},
   {match: /~~NOCACHE~~/, name: "keyword.other.nocache.dokuwiki"},
   {match: /^\s*-{4,}\s*$/, name: "meta.separator.dokuwiki"},
   {match: /\\\\\s/, name: "markup.other.paragraph.dokuwiki"},
   {begin: /^(?<_1>(?<_2>\t+)|(?<_3> {2,}))(?<_4>\*)/,
    captures: {4 => {name: "punctuation.definition.list_item.dokuwiki"}},
    end: "$\\n?",
    name: "markup.list.unnumbered.dokuwiki",
    patterns: [{include: "#inline"}]},
   {begin: /^(?<_1>(?<_2>\t+)|(?<_3> {2,}))(?<_4>-)/,
    captures: {4 => {name: "punctuation.definition.list_item.dokuwiki"}},
    end: "$\\n?",
    name: "markup.list.numbered.dokuwiki",
    patterns: [{include: "#inline"}]},
   {begin: /^[|^]/,
    beginCaptures: {0 => {name: "punctuation.definition.table.dokuwiki"}},
    end: "$",
    name: "markup.other.table.dokuwiki",
    patterns: [{include: "#inline"}]},
   {begin: /(?<_1>\<)(?<_2>file|nowiki)(?<_3>\>)/,
    captures: 
     {0 => {name: "meta.tag.template.dokuwiki"},
      1 => {name: "punctuation.definition.tag.dokuwiki"},
      2 => {name: "entity.name.tag.dokuwiki"},
      3 => {name: "punctuation.definition.tag.dokuwiki"}},
    end: "(<\\/)(\\2)(\\>)",
    name: "markup.raw.dokuwiki"},
   {begin: /(?<_1>%%|\'\')/,
    captures: {0 => {name: "punctuation.definition.raw.dokuwiki"}},
    end: "\\1",
    name: "markup.raw.dokuwiki"},
   {begin: /(?<_1><)(?<_2>html)(?<_3>>)/,
    captures: 
     {0 => {name: "meta.tag.template.block.dokuwiki"},
      1 => {name: "punctuation.definition.tag.dokuwiki"},
      2 => {name: "entity.name.tag.dokuwiki"},
      3 => {name: "punctuation.definition.tag.dokuwiki"}},
    end: "(</)(html)(>)",
    patterns: [{include: "text.html.basic"}]},
   {match: /^(?<_1>(?<_2>\s\s)|(?<_3>\t))[^\*\-].*$/,
    name: "markup.raw.dokuwiki"},
   {begin: /(?<_1>\<)(?<_2>sub|sup|del)(?<_3>\>)/,
    captures: 
     {0 => {name: "meta.tag.template.dokuwiki"},
      1 => {name: "punctuation.definition.tag.dokuwiki"},
      2 => {name: "entity.name.tag.dokuwiki"},
      3 => {name: "punctuation.definition.tag.dokuwiki"}},
    end: "(\\</)(\\2)(\\>)",
    name: "markup.other.dokuwiki",
    patterns: [{include: "#inline"}]},
   {begin: /(?<_1><)(?<_2>code)(?:\s+[^>]*)?(?<_3>>)/,
    captures: 
     {0 => {name: "meta.tag.template.code.dokuwiki"},
      1 => {name: "punctuation.definition.tag.dokuwiki"},
      2 => {name: "entity.name.tag.dokuwiki"},
      3 => {name: "punctuation.definition.tag.dokuwiki"}},
    end: "(</)(code)(>)",
    name: "markup.raw.dokuwiki"}],
 repository: 
  {inline: 
    {patterns: 
      [{begin: /\*\*/,
        captures: {0 => {name: "punctuation.definition.bold.dokuwiki"}},
        end: "\\*\\*",
        name: "markup.bold.dokuwiki",
        patterns: [{include: "#inline"}]},
       {begin: /\/\//,
        captures: {0 => {name: "punctuation.definition.italic.dokuwiki"}},
        end: "//",
        name: "markup.italic.dokuwiki",
        patterns: [{include: "#inline"}]},
       {begin: /__/,
        captures: {0 => {name: "punctuation.definition.underline.dokuwiki"}},
        end: "__",
        name: "markup.underline.dokuwiki",
        patterns: [{include: "#inline"}]},
       {captures: 
         {1 => {name: "punctuation.definition.image.dokuwiki"},
          2 => {name: "markup.underline.link.dokuwiki"},
          3 => {name: "punctuation.definition.image.dokuwiki"}},
        match: /(?<_1>\{\{)(?<_2>.+?)(?<_3>\}\})/,
        name: "meta.image.inline.dokuwiki"},
       {captures: 
         {1 => {name: "punctuation.definition.link.dokuwiki"},
          2 => {name: "markup.underline.link.dokuwiki"},
          3 => {name: "punctuation.definition.link.dokuwiki"}},
        match: /(?<_1>\[\[)(?<_2>.*?)(?<_3>\]\])/,
        name: "meta.link.dokuwiki"},
       {captures: 
         {1 => {name: "punctuation.definition.link.dokuwiki"},
          2 => {name: "markup.underline.link.interwiki.dokuwiki"},
          3 => {name: "punctuation.definition.link.dokuwiki"}},
        match: /(?<_1>\[\[)(?<_2>[^\[\]]+\>[^|\]]+)(?<_3>\]\])/},
       {captures: {1 => {name: "markup.underline.link.dokuwiki"}},
        match: 
         /(?<_1>(?<_2>https?|telnet|gopher|wais|ftp|ed2k|irc):\/\/[\w\/\#~:.?+=&%@!\-;,]+?(?=[.:?\-;,]*[^\w\/\#~:.?+=&%@!\-;,]))/},
       {captures: 
         {1 => {name: "punctuation.definition.link.dokuwiki"},
          2 => {name: "markup.underline.link.dokuwiki"},
          3 => {name: "punctuation.definition.link.dokuwiki"}},
        match: 
         /(?<_1><)(?<_2>[\w0-9\-_.]+?@[\w\-]+\.[\w\-\.]+\.*[\w]+)(?<_3>\>)/,
        name: "meta.link.email.dokuwiki"}]},
   php: 
    {patterns: 
      [{include: "source.php"},
       {begin: /(?<_1>^\s*)?(?=<php>)/,
        beginCaptures: 
         {1 => {name: "punctuation.whitespace.embedded.leading.dokuwiki"}},
        contentName: "meta.embedded.php",
        end: "(?<=</php>)(?!<php>)(\\s*$\\n?)",
        endCaptures: 
         {1 => {name: "punctuation.whitespace.embedded.trailing.dokuwiki"}},
        patterns: 
         [{begin: /(?<_1>(?<_2><)(?<_3>php)(?<_4>>))/,
           beginCaptures: 
            {0 => {name: "punctuation.definition.embedded.begin.dokuwiki"},
             1 => {name: "meta.tag.template.dokuwiki"},
             2 => {name: "punctuation.definition.tag.dokuwiki"},
             3 => {name: "entity.name.tag.dokuwiki"},
             4 => {name: "punctuation.definition.tag.dokuwiki"}},
           contentName: "source.php",
           end: "(((</))(php)(>))",
           endCaptures: 
            {0 => {name: "punctuation.definition.embedded.end.dokuwiki"},
             1 => {name: "meta.tag.template.dokuwiki"},
             2 => {name: "punctuation.definition.tag.dokuwiki"},
             3 => {name: "source.php"},
             4 => {name: "entity.name.tag.dokuwiki"},
             5 => {name: "punctuation.definition.tag.dokuwiki"}},
           patterns: [{include: "source.php"}]}]}]}},
 scopeName: "text.html.dokuwiki",
 uuid: "862D8B02-501E-4205-9DA4-FB7CDA7AE3DA"}