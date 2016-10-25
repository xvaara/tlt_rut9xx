/*
 * scan - functions to find and match text 
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
#include <syslog.h>

#include "util.h"
#include "scan.h"
extern int DEBUG;

#define isoctdigit(a) (a >= '0' && a <= '7')

/* Returns number of values scan will return */
int scan_count(const char *fmt)
{
	int count = 0;
	while (*fmt) {
		if (*fmt == '%') {
			if (*(++fmt) == '*')
				continue;

			while (isdigit(*fmt))
				fmt++;

			if (*fmt == 'd' || *fmt == 'i' || *fmt == 'u' ||
				*fmt == 'f' ||
				*fmt == 'o' || *fmt == 'x' || *fmt == 'X' ||
				*fmt == 'c' || *fmt == 's' || *fmt == 'b') {
				count++;
			} else {
				printf("Error: unrecognized pattern type: `%%%c'\n", *fmt);
				syslog(LOG_DEBUG, "Error: unrecognized pattern type: `%%%c'\n", *fmt);
				exit(1); // FIXME
			}
		}

		fmt++;
	}
	return count;
}

void matchString(match_t *results)
{
	if (results->values->count == results->find)
	{
		int lentotal=0;
		char *fmt = results->pattern;
		char *newstr;
		element_st *values = (element_st *)results->values->first;
		while (values){
			lentotal += strlen(values->value)+1;
			values = (element_st *)values->next;
		}
		lentotal += strlen(results->pattern);
		newstr = malloc(lentotal+1);
		int cnew = 0;
		values = (element_st *)results->values->first;
		while (*fmt && values) {
			if (*fmt == '%') {
				if (*(++fmt) == '*')
					continue;
				while (isdigit(*fmt))
					fmt++;
				if (*fmt == 'd' || *fmt == 'i' || *fmt == 'u' ||
					*fmt == 'f' ||
					*fmt == 'o' || *fmt == 'x' || *fmt == 'X' ||
					*fmt == 'c' || *fmt == 's' || *fmt == 'b') {
					char *toadd = values->value;
					while(*toadd){
						newstr[cnew++] = *toadd;
						newstr[cnew] = '\0';
						toadd++;
					}
					values = (element_st *)values->next;
				} else {
					printf("Error: unrecognized pattern type: `%%%c'\n", *fmt);
					syslog(LOG_DEBUG, "Error: unrecognized pattern type: `%%%c'\n", *fmt);
					exit(1); // FIXME
				}
			} else {
				newstr[cnew++] = *fmt;
				newstr[cnew] = '\0';
			}
			fmt++;
		}
		lentotal = strlen(newstr);
		results->string = malloc(lentotal+1);
		strcpy(results->string,newstr);
		results->string[lentotal] = '\0';
		free(newstr);
	}
}		

void addToList(list_st *list, const char *value)
{
	element_st *d, *p;
	int len = strlen(value);
	d = malloc(sizeof(element_st));
	d->value = malloc(len+1);
	strcpy(d->value, value);
	d->value[len] = '\0';
	d->next = NULL;
	if (list->last){
		p = (element_st *)list->last;
		p->next = (struct element_st *) d;
		d->prev = (struct element_st *) p;
	}
	if (list->first == NULL)
		list->first = (struct element_st *) d;
	list->last = (struct element_st *) d;
	list->count++;
}

list_st * initList(){
	list_st *list = malloc(sizeof(list_st));
	list->first = NULL;
	list->last = NULL;
	list->count = 0;
	return list;
}

match_t *initMatch(uci_logcheck *checklog, char *pattern)
{
	match_t *result = malloc(sizeof(match_t));
	result->find = scan_count(pattern);
	result->pattern = malloc(strlen(pattern)+1);
	if (result->pattern==NULL) {
		printf("Error: Memory could not be allocated creating match_t*\n");
		exit(-1);
	}
	result->values = initList();
	result->labels = initList();
	if (checklog->fields){
		char delims[] = " ";
		char *varname = NULL;
		char *flds = strdup(checklog->fields);
		varname = strtok(flds, delims);
		while( varname != NULL ) 
		{
			char tmp[65];
			sprintf( tmp, "LT_%s", varname );
			addToList(result->labels, tmp);
			varname = strtok(NULL, delims);
		}
		free(flds);
	}

	strcpy(result->pattern, pattern);
	result->string = NULL;
	return result;
}

void *freeList(list_st *list)
{
	element_st *d = (element_st *)list->first;
	while(d){
		element_st * e = d;
		d = (element_st *)d->next;
		free(e->value);
		free(e);
	}
	free(list);
	return NULL;
}

match_t *matchFree(match_t *result)
{
	if (result){
		result->values = freeList(result->values);
		result->labels = freeList(result->labels);
		result->find = 0;
		if (result->string!=NULL){
			free(result->string);
			result->string = NULL;
		}
		if (result->pattern!=NULL){
			free(result->pattern);
			result->pattern = NULL;
		}
		free(result);
		result = NULL;
	}
	return result;
}

void showMatch(match_t *result)
{
	if (result->string)
		printf("\033[1m%24s: %s\033[0m\n", "string", result->string);
	element_st *labels = (element_st *)result->labels->first;
	element_st *values = (element_st *)result->values->first;
	while (labels && values){
		printf("\033[1m%24s: \033[32m%s\033[0m\n",  labels->value, values->value);
		values = (element_st *)values->next;
		labels = (element_st *)labels->next;
	}
}

