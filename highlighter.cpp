
#include "main_window.h"
#include "highlighter.h"
#include "globals.h"


Highlighter::Highlighter(QTextDocument *parent) : QSyntaxHighlighter(parent) {
}

void Highlighter::highlightBlock(const QString &text) {

  if(!RTEST(rb_highlight)) {return;}
  if(c_te->hl == NULL) {return;}

  int blocknum = currentBlock().blockNumber();

  VALUE linetags = rb_hash_lookup(rb_highlight, INT2NUM(blocknum));
  
    // QTextCharFormat *newfmt = new QTextCharFormat();
    // newfmt->setFontWeight(QFont::Bold);


  if (RTEST(linetags)) {
    for (int i = 0; i < RARRAY_LEN(linetags); i++) {
      VALUE hv = rb_ary_entry(linetags, i);
      int startpos = NUM2INT(rb_ary_entry(hv, 0));
      int endpos = NUM2INT(rb_ary_entry(hv, 1));
      int format = NUM2INT(rb_ary_entry(hv, 2));
      int length = endpos - startpos + 1;
      // printf("%d ",format);
       // printf("startpos:%d length:%d  format:%d\n",startpos,endpos,format);
       
       
      setFormat(startpos, length, *(g_editor->textFormats[format]));
      
      // setFormat(startpos, length, *newfmt);
      
               // qDebug()  << "line no:" << currentBlock().blockNumber() << " hashv:" << RTEST(hv);
    }
  }
  // printf("\n");
  return;
  // For reference:
  // setCurrentBlockState(0);

  // int startIndex = 0;
  // if (previousBlockState() != 1)
  // startIndex = commentStartExpression.indexIn(text);

  // while (startIndex >= 0) {
  // int endIndex = commentEndExpression.indexIn(text, startIndex);
  // int commentLength;
  // if (endIndex == -1) {
  // setCurrentBlockState(1);
  // commentLength = text.length() - startIndex;
  // } else {
  // commentLength = endIndex - startIndex + commentEndExpression.matchedLength();
  // }
  // setFormat(startIndex, commentLength, multiLineCommentFormat);
  // startIndex = commentStartExpression.indexIn(text, startIndex + commentLength);
  // }
}
//! [11]
