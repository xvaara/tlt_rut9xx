/*
 * list - functions to keep track of found matches
 *
 * Copyright (C) 2015 Teltonika
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

#include <ctype.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <malloc.h>

#include "list.h"

extern int DEBUG;

struct ban_element *list_add_elem(ban_list *list, void *data)
{
	struct ban_element *new;

	new = malloc(sizeof(struct ban_element));
	if (!new) {
		fprintf(stderr, "list_add_elem. malloc ERROR\n");
		return NULL;
	}
	
	memset(new, 0, sizeof(struct ban_element));
	new->data = data;
	new->next = NULL;
	if (list->last) {
		list->last->next = new;
		new->prev = list->last;
	}
	if (list->first == NULL)
		list->first = new;
	list->last = new;
	list->count++;
	return new;
}

int list_delete(ban_list *list, struct ban_element *elem)
{
	struct ban_element *curr;
	
	if (!elem)
		return -1;
	
	curr = list->first;
	while (curr) {
		if (curr == elem) {
			if (curr == list->first) {
				list->first = curr->next;
				if (curr->next)
					curr->next->prev = NULL;
			} else if (curr == list->last) {
				list->last = curr->prev;
				if (curr->prev)
					curr->prev->next = NULL;
			} else {
				curr->next->prev = curr->prev;
				curr->prev->next = curr->next;
			}
			
			if (elem->data)
				free(elem->data);
			free(curr);
			list->count--;
			
			if (list->count == 0)
				list->last = NULL;
			
			return 0;
		}
		curr = curr->next;
	}
	
	fprintf(stderr, "list_delete. ERROR: element not found\n");
	return -1;
}

int list_print(ban_list *list)
{
	struct ban_element *curr = list->first;
	
	printf("list: %p, len: %d, first: %p, last: %p\n", list, list->count, list->first, list->last);
	
	while (curr) {
		printf("\tcurr: %p, pr: %p, \tnext: %p,    \tfail: %d, \tdata: %p, '%s'\n",
			curr, curr->prev, curr->next, curr->fail, curr->data, (char *)curr->data);
		curr = curr->next;
	}
	
	return 0;
}

ban_list *list_init(void)
{
	ban_list *list = malloc(sizeof(ban_list));
	
	if (!list) {
		fprintf(stderr, "list_init. malloc ERROR\n");
		return NULL;
	}
	
	list->first = NULL;
	list->last = NULL;
	list->count = 0;
	return list;
}

struct ban_element *list_get_elem_by_data(ban_list *list, char *data)
{
	struct ban_element *curr = list->first;
	
	while (curr) {
		if (!strcmp(curr->data, data)) {
			printf("MANO list_get_elem_by_data. found: %p\n", curr);
			return curr;
		}
		curr = curr->next;
	}
	
	printf("MANO list_get_elem_by_data. Not found\n");
	return NULL;
}
