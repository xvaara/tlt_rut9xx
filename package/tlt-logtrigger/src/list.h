#ifndef _LOGTRIGGER_LIST_H
#define _LOGTRIGGER_LIST_H

struct ban_element {
	void *data;
	int fail;
	struct ban_element *next;
	struct ban_element *prev;
};

typedef struct {
	struct ban_element *first;
	struct ban_element *last;
	int count;
} ban_list;

/*typedef struct {
	char rule[;
} ban_data;*/

struct ban_element *list_add_elem(ban_list *list, void *data);
int list_delete(ban_list *list, struct ban_element *elem);
int list_print(ban_list *list);
ban_list *list_init(void);
struct ban_element *list_get_elem_by_data(ban_list *list, char *data);

#endif