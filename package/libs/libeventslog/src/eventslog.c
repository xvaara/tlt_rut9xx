#include "libevents.h"

char *return_eventslog(struct eventslog *new_task) {

	int buffer_size = 5500000;
	int query_size =512;
	char *buffer=NULL;
	char tmp_query[query_size];
	fd_set readfds;
	int socket_fd=-1, len;
	struct sockaddr_un remote;
	int a, find_ok = 0, skip=0;
	struct timeval timeout;

	buffer = (char*)calloc( 1, buffer_size);
	if (!buffer) {
		goto ERROR;
	}

	if( new_task->table ){
		if( new_task->date == 1 ) {
			strcpy(tmp_query, "select ID, datetime(`TIME`, 'unixepoch', 'localtime') as TIME, NAME, TEXT from ");
		}else{
			strcpy(tmp_query, "select * from ");
		}

		if(strncasecmp(new_task->table, "ALL", 3) == 0){
			sprintf(buffer, "%s EVENTS UNION ALL %s CONNECTIONS order by TIME", tmp_query, tmp_query);
		}else if( strncasecmp(new_task->table, "events", 6) == 0 || strncasecmp(new_task->table, "connections", 11) == 0){
			sprintf(buffer, "%s %s", tmp_query, new_task->table);
		}else{
			goto ERROR;
		}

	}else{
		goto ERROR;
	}

	if( new_task->query ){
		strcat(buffer, " ");
		strcat(buffer, new_task->query);
	}

	if( new_task->order ){
		strcat(buffer, " ORDER BY ");
		strcat(buffer, new_task->order);
	}

	if( new_task->limit ){
		strcat(buffer, " LIMIT ");
		strcat(buffer, new_task->limit);
	}

	if ((socket_fd = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
		goto ERROR;
	}

	remote.sun_family = AF_UNIX;
	strcpy(remote.sun_path, LOG_UNIX_SOCK_PATH);
	len = strlen(remote.sun_path) + sizeof(remote.sun_family);

	if (connect(socket_fd, (struct sockaddr *)&remote, len) == -1) {
		goto ERROR_socket;
	}

	if ( send( socket_fd, buffer, strlen(buffer), 0) == -1) {
		goto ERROR_socket;
	}

	timeout.tv_sec = 5;
	timeout.tv_usec = 0;

	while(socket_fd){
		FD_ZERO(&readfds);
		FD_SET(socket_fd, &readfds);

		if (select(socket_fd+1, &readfds, NULL, NULL, &timeout) < 0){
			perror("on select");
			goto ERROR_socket;
		}

		if (FD_ISSET(socket_fd, &readfds)){
			a=recv(socket_fd, buffer, buffer_size-1, 0);
			buffer[a]='\0';
			if( strncmp(buffer, "OK=\n", 4) == 0 ){
				find_ok = 1;
				break;
			}else if( strncmp(buffer, "ER=\n", 4) == 0 ){
				find_ok = 0;
				break;
			}
		}
	}

ERROR_socket:
	if(socket_fd)
		close(socket_fd);
ERROR:
	if(find_ok)
		return buffer;
	else{
		if(buffer)
			free(buffer);
		return NULL;
	}
}

int print_events_log_db(struct eventslog *new_task) {

	int query_size =512;
	char full_query[query_size];
	char tmp_query[query_size];
	fd_set readfds;
	int socket_fd=-1, len;
	struct sockaddr_un remote;
	int a, find_ok = 0, skip=0;
	FILE *f = NULL;
	struct timeval timeout;

	if( new_task->table ){
		if( new_task->date == 1 ) {
			strcpy(full_query, "select ID, datetime(`TIME`, 'unixepoch', 'localtime') as TIME, NAME, TEXT from ");
		}else{
			strcpy(full_query, "select * from ");
		}

		if(strncasecmp(new_task->table, "ALL", 3) == 0){
			sprintf(tmp_query, "%s EVENTS UNION ALL %s CONNECTIONS order by TIME", full_query, full_query);
			strcpy(full_query, tmp_query);
		}else if( strncasecmp(new_task->table, "events", 6) == 0 || strncasecmp(new_task->table, "connections", 11) == 0){
			strcat(full_query, new_task->table);
		}else{
			goto ERROR;
		}
	}else{
		goto ERROR;
	}

	if( new_task->query ){
		strcat(full_query, " ");
		strcat(full_query, new_task->query);
	}

	if( new_task->order ){
		strcat(full_query, " ORDER BY ");
		strcat(full_query, new_task->order);
	}

	if( new_task->limit ){
		strcat(full_query, " LIMIT ");
		strcat(full_query, new_task->limit);
	}

	if( new_task->file ){
		f = fopen( new_task->file, "w");
		if (f == NULL){
			goto ERROR;
		}

	}else if( new_task->file_end ){
		f = fopen( new_task->file_end, "a");
		if (f == NULL){
			goto ERROR;
		}
	}

	if ((socket_fd = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
		goto ERROR_file;
	}

	remote.sun_family = AF_UNIX;
	strcpy(remote.sun_path, LOG_UNIX_SOCK_PATH);
	len = strlen(remote.sun_path) + sizeof(remote.sun_family);

	if (connect(socket_fd, (struct sockaddr *)&remote, len) == -1) {
		goto ERROR_socket;
	}

	if ( send( socket_fd, full_query, strlen(full_query), 0) == -1) {
		//fprintf(stderr, "Error: %s\n", strerror( errno ));
		goto ERROR_socket;
	}

	timeout.tv_sec = 5;
	timeout.tv_usec = 0;

	while(socket_fd){
		FD_ZERO(&readfds);
		FD_SET(socket_fd, &readfds);

		if (select(socket_fd+1, &readfds, NULL, NULL, &timeout) < 0){
			perror("on select");
			goto ERROR_socket;
		}

		if (FD_ISSET(socket_fd, &readfds)){
			a=recv(socket_fd, full_query, query_size-1, 0);
			full_query[a]='\0';
			if( find_ok == 0){
				if( strncmp(full_query, "OK=\n", 4) == 0 ){
					find_ok = 1;
					skip = 4;
				}else if( strncmp(full_query, "ER=\n", 4) == 0 ){
					goto ERROR_socket;
				}
			}

			if (a>0){
				if( find_ok == 1 ){
					if ( f ){
						fprintf(f, "%s", full_query + skip);
					}else
						printf("%s", full_query + skip);
					skip=0;
				}
			}else{
				if( find_ok != 1 ){
					goto ERROR_socket;
				}
				break;
			}
		}
	}

	if ( f )
		fclose(f);

	close(socket_fd);
	return 0;

ERROR_socket:
	close(socket_fd);
ERROR_file:
	if ( f )
		fclose(f);
ERROR:
	return 1;
}

int insert_events_log_db(struct eventslog *new_task) {
	int query_size =512;
	char full_query[query_size];
	fd_set readfds;
	int socket_fd=-1, len;
	struct sockaddr_un remote;
	int a;
	int status;
	int i;
	time_t rawtime;
	int error = 1;
	struct timeval timeout;
	timeout.tv_sec = 5;
	timeout.tv_usec = 0;

	if ( !new_task->table || !new_task->type || !new_task->text ){
		goto EXIT;
	}

	if( strncasecmp(new_task->table, "events", 6) == 0 || strncasecmp(new_task->table, "connections", 11) == 0){
		sprintf(full_query, "INSERT INTO %s ('TIME', 'NAME', 'TEXT') VALUES ('%d', '%s', '%s');", new_task->table, time (&rawtime), new_task->type, new_task->text);
	}else{
		goto EXIT;
	}

	if ((socket_fd = socket(AF_UNIX, SOCK_STREAM, 0)) == -1) {
		goto EXIT;
	}

	remote.sun_family = AF_UNIX;
	strcpy(remote.sun_path, LOG_UNIX_SOCK_PATH);
	len = strlen(remote.sun_path) + sizeof(remote.sun_family);

	if (connect(socket_fd, (struct sockaddr *)&remote, len) == -1) {
		goto EXIT_socket;
	}

	if ( send( socket_fd, full_query, strlen(full_query), 0) == -1) {
		//fprintf(stderr, "Error: %s\n", strerror( errno ));
		goto EXIT_socket;
	}

	while(socket_fd){
		FD_ZERO(&readfds);
		FD_SET(socket_fd, &readfds);

		if (select(socket_fd+1, &readfds, NULL, NULL, &timeout) < 0){
			goto EXIT_socket;
		}

		if (FD_ISSET(socket_fd, &readfds)){
			a=recv(socket_fd, full_query, query_size-1, 0);
			full_query[a]='\0';
			if ( a > 0 ){
				if( strncmp(full_query, "OK=\n", 4) == 0 ){
					error=0;
					goto EXIT_socket;
				}else if( strncmp(full_query, "ER=\n", 4) == 0 ){
					error=1;
					goto EXIT_socket;
				}
			}else{
				break;
			}
		}
	}

EXIT_socket:
	close(socket_fd);

EXIT:
	call_messaged(new_task->type, new_task->text);
	return error;
}

void call_messaged(char *type, char *text){
	int a=1;
	FILE *fp = NULL;
	char buffer[1035];

	/* Open the command for reading. */
	fp = popen("ps w", "r");
	if (fp == NULL) {
		printf("Failed to run command\n" );
		return;
	}
	while (fgets(buffer, sizeof(buffer)-1, fp) != NULL) {
		if(strstr(buffer, "/usr/sbin/messaged") != NULL) { //check if messeged is in ps
			a=0;
			break;
		}
	}
	pclose(fp);
	fp = NULL;

	if( a == 1 ){
		sprintf( buffer, "/usr/sbin/messaged 'event' '%s' '%s' &", type, text); // call messaged
		system( buffer);
	}else{
		fp = fopen("/tmp/events_to_check", "a"); // write to file if messaged is working
		if (fp == NULL){
			printf("Error opening file!\n");
			return;
		}
		fprintf(fp, "%s|%s|\n", type, text);
		fclose(fp);
	}
}

void default_task(struct eventslog *new_task) {
	new_task->table = NULL;
	new_task->query = NULL;
	new_task->date = 0;
	new_task->limit = NULL;
	new_task->type = NULL;
	new_task->text = NULL;
	new_task->order = NULL;
	new_task->file = NULL;
	new_task->file_end = NULL;
}

int execute_task(struct eventslog *new_task){
	int ret = 0;
	switch (new_task->requests) {
		case PRINT_DB:
			ret = print_events_log_db( new_task);
			break;
		case INSERT:
			ret=insert_events_log_db( new_task);
			break;
	}
	return ret;
}

void insert_event_into_db(char *tabl, char *typ, char *txt){
	struct eventslog new_task;
	default_task(&new_task);
	new_task.requests = INSERT;
	new_task.table = tabl;
	new_task.type = typ;
	new_task.text = txt;
	execute_task(&new_task);
}
