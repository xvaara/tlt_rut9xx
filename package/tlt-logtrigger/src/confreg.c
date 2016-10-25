#include <stdio.h>
#include <strings.h>
#include <string.h>
#include <stddef.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdbool.h>
#include "util.h"
#include "files.h"
#include "confreg.h"
#include "logread.h"

extern int DEBUG;

uci_list *listNew()
{
	uci_list *list = malloc(sizeof(uci_list));
	list->first = NULL;
	list->last = NULL;
	list->count = 0;
	return list;
}

uci_logcheck *listAddlogcheck(uci_list* list, int enable, char* name, char* pattern, char* pattern_ok, char* fields, int maxfail, char *script, char *service, char *host, char *logfile, char *id, pairlist_st *params)
{
	uci_logcheck *d;
	uci_logcheck *p;
	d = malloc(sizeof(uci_logcheck));
	d->enable = enable;
	d->name = name;
	d->pattern = pattern;
	d->pattern_ok = pattern_ok;
	d->fields = fields;
	d->maxfail = maxfail;
	d->script = script;
	d->service = service;
	d->host = host;
	d->logfile = logfile;
	d->id = id;
	d->params = (pairlist_st *) params;
	d->next = NULL;
	d->bans = list_init();
	if (list->last){
		p = list->last;
		p->next = d;
		d->prev = p;
	}
	if (list->first == NULL)
		list->first = d;
	list->last = d;
	list->count++;
	return d;
}

filelist_st *newFileList()
{
	filelist_st *list = malloc(sizeof(filelist_st));
	list->first = NULL;
	list->last = NULL;
	list->count = 0;
	return list;
}

file_st * addFile(filelist_st *list, const char *filename, const char *id, int disabled)
{
	file_st *d;
	file_st *p;

	d = malloc(sizeof(file_st));
	if (filename)
		d->name = strndup(filename,strlen(filename));
	else
		d->name = NULL;
	if (id)
		d->id = strndup(id,strlen(id));
	else
		d->id = NULL;
		
	if (filename && !strcmp(filename,"OpenWrtLogSharedMemory"))
		d->lasteof = get_tail();
	else
		d->lasteof = getsize(filename);
	if (d->lasteof < 0)
		disabled++;
	d->disabled = disabled;
	d->next = NULL;
	if (list->last){
		p = (file_st *)list->last;
		p->next = (struct file_st *)d;
		d->prev = (struct file_st *)p;
	}
	if (list->first == NULL)
		list->first = (struct file_st *)d;
	list->last = (struct file_st *)d;
	list->count++;
	if (DEBUG>4)
		printf("(%d) Adding %s to file list with ID: %s\n", list->count, filename, id);
	return d;
}
