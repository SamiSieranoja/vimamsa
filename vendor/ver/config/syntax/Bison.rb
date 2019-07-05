# Encoding: UTF-8

{fileTypes: ["y"],
 name: "Bison",
 patterns: 
  [{begin: /^%\{/,
    contentName: "source.c",
    end: "%\\}",
    name: "meta.prologue.bison",
    patterns: [{include: "source.c"}]},
   {begin: /^(?!%%$)/, end: "^(?=%%$)", name: "meta.declarations.bison"},
   {begin: /^%%$/,
    end: "$.^",
    patterns: 
     [{begin: /^(?!%%$)/,
       contentName: "meta.rules.bison",
       end: "^(?=%%$)",
       patterns: [{include: "source.c"}]},
      {begin: /^%%$/,
       contentName: "meta.epilogue.bison",
       end: "$.^",
       patterns: 
        [{begin: /^/,
          end: "$.^",
          name: "source.c",
          patterns: [{include: "source.c"}]}]}]}],
 scopeName: "source.bison",
 uuid: "1AA6D027-D1AF-4868-951D-1634BD88D910"}
