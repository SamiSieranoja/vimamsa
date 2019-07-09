# Encoding: UTF-8

{comment: "Flash JavaScript Syntax: Version 1.0",
 fileTypes: ["jsfl"],
 foldingStartMarker: 
  /^.*\bfunction\s*(?<_1>\w+\s*)?\([^\)]*\)(?<_2>\s*\{[^\}]*)?\s*$/,
 foldingStopMarker: /^\s*\}/,
 keyEquivalent: "^~J",
 name: "JSFL",
 patterns: 
  [{match: 
     /\b(?<_1>alert|confirm|prompt|configureEffect|executeEffect|removeEffect|activate|configureTool|deactivate|keyDown|keyUp|mouseDoubleClick|mouseDown|mouseMove|mouseUp|notifySettingsChanged|setCursor)\b/,
    name: "support.function.global.jsfl"},
   {match: 
     /\b(?<_1>Rectangle|XMLUI|Mat(?<_2>h|rix)|comp(?<_3>ilerErrors|onentsPanel)|BitmapI(?<_4>nstance|tem)|S(?<_5>hape|ymbolI(?<_6>nstance|tem)|creen(?<_7>Outline)?|troke|oundItem)|HalfEdge|outputPanel|drawingLayer|Co(?<_8>ntour|mp(?<_9>iledClipInstance|onentInstance))|T(?<_10>imeline|ool(?<_11>s|Obj)|ext(?<_12>Run|Attrs)?)|I(?<_13>nstance|tem)|Oval|Document|P(?<_14>a(?<_15>th|rameter)|roject(?<_16>Item)?)|f(?<_17>o(?<_18>ntItem|lderItem)|l)|E(?<_19>dge|ffect|lement)|V(?<_20>ideoItem|ertex)|library|actionsPanel|F(?<_21>il(?<_22>ter|l)|rame|Lfile)|Layer)\b/,
    name: "support.object.jsfl"},
   {match: 
     /\b(?<_1>s(?<_2>h(?<_3>iftIsDown|ortcut|a(?<_4>dowColor|pe(?<_5>TweenBlend|Fill)))|ymbolType|c(?<_6>al(?<_7>ingGrid(?<_8>Rect)?|e(?<_9>X|Y|Type))|r(?<_10>iptURI|ollable|een(?<_11>s|Outline)))|t(?<_12>yle|art(?<_13>Frame|Angle)|r(?<_14>okeHinting|ength))|i(?<_15>ze|lent)|ou(?<_16>nd(?<_17>Sync|Name|Effect|L(?<_18>ibraryItem|oop(?<_19>Mode)?))|rce(?<_20>File(?<_21>Path)?|LibraryName|AutoUpdate))|pace|elect(?<_22>ion(?<_23>Start|End)?|ed|able)|kew(?<_24>X|Y)|a(?<_25>turation|mpleRate))|h(?<_26>i(?<_27>d(?<_28>den|eObject)|ghlightColor)|ue|eight|Pixels|a(?<_29>sCustomEase|tchThickness))|n(?<_30>extScreen|Pts|ame)|Math|c(?<_31>h(?<_32>ildScreens|aracter(?<_33>s|Spacing|Position))|tlIsDown|o(?<_34>n(?<_35>t(?<_36>ours|actSensitiveSelection|rast)|vertStereoToMono|fig(?<_37>Directory|URI))|lor(?<_38>Red(?<_39>Percent|Amount)|Green(?<_40>Percent|Amount)|Mode|Blue(?<_41>Percent|Amount)|A(?<_42>lpha(?<_43>Percent|Amount)|rray))?|mp(?<_44>ilerErrors|onentsPanel|ressionType))|ur(?<_45>ve|rent(?<_46>Screen|Timeline|PublishProfile|Frame|Layer))|losePath|a(?<_47>cheAsBitmap|tegory|pType)|reateNew(?<_48>TemplateList|DocList(?<_49>Type)?))|t(?<_50>hickness|y(?<_51>pe)?|imeline(?<_52>s)?|o(?<_53>ol(?<_54>s|Objs)|p(?<_55>RightRadius|LeftRadius)?)|ext(?<_56>Runs|Type|Attrs)|ween(?<_57>Type|Easing)|a(?<_58>rget|bIndex)|ransform(?<_59>X|Y)|x)|i(?<_60>s(?<_61>RectangleObject|Group|Missing|OvalObject|DrawingObject|Line)|n(?<_62>stance(?<_63>Name|Type)|ner(?<_64>Radius)?|terior|de(?<_65>nt|x))|conID|t(?<_66>em(?<_67>s|Type|URI)|alic)|d)|zoomFactor|o(?<_68>ut(?<_69>putPanel|line)|verflow|rientation|bjectDrawingMode)|d(?<_70>is(?<_71>tance|playName)|o(?<_72>c(?<_73>Class|uments)|tS(?<_74>ize|pace))|uration|e(?<_75>scription|nsity|pth|faultItem)|ash(?<_76>1|2)|rawingLayer)|u(?<_77>se(?<_78>XMLToUI|SingleEaseCurve|Imported(?<_79>MP3Quality|JPEGQuality)|DeviceFonts)|rl)|j(?<_80>iggle|oinType)|p(?<_81>os(?<_82>ition|Array)|ublishProfile(?<_83>s)?|en(?<_84>DownLoc|Loc)|a(?<_85>ckagePaths|t(?<_86>h|tern)|r(?<_87>ent(?<_88>Screen|Layer)|ameters))|r(?<_89>ojectURI|evScreen))|e(?<_90>n(?<_91>dAngle|abled)|dges|ffect(?<_92>s|Name)|lement(?<_93>s|Type)|mbed(?<_94>Ranges|dedCharacters))|v(?<_95>i(?<_96>sible|deoType|ewMatrix)|er(?<_97>sion|tices|bose)|Pixels|a(?<_98>lue(?<_99>Type)?|ria(?<_100>tion|bleName)))|knockout|quality|f(?<_101>i(?<_102>l(?<_103>ters|lColor)|rstFrame)|o(?<_104>ntRenderingMode|calPoint|rceSimple)|ace|rame(?<_105>s|Rate|Count))|w(?<_106>idth|ave(?<_107>Height|Length))|l(?<_108>i(?<_109>stIndex|n(?<_110>e(?<_111>Spacing|Type|arRGB)|kage(?<_112>BaseClass|ClassName|I(?<_113>dentifier|mportForRS)|URL|Export(?<_114>InFirstFrame|For(?<_115>RS|AS))))|vePreview|brary(?<_116>Item)?)|o(?<_117>ck(?<_118>ed|Flag)|op)|e(?<_119>ngth|tterSpacing|ft(?<_120>Margin)?)|a(?<_121>yer(?<_122>s|Count|Type)?|belType))|a(?<_123>s(?<_124>3(?<_125>StrictMode|Dialect|PackagePaths|ExportFrame|WarningsMode|AutoDeclare)|Version)|n(?<_126>tiAlias(?<_127>Sharpness|Thickness)|gle)|c(?<_128>cName|ti(?<_129>on(?<_130>sPanel|Script)|ve(?<_131>Tool|Effect)))|uto(?<_132>Expand|Kern|Label)|l(?<_133>tIsDown|i(?<_134>asText|gnment)|lowSmoothing))|r(?<_135>ightMargin|o(?<_136>tat(?<_137>ion|e)|otScreen)|enderAsHTML)|groupName|xmlui|m(?<_138>iterLimit|o(?<_139>tionTween(?<_140>Rotate(?<_141>Times)?|S(?<_142>ync|nap|cale)|OrientToPath)|useIsDown)|a(?<_143>trix|xCharacters)|ruRecentFileList(?<_144>Type)?)|b(?<_145>it(?<_146>s|Rate)|o(?<_147>ttom(?<_148>RightRadius|LeftRadius)|ld|rder)|uttonTracking|l(?<_149>ur(?<_150>X|Y)|endMode)|ackgroundColor|r(?<_151>ightness|eakAtCorners)))\b/,
    name: "support.property.jsfl"},
   {match: 
     /\b(?<_1>s(?<_2>how(?<_3>TransformHandles|IdleMessage|PIControl|LayerMasking)|ynchronize(?<_4>DocumentWithHeadVersion|WithHeadVersion)|napPoint|caleSelection|traightenSelection|p(?<_5>litEdge|ace)|e(?<_6>t(?<_7>RectangleObjectProperty|M(?<_8>obileSettings|e(?<_9>nuString|tadata))|B(?<_10>its|lendMode)|S(?<_11>cr(?<_12>iptAssistMode|eenProperty)|troke(?<_13>S(?<_14>tyle|ize)|Color)?|elect(?<_15>ion(?<_16>Rect|Bounds)?|ed(?<_17>Screens|Frames|Layers)))|C(?<_18>o(?<_19>ntrol(?<_20>ItemElement(?<_21>s)?)?|lor)|u(?<_22>stom(?<_23>Stroke|Ease|Fill)|r(?<_24>sor|rentScreen)))|T(?<_25>ool(?<_26>Name|Tip)|ext(?<_27>Rectangle|S(?<_28>tring|election)|Attr)?|ransformationPoint)|I(?<_29>nstance(?<_30>Brightness|Tint|Alpha)|con|temProperty)|O(?<_31>ptionsFile|valObjectProperty)|P(?<_32>I|ersistentData|layerVersion)|E(?<_33>nabled|lement(?<_34>TextAttr|Property))|Visible|F(?<_35>il(?<_36>ter(?<_37>s|Property)|lColor)|rameProperty)|L(?<_38>ocation|ayerProperty)|A(?<_39>ctiveWindow|ttributes|lignToDocument))?|lect(?<_40>None|Tool|Item|Element|All(?<_41>Frames)?))|kewSelection|wap(?<_42>StrokeAndFill|Element)|ave(?<_43>Document(?<_44>As)?|A(?<_45>ndCompact|Version(?<_46>OfDocument)?|ll))?|moothSelection)|has(?<_47>Selection|Data|PersistentData)|n(?<_48>otifySettingsChanged|ew(?<_49>Contour|Path|Folder))|c(?<_50>hangeFilterOrder|o(?<_51>n(?<_52>strainPoint|catMatrix|vert(?<_53>To(?<_54>BlankKeyframes|Symbol|CompiledClip|Keyframes)|LinesToFills)|fi(?<_55>rm|gure(?<_56>Tool|Effect)))|py(?<_57>Motion(?<_58>AsAS3)?|ScreenFromFile|Frames)?)|u(?<_59>tFrames|rveTo|bicCurveTo)|l(?<_60>ip(?<_61>C(?<_62>opy(?<_63>String)?|ut)|Paste)|ose(?<_64>Document|Project|All(?<_65>PlayerDocuments)?)?|ear(?<_66>Keyframes|Frames)?)|an(?<_67>Revert|cel|SaveAVersion|Test(?<_68>Movie|Scene|Project)?|Publish(?<_69>Project)?|EditSymbol)|r(?<_70>op|eate(?<_71>MotionTween|Document|Project|Folder)))|t(?<_72>est(?<_73>Movie|Scene|Project)?|ra(?<_74>nsformSelection|ce(?<_75>Bitmap)?))|i(?<_76>n(?<_77>sert(?<_78>BlankKeyframe|Screen|NestedScreen|Item|Keyframe|Frames)|tersect|vertMatrix)|temExists|mport(?<_79>SWF|PublishProfile|EmbeddedSWF|File))|op(?<_80>timizeCurves|en(?<_81>Script|Document|Project))|d(?<_82>is(?<_83>tribute(?<_84>ToLayers)?|able(?<_85>OtherFilters|Filter|AllFilters))|o(?<_86>cumentHasData|wnloadLatestVersion)|uplicate(?<_87>S(?<_88>c(?<_89>ene|reen)|election)|Item|PublishProfile)|e(?<_90>lete(?<_91>S(?<_92>c(?<_93>ene|reen)|election)|Item|PublishProfile|E(?<_94>nvelope|dge)|Layer)|activate)|rawPath)|u(?<_95>n(?<_96>Group|ion|lockAllElements)|pdateItem)|p(?<_97>ointDistance|u(?<_98>nch|blish(?<_99>Project)?)|aste(?<_100>Motion|Frames)|rompt)|e(?<_101>n(?<_102>terEditMode|d(?<_103>Draw|Edit|Frame)|able(?<_104>ImmediateUpdates|PIControl|Filter|AllFilters))|dit(?<_105>Scene|Item)|x(?<_106>i(?<_107>sts|tEditMode)|p(?<_108>ort(?<_109>SW(?<_110>C|F)|P(?<_111>NG|ublishProfile))|andFolder)|ecuteEffect))|key(?<_112>Down|Up)|quit|fi(?<_113>nd(?<_114>ItemIndex|ObjectInDocBy(?<_115>Name|Type)|Document(?<_116>Index|DOM)|ProjectItem|LayerIndex)|leExists)|write|li(?<_117>stFolder|neTo)|a(?<_118>c(?<_119>cept|tivate)|dd(?<_120>MotionGuide|New(?<_121>Rectangle|Scene|Text|Item|Oval|PublishProfile|L(?<_122>ine|ayer))|Cu(?<_123>rve|bicCurve)|Item(?<_124>ToDocument)?|Data(?<_125>To(?<_126>Selection|Document))?|Point|EventListener|Fil(?<_127>ter|e))|l(?<_128>ign|ert|lowScreens)|rrange)|r(?<_129>otateSelection|unScript|e(?<_130>set(?<_131>RectangleObject|Transformation|OvalObject|PackagePaths|AS3PackagePaths)|name(?<_132>Sc(?<_133>ene|reen)|Item|PublishProfile)|order(?<_134>Scene|Layer)|placeSelectedText|ver(?<_135>seFrames|t(?<_136>ToLastVersion|Document(?<_137>ToLastVersion)?)?)|load(?<_138>Tools|Effects)?|ad|move(?<_139>Item|Data(?<_140>From(?<_141>Selection|Document))?|PersistentData|E(?<_142>ventListener|ffect)|F(?<_143>ilter|rames)|AllFilters)?))|g(?<_144>et(?<_145>M(?<_146>o(?<_147>dificationDate(?<_148>Obj)?|bileSettings)|etadata)|B(?<_149>its|lendMode)|S(?<_150>criptAssistMode|ize|elect(?<_151>ionRect|ed(?<_152>Screens|Text|Items|Frames|Layers)))|HalfEdge|Next|C(?<_153>ontrol(?<_154>ItemElement)?|ustom(?<_155>Stroke|Ease|Fill)|lassForObject|reationDate(?<_156>Obj)?)|T(?<_157>imeline|ext(?<_158>String|Attr)?|ransformationPoint)|Item(?<_159>Type|Property)|OppositeHalfEdge|D(?<_160>ocumentDOM|ata(?<_161>FromDocument)?)|P(?<_162>ersistentData|layerVersion|r(?<_163>oject|ev))|E(?<_164>nabled|dge|lement(?<_165>TextAttr|Property))|V(?<_166>isible|ertex)|KeyDown|F(?<_167>ilters|rameProperty)|LayerProperty|A(?<_168>ttributes|ppMemoryInfo|lignToDocument))?|roup)|xmlPanel|m(?<_169>o(?<_170>use(?<_171>Move|Click|D(?<_172>o(?<_173>ubleClick|wn)|blClk)|Up)|ve(?<_174>S(?<_175>creen|elect(?<_176>ionBy|edBezierPointsBy))|To(?<_177>Folder)?))|a(?<_178>tch|pPlayerURL|keShape))|b(?<_179>egin(?<_180>Draw|Edit|Frame)|r(?<_181>owseForF(?<_182>ileURL|olderURL)|eakApart)))\b/,
    name: "support.function.jsfl"},
   {include: "source.js"}],
 scopeName: "source.js.jsfl",
 uuid: "7195838E-5F71-407E-8B10-98265273C62A"}