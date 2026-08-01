#include "mailbox.h"
#include "SDL3/SDL_log.h"
#include "SDL3/SDL_mutex.h"
#include <string.h>

bool mailbox_init(MailBox *mb, void *data, size_t data_size) {
  mb->data = data;
  mb->data_size = data_size;
  mb->condition = SDL_CreateCondition();
  mb->empty_condition = SDL_CreateCondition();
  mb->is_set = false;
  mb->mutex = SDL_CreateMutex();
  return mb->mutex && mb->condition && mb->empty_condition;
}

void mailbox_done(MailBox *mb) {
  mb->is_set = false;
  SDL_DestroyCondition(mb->condition);
  SDL_DestroyCondition(mb->empty_condition);
  SDL_DestroyMutex(mb->mutex);
}

bool mailbox_send(MailBox *mb, void *new_data_value, size_t data_size) {
  SDL_LockMutex(mb->mutex);
  // Block until the slot is free (previous message consumed by receiver)
  while (mb->is_set) {
    SDL_WaitCondition(mb->empty_condition, mb->mutex);
  }
  bool result = false;
  if (data_size == mb->data_size) {
    memcpy(mb->data, new_data_value, data_size);
    mb->is_set = true;
    result = true;
  } else {
    SDL_LogError(SDL_LOG_CATEGORY_APPLICATION, "data_size mismatch!");
  }
  SDL_UnlockMutex(mb->mutex);
  SDL_SignalCondition(mb->condition);
  return result;
}

bool mailbox_receive_and_lock(MailBox *mb, Sint32 timeout) {
  SDL_LockMutex(mb->mutex);
  if (!mb->is_set) {
    if (timeout < 0) {
      while (!mb->is_set) {
        SDL_WaitCondition(mb->condition, mb->mutex);
      }
    } else {
      /* Loop to guard against spurious wakeups: re-check is_set after each
         SDL_WaitConditionTimeout returns. Break only on a genuine timeout
         (return value false). */
      while (!mb->is_set) {
        if (!SDL_WaitConditionTimeout(mb->condition, mb->mutex, timeout)) {
          break; /* genuine timeout */
        }
      }
    }
  }
  return mb->is_set;
}

void mailbox_unlock(MailBox *mb) {
  mb->is_set = false;
  SDL_SignalCondition(mb->empty_condition);
  SDL_UnlockMutex(mb->mutex);
}
