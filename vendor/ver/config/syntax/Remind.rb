# Encoding: UTF-8

{fileTypes: ["defs.rem", "REM*.txt", ".reminders"],
 firstLineMatch: "^REM*",
 name: "Remind",
 patterns: 
  [{captures: {1 => {name: "punctuation.definition.comment.remind"}},
    match: /[ ]*(?<_1>#).*\n?/,
    name: "comment.line.number-sign.remind"},
   {captures: {1 => {name: "punctuation.definition.comment.remind"}},
    match: /[ ]*(?<_1>;).*\n?/,
    name: "comment.line.semicolon.remind"},
   {captures: {0 => {name: "keyword.control.single.command.remind"}},
    match: 
     /\b(?i:(?:RUN\s+(?<_1>ON|OFF))|(?<_2>PUSH|CLEAR|POP)-OMIT-CONTEXT)\b/,
    name: "meta.single.command.remind"},
   {begin: /\b(?i:(?<_1>SET))\s+(?<_2>\$?\w+)\s+/,
    beginCaptures: 
     {1 => {name: "keyword.control.set.setline.remind"},
      2 => {name: "variable.other.setline.remind"}},
    end: "(?=#|\\n|\\z)",
    name: "meta.setline.remind",
    patterns: [{include: "#expression"}]},
   {begin: 
     /\b(?i:(?<_1>FSET))\s+(?<_2>\w+(?<_3>\())(?<_4>\w+)?(?:,(?<_5>\w+))*(?<_6>\))/,
    beginCaptures: 
     {1 => {name: "keyword.control.fset.fsetline.remind"},
      2 => {name: "entity.name.function.fsetline.remind"},
      3 => {name: "punctuation.definition.arguments.remind"},
      4 => {name: "variable.parameter.fsetline.remind"},
      5 => {name: "variable.parameter.fsetline.remind"},
      6 => {name: "punctuation.definition.arguments.remind"}},
    end: "(?=#|\\n|\\z)",
    name: "meta.fsetline.remind",
    patterns: [{include: "#expression"}]},
   {begin: /\b(?i:(?<_1>UNSET))\b/,
    beginCaptures: {1 => {name: "keyword.control.set.unsetline.remind"}},
    end: "(?=#|\\n|\\z)",
    name: "meta.unsetline.remind",
    patterns: [{match: /\b\w+\b/, name: "variable.other.unsetline.remind"}]},
   {begin: /\b(?i:(?<_1>IF))\b/,
    captures: {1 => {name: "keyword.control.if.remind"}},
    end: "(?=#|\\n|\\z)",
    name: "meta.if.remind",
    patterns: [{include: "#expression"}]},
   {begin: /\b(?i:(?<_1>IFTRIG))\b/,
    captures: {1 => {name: "keyword.control.iftrig.remind"}},
    end: "(?=#|\\n|\\z)",
    name: "meta.iftrig.remind",
    patterns: [{include: "#trigger"}]},
   {match: /\b(?i:(?<_1>ELSE|ENDIF))\s*(?=#|\n|\z)/,
    name: "keyword.control.else-or-endif.remind"},
   {begin: /\b(?i:INCLUDE)\b/,
    beginCaptures: {0 => {name: "keyword.control.include.commandline.remind"}},
    end: "(?=#|\\n|\\z)",
    name: "meta.includeline.remind"},
   {begin: /\b(?i:REM|OMIT|BANNER)\b/,
    beginCaptures: {0 => {name: "keyword.control.command.commandline.remind"}},
    end: "(%?[ \\t]*)(?=(#|\\n|\\z))",
    endCaptures: {0 => {name: "keyword.control.endline.commandline.remind"}},
    name: "meta.commandline.remind",
    patterns: 
     [{match: /\b(?i:SCHED|WARN|SCANFROM|SCAN|UNTIL)\b/,
       name: "keyword.control.expiry.commandline.remind"},
      {begin: /\b(?i:SATISFY)\b/,
       beginCaptures: 
        {0 => {name: "keyword.control.satisfy.commandline.remind"}},
       end: "(?=(#|\\n|\\z))",
       name: "meta.satisfy.remind",
       patterns: [{include: "#expression"}]},
      {include: "#trigger"},
      {include: "#message-body"},
      {include: "#bracketed-expression"},
      {include: "#message"}]},
   {include: "#bracketed-expression"},
   {include: "#message"}],
 repository: 
  {:"bracketed-expression" => 
    {begin: /\[/,
     captures: {0 => {name: "punctuation.section.scope.remind"}},
     end: "\\]",
     patterns: [{include: "#expression"}]},
   :"date-item" => 
    {patterns: 
      [{match: 
         /\b(?i:January|Jan|February|Feb|March|Mar|April|Apr|May|June|Jun|July|Jul|August|Aug|September|Sep|October|Oct|November|Nov|December|Dec)\b/,
        name: "support.constant.month.dateitem.remind"},
       {match: 
         /\b(?i:Monday|Mon|Tuesday|Tue|Wednesday|Wed|Thursday|Thu|Friday|Fri|Saturday|Sat|Sunday|Sun)\b/,
        name: "support.constant.weekday.dateitem.remind"},
       {match: /\b(?:\d{1,2})\b/,
        name: "support.constant.day.dateitem.remind"},
       {match: /\b(?:\d{4})\b/,
        name: "support.constant.year.dateitem.remind"}]},
   expression: 
    {patterns: 
      [{begin: /\(/,
        captures: {0 => {name: "punctuation.section.scope.remind"}},
        end: "\\)",
        patterns: [{include: "#expression"}]},
       {match: /-|\*|\/|%|\+|-|[!<>=]=?|&&|\|\|/,
        name: "keyword.operator.remind"},
       {begin: /"/,
        beginCaptures: 
         {0 => {name: "punctuation.definition.string.begin.remind"}},
        end: "\"",
        endCaptures: {0 => {name: "punctuation.definition.string.end.remind"}},
        name: "string.quoted.double.remind",
        patterns: [{match: /\\./, name: "constant.character.escape.remind"}]},
       {match: /'\d{4}(?<_1>[\-\/])\d{1,2}\k<_1>\d{1,2}'/,
        name: "constant.other.date.remind"},
       {match: /\d{1,2}[:.]\d{2}/, name: "constant.other.time.remind"},
       {match: /\d+/, name: "constant.numeric.integer.remind"},
       {match: 
         /\$(?:CalcUTC|CalMode|Daemon|DefaultPrio|DontFork|DontTrigAts|DontQueue|EndSent|EndSentIg|FirstIndent|FoldYear|FormWidth|HushMode|IgnoreOnce|InfDelta|LatDeg|LatMin|LatSec|Location|LongDeg|LongMin|LongSec|MaxSatIter|MinsFromUTC|NextMode|NumQueued|NumTrig|PrefixLineNo|PSCal|RunOff|SimpleCal|SortByDate|SortByPrio|SortByTime|SubsIndent)\b/,
        name: "variable.language.system.remind"},
       {begin: 
         /\b(?:abs|access|args|asc|baseyr|char|choose|coerce|date|dawn|day|daysinmon|defined|dosubst|dusk|easterdate|filedate|filedir|filename|getenv|hour|iif|index|isdst|isleap|isomitted|hebdate|hebday|hebmon|hebyear|language|lower|max|min|minsfromutc|minute|min|monnum|moondate|moontime|moonphase|now|ord|ostype|plural|psmoon|psshade|realnow|realtoday|sgn|shell|strlen|substr|sunrise|sunset|time|today|trigdate|trigger|trigtime|trigvalid|typeof|upper|value|version|wkday|wkdaynum|year)\(/,
        captures: {0 => {name: "support.function.builtin.remind"}},
        end: "\\)",
        name: "meta.function.builtin.remind",
        patterns: [{include: "#expression"}]},
       {begin: /\b(?<_1>\w+)(?<_2>\()/,
        beginCaptures: 
         {1 => {name: "entity.name.function.remind"},
          2 => {name: "punctuation.definition.arguments.remind"}},
        end: "(\\))",
        endCaptures: {1 => {name: "punctuation.definition.arguments.remind"}},
        name: "meta.function.user.remind",
        patterns: [{include: "#expression"}]},
       {match: /\b\w+\b/, name: "variable.parameter.user.remind"}]},
   message: 
    {begin: /\b(?i:MSG|MSF|RUN|CAL|SPECIAL|PS|PSFILE)\b\s*/,
     beginCaptures: 
      {0 => {name: "keyword.control.message.commandline.remind"}},
     end: "(%?[ \\t]*)(?=\\n|\\z)",
     endCaptures: {0 => {name: "keyword.control.endline.commandline.remind"}},
     patterns: [{include: "#message-body"}]},
   :"message-body" => 
    {patterns: 
      [{captures: {1 => {name: "punctuation.definition.constant.remind"}},
        match: /(?<_1>%)[a-zA-Z0-9_!@#]/,
        name: "constant.other.placeholder.remind"},
       {begin: /%"/,
        beginCaptures: 
         {0 => {name: "punctuation.definition.string.begin.remind"}},
        end: "%\"",
        endCaptures: {0 => {name: "punctuation.definition.string.end.remind"}},
        name: "string.quoted.double.remind"},
       {include: "#bracketed-expression"}]},
   trigger: 
    {patterns: 
      [{captures: 
         {1 => {name: "keyword.other.attime.trigger.remind"},
          2 => {name: "constant.other.time.trigger.remind"},
          3 => {name: "variable.other.component.trigger.remind"},
          4 => {name: "variable.other.comp.trigger.remind"}},
        match: 
         /\b(?i:(?<_1>AT))\s+(?<_2>\d{1,2}[:.]\d{2})(?:\s+(?<_3>\+{1,2}\d+))?(?:\s+(?<_4>\*\d+))?(?=\s)/,
        name: "meta.attime.trigger.remind"},
       {captures: 
         {1 => {name: "keyword.other.duration.trigger.remind"},
          2 => {name: "constant.other.time.trigger.remind"}},
        match: /\b(?i:(?<_1>DURATION))\s+(?<_2>\d{1,2}[:.]\d{2})(?=\s)/,
        name: "meta.duration.trigger.remind"},
       {match: /\b(?i:OMIT)\b/,
        name: "keyword.control.command.trigger.remind"},
       {match: /\b(?i:ONCE|SKIP|BEFORE|AFTER)\b/,
        name: "keyword.control.move-reminder.trigger.remind"},
       {captures: {1 => {name: "punctuation.definition.variable.remind"}},
        match: /(?<_1>\+{1,2})\d+/,
        name: "variable.other.component.delta.trigger.remind"},
       {captures: {1 => {name: "punctuation.definition.variable.remind"}},
        match: /(?<_1>\-{1,2})\d+/,
        name: "variable.other.component.back.trigger.remind"},
       {captures: {1 => {name: "punctuation.definition.variable.remind"}},
        match: /(?<_1>\*)\d+/,
        name: "variable.other.component.repeat.trigger.remind"},
       {include: "#date-item"}]}},
 scopeName: "source.remind",
 uuid: "8D255A1E-9CBC-4B22-8AAD-F8536C276727"}