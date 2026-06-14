#pragma once
#include "SDL3/SDL_mutex.h"
#include <SDL3/SDL_thread.h>

/// one-way one-slot communiction between threads
typedef struct {
  SDL_Condition *condition;
  SDL_Mutex *mutex;
  void *data;
  size_t data_size;
  bool is_set;
} MailBox;

/// data is a reusable buffer
bool mailbox_init(MailBox *mb, void *data, size_t data_size);
void mailbox_done(MailBox *mb);
/// signals, data is ready, is_set = true
/// returns false if the mailbox is already set, and the data is not updated
/// data_size must be the same as in mailbox_init
bool mailbox_send(MailBox *mb, void *new_data_value, size_t data_size);

/// waits for condition, then locks, timeout is -1 for indef, or milliseconds
/// returns true if there's data set
bool mailbox_receive_and_lock(MailBox *mb, Sint32 timeout);

/// unlocks mutex, mailbox ready for next send, is_set = false
void mailbox_unlock(MailBox *mb);
