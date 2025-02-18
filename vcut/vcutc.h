#pragma once
#include <stdbool.h>
#include <stdint.h>

struct _Vcutc;
typedef struct _Vcutc VcutC;

typedef void (*time_pos_change_cb_t)(double new_time, void *user_data);
typedef void (*file_loaded_cb_t)(void *user_data);

bool vcutc_init_mpv(int64_t xid, VcutC **v, time_pos_change_cb_t time_cb, void *time_cb_data);
void vcutc_free_mpv(VcutC **v);

void vcutc_set_file_loaded_cb(VcutC *v, file_loaded_cb_t cb, void *user);
void vcutc_play_pause(VcutC *v);
// seconds
double vcutc_get_film_duration(VcutC *v);
// seconds
double vcutc_get_film_position(VcutC *v);
void vcutc_seek(VcutC *v, double percent_pos);
void vcutc_seek_sec_relative(VcutC *v, double sec_pos);
// rewinds and sets points, clears on repeat
void vcutc_ab_loop(VcutC *v, double start, double end);
void vcutc_set_pause(VcutC *v, bool paused);