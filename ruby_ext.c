

#include "ruby_ext.h"

extern "C" {

int qt_process_deltas(); 
int center_where_cursor(); 


#include <stdio.h>
#include <ruby/defines.h>
#include <ruby/thread.h>

VALUE method_qt_quit(VALUE self) { _quit = 1; }

VALUE method_open_file_dialog(VALUE self, VALUE path) {
  g_editor->fileOpen(QString(StringValueCStr(path)));
}

VALUE qt_file_saveas(VALUE self, VALUE savepath) {
  g_editor->fileSaveAs(QString(StringValueCStr(savepath)));
}

VALUE method_restart(VALUE self) {
  QProcess::startDetached(QApplication::applicationFilePath());
  exit(12);
}

VALUE method_set_window_title(VALUE self, VALUE new_title) {
  window_title = new QString(StringValueCStr(new_title));
  g_editor->setWindowTitle(*window_title);
}

int center_where_cursor();

_sleep(void *ptr) { QThread::usleep(3000); }

VALUE qt_set_cursor_pos(VALUE self, VALUE BUFID, VALUE cursor_pos);

VALUE qt_update_cursor_pos(VALUE self) {
  // QTextCursor tc = c_te->textCursor();
  // int cursor_pos = c_te->cursor_pos;
}


VALUE qt_trigger_event(VALUE self) {
c_te->new_event = 1;
}


VALUE qt_process_events(VALUE self) {
  app->processEvents();
  
  render_minibuffer(NULL);
  
  qt_process_deltas();
  
  // QTextCursor tc = c_te->textCursor();
  // tc.setPosition(c_te->cursor_pos);
  // tc.setPosition(0);
  // c_te->setTextCursor(tc);
  // c_te->ensureCursorVisible();
 
  if (c_te->new_event == 1) {
    c_te->drawTextCursor();
  }
  c_te->new_event = 0;

  rb_eval_string("$buffer.highlight()");

  c_te->processHighlights();

}

VALUE method_center_where_cursor(VALUE self) {
  center_where_cursor();
  qt_process_events(NULL);
}

VALUE c_startup(VALUE self) {

  printf("Start MAIN LOOP\n");
  QByteArray ba;
  const char *c_str2;

  cpp_init_qt();

  rb_eval_string("vma.start");
  window_title = new QString("Vimamsa");
  return INT2NUM(1);
}


VALUE method_main_loop(VALUE self) {

  while (1) {
    qt_process_events(NULL);
    rb_thread_call_without_gvl(_sleep, NULL, NULL, NULL);
  }
  return INT2NUM(1);
}

/** START This code ripped from ruby string.c **/

#define BEG(no) (regs->beg[(no)])
#define END(no) (regs->end[(no)])
#define STR_ENC_GET(str) rb_enc_from_index(ENCODING_GET(str))

static VALUE scan_once(VALUE str, VALUE pat, long *start_i) {
  VALUE result, match;
  struct re_registers *regs;
  int i;

  if (rb_reg_search(pat, str, *start_i, 0) >= 0) {
    match = rb_backref_get();
    regs = RMATCH_REGS(match);
    if (BEG(0) == END(0)) {
      rb_encoding *enc = STR_ENC_GET(str);
      /*
       * Always consume at least one character of the input string
       */
      if (RSTRING_LEN(str) > END(0))
        *start_i = END(0) + rb_enc_fast_mbclen(RSTRING_PTR(str) + END(0), RSTRING_END(str), enc);
      else
        *start_i = END(0) + 1;
    } else {
      *start_i = END(0);
    }
    if (regs->num_regs == 1
        // TODO multiple matches (regexp groups) not implemented yet
        || regs->num_regs > 1) {

      // START From ruby re.c:rb_reg_nth_match
      long start, end, len;
      struct re_registers *regs;
      int nth = 0;

      if (NIL_P(match))
        return Qnil;
      // match_check(match);
      // ruby_ext.c:100:22: error: ‘match_check’ was not declared in this scope
      // Seems to work fine without

      regs = RMATCH_REGS(match);
      if (nth >= regs->num_regs) {
        return Qnil;
      }
      if (nth < 0) {
        nth += regs->num_regs;
        if (nth <= 0)
          return Qnil;
      }
      start = BEG(nth);
      if (start == -1)
        return Qnil;
      end = END(nth);
      len = end - start;
      // TODO:optimize str_sublen??
      result = INT2NUM(rb_str_sublen(str, start));
      return result;
      // str = rb_str_subseq(RMATCH(match)->str, start, len);
      // OBJ_INFECT(str, match);
      // END FROM ruby re.c:rb_reg_nth_match

      // return rb_reg_nth_match(0, match);
    }
    result = rb_ary_new2(regs->num_regs);
    for (i = 1; i < regs->num_regs; i++) {

      // TODO multiple matches (groups) not implemented yet
      rb_ary_push(result, rb_reg_nth_match(i, match));
    }

    return result;
  }
  return Qnil;
}

/** END of code ripped from ruby string.c **/

/**
 * This does the same as String::Scan, but returns a list of index numbers
 * instead of matched strings.
 *
 * The purpose of this function is to replace the following ruby code with
 * a faster version:
 *
 *         @line_ends = []
 *         i = 0
 *         while true
 *             i = self.index(/\n/,i+1)
 *             break if i == nil
 *             @line_ends << i
 *         end
 *
 ***/
VALUE method_scan_indexes(VALUE self, VALUE str, VALUE pat) {

  // VALUE pat = ""
  VALUE result;
  long start = 0;
  long last = -1, prev = 0;
  char *p = RSTRING_PTR(str);
  long len = RSTRING_LEN(str);
  VALUE ary = rb_ary_new();

  // pat = get_pat(pat, 1);
  if (1) {

    while (!NIL_P(result = scan_once(str, pat, &start))) {
      last = prev;
      prev = start;
      // rb_ary_push(ary, result);
      // rb_ary_push(ary, INT2NUM(start));
      // TODO: if result != Qnil
      // TODO: start gives end of pattern+1? Currently compensating in ruby.
      // rb_ary_push(ary, INT2NUM(rb_str_sublen(str,start)));// TODO:optimize str_sublen
      rb_ary_push(ary, result);
    }
    if (last >= 0)
      rb_reg_search(pat, str, last, 0);
    return ary;
  }
  return ary;
}

VALUE method_render_text(VALUE self, VALUE text, VALUE _pos, VALUE _selection_start, VALUE _reset) {

  // Ignore cursor position change events until rendering is over.

  // textbuf = text;

  int cursor_pos = NUM2INT(_pos);
  int reset_buffer = NUM2INT(_reset);
  int selection_start = NUM2INT(_selection_start);

  render_text(text, cursor_pos, selection_start, reset_buffer);

  return INT2NUM(1);
}

VALUE qt_load_theme(VALUE self, VALUE theme) {
  c_te->loadTheme();
  g_editor->clearTextFormats();
}

int get_visible_area(int &start_pos, int &end_pos) {
  //  QTextCursor cursor = c_te->cursorForPosition(QPoint(0, 0));
  QTextCursor cursor = c_te->cursorForPosition(QPoint(0, 20));
  //  QPoint bottom_right(c_te->viewport()->width() - 1, c_te->viewport()->height() - 1);
  QPoint bottom_right(c_te->viewport()->width() - 1, c_te->viewport()->height() - 20);
  start_pos = cursor.position();
  end_pos = c_te->cursorForPosition(bottom_right).position();
  cursor.setPosition(end_pos, QTextCursor::KeepAnchor);
  qDebug() << "cursor pos:" << cursor.selectedText() << endl;
  printf("Visible range: %d - %d\n", start_pos, end_pos);
  return 0;
}

VALUE rb_get_visible_area() {
  int start_pos;
  int end_pos;
  VALUE range = rb_ary_new();
  get_visible_area(start_pos, end_pos);
  rb_ary_push(range, INT2NUM(start_pos));
  rb_ary_push(range, INT2NUM(end_pos));
  return range;
}
// http://doc.qt.io/qt-5/qabstractslider.html#pageStep-prop
// http://doc.qt.io/qt-5/qplaintextedit.html#cursorRect
// cursorRect: returns a rectangle (in viewport coordinates) that includes the cursor of the text
// edit.

int center_where_cursor() {
  printf("int center_where_cursor() \n");
  int cursorY = c_te->cursorRect().bottom();
  int scrollbar = c_te->verticalScrollBar()->value();
  int offset_y = scrollbar + cursorY - c_te->size().height() / 2;

  //  qDebug() << "cursorY: " << cursorY << "scrollbar:" << scrollbar << " offset_y:" << offset_y
  //  << "size.height:" << c_te->size().height() << endl ;
  // Example: cursorY:  15 scrollbar: 2116  offset_y: 1766 size.height: 730
  c_te->verticalScrollBar()->setValue(offset_y);
}

VALUE page_up() {

  QTextCursor cursor = c_te->cursorForPosition(QPoint(0, 20));
  int offset_y = c_te->verticalScrollBar()->value() - ((int)c_te->size().height() * 0.9);
  if (offset_y < 0) {
    offset_y = 0;
  }

  c_te->verticalScrollBar()->setValue(offset_y);

  cursor = c_te->cursorForPosition(QPoint(0, ((int)(c_te->size().height() * 0.8))));
  int new_cursor_pos = cursor.position() + 1;

  QString evalcmd = QString("$buffer.set_pos(%1);$buffer.jump(BEGINNING_OF_LINE)")
                        .arg(QString::number(new_cursor_pos));
  // BUG: Sometimes cursorForPosition gives position for end of
  // line.$buffer.jump(BEGINNING_OF_LINE) used as quick hack.

  rb_eval_string(evalcmd.toLatin1().data());
  return 0;
}

VALUE page_down() {
  printf("page_down()\n");

  QTextCursor cursor = c_te->cursorForPosition(QPoint(0, 20));
  int offset_y = c_te->verticalScrollBar()->value() + ((int)c_te->size().height() * 0.9);

  //  qDebug() << "scrollbar val:" << c_te->verticalScrollBar()->value() << " height:" <<
  //  c_te->size().height() << "offset:" << offset_y << endl;

  c_te->verticalScrollBar()->setValue(offset_y);

  cursor = c_te->cursorForPosition(QPoint(0, ((int)(c_te->size().height() * 0.2))));
  int new_cursor_pos = cursor.position();

  QString evalcmd = QString("$buffer.set_pos(%1);$buffer.jump(BEGINNING_OF_LINE)")
                        .arg(QString::number(new_cursor_pos));
  rb_eval_string(evalcmd.toLatin1().data());

  return 0;
}

VALUE top_where_cursor() {
  int cursorY = c_te->cursorRect().bottom();
  int offset_y =
      c_te->verticalScrollBar()->value() + cursorY - c_te->size().height() + c_te->size().height();
  c_te->verticalScrollBar()->setValue(offset_y);
  VALUE ret = rb_ary_new();
  return ret;
}

VALUE bottom_where_cursor() {
  int cursorY = c_te->cursorRect().bottom();
  int offset_y = c_te->verticalScrollBar()->value() + cursorY - c_te->size().height();
  c_te->verticalScrollBar()->setValue(offset_y);
  VALUE ret = rb_ary_new();
  return ret;
}

VALUE set_system_clipboard(VALUE self, VALUE text) {
  VALUE ret;
  QClipboard *p_Clipboard = QApplication::clipboard();
  p_Clipboard->setText(StringValueCStr(text));
  ret = INT2NUM(1);
  return ret;
}

VALUE ruby_cpp_function_wrapper(VALUE self, VALUE method_name, VALUE args) {
  VALUE ret;
  switch (NUM2INT(method_name)) {
  case 0:
    ret = pos_to_viewport_coordinates(args);
    break;
  case 1:
    ret = draw_text(args);
    break;
  case 2:
    ret = rb_get_visible_area();
    break;
  case 3:
    center_where_cursor();
    break;
  }
  return ret;
}

VALUE set_qt_style(VALUE self, VALUE style_id) {
  g_editor->setQtStyle(NUM2INT(style_id));
  return INT2NUM(0);
}

VALUE qt_select_window(VALUE self, VALUE item_list, VALUE jump_keys, VALUE callback,
                       VALUE use_filter) {
  select_w = new SelectWindow(g_editor, NUM2INT(use_filter));
  select_w->setItems(item_list, jump_keys);
  select_w->select_callback = rb_intern_str(callback);
  // SelectWindow* select_w = new SelectWindow(parent);
  select_w->resize(500, 700);
  select_w->show();
  return INT2NUM(0);
}

VALUE qt_set_num_columns(VALUE self, VALUE num_columns) {
  g_editor->setNumColumns(NUM2INT(num_columns));
  return INT2NUM(0);
}

VALUE qt_select_window_close(VALUE self, VALUE id) {
  qDebug() << "close window: ";
  if (select_w) {
    qDebug() << "[Y]";
    select_w->close();
  }
  return INT2NUM(0);
}

VALUE qt_select_update_window(VALUE self, VALUE item_list, VALUE jump_keys, VALUE select_callback,
                              VALUE update_callback) {
  select_w = new SelectWindow(g_editor, 1);
  select_w->select_callback = rb_intern_str(select_callback);
  select_w->update_callback = rb_intern_str(update_callback);

  // ID id = rb_to_id(update_callback);
  // ID id = rb_intern_str(update_callback);

  select_w->show();
  select_w->resize(500, 700);
  select_w->updateItemList(item_list);
  return INT2NUM(0);
}

VALUE qt_popup_window(VALUE self, VALUE params) {
  select_w = new SelectWindow(g_editor, params);
  select_w->show();
  // select_w->resize(500, 700);
  return INT2NUM(0);
}

VALUE qt_create_buffer(VALUE self, VALUE id) {
  g_editor->createBuffer(NUM2INT(id));
  return INT2NUM(0);
}

VALUE qt_set_buffer_contents(VALUE self, VALUE id, VALUE txt) {
  char *cstr = StringValueCStr(txt);
  int i_id = NUM2INT(id);
  g_editor->buffers[i_id]->buf->setPlainText(cstr);
  
  return INT2NUM(0);
}


VALUE qt_set_current_buffer(VALUE self, VALUE id) {
  g_editor->setCurrentBuffer(NUM2INT(id));
  return INT2NUM(0);
}

VALUE qt_open_url(VALUE self, VALUE url) {
  char *cstr_url = StringValueCStr(url);
  QDesktopServices::openUrl(QUrl(cstr_url));
  return INT2NUM(0);
}

VALUE qt_add_font_style(VALUE self, VALUE sty) {
  printf("qt_add_font_style\n");
  // qt_add_font_style_cpp(sty);
  // Qstring QString(StringValueCStr(new_title));

  return INT2NUM(0);
}

VALUE qt_add_image(VALUE self, VALUE imgfn, VALUE pos) {
  QString fn = QString(StringValueCStr(imgfn));
  QUrl Uri(QString("file://%1").arg(fn));

  QImageReader reader(fn);
  QImage image = reader.read();
  if (image.isNull()) {
    rb_eval_string("message('IMAGE=NULL')");
    return INT2NUM(0);
  }

  printf("img nfo: width:%d height:%d, buf width:%d\n", image.width(), image.height(),
         c_te->width());
  int img_screen_width = image.width();
  int img_screen_height = image.height();
  float fit_ratio = ((float)(image.width())) / (c_te->width() - 30);
  // If does not fit window, make smaller
  if (fit_ratio > 1.0) {
    img_screen_width = img_screen_width / (fit_ratio);
    img_screen_height = img_screen_height / (fit_ratio);
  }
  // QImageReader ( fn ).read();

  rb_eval_string("message('Adding image')");

  QTextDocument *textDocument = c_te->document();
  // QTextCursor cursor = c_te->textCursor();
  QTextCursor *cursor = new QTextCursor(textDocument);
  textDocument->addResource(QTextDocument::ImageResource, Uri, QVariant(image));
  QTextImageFormat imageFormat;
  imageFormat.setWidth(img_screen_width);
  imageFormat.setHeight(img_screen_height);

  imageFormat.setName(Uri.toString());
  cursor->setPosition(NUM2INT(pos));
  cursor->setPosition(NUM2INT(pos) + 1, QTextCursor::KeepAnchor);
  cursor->insertText("");
  cursor->setPosition(NUM2INT(pos));
  cursor->insertImage(imageFormat);
  return INT2NUM(8888);
}

VALUE qt_add_text_format(VALUE self, VALUE forec, VALUE backc, VALUE fontStyle, VALUE fontScale) {
  // VALUE qt_add_text_format(VALUE self, VALUE forec,VALUE backc, VALUE fontStyle) {
  QString foregroundColor = QString(StringValueCStr(forec));
  QString backgroundColor = QString(StringValueCStr(backc));
  int fs = NUM2INT(fontStyle);
  float scale = (float)NUM2DBL(fontScale);
  g_editor->addTextFormat(foregroundColor, backgroundColor, fs, scale);
  return INT2NUM(0);
}

VALUE qt_set_stylesheet(VALUE self, VALUE css) {
  qt_set_stylesheet_cpp(css);
  return INT2NUM(0);
}

void srn_dst_wrap(void *y) {
  void **x = (void **)y;
  char *a = (char *)x[0];
  char *b = (char *)x[1];
  float *d = (float *)x[2];
  *d = srn_dst(a, b);
  // printf("00000 A:%s B:%s %f\n",a,b,*d);
}

VALUE _srn_dst(VALUE self, VALUE s1, VALUE s2) {
  VALUE ret;
  float d;
  void **ptr = malloc(sizeof(void *) * 3);
  ptr[0] = (void *)StringValueCStr(s1);
  ptr[1] = (void *)StringValueCStr(s2);
  ptr[2] = (void *)&d;
  rb_thread_call_without_gvl(srn_dst_wrap, ptr, NULL, NULL);
  // d = srn_dst(StringValueCStr(s1), StringValueCStr(s2));
  ret = rb_float_new(d);
  free(ptr);
  return ret;
}

// Process changes to buffer contents. Update qt qtextedit according to changes to ruby Buffer.
int qt_process_deltas() {

  QTextCursor tc = c_te->textCursor();
  VALUE deltas = rb_eval_string("buf.deltas");

  while (RARRAY_LEN(deltas) > 0) {
    VALUE d = rb_ary_shift(deltas);
    // qDebug() << "DELTA: "
    // << " " << NUM2INT(rb_ary_entry(d, 0)) << " " << NUM2INT(rb_ary_entry(d, 1)) << " "
    // << NUM2INT(rb_ary_entry(d, 2)) << "\n";
    int _pos = NUM2INT(rb_ary_entry(d, 0));
    int op = NUM2INT(rb_ary_entry(d, 1));
    int count = NUM2INT(rb_ary_entry(d, 2));

    if (op == DELETE) {
      tc.setPosition(_pos);
      tc.setPosition(_pos + count, QTextCursor::KeepAnchor);
      tc.insertText("");
    } else if (op == INSERT) {
      tc.setPosition(_pos);
      // tc.setPosition(_pos + count,QTextCursor::KeepAnchor);
      VALUE c = rb_ary_entry(d, 3);
      tc.insertText(StringValueCStr(c));
    }

    if (RARRAY_LEN(deltas) == 0) { // last iteration
      rb_eval_string("$hook.call(:buffer_changed)");
    }
  }
  return 0;
}

VALUE _qt_process_deltas(VALUE self) {
  qt_process_deltas();
  return INT2NUM(0);
}

VALUE render_minibuffer(VALUE self) {
  VALUE minibuf;
  minibuf = rb_eval_string("$minibuffer.to_s");
  QString *minibufstr = new QString(StringValueCStr(minibuf));
  miniEditor->setPlainText(*minibufstr);
  delete minibufstr;
  return INT2NUM(0);
}


void _init_ruby(int argc, char *argv[]) {
  ruby_sysinit(&argc, &argv);
  RUBY_INIT_STACK;
  ruby_init();
  ruby_init_loadpath();

  VALUE *MyTest;
  rb_define_global_function("render_text", method_render_text, 4);

  rb_define_global_function("qt_process_deltas", _qt_process_deltas, 0);

  rb_define_global_function("scan_indexes", method_scan_indexes, 2);
  
  rb_define_global_function("c_startup", c_startup, 0);
  rb_define_global_function("main_loop", method_main_loop, 0);
  rb_define_global_function("qt_quit", method_qt_quit, 0);
  rb_define_global_function("qt_trigger_event", qt_trigger_event, 0);
  
  rb_define_global_function("qt_open_file_dialog", method_open_file_dialog, 1);
  rb_define_global_function("qt_file_saveas", qt_file_saveas, 1);
  rb_define_global_function("qt_load_theme", qt_load_theme, 1);
  
  
  rb_define_global_function("render_minibuffer", render_minibuffer, 0);
  
  

  rb_define_global_function("restart_application", method_restart, 0);
  rb_define_global_function("cpp_function_wrapper", ruby_cpp_function_wrapper, 2);
  rb_define_global_function("srn_dst", _srn_dst, 2);

  rb_define_global_function("set_window_title", method_set_window_title, 1);
  rb_define_global_function("set_system_clipboard", set_system_clipboard, 1);
  rb_define_global_function("set_qt_style", set_qt_style, 1);
  rb_define_global_function("qt_set_num_columns", qt_set_num_columns, 1);
  rb_define_global_function("qt_select_window", qt_select_window, 4);
  rb_define_global_function("qt_select_window_close", qt_select_window_close, 1);

  rb_define_global_function("qt_select_update_window", qt_select_update_window, 4);
  rb_define_global_function("qt_popup_window", qt_popup_window, 1);
  rb_define_global_function("qt_add_text_format", qt_add_text_format, 4);

  rb_define_global_function("qt_create_buffer", qt_create_buffer, 1);
  rb_define_global_function("qt_set_buffer_contents", qt_set_buffer_contents, 2);
  
  rb_define_global_function("qt_set_current_buffer", qt_set_current_buffer, 1);

  rb_define_global_function("qt_add_image", qt_add_image, 2);

  rb_define_global_function("qt_open_url", qt_open_url, 1);
  // rb_define_global_function("qt_get_buffer", qt_get_buffer, 0);
  rb_define_global_function("qt_add_font_style", qt_add_font_style, 1);
  rb_define_global_function("qt_set_stylesheet", qt_set_stylesheet, 1);
  rb_define_global_function("qt_set_cursor_pos", qt_set_cursor_pos, 2);
  rb_define_global_function("qt_set_selection_start", qt_set_selection_start, 2);
  rb_define_global_function("qt_refresh_cursor", qt_refresh_cursor, 0);

  rb_define_global_function("qt_update_cursor_pos", qt_update_cursor_pos, 0);

  rb_define_global_function("top_where_cursor", top_where_cursor, 0);
  rb_define_global_function("bottom_where_cursor", bottom_where_cursor, 0);
  rb_define_global_function("page_down", page_down, 0);
  rb_define_global_function("page_up", page_up, 0);

  rb_define_global_function("center_where_cursor", method_center_where_cursor, 0);

  rb_define_global_function("qt_process_events", qt_process_events, 0);

  VALUE qt_module = rb_define_module("Qt");
#include "qt_keys.h"

  // cat a  | awk '{printf("rb_define_const(qt_module, '"'"'%s'"'"',INT2NUM(Qt::%s));\n",$1,$1)}'
  // | sed -e "s/'/\"/g" > ../qt_keys.h rb_define_const(qt_module,
  // "Key_Backspace",INT2NUM(Qt::Key_Context1));

  ruby_script("vimamsa.rb");
  ruby_run_node(ruby_options(argc, argv));
  return;
}

} // END of extern "C"

