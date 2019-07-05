# Encoding: UTF-8

{fileTypes: ["xsl", "xslt"],
 foldingStartMarker: 
  /^\s*(?<_1><[^!?%\/](?!.+?(?<_2>\/>|<\/.+?>))|<[!%]--(?!.+?--%?>)|<%[!]?(?!.+?%>))/,
 foldingStopMarker: /^\s*(?<_1><\/[^>]+>|[\/%]>|-->)\s*$/,
 keyEquivalent: "^~X",
 name: "XSL",
 patterns: 
  [{begin: /(?<_1><)(?<_2>xsl)(?<_3>(?<_4>:))(?<_5>template)/,
    captures: 
     {1 => {name: "punctuation.definition.tag.xml"},
      2 => {name: "entity.name.tag.namespace.xml"},
      3 => {name: "entity.name.tag.xml"},
      4 => {name: "punctuation.separator.namespace.xml"},
      5 => {name: "entity.name.tag.localname.xml"}},
    end: "(>)",
    name: "meta.tag.xml.template",
    patterns: 
     [{captures: 
        {1 => {name: "entity.other.attribute-name.namespace.xml"},
         2 => {name: "entity.other.attribute-name.xml"},
         3 => {name: "punctuation.separator.namespace.xml"},
         4 => {name: "entity.other.attribute-name.localname.xml"}},
       match: / (?:(?<_1>[-_a-zA-Z0-9]+)(?<_2>(?<_3>:)))?(?<_4>[a-zA-Z-]+)/},
      {include: "#doublequotedString"},
      {include: "#singlequotedString"}]},
   {include: "text.xml"}],
 repository: 
  {doublequotedString: 
    {begin: /"/,
     beginCaptures: {0 => {name: "punctuation.definition.string.begin.xml"}},
     end: "\"",
     endCaptures: {0 => {name: "punctuation.definition.string.end.xml"}},
     name: "string.quoted.double.xml"},
   singlequotedString: 
    {begin: /'/,
     beginCaptures: {0 => {name: "punctuation.definition.string.begin.xml"}},
     end: "'",
     endCaptures: {0 => {name: "punctuation.definition.string.end.xml"}},
     name: "string.quoted.single.xml"}},
 scopeName: "text.xml.xsl",
 uuid: "DB8033A1-6D8E-4D80-B8A2-8768AAC6125D"}