match_t *match(const char *buf, uci_logcheck *checklog, char *pattern)
{
	int init = 1;
	int match_bits = 3;
	int equal_counter = 0;
	if (DEBUG>4)
		printf("\tRulePattern: \033[1m%s\033[0m\n", pattern);
	match_t *results = initMatch(checklog, pattern);
	char *fmt = pattern;
	while (*fmt && *buf) {
		switch (*fmt)
		{
			case '%':
				init = 0;
				if (*(++fmt) == '%'){
					if (*buf != '%')
						return results;
					buf++;
				} else {
					int ignore = 0;
					int length = -1;
					long int value = 0;
					const char *start;

					if (*fmt == '*')
						ignore = 1, fmt++;

					if (isdigit(*fmt)) {
						length = atoi(fmt);
						do {
							fmt++;
						} while (isdigit(*fmt));
					}

					/* skip white spaces like scanf does */
					if (strchr("difuoxX", *fmt))
						while (isspace(*buf))
							buf++;

					start = buf;

					switch (*fmt) {
						/* if it is signed int or float,
						* we can have minus in front */
						case 'd':
						case 'i':
						case 'f':
							if (*buf == '-' && length)
								buf++, length--;
						case 'u':
							while (isdigit(*buf) && length)
								buf++, length--;

							/* integer value ends here */
							if (*fmt == 'f' && *buf == '.' && length) {
								buf++, length--;
								while (isdigit(*buf) && length)
									buf++, length--;
							}

							/* ignore if value not found */
							if (start == buf || atoi(start) == '-')
								break;

							if (!ignore)
								addToList(results->values, start);
							break;

						case 'o':
							while (isoctdigit(*buf) && length) {
								value <<= 3;
								value += *buf - '0';
								buf++, length--;
							}

							/* ignore if value not found */
							if (start == buf)
								break;

							if (!ignore) {
								char *tmp = valuedup(value);
								addToList(results->values, tmp);
								free(tmp);
							}
							break;

						case 'x':
						case 'X':
							while (isxdigit(*buf) && length) {
								value <<= 4;
								if (isdigit(*buf))
									value += *buf - '0';
								else if (islower(*buf))
										value += *buf - 'a' + 10;
									else
										value += *buf - 'A' + 10;

								buf++, length--;
							}

							/* ignore if value not found */
							if (start == buf)
								break;

							if (!ignore) {
								char *tmp = valuedup(value);
								addToList(results->values, tmp);
								free(tmp);
							}
							break;

						case 's':
							while (!isspace(*buf) && length && *buf != *(fmt + 1)) {
								buf++, length--;
							}
 
							if (!ignore){
								addToList(results->values, start);
							}
							break;

						case 'b':
							while (buf && *buf != *(fmt + 1)) {
								buf++, length--;
							}
 
							if (!ignore)
								addToList(results->values, start);
							break;

						case 'c':
							if (length < 0)
								length = 1;        // default length is 1

							while (*buf && length > 0) {
								buf++, length--;
							}
							if (length > 0)
								return results;
							if (!ignore)
								addToList(results->values, start);
							break;
						default: /* should never happen! */
//							send_log(LOG_DEBUG,"Error: unrecognized pattern type: `%%%c'\n", *fmt);
							exit(1); // FIXME
					}
				}
				fmt++;
				break;
			default:
				if (init){
					if(equal_counter >= match_bits){
						break;
					}
					equal_counter++;
					while (*buf != *fmt && *buf && *fmt)
						buf++;
				}
		}
		if (*buf != *fmt) break;
		fmt++; buf++;
	}
	matchString(results);
	return results;
}

struct ban_element *ban_get_elem(ban_list *bans, match_t *matchst, char *label_name)
{
	if (!bans) {
		fprintf(stderr, "ban_get_elem. ERROR: no bans list\n");
		return NULL;
	}
	
	element_st *labels = (element_st *)matchst->labels->first;
	element_st *values = (element_st *)matchst->values->first;
	
	while (labels && values) {
		if (!strcmp(labels->value, label_name)) {
			//printf("rado1: %s\n", values->value);
			struct ban_element *elem = list_get_elem_by_data(bans, values->value);
			if (elem) {
				//printf("rado2: %p\n", elem);
				return elem;
			}
		}
		values = (element_st *)values->next;
		labels = (element_st *)labels->next;
	}
	
	return NULL;
}

int ban_add_elem(ban_list *bans, match_t *matchst, char *label_name)
{
	printf("MANO ban_add_elem\n");
	if (!bans) {
		fprintf(stderr, "ban_add_elem. ERROR: no bans list\n");
		return -1;
	}
	
	element_st *labels = (element_st *)matchst->labels->first;
	element_st *values = (element_st *)matchst->values->first;
	
	while (labels && values) {
		if (!strcmp(labels->value, label_name)) {
			//printf("rado: %s\n", values->value);
			char *data = malloc(strlen(values->value) + 1);
			if (!data) {
				fprintf(stderr, "ban_add_elem. malloc ERROR\n");
				return -1;
			}
			strcpy(data, values->value);
			struct ban_element *elem = list_add_elem(bans, data);
			if (!elem) {
				fprintf(stderr, "ban_add_data. list_add_elem ERROR\n");
				return -1;
			}
			elem->fail = 1;
			return 0;
		}
		values = (element_st *)values->next;
		labels = (element_st *)labels->next;
	}
	return -1;
}
