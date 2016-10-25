#ifndef _LOGTRIGGER_SCAN_H
#define _LOGTRIGGER_SCAN_H
#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <malloc.h>
#include "pairs.h"
#include "confreg.h"
#include "list.h"

typedef struct {
	char *value;
	struct element_st *next;
	struct element_st *prev;
} element_st;

typedef struct {
	struct element_st *first;
	struct element_st *last;
	int count;
} list_st;

typedef struct {
	int find;
	list_st *labels;
	list_st *values;
	char *pattern;
	char *string;
} match_t;

int scan_count(const char *fmt);
void matchString(match_t *result);
void addToList(list_st *list, const char *value);
list_st * initList();
match_t *initMatch(uci_logcheck *checklog, char *pattern);
void *freeList(list_st *list);
match_t *matchFree(match_t *result);

void showMatch(match_t *result);
match_t *match(const char *buf, uci_logcheck *checklog, char *pattern);
struct ban_element *ban_get_elem(ban_list *bans, match_t *matchst, char *label_name);
int ban_add_elem(ban_list *bans, match_t *matchst, char *label_name);
#endif
