# Encoding: UTF-8

{fileTypes: ["xml", "tld", "jsp", "pt", "cpt", "dtml", "rss", "opml"],
 foldingStartMarker: 
  /^\s*(?<_1><[^!?%\/](?!.+?(?<_2>\/>|<\/.+?>))|<[!%]--(?!.+?--%?>)|<%[!]?(?!.+?%>))/,
 foldingStopMarker: /^\s*(?<_1><\/[^>]+>|[\/%]>|-->)\s*$/,
 keyEquivalent: "^~X",
 name: "XML",
 patterns: 
  [{begin: /(?<_1><\?)\s*(?<_2>[-_a-zA-Z0-9]+)/,
    captures: 
     {1 => {name: "punctuation.definition.tag.xml"},
      2 => {name: "entity.name.tag.xml"}},
    end: "(\\?>)",
    name: "meta.tag.preprocessor.xml",
    patterns: 
     [{match: / (?<_1>[a-zA-Z-]+)/, name: "entity.other.attribute-name.xml"},
      {include: "#doublequotedString"},
      {include: "#singlequotedString"}]},
   {begin: /(?<_1><!)(?<_2>DOCTYPE)\s+(?<_3>[:a-zA-Z_][:a-zA-Z0-9_.-]*)/,
    captures: 
     {1 => {name: "punctuation.definition.tag.xml"},
      2 => {name: "keyword.doctype.xml"},
      3 => {name: "variable.documentroot.xml"}},
    end: "\\s*(>)",
    name: "meta.tag.sgml.doctype.xml",
    patterns: [{include: "#internalSubset"}]},
   {begin: /<[!%]--/,
    captures: {0 => {name: "punctuation.definition.comment.xml"}},
    end: "--%?>",
    name: "comment.block.xml"},
   {begin: 
     /(?<_1><)(?<_2>(?:(?<_3>[-_a-zA-Z0-9]+)(?<_4>(?<_5>:)))?(?<_6>[-_a-zA-Z0-9:]+))(?=(?<_7>\s[^>]*)?><\/\k<_2>>)/,
    beginCaptures: 
     {1 => {name: "punctuation.definition.tag.xml"},
      3 => {name: "entity.name.tag.namespace.xml"},
      4 => {name: "entity.name.tag.xml"},
      5 => {name: "punctuation.separator.namespace.xml"},
      6 => {name: "entity.name.tag.localname.xml"}},
    end: "(>(<))/(?:([-_a-zA-Z0-9]+)((:)))?([-_a-zA-Z0-9:]+)(>)",
    endCaptures: 
     {1 => {name: "punctuation.definition.tag.xml"},
      2 => {name: "meta.scope.between-tag-pair.xml"},
      3 => {name: "entity.name.tag.namespace.xml"},
      4 => {name: "entity.name.tag.xml"},
      5 => {name: "punctuation.separator.namespace.xml"},
      6 => {name: "entity.name.tag.localname.xml"},
      7 => {name: "punctuation.definition.tag.xml"}},
    name: "meta.tag.no-content.xml",
    patterns: [{include: "#tagStuff"}]},
   {begin: 
     /(?<_1><\/?)(?:(?<_2>[-_a-zA-Z0-9]+)(?<_3>(?<_4>:)))?(?<_5>[-_a-zA-Z0-9:]+)/,
    captures: 
     {1 => {name: "punctuation.definition.tag.xml"},
      2 => {name: "entity.name.tag.namespace.xml"},
      3 => {name: "entity.name.tag.xml"},
      4 => {name: "punctuation.separator.namespace.xml"},
      5 => {name: "entity.name.tag.localname.xml"}},
    end: "(/?>)",
    name: "meta.tag.xml",
    patterns: [{include: "#tagStuff"}]},
   {include: "#entity"},
   {include: "#bare-ampersand"},
   {begin: /<%@/,
    beginCaptures: {0 => {name: "punctuation.section.embedded.begin.xml"}},
    end: "%>",
    endCaptures: {0 => {name: "punctuation.section.embedded.end.xml"}},
    name: "source.java-props.embedded.xml",
    patterns: 
     [{match: /page|include|taglib/, name: "keyword.other.page-props.xml"}]},
   {begin: /<%[!=]?(?!--)/,
    beginCaptures: {0 => {name: "punctuation.section.embedded.begin.xml"}},
    end: "(?!--)%>",
    endCaptures: {0 => {name: "punctuation.section.embedded.end.xml"}},
    name: "source.java.embedded.xml",
    patterns: [{include: "source.java"}]},
   {begin: /<!\[CDATA\[/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.xml"}},
    end: "]]>",
    endCaptures: {0 => {name: "punctuation.definition.string.end.xml"}},
    name: "string.unquoted.cdata.xml"}],
 repository: 
  {EntityDecl: 
    {begin: 
      /(?<_1><!)(?<_2>ENTITY)\s+(?<_3>%\s+)?(?<_4>[:a-zA-Z_][:a-zA-Z0-9_.-]*)(?<_5>\s+(?:SYSTEM|PUBLIC)\s+)?/,
     captures: 
      {1 => {name: "punctuation.definition.tag.xml"},
       2 => {name: "keyword.entity.xml"},
       3 => {name: "punctuation.definition.entity.xml"},
       4 => {name: "variable.entity.xml"},
       5 => {name: "keyword.entitytype.xml"}},
     end: "(>)",
     patterns: 
      [{include: "#doublequotedString"}, {include: "#singlequotedString"}]},
   :"bare-ampersand" => 
    {match: /&/, name: "invalid.illegal.bad-ampersand.xml"},
   doublequotedString: 
    {begin: /"/,
     beginCaptures: {0 => {name: "punctuation.definition.string.begin.xml"}},
     end: "\"",
     endCaptures: {0 => {name: "punctuation.definition.string.end.xml"}},
     name: "string.quoted.double.xml",
     patterns: [{include: "#entity"}, {include: "#bare-ampersand"}]},
   entity: 
    {captures: 
      {1 => {name: "punctuation.definition.constant.xml"},
       3 => {name: "punctuation.definition.constant.xml"}},
     match: 
      /(?<_1>&)(?<_2>[:a-zA-Z_][:a-zA-Z0-9_.-]*|#[0-9]+|#x[0-9a-fA-F]+)(?<_3>;)/,
     name: "constant.character.entity.xml"},
   internalSubset: 
    {begin: /(?<_1>\[)/,
     captures: {1 => {name: "punctuation.definition.constant.xml"}},
     end: "(\\])",
     name: "meta.internalsubset.xml",
     patterns: [{include: "#EntityDecl"}, {include: "#parameterEntity"}]},
   parameterEntity: 
    {captures: 
      {1 => {name: "punctuation.definition.constant.xml"},
       3 => {name: "punctuation.definition.constant.xml"}},
     match: /(?<_1>%)(?<_2>[:a-zA-Z_][:a-zA-Z0-9_.-]*)(?<_3>;)/,
     name: "constant.character.parameter-entity.xml"},
   singlequotedString: 
    {begin: /'/,
     beginCaptures: {0 => {name: "punctuation.definition.string.begin.xml"}},
     end: "'",
     endCaptures: {0 => {name: "punctuation.definition.string.end.xml"}},
     name: "string.quoted.single.xml",
     patterns: [{include: "#entity"}, {include: "#bare-ampersand"}]},
   tagStuff: 
    {patterns: 
      [{captures: 
         {1 => {name: "entity.other.attribute-name.namespace.xml"},
          2 => {name: "entity.other.attribute-name.xml"},
          3 => {name: "punctuation.separator.namespace.xml"},
          4 => {name: "entity.other.attribute-name.localname.xml"}},
        match: 
         / (?:(?<_1>[-_a-zA-Z0-9]+)(?<_2>(?<_3>:)))?(?<_4>[_a-zA-Z-]+)=/},
       {include: "#doublequotedString"},
       {include: "#singlequotedString"}]}},
 scopeName: "text.xml",
 uuid: "D3C4E6DA-6B1C-11D9-8CC2-000D93589AF6"}
