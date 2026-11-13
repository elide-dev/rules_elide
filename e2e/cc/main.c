#include <math.h>
#include <stdio.h>
#include <string.h>

#include "util/greet.h"

int main(int argc, char **argv) {
  /* libm via -lm, libc stdio/string from the bundled sysroot. */
  printf("hello from %s: sqrt(%d)=%d args=%d\n", greeting(), 1764,
         (int)sqrt(1764.0), argc - 1);
  return strcmp(argc > 1 ? argv[1] : "", "fail") == 0 ? 3 : 0;
}
