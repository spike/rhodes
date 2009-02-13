#include "symbian.h"

#include <sys/signal.h>
#include <fcntl.h>
#include <pthreadtypes.h>

char **environ = 0;

typedef void (*sighandler_t)(int);

sighandler_t signal(int signum, sighandler_t handler)
{
	return (sighandler_t)0;
}

int sigfillset(sigset_t * set)
{
	return 0;
}
	
int sigdelset(sigset_t * set, int signum)
{
	return 0;
}

int sigprocmask(int how, const sigset_t * set, sigset_t * oldset)
{
	return 0;
}

int raise(int sig)
{
	return 0;
}

int kill(pid_t pid, int sig)
{
	return 0;
}

int pthread_sigmask(int how, const sigset_t * set, sigset_t * oset)
{
	return -1;
}	

int pthread_kill(pthread_t thread, int sig)
{
	return -1;
}

int sigmask(int signum) {
	return -1;
}

int sigblock(int mask) {
	return -1;
}

int sigsetmask(int mask) {
	return -1;
}

sighandler_t posix_signal(int signum, sighandler_t handler)
{
    return signal((signum),(handler));
}

int execl(const char * arg1, const char * arg2, ...){
  return 0;
}

int execv(const char *path, char *const argv[]){
  return 0;
}

/*int _symbian_close(int fd){
	return close(fd);
}*/
