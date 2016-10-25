#include <malloc.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

#include "util.h"


char *strndup(const char *s, size_t n)
{
	char *d;
	size_t i;
 
	if (!n)
		return NULL;

	d = malloc(n + 1);
	for (i = 0; i < n; i++)
		d[i] = s[i];
	d[i] = '\0';
	return d;
}

char *valuedup(const long int value)
{
	char *dec;
	dec = malloc(21);
	memset(dec,0,21);
	snprintf(dec, 21, "%ld", value);
	return dec;
}
