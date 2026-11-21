#ifndef _STRING_H
#define _STRING_H

/* 最小 string.h。实现见 support.c（不用 size_t，避免和编译器头冲突）。 */
char *strcpy(char *dst, const char *src);
int   strcmp(const char *a, const char *b);
void *memcpy(void *dst, const void *src, unsigned int n);

#endif
