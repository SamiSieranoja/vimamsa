# Encoding: UTF-8

{
  fileTypes: ['txt'],
  name: 'TXT',
  patterns: [
    { name: 'entity.name.section.asciidoc',
      match: /^=+.*/, },
    { name: 'meta.tag.email.asciidoc',
      match: /(\w(\w|[.-])*)@(\w|[.-])*[0-9A-Za-z_.]/ },
      
    { name: 'markup.h1',
      match: /^◼[^◼].*/ },
      
     { name: 'markup.h2',
      match: /^◼◼[^◼].*/ },
      
     { name: 'markup.h3',
      match: /^◼◼◼[^◼].*/ },
      
      { name: 'markup.h4',
      match: /^◼◼◼◼[^◼].*/ },
      
     { name: 'page.title',
      match: /^❙.*❙/ },
      { name: 'text.bold',
      match: /(?<=[◦⦁]).+(?=[◦⦁])/ },
     
     { name: 'text.date',
      match: /^(\d\d\.\d\d\.\d\d\d\d|\d\d\d\d-\d\d-\d\d)/ },
      

    { name: 'keyword.other.asciidoc',
      match: /TODO|FIXME|XXX|ZZZ/ },
    { name: 'constant.character.backslash.asciidoc',
      match: /\\/ },
    { name: 'markup.underline.link.asciidoc',
      match: /(http|https|ftp|file|irc):\/\/[^|\s]*(\w|\/)/ },
     { name: 'markup.link',
      match: /⟦.*⟧/ },
     
      
      
  ],
  repository: {
  },
  scopeName: 'text.plain.txt',
}
