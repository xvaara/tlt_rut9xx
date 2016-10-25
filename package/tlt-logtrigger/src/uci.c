/*
 * uci - interface to read uci files
 *
 * Copyright (C) 2010 Fabian Omar Franzotti <fofware@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU Lesser General Public License version 2.1
 * as published by the Free Software Foundation
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 */
/*
 * Special Thanks to Jo-Philipp Wich 
 */
#include <stdio.h>
#include <strings.h>
#include <string.h>
#include <stddef.h>
#include <stdlib.h>
#include <unistd.h>
#include <stdbool.h>
#include "util.h"
#include "files.h"
#include "uci.h"

extern int DEBUG;
extern uci_list *listlogcheck;
extern filelist_st *files;

void read_conf_uci(const char *name)
{
	struct uci_context *ctx;
	struct uci_package *p = NULL;

	ctx = uci_alloc_context();
	if (!ctx)
		return;

	uci_load(ctx, name, &p);
	if (!p) {
		uci_perror(ctx, "Failed to load config file: ");
		uci_free_context(ctx);
		exit(-1);
	}

	parse_sections(p);
	uci_free_context(ctx);
}

void do_logcheck(struct uci_section *s)
{
	struct uci_element *n;
	bool enabled=0;
	char *name=NULL;
	char *pattern=NULL;
	char *pattern_ok=NULL;
	char *fields=NULL;
	int maxfail = 0;
	char *script=NULL;
	char *host=NULL;
	char *service=NULL;
	char *logfile=NULL;
	char *id=NULL;
	
	pairlist_st *params = (pairlist_st *)newPairList();
	
	uci_foreach_element(&s->options, n) {
		struct uci_option *o = uci_to_option(n);
		if (!strcmp(n->name,"enabled")){
			if(!strcmp(o->v.string,"1")){
				enabled=1;
			}else{
				enabled=0;
			}
		} else if (!strcmp(n->name,"name")){
			name = malloc(strlen(o->v.string));
			strcpy(name,o->v.string);
		} else if (!strcmp(n->name,"pattern")){
			pattern = malloc(strlen(o->v.string));
			strcpy(pattern,o->v.string);
		} else if (!strcmp(n->name,"pattern_ok")){
			pattern_ok = malloc(strlen(o->v.string));
			strcpy(pattern_ok,o->v.string);
		} else if (!strcmp(n->name,"fields")){
			fields = malloc(strlen(o->v.string));
			strcpy(fields,o->v.string);
		} else if (!strcmp(n->name,"script")){
			script = malloc(strlen(o->v.string));
			strcpy(script,o->v.string);
/*
		} else if (!strcmp(n->name,"service")){
			service = strndup(o->v.string, strlen(o->v.string));
		} else if (!strcmp(n->name,"host")){
			host = strndup(o->v.string, strlen(o->v.string));
		} else if (!strcmp(n->name,"logfile")){
			logfile = strndup(o->v.string, strlen(o->v.string));
		} else if (!strcmp(n->name,"id")){
			id = strndup(o->v.string, strlen(o->v.string));
*/
		} else if (!strcmp(n->name,"maxfail")){
			maxfail = atoi(o->v.string);
		} else {  // Add user parameters to destination script
			char tmp[65];
			sprintf( tmp, "LT_%s", n->name );
			addPair(params, tmp, o->v.string);
		}
	}
	if (enabled == 1){
		listAddlogcheck(listlogcheck, enabled, name, pattern, pattern_ok, fields, maxfail, script, service, host, logfile, id, params );
	} else {
		if (name) free(name);
		if (pattern) free(pattern);
		if (fields) free(fields);
		if (script) free(script);
		if (id) free(id);
		if (logfile) free(logfile);
		if (service) free(service);
		if (host) free(host);
		if (params) params = freePairList(params);
	}
}

void do_logfiles(struct uci_section *s)
{
	struct uci_element *n;
	int disabled = 0;
	key_t key = 0;
	char *logfilename=NULL;
	char *id=NULL;
	
	uci_foreach_element(&s->options, n) {
		struct uci_option *o = uci_to_option(n);
		if (!strcmp(n->name,"disabled")){
			disabled = atoi(o->v.string);
		} else if (!strcmp(n->name,"file")){
			logfilename = strndup(o->v.string, strlen(o->v.string));
		} else if (!strcmp(n->name,"id")){
			id = strndup(o->v.string, strlen(o->v.string));
		} else if (!strcmp(n->name,"key")){
			if (logfilename)
				free(logfilename);
			logfilename=strndup("nofile_sharedmemory",19);
			sscanf(o->v.string, "0x%x", &key); 
		}
		if(DEBUG>5)
			printf("\t%s->%s\n", n->name, o->v.string);
	}
	if (disabled==0){
		file_st * p = addFile(files,logfilename, id, disabled);
		if(DEBUG>5)
			printf("%s: %ld %d %d\n",p->name, p->lasteof, p->disabled, p->key);
	} else {
		if (DEBUG>5)
			printf("Discard %s", logfilename);
	}
	disabled = 0;
	key = 0;
	if (logfilename) free(logfilename);
	if (id) free(id);
}


void parse_sections(struct uci_package *p)
{
	struct uci_element *e;
	struct uci_section *s;
	uci_foreach_element(&p->sections, e) {
		s = uci_to_section(e);
		if (strcmp(s->type, "rule") == 0){
			do_logcheck(s);
		}

		if (strcmp(s->type, "logfile") == 0){
			do_logfiles(s);
		}
	}
	
}
