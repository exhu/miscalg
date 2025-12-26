/// public export
#pragma once

struct myclib_ctx_t;
typedef struct myclib_ctx_t myclib_ctx_t;

myclib_ctx_t * myclib_init(const char *name);
/// do not free returned pointer!
const char* myclib_get_name(myclib_ctx_t *ctx);
void myclib_done(myclib_ctx_t *ctx);
