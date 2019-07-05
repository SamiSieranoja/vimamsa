# Encoding: UTF-8

{fileTypes: ["pom.xml"],
 keyEquivalent: "^~M",
 name: "Maven POM",
 patterns: 
  [{include: "#profiles"}, {include: "#pom-body"}, {include: "#maven-xml"}],
 repository: 
  {build: 
    {patterns: 
      [{begin: /(?<_1><)(?<_2>build)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.build.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(build)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.build.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.build.xml.pom",
        patterns: 
         [{include: "#plugins"},
          {include: "#extensions"},
          {include: "#maven-xml"}]}]},
   dependencies: 
    {patterns: 
      [{begin: /(?<_1><)(?<_2>dependencies)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.dependencies.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(dependencies)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.dependencies.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.dependencies.xml.pom",
        patterns: [{include: "#dependency"}, {include: "#maven-xml"}]}]},
   dependency: 
    {patterns: 
      [{begin: /(?<_1><)(?<_2>dependency)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.dependency.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(dependency)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.dependency.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.dependency.xml.pom",
        patterns: 
         [{begin: /(?<=<artifactId>)/,
           end: "(?=</artifactId>)",
           name: "meta.dependency-id.xml.pom"},
          {include: "#maven-xml"}]}]},
   distributionManagement: 
    {patterns: 
      [{begin: 
         /(?<_1><)(?<_2>distributionManagement)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.distributionManagement.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(distributionManagement)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.distributionManagement.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.distributionManagement.xml.pom",
        patterns: [{include: "#maven-xml"}]}]},
   extension: 
    {patterns: 
      [{begin: /(?<_1><)(?<_2>extension)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.extension.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(extension)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.extension.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.extension.xml.pom",
        patterns: 
         [{begin: /(?<=<artifactId>)/,
           end: "(?=</artifactId>)",
           name: "meta.extension-id.xml.pom"},
          {include: "#maven-xml"}]}]},
   extensions: 
    {patterns: 
      [{begin: /(?<_1><)(?<_2>extensions)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.extensions.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(extensions)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.extensions.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.extensions.xml.pom",
        patterns: [{include: "#extension"}, {include: "#maven-xml"}]}]},
   :"groovy-plugin" => 
    {patterns: 
      [{begin: 
         /(?<_1>(?<_2><)(?<_3>artifactId)\s*(?<_4>>)(?!<\s*\/\k<_2>\s*>))(?<_5>groovy-maven-plugin)(?<_6>(?<_7><\/)(?<_8>artifactId)\s*(?<_9>>)(?!<\s*\/\k<_2>\s*>))/,
        beginCaptures: 
         {0 => {name: "meta.groovy-plugin.identifier.xml.pom"},
          1 => {name: "meta.tag.artifactId.begin.xml.pom"},
          2 => {name: "punctuation.definition.tag.xml.pom"},
          3 => {name: "entity.name.tag.xml.pom"},
          4 => {name: "punctuation.definition.tag.xml.pom"},
          5 => {name: "meta.plugin-id.xml.pom"},
          6 => {name: "meta.tag.artifactId.begin.xml.pom"},
          7 => {name: "punctuation.definition.tag.xml.pom"},
          8 => {name: "entity.name.tag.xml.pom"},
          9 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(?=</plugin>)",
        name: "meta.plugin.groovy-plugin.xml.pom",
        patterns: 
         [{begin: /(?<_1><)(?<_2>source)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
           beginCaptures: 
            {0 => {name: "meta.tag.plugin.begin.xml.pom"},
             1 => {name: "punctuation.definition.tag.xml.pom"},
             2 => {name: "entity.name.tag.xml.pom"},
             3 => {name: "punctuation.definition.tag.xml.pom"}},
           contentName: "source.groovy",
           end: "(</)(source)\\s*(>)(?!<\\s*/\\2\\s*>)",
           endCaptures: 
            {0 => {name: "meta.tag.plugin.end.xml.pom"},
             1 => {name: "punctuation.definition.tag.xml.pom"},
             2 => {name: "entity.name.tag.xml.pom"},
             3 => {name: "punctuation.definition.tag.xml.pom"}},
           name: "meta.source.groovy.xml.pom",
           patterns: [{include: "source.groovy"}]},
          {include: "#maven-xml"}]}]},
   :"maven-xml" => 
    {patterns: 
      [{begin: /\${/,
        beginCaptures: 
         {0 => {name: "punctuation.definition.variable.begin.xml.pom"}},
        end: "}",
        endCaptures: 
         {0 => {name: "punctuation.definition.variable.begin.xml.pom"}},
        name: "variable.other.expression.xml.pom"},
       {include: "text.xml"}]},
   plugin: 
    {patterns: 
      [{begin: /(?<_1><)(?<_2>plugin)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.plugin.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(plugin)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.plugin.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.plugin.xml.pom",
        patterns: 
         [{include: "#groovy-plugin"},
          {begin: /(?<=<artifactId>)/,
           end: "(?=</artifactId>)",
           name: "meta.plugin-id.xml.pom"},
          {include: "#maven-xml"}]}]},
   plugins: 
    {patterns: 
      [{begin: /(?<_1><)(?<_2>plugins)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.plugins.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(plugins)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.plugins.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.plugins.xml.pom",
        patterns: [{include: "#plugin"}, {include: "#maven-xml"}]}]},
   :"pom-body" => 
    {patterns: 
      [{include: "#dependencies"},
       {include: "#repositories"},
       {include: "#build"},
       {include: "#reporting"},
       {include: "#distributionManagement"},
       {include: "#properties"},
       {include: "#maven-xml"}]},
   profile: 
    {patterns: 
      [{begin: /(?<_1><)(?<_2>profile)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.profile.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(profile)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.profile.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.profile.xml.pom",
        patterns: 
         [{begin: /(?<=<id>)/,
           end: "(?=</id>)",
           name: "meta.profile-id.xml.pom"},
          {include: "#pom-body"}]}]},
   profiles: 
    {patterns: 
      [{begin: /(?<_1><)(?<_2>profiles)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.profiles.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(profiles)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.profiles.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.profiles.xml.pom",
        patterns: [{include: "#profile"}]}]},
   properties: 
    {patterns: 
      [{begin: /(?<_1><)(?<_2>properties)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.properties.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(properties)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.properties.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.properties.xml.pom",
        patterns: 
         [{begin: /(?<_1><)(?<_2>\w+)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
           beginCaptures: 
            {0 => {name: "meta.tag.property.begin.xml.pom"},
             1 => {name: "punctuation.definition.tag.xml.pom"},
             2 => {name: "entity.name.tag.xml.pom"},
             3 => {name: "punctuation.definition.tag.xml.pom"}},
           end: "(</)(\\w+)\\s*(>)(?!<\\s*/\\2\\s*>)",
           endCaptures: 
            {0 => {name: "meta.tag.property.end.xml.pom"},
             1 => {name: "punctuation.definition.tag.xml.pom"},
             2 => {name: "entity.name.tag.xml.pom"},
             3 => {name: "punctuation.definition.tag.xml.pom"}},
           name: "meta.property.xml.pom"},
          {include: "#maven-xml"}]}]},
   reporting: 
    {patterns: 
      [{begin: /(?<_1><)(?<_2>reporting)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.reporting.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(reporting)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.reporting.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.reporting.xml.pom",
        patterns: [{include: "#plugins"}, {include: "#maven-xml"}]}]},
   repositories: 
    {patterns: 
      [{begin: /(?<_1><)(?<_2>repositories)\s*(?<_3>>)(?!<\s*\/\k<_2>\s*>)/,
        beginCaptures: 
         {0 => {name: "meta.tag.repositories.begin.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        end: "(</)(repositories)\\s*(>)(?!<\\s*/\\2\\s*>)",
        endCaptures: 
         {0 => {name: "meta.tag.repositories.end.xml.pom"},
          1 => {name: "punctuation.definition.tag.xml.pom"},
          2 => {name: "entity.name.tag.xml.pom"},
          3 => {name: "punctuation.definition.tag.xml.pom"}},
        name: "meta.repositories.xml.pom",
        patterns: [{include: "#maven-xml"}]}]}},
 scopeName: "text.xml.pom",
 uuid: "FF85557D-4A93-4CD0-954C-DB74F36A27D8"}
