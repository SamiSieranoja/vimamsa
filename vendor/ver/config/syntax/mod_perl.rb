# Encoding: UTF-8

{fileTypes: [],
 foldingStartMarker: 
  /^[ ]*(?x)
	(?<_1><(?i:FilesMatch|Files|DirectoryMatch|Directory|LocationMatch|Location|VirtualHost|IfModule|IfDefine|Perl)\b.*?>
	)/,
 foldingStopMarker: 
  /^[ ]*(?x)
	(?<_1><\/(?i:FilesMatch|Files|DirectoryMatch|Directory|LocationMatch|Location|VirtualHost|IfModule|IfDefine|Perl)>
	)/,
 keyEquivalent: "^~A",
 name: "mod_perl",
 patterns: 
  [{begin: /^=/,
    captures: {0 => {name: "punctuation.definition.comment.mod_perl"}},
    end: "^=cut",
    name: "comment.block.documentation.apache-config.mod_perl"},
   {match: 
     /\b(?<_1>PerlAddVar|PerlConfigRequire|PerlLoadModule|PerlModule|PerlOptions|PerlPassEnv|PerlPostConfigRequire|PerlRequire|PerlSetEnv|PerlSetVar|PerlSwitches|SetHandler|PerlOpenLogsHandler|PerlPostConfigHandler|PerlChildInitHandler|PerlChildExitHandler|PerlPreConnectionHandler|PerlProcessConnectionHandler|PerlInputFilterHandler|PerlOutputFilterHandler|PerlSetInputFilter|PerlSetOutputFilter|PerlPostReadRequestHandler|PerlTransHandler|PerlMapToStorageHandler|PerlInitHandler|PerlHeaderParserHandler|PerlAccessHandler|PerlAuthenHandler|PerlAuthzHandler|PerlTypeHandler|PerlFixupHandler|PerlResponseHandler|PerlLogHandler|PerlCleanupHandler|PerlInterpStart|PerlInterpMax|PerlInterpMinSpare|PerlInterpMaxSpare|PerlInterpMaxRequests|PerlInterpScope|PerlTrace)\b/,
    name: "support.constant.apache-config.mod_perl"},
   {match: 
     /\b(?<_1>PerlHandler|PerlScript|PerlSendHeader|PerlSetupEnv|PerlTaintCheck|PerlWarn|PerlFreshRestart)\b/,
    name: "support.constant.apache-config.mod_perl_1.mod_perl"},
   {begin: /^\s*(?<_1>(?<_2><)(?<_3>Perl)(?<_4>>))/,
    beginCaptures: 
     {1 => {name: "meta.tag.apache-config"},
      2 => {name: "punctuation.definition.tag.apache-config"},
      3 => {name: "entity.name.tag.apache-config"},
      4 => {name: "punctuation.definition.tag.apache-config"}},
    end: "^\\s*((</)(Perl)(>))",
    endCaptures: 
     {1 => {name: "meta.tag.apache-config"},
      2 => {name: "punctuation.definition.tag.apache-config"},
      3 => {name: "entity.name.tag.apache-config"},
      4 => {name: "punctuation.definition.tag.apache-config"}},
    name: "meta.perl-section.apache-config.mod_perl",
    patterns: [{include: "source.perl"}]},
   {include: "source.apache-config"}],
 scopeName: "source.apache-config.mod_perl",
 uuid: "6A616B03-1053-49BF-830F-0F4E63DB2447"}
