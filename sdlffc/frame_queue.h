#pragma once
#include <stdbool.h>
#include <SDL3/SDL_atomic.h>
#include <SDL3/SDL_mutex.h>
#include <libavutil/frame.h>

#define FRAME_QUEUE_SIZE 8

/// Thread-safe single-producer / single-consumer ring buffer of decoded AVFrame*.
/// Each slot holds a ref-counted AVFrame* and its presentation time in seconds
/// (relative to the first frame) for wall-clock timing.
typedef struct {
    AVFrame      *frames[FRAME_QUEUE_SIZE];
    double        pts[FRAME_QUEUE_SIZE];   ///< presentation time in seconds from first frame
    SDL_Mutex    *mutex;
    SDL_Condition *not_full;
    SDL_Condition *not_empty;
    int           write_idx;
    int           read_idx;
    int           count;
} FrameQueue;

bool     frame_queue_init(FrameQueue *q);
void     frame_queue_done(FrameQueue *q);

/// Blocks until space is available or *quit_requested becomes non-zero.
/// On success returns true and the queue owns the frame.
/// On abort (quit) returns false; caller must unref+free the frame.
bool     frame_queue_push(FrameQueue *q, AVFrame *frame, double pts,
                          SDL_AtomicInt *quit_requested);

/// Non-blocking: pops and returns the head frame if its pts <= max_pts.
/// Returns NULL if the queue is empty or the head pts > max_pts.
/// Caller owns the returned frame and must av_frame_free() it when done.
AVFrame *frame_queue_try_pop(FrameQueue *q, double max_pts);

/// Non-blocking: peeks the PTS of the head frame in the queue without popping.
/// Returns true if a frame is available and writes its PTS to *out_pts.
/// Returns false if the queue is empty.
bool     frame_queue_peek_pts(FrameQueue *q, double *out_pts);

/// Drain all frames (av_frame_unref + av_frame_free each) and broadcast
/// not_full. Used during shutdown to unblock a blocked push.
void     frame_queue_flush(FrameQueue *q);
