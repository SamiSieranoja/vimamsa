#include "editor.h"
#include "main_window.h"
#include "buffer_widget.h"
#include "globals.h"

extern "C" {
#include <ruby.h>
#include <stdio.h>
}


int main(int argc, char *argv[]) {
  _argc = &argc;
  _argv = argv;
  

  char **argv2 = malloc((*_argc + 2) * sizeof(char *));
  char const *script_name = "main.rb";
  argv2[0] = script_name;
  argv2[1] = script_name;
  for (int i = 0; i < *_argc; i++) {
    argv2[i + 2] = _argv[i];
  }
  _init_ruby(*_argc + 2, argv2);

  return 0;
}
