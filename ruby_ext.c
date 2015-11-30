

//TODO: put to ruby_ext.h
VALUE pos_to_viewport_coordinates(VALUE args);
VALUE draw_text(VALUE args);


extern "C" {

#include <stdio.h>
#include <ruby/defines.h>

VALUE method_qt_quit(VALUE self) {
 _quit = 1;
}

VALUE method_open_file_dialog(VALUE self) {
    mw->fileOpen();
}

VALUE method_restart(VALUE self) {
    QProcess::startDetached(QApplication::applicationFilePath());
    exit(12);
}


VALUE method_set_window_title(VALUE self, VALUE new_title) {
    //mw->setWindowTitle(QString(StringValueCStr(new_title)));

    // For some reason program segfaults if we call mw->setWindowTitle from here.
    // But from main_loop its ok..
    window_title = new QString(StringValueCStr(new_title));
}


VALUE method_main_loop(VALUE self) {

    printf("Start MAIN LOOP\n");
    QByteArray ba;
    const char *c_str2;

    cpp_init_qt_thread();
    QApplication a(*_argc, _argv);
    app = &a;

    qDebug() << "hello from GUI thread " << QThread::currentThreadId();
    //qDebug() << "main_loop thread id:" << thread()->currentThreadId();
    Editor mw;
    mw.resize(700, 800);
    mw.show();


    rb_eval_string("viwbaw_init");
    window_title = new QString("VIwbaw");
    VALUE rb_event;
    VALUE handle_key_event = rb_intern("handle_key_event");
    while(1) {
        a.processEvents();
        //rb_thread_schedule(); //TODO if there are plugins with threads?

    mw.setWindowTitle(*window_title);// TODO only when changed
        QThread::usleep(2000);
    }
    return INT2NUM(1);
}

/** START This code ripped from ruby string.c **/

#define BEG(no) (regs->beg[(no)])
#define END(no) (regs->end[(no)])
#define STR_ENC_GET(str) rb_enc_from_index(ENCODING_GET(str))

static VALUE
scan_once(VALUE str, VALUE pat, long *start_i)
{
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
		*start_i = END(0)+rb_enc_fast_mbclen(RSTRING_PTR(str)+END(0),
						   RSTRING_END(str), enc);
	    else
		*start_i = END(0)+1;
	}
	else {
	    *start_i = END(0);
	}
	if (regs->num_regs == 1
            //TODO multiple matches (regexp groups) not implemented yet
            || regs->num_regs > 1 ) {

        // START From ruby re.c:rb_reg_nth_match
        long start, end, len;
        struct re_registers *regs;
        int nth = 0;

        if (NIL_P(match)) return Qnil;
        //match_check(match);
        // ruby_ext.c:100:22: error: ‘match_check’ was not declared in this scope
        // Seems to work fine without

        regs = RMATCH_REGS(match);
        if (nth >= regs->num_regs) {
            return Qnil;
        }
        if (nth < 0) {
            nth += regs->num_regs;
            if (nth <= 0) return Qnil;
        }
        start = BEG(nth);
        if (start == -1) return Qnil;
        end = END(nth);
        len = end - start;
        // TODO:optimize str_sublen??
        result = INT2NUM(rb_str_sublen(str,start));
        return result;
        //str = rb_str_subseq(RMATCH(match)->str, start, len);
        //OBJ_INFECT(str, match);
        // END FROM ruby re.c:rb_reg_nth_match


	    //return rb_reg_nth_match(0, match);
	}
	result = rb_ary_new2(regs->num_regs);
	for (i=1; i < regs->num_regs; i++) {

        //TODO multiple matches (groups) not implemented yet
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
VALUE method_scan_indexes(VALUE self,VALUE str,VALUE pat) {

    //VALUE pat = ""
   VALUE result;
    long start = 0;
    long last = -1, prev = 0;
    char *p = RSTRING_PTR(str); long len = RSTRING_LEN(str);
    VALUE ary = rb_ary_new();

    //pat = get_pat(pat, 1);
    if (1) {

        while (!NIL_P(result = scan_once(str, pat, &start))) {
            last = prev;
            prev = start;
            //rb_ary_push(ary, result);
            //rb_ary_push(ary, INT2NUM(start));
            //TODO: if result != Qnil
            //TODO: start gives end of pattern+1? Currently compensating in ruby.
            //rb_ary_push(ary, INT2NUM(rb_str_sublen(str,start)));// TODO:optimize str_sublen
            rb_ary_push(ary, result);
        }
        if (last >= 0) rb_reg_search(pat, str, last, 0);
        return ary;
    }
    return ary;
}

VALUE method_render_text(VALUE self,VALUE text, VALUE _pos, VALUE _selection_start, VALUE _reset) {

    // Ignore cursor position change events until rendering is over.

    reset_buffer = NUM2INT(_reset);
    textbuf = text;
    cursor_pos = NUM2INT(_pos);
    selection_start = NUM2INT(_selection_start);

    render_text();

	return INT2NUM(1);
}

int get_visible_area(int& start_pos, int& end_pos) {
    QTextCursor cursor = c_te->cursorForPosition(QPoint(0, 0));
    QPoint bottom_right(c_te->viewport()->width() - 1, c_te->viewport()->height() - 1);
    start_pos = cursor.position();
    end_pos = c_te->cursorForPosition(bottom_right).position();
    cursor.setPosition(end_pos, QTextCursor::KeepAnchor);
    qDebug() << cursor.selectedText();
    printf("Visible range: %d - %d\n", start_pos,end_pos);
    return 0;
}

VALUE rb_get_visible_area() {
    int start_pos; int end_pos;
    VALUE range = rb_ary_new();
    get_visible_area(start_pos,end_pos);
    rb_ary_push(range, INT2NUM(start_pos));
    rb_ary_push(range, INT2NUM(end_pos));
    return range;
}

int center_where_cursor() {
    int cursorY = c_te->cursorRect().bottom();
    int offset_y = c_te->verticalScrollBar()->value() + cursorY - c_te->size().height()/2; 
    c_te->verticalScrollBar()->setValue(offset_y);
}


VALUE ruby_cpp_function_wrapper(VALUE self,VALUE method_name, VALUE args) {
    VALUE ret;
    switch(NUM2INT(method_name)) {
        case 0:
            ret = pos_to_viewport_coordinates(args); break;
        case 1:
            ret = draw_text(args); break;
        case 2:
            ret = rb_get_visible_area(); break;
        case 3:
            center_where_cursor(); break;
    }
    return ret;
}



void _init_ruby(int argc, char *argv[]) {
    ruby_sysinit(&argc,&argv);
    RUBY_INIT_STACK;
    ruby_init();
    ruby_init_loadpath();

    VALUE* MyTest;
    rb_define_global_function("render_text",method_render_text,4);
    rb_define_global_function("scan_indexes",method_scan_indexes,2);
    //rb_define_global_function("render_text",method_render_text,-1);
    rb_define_global_function("main_loop",method_main_loop,0);
    rb_define_global_function("qt_quit",method_qt_quit,0);
    rb_define_global_function("open_file_dialog",method_open_file_dialog,0);
    rb_define_global_function("restart_application",method_restart,0);
    rb_define_global_function("cpp_function_wrapper",ruby_cpp_function_wrapper,2);

    rb_define_global_function("set_window_title",method_set_window_title,1);

    VALUE qt_module = rb_define_module("Qt");
#include "qt_keys.h"

    //cat a  | awk '{printf("rb_define_const(qt_module, '"'"'%s'"'"',INT2NUM(Qt::%s));\n",$1,$1)}' | sed -e "s/'/\"/g" > ../qt_keys.h
    //rb_define_const(qt_module, "Key_Backspace",INT2NUM(Qt::Key_Context1));

    ruby_script("viwbaw.rb");
    ruby_run_node(ruby_options(argc, argv));
    return;

}

} // END of extern "C"



VALUE cursor_to_viewport_pos(int cursorpos) {
    //printf("cursorpos:%d ",cursorpos);
    QTextCursor cursor = c_te->textCursor();
    cursor.setPosition(cursorpos);
    QRect r = c_te->cursorRect(cursor);
    VALUE point = rb_ary_new();
    rb_ary_push(point, INT2NUM(r.x()));
    rb_ary_push(point, INT2NUM(r.y()));
    return point;


    //jm_x = r.x()-6;
    //jm_y = r.y()-7;
}


VALUE pos_to_viewport_coordinates(VALUE args)
{
    VALUE vpcrd;
    printf("pos_to_viewport_coordinates\n");
    vpcrd = rb_ary_new();

    VALUE point;
    VALUE cursorpos;
    VALUE a_cursorpos = rb_ary_entry(args,0);

    for (int i = 0; i < RARRAY_LEN(a_cursorpos); ++i) {
        cursorpos = rb_ary_entry(a_cursorpos,i);
        point = cursor_to_viewport_pos(NUM2INT(cursorpos));
        rb_ary_push(vpcrd, point);
    }
    return vpcrd;
}


VALUE draw_text(VALUE args) {
    c_te->overlay->draw_text("AX",40,40);
}


int render_text() {
    qDebug() << "c:RENDER_TEXT\n";
    //qDebug() << "render_text thread:" <<QThread::currentThreadId();
    VALUE minibuf;
    minibuf = rb_eval_string("$minibuffer.to_s");
    //VALUE is_command_mode;
    VALUE icmtmp = rb_eval_string("$at.is_command_mode()");
    c_te->is_command_mode = NUM2INT(icmtmp);
    QString *minibufstr = new QString(StringValueCStr(minibuf));
    miniEditor->setPlainText(*minibufstr);
    delete minibufstr;

    if(reset_buffer == 1) {
        qDebug() << "QT:RESET BUFFER\n";
        stext = new QString(StringValueCStr(textbuf));
        c_te->setPlainText(*stext);
        delete stext;
    }

    //return;

    QTextCursor tc = c_te->textCursor();


        qDebug() << "QT:process deltas\n";
    //ID rb_intern(const char *name)
    VALUE deltas = rb_eval_string("$buffer.deltas");
    while(RARRAY_LEN(deltas) > 0) {
        VALUE d = rb_ary_shift(deltas);
        qDebug() << "DELTA: " << " " << NUM2INT(rb_ary_entry(d,0)) << " " << NUM2INT(rb_ary_entry(d,1)) << " " << NUM2INT(rb_ary_entry(d,2)) << "\n";
        int _pos = NUM2INT(rb_ary_entry(d,0));
        int op = NUM2INT(rb_ary_entry(d,1));
        int count = NUM2INT(rb_ary_entry(d,2));

        if(op == DELETE) {
            tc.setPosition(_pos);
            tc.setPosition(_pos + count,QTextCursor::KeepAnchor);
            tc.insertText("");
        }
        else if(op == INSERT) {
            tc.setPosition(_pos);
            //tc.setPosition(_pos + count,QTextCursor::KeepAnchor);
            VALUE c = rb_ary_entry(d,3);
            tc.insertText(StringValueCStr( c ));
        }

    }

        qDebug() << "QT: END process deltas\n";

  if(selection_start >= 0 ) {
      tc.setPosition(selection_start);
      tc.setPosition(cursor_pos,QTextCursor::KeepAnchor);
  }
  else {
      tc.setPosition(cursor_pos);
  }
  c_te->setTextCursor(tc);
  c_te->drawTextCursor();

  //c_te->repaint(c_te->contentsRect());

  // Without this draw area is not always updated although
  // Overlay::paintEvent is called
  c_te->overlay->repaint(c_te->overlay->contentsRect());

  //get_visible_area();

  app->processEvents();
}

