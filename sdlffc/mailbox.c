#include "mailbox.h"
#include "SDL3/SDL_mutex.h"

bool mailbox_init(MailBox *mb, void *data) {
  mb->data = data;
  mb->condition = SDL_CreateCondition();
  mb->is_set = false;
  mb->mutex = SDL_CreateMutex();
  return mb->mutex && mb->condition;
}

void mailbox_done(MailBox *mb) {
  mb->is_set = false;
  SDL_DestroyCondition(mb->condition);
  SDL_DestroyMutex(mb->mutex);
}

bool mailbox_send(MailBox *mb) {
  SDL_LockMutex(mb->mutex);
  if (mb->is_set) {
    SDL_UnlockMutex(mb->mutex);
    return false;
  }
  mb->is_set = true;
  SDL_UnlockMutex(mb->mutex);
  SDL_SignalCondition(mb->condition);
  return true;
}

bool mailbox_receive_and_lock(MailBox *mb, Sint32 timeout) {
  bool is_set = false;
  SDL_LockMutex(mb->mutex);
  SDL_WaitConditionTimeout(mb->condition, mb->mutex, timeout);
  is_set= mb->is_set;
  return is_set;
}

void mailbox_unlock(MailBox *mb) {
  mb->is_set = false;
  SDL_UnlockMutex(mb->mutex);
}
