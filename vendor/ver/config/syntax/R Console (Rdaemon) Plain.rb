# Encoding: UTF-8

{fileTypes: ["Rcon"],
 keyEquivalent: "^~R",
 name: "R Console (Rdaemon) Plain",
 patterns: 
  [{begin: /(?i)^\s*(?<_1>error|erreur|fehler|errore|erro)(?<_2> |:)/,
    beginCaptures: {0 => {name: "constant.other.rd.console.error"}},
    end: "(.*)(?=> )",
    endCaptures: {0 => {name: "keyword.other.embedded.rd.console"}},
    name: "markup.quote.rd.console.error"},
   {begin: 
     /^\s*(?<_1>Warning|Warning messages?|Message d.avis|Warnmeldung|Messaggio di avvertimento|Mensagem de aviso):/,
    beginCaptures: {0 => {name: "entity.name.tag.rd.console.warning"}},
    end: ".*(?=> )",
    endCaptures: {0 => {name: "keyword.other.embedded.rd.console"}},
    name: "storage.type.method.rd.console.warning"},
   {begin: /^[>+:] /,
    beginCaptures: {0 => {name: "keyword.other.embedded.rd.console"}},
    end: "\\n\\z",
    name: "source.rd.console.prompt",
    patterns: [{include: "source.r"}]},
   {begin: /^Browse\[\d+\]/,
    beginCaptures: {0 => {name: "meta.section.embedded.rd.console"}},
    end: "\\n\\z",
    name: "source.rd.console.prompt",
    patterns: [{include: "source.r"}]},
   {begin: /^(?<![>+:])/, end: "\\n", name: "source.r.embedded"}],
 scopeName: "source.rd.console.plain",
 uuid: "CB39EEE4-89EC-4ADE-8316-BC825F1CE056"}