VALUE qt_refresh_cursor(VALUE self) {
  int selection_start = NUM2INT(rb_eval_string("buf.selection_start()")); // TODO: fix
  // c_te->cursor_pos = cursor_pos;
  // if (NUM2INT(do_center) == 1) {
  qDebug() << "sel start:" << selection_start << "\n";

  QTextCursor tc = c_te->textCursor();
  // int i_cursor_pos = g_editor->buffers[id]->buf->cursor_pos;
  int i_cursor_pos = c_te->cursor_pos;
  if (selection_start >= 0) {
    if (i_cursor_pos < selection_start) {
      tc.setPosition(selection_start + 1);
      tc.setPosition(i_cursor_pos, QTextCursor::KeepAnchor);
    } else {
      tc.setPosition(selection_start);
      tc.setPosition(i_cursor_pos, QTextCursor::KeepAnchor);
    }
  } else {
    tc.setPosition(i_cursor_pos);
  }

  c_te->setTextCursor(tc);
}

VALUE qt_set_cursor_pos(VALUE self, VALUE BUFID, VALUE cursor_pos) {
  int id = NUM2INT(BUFID);
  int i_cursor_pos = NUM2INT(cursor_pos);
  g_editor->buffers[id]->buf->cursor_pos = NUM2INT(cursor_pos);

  return INT2NUM(0);
}

