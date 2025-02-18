#include "vcutc.h"

#include <mpv/client.h>

#include <glib.h>

#include <stdio.h>
#include <stdlib.h>
#include <locale.h>
#include <inttypes.h>
#include <string.h>

struct _Vcutc {
    mpv_handle *mpv;
    time_pos_change_cb_t time_pos_cb;
    void *time_pos_cb_data;
    file_loaded_cb_t file_loaded_cb;
    void *file_loaded_user;
};

static void handle_mpv_event(VcutC *vc, mpv_event *event) {
    if (vc->mpv == NULL) {
        puts("vc->mpv == NULL!!!\n");
    }
    switch (event->event_id) {
        case MPV_EVENT_PROPERTY_CHANGE: {
            mpv_event_property *prop = (mpv_event_property *)event->data;
            if (strcmp(prop->name, "time-pos") == 0) {
                if (prop->format == MPV_FORMAT_DOUBLE) {
                    double time = *(double *)prop->data;
                    vc->time_pos_cb(time, vc->time_pos_cb_data);
                } else if (prop->format == MPV_FORMAT_NONE) {
                    // The property is unavailable, which probably means playback
                    // was stopped.
                }
            }
            break;
        }
        case MPV_EVENT_VIDEO_RECONFIG: {
            // Retrieve the new video size.
            int64_t w, h;
            if (mpv_get_property(vc->mpv, "dwidth", MPV_FORMAT_INT64, &w) >= 0 &&
                mpv_get_property(vc->mpv, "dheight", MPV_FORMAT_INT64, &h) >= 0 &&
                w > 0 && h > 0)
            {
                // Note that the MPV_EVENT_VIDEO_RECONFIG event doesn't necessarily
                // imply a resize, and you should check yourself if the video
                // dimensions really changed.
                // mpv itself will scale/letter box the video to the container size
                // if the video doesn't fit.
                printf("reconfig %" PRIi64 "x%" PRIi64 "\n", w, h);
            }
            break;
        }
        case MPV_EVENT_LOG_MESSAGE: {
            struct mpv_event_log_message *msg = (struct mpv_event_log_message *)event->data;
            printf("[%s] %s: %s\n", msg->prefix, msg->level, msg->text);
            break;
        }
        case MPV_EVENT_SHUTDOWN: {
            mpv_terminate_destroy(vc->mpv);
            vc->mpv = NULL;
            break;
        }
        case MPV_EVENT_FILE_LOADED: {
            puts("MPV_EVENT_FILE_LOADED");
            vc->file_loaded_cb(vc->file_loaded_user);
            break;
        }
        case MPV_EVENT_END_FILE: {
            puts("MPV_EVENT_END_FILE");
            break;
        }
        default: ;
            // Ignore uninteresting or unknown events.
    }
}

/// must be called from main thread!
static int on_mpv_events(void *param) {
    VcutC *vc = (VcutC*)param;
    // Process all events, until the event queue is empty.
    while (vc->mpv) {
        mpv_event *event = mpv_wait_event(vc->mpv, 0);
        if (event->event_id == MPV_EVENT_NONE)
            break;
        handle_mpv_event(vc, event);
    }

    return FALSE;
}

/// called from multiple threads!
static void wakeup(void *ctx) {
    // This callback is invoked from any mpv thread (but possibly also
    // recursively from a thread that is calling the mpv API). Just notify
    // the GUI thread to wake up (so that it can process events with
    // mpv_wait_event()), and return as quickly as possible.

    VcutC *vc = (VcutC*)ctx;
    // post event to gtk queue
    g_idle_add(on_mpv_events, vc);
}

