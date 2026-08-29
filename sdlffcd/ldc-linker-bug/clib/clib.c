#include "clib.h"
#include <libavutil/avutil.h>

const char* clib_get_version(void) {
    return av_version_info();
}