VALUE qt_set_selection_start(VALUE self, VALUE BUFID, VALUE cursor_pos) {
  int id = NUM2INT(BUFID);
  int aa = NUM2INT(cursor_pos);
  g_editor->buffers[id]->buf->selection_start = NUM2INT(cursor_pos);
  return 0;
}

VALUE cursor_to_viewport_pos(int cursorpos) {
  // printf("cursorpos:%d ",cursorpos);
  QTextCursor cursor = c_te->textCursor();
  cursor.setPosition(cursorpos);
  QRect r = c_te->cursorRect(cursor);
  VALUE point = rb_ary_new();
  rb_ary_push(point, INT2NUM(r.x()));
  rb_ary_push(point, INT2NUM(r.y()));
  return point;

  // jm_x = r.x()-6;
  // jm_y = r.y()-7;
}

VALUE pos_to_viewport_coordinates(VALUE args) {
  VALUE vpcrd;
  printf("pos_to_viewport_coordinates\n");
  vpcrd = rb_ary_new();

  VALUE point;
  VALUE cursorpos;
  VALUE a_cursorpos = rb_ary_entry(args, 0);

  for (int i = 0; i < RARRAY_LEN(a_cursorpos); ++i) {
    cursorpos = rb_ary_entry(a_cursorpos, i);
    point = cursor_to_viewport_pos(NUM2INT(cursorpos));
    rb_ary_push(vpcrd, point);
  }
  return vpcrd;
}

