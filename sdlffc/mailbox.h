#pragma once
#include "SDL3/SDL_mutex.h"
#include <SDL3/SDL_thread.h>

/// one-way one-slot communiction between threads
typedef struct {
  SDL_Condition *condition;
  SDL_Mutex *mutex;
  void *data;
  bool is_set;
} MailBox;

bool mailbox_init(MailBox *mb, void *data);
void mailbox_done(MailBox *mb);
/// signals, data is ready, is_set = true
bool mailbox_send(MailBox *mb);

/// waits for condition, then locks, timeout is -1 for indef, or milliseconds
/// returns true if there's data set
bool mailbox_receive_and_lock(MailBox *mb, Sint32 timeout);

/// unlocks mutex, mailbox ready for next send, is_set = false
void mailbox_unlock(MailBox *mb);
