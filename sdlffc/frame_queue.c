#include "frame_queue.h"

#include <string.h>
#include <SDL3/SDL_log.h>
#include <libavutil/frame.h>

bool frame_queue_init(FrameQueue *q) {
    memset(q, 0, sizeof(*q));
    q->mutex     = SDL_CreateMutex();
    q->not_full  = SDL_CreateCondition();
    return q->mutex && q->not_full;
}

void frame_queue_done(FrameQueue *q) {
    frame_queue_flush(q);
    SDL_DestroyCondition(q->not_full);
    SDL_DestroyMutex(q->mutex);
    q->not_full  = NULL;
    q->mutex     = NULL;
}

bool frame_queue_push(FrameQueue *q, AVFrame *frame, double pts,
                      SDL_AtomicInt *quit_requested) {
    SDL_LockMutex(q->mutex);
    /* Block while full, but bail out if quit is requested */
    while (q->count == FRAME_QUEUE_SIZE &&
           !SDL_GetAtomicInt(quit_requested)) {
        SDL_WaitCondition(q->not_full, q->mutex);
    }
    if (SDL_GetAtomicInt(quit_requested)) {
        SDL_UnlockMutex(q->mutex);
        return false;
    }
    int idx = q->write_idx;
    q->frames[idx] = frame;
    q->pts[idx]    = pts;
    q->write_idx   = (idx + 1) % FRAME_QUEUE_SIZE;
    q->count++;
    SDL_UnlockMutex(q->mutex);
    return true;
}

AVFrame *frame_queue_try_pop(FrameQueue *q, double max_pts) {
    SDL_LockMutex(q->mutex);
    AVFrame *frame = NULL;
    if (q->count > 0 && q->pts[q->read_idx] <= max_pts) {
        frame = q->frames[q->read_idx];
        q->frames[q->read_idx] = NULL;
        q->read_idx = (q->read_idx + 1) % FRAME_QUEUE_SIZE;
        q->count--;
        SDL_SignalCondition(q->not_full);
    }
    SDL_UnlockMutex(q->mutex);
    return frame;
}

bool frame_queue_peek_pts(FrameQueue *q, double *out_pts) {
    SDL_LockMutex(q->mutex);
    bool has_frame = false;
    if (q->count > 0) {
        if (out_pts) {
            *out_pts = q->pts[q->read_idx];
        }
        has_frame = true;
    }
    SDL_UnlockMutex(q->mutex);
    return has_frame;
}

void frame_queue_flush(FrameQueue *q) {
    SDL_LockMutex(q->mutex);
    while (q->count > 0) {
        AVFrame *f = q->frames[q->read_idx];
        q->frames[q->read_idx] = NULL;
        q->read_idx = (q->read_idx + 1) % FRAME_QUEUE_SIZE;
        q->count--;
        if (f) {
            av_frame_unref(f);
            av_frame_free(&f);
        }
    }
    q->read_idx  = 0;
    q->write_idx = 0;
    /* Wake any blocked push so the producer can observe quit_requested */
    SDL_BroadcastCondition(q->not_full);
    SDL_UnlockMutex(q->mutex);
}