VALUE draw_text(VALUE args) { c_te->overlay->draw_text("AX", 40, 40); }

int render_text(VALUE textbuf, int cursor_pos, int selection_start, int reset_buffer) {
  // int render_text(int reset_buffer) {
  // qDebug() << "c:RENDER_TEXT\n";
  // qDebug() << "render_text thread:" <<QThread::currentThreadId();
  // VALUE minibuf;
  // minibuf = rb_eval_string("$minibuffer.to_s");
  // VALUE icmtmp = rb_eval_string("is_command_mode()");
  // c_te->is_command_mode = NUM2INT(icmtmp);
  // QString *minibufstr = new QString(StringValueCStr(minibuf));
  // miniEditor->setPlainText(*minibufstr);
  // delete minibufstr;

  if (reset_buffer == 1) {
    // stext = new QString(StringValueCStr(textbuf));
    // qDebug() << "QT:RESET BUFFER\n";
    // qDebug() << *stext;
    // qDebug() << "\n=========A=====\n";
    // c_te->setPlainText(*stext);
    // c_te->document()->setPlainText(*stext);
    // qDebug() << c_te->document()->toPlainText();
    // qDebug() << "\n=========B=====\n";
    delete stext;
  }

  // qt_process_deltas();

  c_te->cursor_pos = cursor_pos;

  // c_te->repaint(c_te->contentsRect());

  // Without this draw area is not always updated although
  // Overlay::paintEvent is called

  // c_te->overlay->repaint(c_te->overlay->contentsRect());

  // app->processEvents();
}



