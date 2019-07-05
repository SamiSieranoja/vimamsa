# Encoding: UTF-8

{comment: 
  "Modified from the original ASP bundle. Originally modified by Thomas Aylott subtleGradient.com",
 fileTypes: ["vb"],
 foldingStartMarker: 
  /(?<_1><(?i:(?<_2>head|table|div|style|script|ul|ol|form|dl))\b.*?>|\{|^\s*<?%?\s*'?\s*(?i:(?<_3>sub|private\s+Sub|public\s+Sub|function|if|while|For))\s*.*$)/,
 foldingStopMarker: 
  /(?<_1><\/(?i:(?<_2>head|table|div|style|script|ul|ol|form|dl))>?|\}|^\s*<?%?\s*\s*'?\s*(?i:(?<_3>end|Next))\s*.*$)/,
 keyEquivalent: "^~A",
 name: "ASP vb.NET",
 patterns: 
  [{match: /\n/, name: "meta.ending-space"},
   {include: "#round-brackets"},
   {begin: /^(?=\t)/,
    end: "(?=[^\\t])",
    name: "meta.leading-space",
    patterns: 
     [{captures: 
        {1 => {name: "meta.odd-tab.tabs"}, 2 => {name: "meta.even-tab.tabs"}},
       match: /(?<_1>\t)(?<_2>\t)?/}]},
   {begin: /^(?= )/,
    end: "(?=[^ ])",
    name: "meta.leading-space",
    patterns: 
     [{captures: 
        {1 => {name: "meta.odd-tab.spaces"},
         2 => {name: "meta.even-tab.spaces"}},
       match: /(?<_1>  )(?<_2>  )?/}]},
   {captures: 
     {1 => {name: "storage.type.function.asp"},
      2 => {name: "entity.name.function.asp"},
      3 => {name: "punctuation.definition.parameters.asp"},
      4 => {name: "variable.parameter.function.asp"},
      5 => {name: "punctuation.definition.parameters.asp"}},
    match: 
     /^\s*(?<_1>(?i:function|sub))\s*(?<_2>[a-zA-Z_]\w*)\s*(?<_3>\()(?<_4>[^)]*)(?<_5>\)).*\n?/,
    name: "meta.function.asp"},
   {begin: /'/,
    beginCaptures: {0 => {name: "punctuation.definition.comment.asp"}},
    end: "(?=(\\n|%>))",
    name: "comment.line.apostrophe.asp"},
   {match: 
     /(?i:\b(?<_1>If|Then|Else|ElseIf|Else If|End If|While|Wend|For|To|Each|Case|Select|End Select|Return|Continue|Do|Until|Loop|Next|With|Exit Do|Exit For|Exit Function|Exit Property|Exit Sub|IIf)\b)/,
    name: "keyword.control.asp"},
   {match: /(?i:\b(?<_1>Mod|And|Not|Or|Xor|as)\b)/,
    name: "keyword.operator.asp"},
   {captures: 
     {1 => {name: "storage.type.asp"},
      2 => {name: "variable.other.bfeac.asp"},
      3 => {name: "meta.separator.comma.asp"}},
    match: 
     /(?i:(?<_1>dim)\s*(?:(?<_2>\b[a-zA-Z_x7f-xff][a-zA-Z0-9_x7f-xff]*?\b)\s*(?<_3>,?)))/,
    name: "variable.other.dim.asp"},
   {match: 
     /(?i:\s*\b(?<_1>Call|Class|Const|Dim|Redim|Function|Sub|Private Sub|Public Sub|End sub|End Function|Set|Let|Get|New|Randomize|Option Explicit|On Error Resume Next|On Error GoTo)\b\s*)/,
    name: "storage.type.asp"},
   {match: /(?i:\b(?<_1>Private|Public|Default)\b)/,
    name: "storage.modifier.asp"},
   {match: /(?i:\s*\b(?<_1>Empty|False|Nothing|Null|True)\b)/,
    name: "constant.language.asp"},
   {begin: /"/,
    beginCaptures: {0 => {name: "punctuation.definition.string.begin.asp"}},
    end: "\"",
    endCaptures: {0 => {name: "punctuation.definition.string.end.asp"}},
    name: "string.quoted.double.asp",
    patterns: 
     [{match: /""/, name: "constant.character.escape.apostrophe.asp"}]},
   {captures: {1 => {name: "punctuation.definition.variable.asp"}},
    match: /(?<_1>\$)[a-zA-Z_x7f-xff][a-zA-Z0-9_x7f-xff]*?\b\s*/,
    name: "variable.other.asp"},
   {match: 
     /(?i:\b(?<_1>Application|ObjectContext|Request|Response|Server|Session)\b)/,
    name: "support.class.asp"},
   {match: 
     /(?i:\b(?<_1>Contents|StaticObjects|ClientCertificate|Cookies|Form|QueryString|ServerVariables)\b)/,
    name: "support.class.collection.asp"},
   {match: 
     /(?i:\b(?<_1>TotalBytes|Buffer|CacheControl|Charset|ContentType|Expires|ExpiresAbsolute|IsClientConnected|PICS|Status|ScriptTimeout|CodePage|LCID|SessionID|Timeout)\b)/,
    name: "support.constant.asp"},
   {match: 
     /(?i:\b(?<_1>Lock|Unlock|SetAbort|SetComplete|BianryRead|AddHeader|AppendToLog|BinaryWrite|Clear|End|Flush|Redirect|Write|CreateObject|HTMLEncode|MapPath|URLEncode|Abandon|Convert|Regex)\b)/,
    name: "support.function.asp"},
   {match: 
     /(?i:\b(?<_1>Application_OnEnd|Application_OnStart|OnTransactionAbort|OnTransactionCommit|Session_OnEnd|Session_OnStart)\b)/,
    name: "support.function.event.asp"},
   {match: /(?i:(?<=as )(?<_1>\b[a-zA-Z_x7f-xff][a-zA-Z0-9_x7f-xff]*?\b))/,
    name: "support.type.vb.asp"},
   {match: 
     /(?i:\b(?<_1>Array|Add|Asc|Atn|CBool|CByte|CCur|CDate|CDbl|Chr|CInt|CLng|Conversions|Cos|CreateObject|CSng|CStr|Date|DateAdd|DateDiff|DatePart|DateSerial|DateValue|Day|Derived|Math|Escape|Eval|Exists|Exp|Filter|FormatCurrency|FormatDateTime|FormatNumber|FormatPercent|GetLocale|GetObject|GetRef|Hex|Hour|InputBox|InStr|InStrRev|Int|Fix|IsArray|IsDate|IsEmpty|IsNull|IsNumeric|IsObject|Item|Items|Join|Keys|LBound|LCase|Left|Len|LoadPicture|Log|LTrim|RTrim|Trim|Maths|Mid|Minute|Month|MonthName|MsgBox|Now|Oct|Remove|RemoveAll|Replace|RGB|Right|Rnd|Round|ScriptEngine|ScriptEngineBuildVersion|ScriptEngineMajorVersion|ScriptEngineMinorVersion|Second|SetLocale|Sgn|Sin|Space|Split|Sqr|StrComp|String|StrReverse|Tan|Time|Timer|TimeSerial|TimeValue|TypeName|UBound|UCase|Unescape|VarType|Weekday|WeekdayName|Year)\b)/,
    name: "support.function.vb.asp"},
   {match: 
     /-?\b(?<_1>(?<_2>0(?<_3>x|X)[0-9a-fA-F]*)|(?<_4>(?<_5>[0-9]+\.?[0-9]*)|(?<_6>\.[0-9]+))(?<_7>(?<_8>e|E)(?<_9>\+|-)?[0-9]+)?)(?<_10>L|l|UL|ul|u|U|F|f)?\b/,
    name: "constant.numeric.asp"},
   {match: 
     /(?i:\b(?<_1>vbtrue|fvbalse|vbcr|vbcrlf|vbformfeed|vblf|vbnewline|vbnullchar|vbnullstring|int32|vbtab|vbverticaltab|vbbinarycompare|vbtextcomparevbsunday|vbmonday|vbtuesday|vbwednesday|vbthursday|vbfriday|vbsaturday|vbusesystemdayofweek|vbfirstjan1|vbfirstfourdays|vbfirstfullweek|vbgeneraldate|vblongdate|vbshortdate|vblongtime|vbshorttime|vbobjecterror|vbEmpty|vbNull|vbInteger|vbLong|vbSingle|vbDouble|vbCurrency|vbDate|vbString|vbObject|vbError|vbBoolean|vbVariant|vbDataObject|vbDecimal|vbByte|vbArray)\b)/,
    name: "support.type.vb.asp"},
   {captures: {1 => {name: "entity.name.function.asp"}},
    match: /(?i:(?<_1>\b[a-zA-Z_x7f-xff][a-zA-Z0-9_x7f-xff]*?\b)(?=\(\)?))/,
    name: "support.function.asp"},
   {match: 
     /(?i:(?<_1>(?<=(?<_2>\+|=|-|\&|\\|\/|<|>|\(|,))\s*\b(?<_3>[a-zA-Z_x7f-xff][a-zA-Z0-9_x7f-xff]*?)\b(?!(?<_4>\(|\.))|\b(?<_5>[a-zA-Z_x7f-xff][a-zA-Z0-9_x7f-xff]*?)\b(?=\s*(?<_6>\+|=|-|\&|\\|\/|<|>|\(|\)))))/,
    name: "variable.other.asp"},
   {match: 
     /!|\$|%|&|\*|\-\-|\-|\+\+|\+|~|===|==|=|!=|!==|<=|>=|<<=|>>=|>>>=|<>|<|>|!|&&|\|\||\?\:|\*=|\/=|%=|\+=|\-=|&=|\^=|\b(?<_1>in|instanceof|new|delete|typeof|void)\b/,
    name: "keyword.operator.js"}],
 repository: 
  {:"round-brackets" => 
    {begin: /\(/,
     beginCaptures: 
      {0 => {name: "punctuation.section.round-brackets.begin.asp"}},
     end: "\\)",
     endCaptures: {0 => {name: "punctuation.section.round-brackets.end.asp"}},
     name: "meta.round-brackets",
     patterns: [{include: "source.asp.vb.net"}]}},
 scopeName: "source.asp.vb.net",
 uuid: "7F9C9343-D48E-4E7D-BFE8-F680714DCD3E"}
