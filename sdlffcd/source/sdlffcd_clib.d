extern(C):

struct AppContext;

AppContext* app_init(const char* title, int width, int height);
bool app_is_running(const AppContext* app);
void app_wait_events(AppContext* app);
void app_render(AppContext* app);
void app_shutdown(AppContext* app);

