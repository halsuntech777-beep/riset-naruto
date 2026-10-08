#define _GNU_SOURCE
#include <math.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
float acosf(float x){return (float)acos((double)x);}
float asinf(float x){return (float)asin((double)x);}
float atan2f(float y,float x){return (float)atan2((double)y,(double)x);}
float log10f(float x){return (float)log10((double)x);}
float sqrtf(float x){return (float)sqrt((double)x);}
float remainderf(float x,float y){return (float)remainder((double)x,(double)y);}
double remainder(double x,double y){int q; return remquo(x,y,&q);}
void free_sized(void*p,size_t s){(void)s;free(p);}
void free_aligned_sized(void*p,size_t a,size_t s){(void)a;(void)s;free(p);}
void* __memset_explicit_chk(void*s,int c,size_t n,size_t d){(void)d;memset(s,c,n);__asm__ volatile("":::"memory");return s;}
speed_t cfgetospeed(const struct termios*t){return t->c_cflag&(CBAUD|CBAUDEX);}
speed_t cfgetispeed(const struct termios*t){speed_t s=(t->c_cflag&CIBAUD)>>16;return s?s:cfgetospeed(t);}
extern void FcDefaultSubstitute(void*);
int FcConfigSetDefaultSubstitute(void*config,void*pat){(void)config;FcDefaultSubstitute(pat);return 1;}
extern void* wl_display_create_queue(void*);
void* wl_display_create_queue_with_name(void*d,const char*n){(void)n;return wl_display_create_queue(d);}
