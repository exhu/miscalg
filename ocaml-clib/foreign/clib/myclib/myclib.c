#include "myclib.h"
#include <string.h>
#include <stdlib.h>
struct myclib_ctx_t{
  const char *name;
};

myclib_ctx_t *myclib_init(const char *name) {
  myclib_ctx_t *ctx = malloc(sizeof(myclib_ctx_t));
  ctx->name = strdup(name);
  return ctx;
}
  
/// do not free returned pointer!
const char *myclib_get_name(myclib_ctx_t *ctx) {
  return ctx->name;
}

void myclib_done(myclib_ctx_t *ctx) {
  free(ctx);
}
