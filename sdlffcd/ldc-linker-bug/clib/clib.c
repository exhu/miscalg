#include "clib.h"
#include "shlib/shlib.h"
#include <libavutil/avutil.h>

const char* clib_get_version(void) {
  int v = shlib_version();
    return av_version_info();
}