bool vcutc_init_mpv(int64_t xid, VcutC **v, time_pos_change_cb_t time_cb, void *time_cb_data) {
    puts("hello from vcut_init_mpv\n");
    VcutC *vc = (VcutC*)malloc(sizeof(VcutC));
    memset(vc, 0, sizeof(VcutC));
    *v = vc;
    setlocale(LC_NUMERIC, "C");
    vc->mpv = mpv_create();
    if (vc->mpv == NULL) {
        puts("Failed to create mpv!\n");
    }

    vc->time_pos_cb = time_cb;
    vc->time_pos_cb_data = time_cb_data;

    mpv_set_option(vc->mpv, "wid", MPV_FORMAT_INT64, &xid);
    // Enable default bindings, because we're lazy. Normally, a player using
    // mpv as backend would implement its own key bindings.
    //mpv_set_option_string(vc->mpv, "input-default-bindings", "yes");

    // Enable keyboard input on the X11 window. For the messy details, see
    // --input-vo-keyboard on the manpage.
    //mpv_set_option_string(vc->mpv, "input-vo-keyboard", "yes");

    // Let us receive property change events with MPV_EVENT_PROPERTY_CHANGE if
    // this property changes.
    mpv_observe_property(vc->mpv, 0, "time-pos", MPV_FORMAT_DOUBLE);

    //mpv_observe_property(vc->mpv, 0, "track-list", MPV_FORMAT_NODE);
    //mpv_observe_property(vc->mpv, 0, "chapter-list", MPV_FORMAT_NODE);

    // Request log messages with level "info" or higher.
    // They are received as MPV_EVENT_LOG_MESSAGE.
    mpv_request_log_messages(vc->mpv, "info");
    mpv_set_wakeup_callback(vc->mpv, wakeup, vc);
    mpv_initialize(vc->mpv);

    return true;
}

void vcutc_open_file(VcutC *v, const char *fn) {
    printf("loading file %s...\n", fn);
    const char *args[] = {"loadfile", fn, "append-play", "keep-open=always", NULL};
    mpv_command_async(v->mpv, 0, args);
}

void vcutc_free_mpv(VcutC **v) {
    VcutC *vc = *v;
    if (!vc) {
        return;
    }

    if (vc->mpv) {
        mpv_terminate_destroy(vc->mpv);
    }
    free((void*)vc);
    *v = NULL;
}

void vcutc_play_pause(VcutC *v) {
    const char *args[] = {"cycle", "pause", NULL};
    mpv_command_async(v->mpv, 0, args);
}

double vcutc_get_film_duration(VcutC *vc) {
    double duration = 0.;
    mpv_get_property(vc->mpv, "duration", MPV_FORMAT_DOUBLE, &duration);
    printf("duration = %f\n", duration);
    return duration;
}


void vcutc_set_file_loaded_cb(VcutC *v, file_loaded_cb_t cb, void *user) {
    v->file_loaded_cb = cb;
    v->file_loaded_user = user;
}

void vcutc_seek(VcutC *v, double percent_pos) {
    char percent_str[100];
    sprintf(percent_str, "%f", percent_pos*100.);
    const char *args[] = {"seek", percent_str, "absolute-percent", NULL};
    mpv_command_async(v->mpv, 0, args);
}

double vcutc_get_film_position(VcutC *vc) {
    double time_pos = 0;
    mpv_get_property(vc->mpv, "time-pos", MPV_FORMAT_DOUBLE, &time_pos);
    return time_pos;
}

void vcutc_seek_sec_relative(VcutC *v, double sec_pos) {
    char seek_str[100];
    sprintf(seek_str, "%.2f", sec_pos);
    const char *args[] = {"seek", seek_str, "exact", NULL};
    mpv_command_async(v->mpv, 0, args);
}

void vcutc_ab_loop(VcutC *vc, double start, double end) {
    char seek_str[100];
    sprintf(seek_str, "%.2f", start);
    const char *args[] = {"seek", seek_str, "absolute", "exact", NULL};
    mpv_command_async(vc->mpv, 0, args);

    mpv_set_property(vc->mpv, "ab-loop-a", MPV_FORMAT_DOUBLE, &start);
    mpv_set_property(vc->mpv, "ab-loop-b", MPV_FORMAT_DOUBLE, &end);

    const char *no_str = "no";
    mpv_set_property(vc->mpv, "pause", MPV_FORMAT_STRING, &no_str);
}

void vcutc_set_pause(VcutC *vc, bool paused) {
    const char *no_str = "no";
    const char *yes_str = "yes";
    mpv_set_property(vc->mpv, "pause", MPV_FORMAT_STRING, paused ? &yes_str : &no_str);
}