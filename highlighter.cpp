/****************************************************************************
**
** Copyright (C) 2013 Digia Plc and/or its subsidiary(-ies).
** Contact: http://www.qt-project.org/legal
**
** This file is part of the examples of the Qt Toolkit.
**
** $QT_BEGIN_LICENSE:BSD$
** You may use this file under the terms of the BSD license as follows:
**
** "Redistribution and use in source and binary forms, with or without
** modification, are permitted provided that the following conditions are
** met:
**   * Redistributions of source code must retain the above copyright
**     notice, this list of conditions and the following disclaimer.
**   * Redistributions in binary form must reproduce the above copyright
**     notice, this list of conditions and the following disclaimer in
**     the documentation and/or other materials provided with the
**     distribution.
**   * Neither the name of Digia Plc and its Subsidiary(-ies) nor the names
**     of its contributors may be used to endorse or promote products derived
**     from this software without specific prior written permission.
**
**
** THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
** "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
** LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
** A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
** OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
** SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
** LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
** DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
** THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
** (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
** OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE."
**
** $QT_END_LICENSE$
**
****************************************************************************/

#include "highlighter.h"

//! [0]
Highlighter::Highlighter(QTextDocument *parent) : QSyntaxHighlighter(parent) {
  HighlightingRule rule;

  //    keywordFormat.setForeground(Qt::blue);
  keywordFormat.setForeground(QColor("#b58900"));
//  keywordFormat.setForeground(QColor("#eeeeee"));
  keywordFormat.setFontWeight(QFont::Bold);
//  keywordFormat.setFontWeight(QFont::Black);

  //! [2]
  classFormat.setFontWeight(QFont::Bold);
  classFormat.setForeground(Qt::darkMagenta);
  rule.pattern = QRegExp("\\bQ[A-Za-z]+\\b");
  rule.format = classFormat;
  highlightingRules.append(rule);
  //! [2]

  //! [3]
  singleLineCommentFormat.setForeground(Qt::red);
  rule.pattern = QRegExp("//[^\n]*");
  rule.format = singleLineCommentFormat;
  highlightingRules.append(rule);

  multiLineCommentFormat.setForeground(Qt::red);
  //! [3]

  //! [4]
  //  quotationFormat.setForeground(Qt::darkGreen);

  quotationFormat.setForeground(QColor("#2aa198"));
  // Comment: quotationFormat.setForeground(QColor("#586e75"));

  rule.pattern = QRegExp("\".*\"");
  rule.format = quotationFormat;
  highlightingRules.append(rule);
  //! [4]

  //! [5]
  // functionFormat.setFontItalic(true);
  functionFormat.setForeground(QColor("#859900"));
  //  rule.pattern = QRegExp("\\b[A-Za-z0-9_]+(?=\\()");
  //  rule.format = functionFormat;
  //  highlightingRules.append(rule);
  //  //! [5]

  //! [6]
  commentStartExpression = QRegExp("/\\*");
  commentEndExpression = QRegExp("\\*/");
}
//! [6]

//! [7]
void Highlighter::highlightBlock(const QString &text) {
  // QTextBlock currentBlock()

//  VALUE highlight = rb_eval_string("$highlight");
  VALUE highlight = rb_eval_string("$buffer.highlights");
  VALUE linetags = rb_hash_lookup(highlight, INT2NUM(currentBlock().blockNumber()));

  if (RTEST(linetags)) {
    for (int i = 0; i < RARRAY_LEN(linetags); i++) {
      VALUE hv = rb_ary_entry(linetags, i);
      int startpos = NUM2INT(rb_ary_entry(hv, 0));
      int endpos = NUM2INT(rb_ary_entry(hv, 1));
      int format = NUM2INT(rb_ary_entry(hv, 2));
      int length = endpos - startpos;
      if (format == 1) {
        setFormat(startpos, length, multiLineCommentFormat);
      }
      if (format == 2) {
        setFormat(startpos, length, quotationFormat);
      }
      if (format == 3) {
        setFormat(startpos, length, keywordFormat);
      }
      if (format == 4) {
        setFormat(startpos, length, functionFormat);
      }
     
//          qDebug()  << "line no:" << currentBlock().blockNumber() << " hashv:" << RTEST(hv);
    }
//    qDebug() << text;
  }
  return;
  //! [7] //! [8]
  setCurrentBlockState(0);
  //! [8]

  //! [9]
  int startIndex = 0;
  if (previousBlockState() != 1)
    startIndex = commentStartExpression.indexIn(text);

  //! [9] //! [10]
  while (startIndex >= 0) {
    //! [10] //! [11]
    int endIndex = commentEndExpression.indexIn(text, startIndex);
    int commentLength;
    if (endIndex == -1) {
      setCurrentBlockState(1);
      commentLength = text.length() - startIndex;
    } else {
      commentLength = endIndex - startIndex + commentEndExpression.matchedLength();
    }
    setFormat(startIndex, commentLength, multiLineCommentFormat);
    startIndex = commentStartExpression.indexIn(text, startIndex + commentLength);
  }
}
//! [11]
