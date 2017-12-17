//
//  TM_Thread.h
//  LanTransmiter
//
//  Created by 天明 on 2017/12/15.
//  Copyright © 2017年 天明. All rights reserved.
//

#ifndef SDL_Thread_h
#define SDL_Thread_h

#include <stdio.h>
#include <pthread.h>
/////////
typedef struct SDL_Thread {
    pthread_t id;
    void* (*func)(void *);
    void *data;
    int retval;
    
} SDL_Thread;

SDL_Thread *SDL_CreateThread(void* (*fn)(void *), void *data);
/////////

#define SDL_MUTEX_TIMEDOUT  1
typedef struct SDL_mutex {
    pthread_mutex_t id;
} SDL_mutex;

SDL_mutex  *SDL_CreateMutex(void);
void        SDL_DestroyMutex(SDL_mutex *mutex);
void        SDL_DestroyMutexP(SDL_mutex **mutex);
int         SDL_LockMutex(SDL_mutex *mutex);
int         SDL_UnlockMutex(SDL_mutex *mutex);

typedef struct SDL_cond {
    pthread_cond_t id;
} SDL_cond;

SDL_cond   *SDL_CreateCond(void);
void        SDL_DestroyCond(SDL_cond *cond);
void        SDL_DestroyCondP(SDL_cond **mutex);
int         SDL_CondSignal(SDL_cond *cond);
int         SDL_CondBroadcast(SDL_cond *cond);
int         SDL_CondWaitTimeout(SDL_cond *cond, SDL_mutex *mutex, uint32_t ms);
int         SDL_CondWait(SDL_cond *cond, SDL_mutex *mutex);




#endif /* TM_Thread_h */
