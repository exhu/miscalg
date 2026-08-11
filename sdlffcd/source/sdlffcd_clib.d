extern(C):

struct sdlffcd_AppContext;

sdlffcd_AppContext* sdlffcd_app_init(const char* title, int width, int height);
bool sdlffcd_app_is_running(const sdlffcd_AppContext* app);
void sdlffcd_app_wait_events(sdlffcd_AppContext* app);
void sdlffcd_app_render(sdlffcd_AppContext* app);
void sdlffcd_app_shutdown(sdlffcd_AppContext* app);

