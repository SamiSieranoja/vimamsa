
#include "main_window.h"
#include "highlighter.h"

extern Editor *g_editor;

Highlighter::Highlighter(QTextDocument *parent) : QSyntaxHighlighter(parent) {
}

void Highlighter::highlightBlock(const QString &text) {
  // QTextBlock currentBlock()
  // https://silverhammermba.github.io/emberb/c/
  // VALUE gv = rb_gv_get("$buffer");
  // VALUE highlight = rb_eval_string("$buffer.highlights");
  if(!RTEST(rb_highlight)) {return;}
  
  VALUE linetags = rb_hash_lookup(rb_highlight, INT2NUM(currentBlock().blockNumber()));
  // printf("g_editor->textFormats

  if (RTEST(linetags)) {
    for (int i = 0; i < RARRAY_LEN(linetags); i++) {
      VALUE hv = rb_ary_entry(linetags, i);
      int startpos = NUM2INT(rb_ary_entry(hv, 0));
      int endpos = NUM2INT(rb_ary_entry(hv, 1));
      int format = NUM2INT(rb_ary_entry(hv, 2));
      int length = endpos - startpos + 1;
      // printf("%d ",format);
      setFormat(startpos, length, *(g_editor->textFormats[format]));

      //          qDebug()  << "line no:" << currentBlock().blockNumber() << " hashv:" << RTEST(hv);
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
