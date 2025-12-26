#if 0
#include "clib/myclib/myclib.h"

void test_dep() {
  myclib_ctx_t *ctx = myclib_init("hello from stubs.c");
  myclib_get_name(ctx);
  myclib_done(ctx);
}
#endif