int render_text_old(VALUE textbuf, int cursor_pos, int selection_start, int reset_buffer) {
  // int render_text(int reset_buffer) {
  // qDebug() << "c:RENDER_TEXT\n";
  // qDebug() << "render_text thread:" <<QThread::currentThreadId();
  VALUE minibuf;
  minibuf = rb_eval_string("$minibuffer.to_s");
  VALUE icmtmp = rb_eval_string("is_command_mode()");
  c_te->is_command_mode = NUM2INT(icmtmp);
  QString *minibufstr = new QString(StringValueCStr(minibuf));
  miniEditor->setPlainText(*minibufstr);
  delete minibufstr;

  if (reset_buffer == 1) {
    stext = new QString(StringValueCStr(textbuf));
    qDebug() << "QT:RESET BUFFER\n";
    // qDebug() << *stext;
    // qDebug() << "\n=========A=====\n";
    // c_te->setPlainText(*stext);
    c_te->document()->setPlainText(*stext);
    // qDebug() << c_te->document()->toPlainText();
    // qDebug() << "\n=========B=====\n";
    delete stext;
  }

  qt_process_deltas();

  c_te->cursor_pos = cursor_pos;

  // c_te->repaint(c_te->contentsRect());

  // Without this draw area is not always updated although
  // Overlay::paintEvent is called

  c_te->overlay->repaint(c_te->overlay->contentsRect());

  app->processEvents();
}
