#include <stdio.h>
#include "myclib/myclib.h"

#define PROJECT_NAME "clib"

int main(int argc, char **argv) {
    if(argc != 1) {
        printf("%s takes no arguments.\n", argv[0]);
        return 1;
    }
    printf("This is project %s.\n", PROJECT_NAME);
    myclib_ctx_t *ctx = myclib_init("hello");
    const char *name = myclib_get_name(ctx);
    printf("Got name: %s\n", name);
    myclib_done(ctx);
    return 0;
}
