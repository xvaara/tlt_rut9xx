#include <stdio.h> 
#include <stdlib.h>
#include <string.h> 
#include <malloc.h> 
#include <errno.h>
#include "files.h"
extern int errno;
extern int DEBUG;

FILE *fileOpen(const char *filename, const char *mode)
{
	FILE *fp=fopen(filename,mode);
	if (!fp) {
		if (DEBUG>5)
			printf("File Open Error %s: (%d)-%s\n",filename, errno, strerror(errno));
	}
	return fp;
}

long getsize(const char *filename)
{
	long length;
	FILE *fp=fileOpen(filename,"rb"); 
	if (!fp) {
		length = -1;
	} else { 
		fseek(fp,0L,SEEK_END); 
		length=ftell(fp); 
		fclose(fp);
	}
	return length;
}	
