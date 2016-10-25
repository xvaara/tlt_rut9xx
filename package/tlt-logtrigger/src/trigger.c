/*
 * trigger - Trigger script for syslog message
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

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <signal.h>
#include <malloc.h>
#include <time.h>
#include <regex.h>
//#define SYSLOG_NAMES
//#define SYSLOG_NAMES_CONST
#include <syslog.h>
#include <unistd.h>

//#include <sys/types.h>
//#include <sys/stat.h>
//#include <fcntl.h>
//#include <sys/socket.h>

#include "config.h"
#include "scan.h"
#include "pairs.h"
#include "util.h"
#include "confreg.h"
#include "trigger.h"
#include "logread.h"
#include "uci.h"


extern int DEBUG;
uci_list *listlogcheck;
filelist_st *files;
//file_st *file = NULL;
extern char logread_buf[10000];

char *matchre(const char *strdata, const char *pattern) 
{
    regex_t    preg;
    int        rc;
    size_t     nmatch = 10;
    regmatch_t pmatch[10];
	char *ret_val = NULL;
	
	if (strlen(strdata) == 0 || strlen(pattern) == 0)
		return NULL;

    if ((rc = regcomp(&preg, pattern, REG_EXTENDED)) != 0) {                    
//       printf("regcomp() failed, returning nonzero (%d)\n", rc);                
       return NULL;                                                                 
    }                                                                           
                                                                                
	if ((rc = regexec(&preg, strdata, nmatch, pmatch, 0)) != 0) {                
//		printf("failed to ERE match \nstring :'%s' \nwith pattern: '%s'\nreturning %d.\n",             
//		string, pattern, rc);                                                    
		regfree(&preg);
		return NULL;
	}
	int len = (pmatch[0].rm_eo-pmatch[0].rm_so);
	ret_val = malloc(len+1);
	memset(ret_val,0,len+1);
	strncpy(ret_val,strdata +pmatch[0].rm_so,len);
	regfree(&preg);
	return ret_val;
}

void prepare_runscript(uci_logcheck *checklog, match_t *matchst, char *message, int fail)
{
	char *str_ip = matchre(message,"([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})\\.([0-9]{1,3})");
	char *str_mac = matchre(message,"([0-9a-fA-F]{2}[:-]){6}");
	runscript(checklog, matchst, str_ip, str_mac, fail, message);
	if (str_ip)
		free(str_ip);
	if (str_mac)
		free(str_mac);
}

int runscript(uci_logcheck *checklog, match_t *matchst, const char *str_ip, const char *str_mac, int fail, const char *message/*, file_st *file*/)
{
	pairlist_st *data = (pairlist_st *) newPairList();
	pair_st *params;
	
	if (checklog->name)
		addPair(data, "LT_name", checklog->name);
	if (message)
		addPair(data, "LT_message", message);
	if (checklog->pattern)
		addPair(data, "LT_pattern", checklog->pattern);
	if (matchst->string)
		addPair(data, "LT_string", matchst->string);
	if (fail) {
		char *tmp = valuedup(fail);
		addPair(data, "LT_count", tmp);
		free(tmp);
	}
	/*if (file->name)
		addPair(data, "LT_generator", file->name);*/
		
	params = (pair_st *)checklog->params->first;
	
	element_st *labels = (element_st *)matchst->labels->first;
	element_st *values = (element_st *)matchst->values->first;
	
	time_t tm1;
	struct tm *ltime;
	time( &tm1 );
	ltime = localtime( &tm1 );
	char mes[4];
	char str_date[16];
	sscanf (message, "%s %d %d:%d:%d", mes, &ltime->tm_mday, &ltime->tm_hour, &ltime->tm_min,&ltime->tm_sec);

	strftime(str_date, sizeof(str_date), "%Y/%m/%d", ltime);
	addPair(data, "LT_date", str_date);

	strftime(str_date, sizeof(str_date), "%H:%M:%S", ltime);
	addPair(data, "LT_time", str_date);
	tm1 = mktime(ltime);
	sprintf(str_date,"%ld", tm1);
	addPair(data, "LT_datetime", str_date); 
	while (labels && values){
		addPair(data, labels->value, values->value);
		values = (element_st *)values->next;
		labels = (element_st *)labels->next;
	}

	while (params){
		addPair(data, params->name, params->value);
		params = (pair_st *)params->next;
	}

	pair_st *tosend = (pair_st *)data->first;
	if(DEBUG)
		printf("\033[0m%24s: \033[33m\033[1m%s\033[0m\n", "Call action script", checklog->script);
	if(DEBUG > 1){
		while(tosend)
		{
			printf("\033[1m%24s: \033[32m%s\033[0m\n", tosend->name, tosend->value);
			tosend = (pair_st *)tosend->next;
		}
		tosend = (pair_st *)data->first;
	}

	int status;
	if ((status = fork()) < 0) {
		printf("\033[0m");
		syslog (LOG_ERR, "logtrigger: fork() returned -1!");
		data = (pairlist_st *)freePairList((pairlist_st *)data);
		return 0;
	}

	if (status > 0) { /* Parent */
		data = (pairlist_st *)freePairList((pairlist_st *)data);
		return 0; 
	}

	int ret;
	while(tosend)
	{
		if ((ret=setenv(tosend->name, tosend->value, 1)) != 0){
			syslog(LOG_ERR, "logtrigger: setenv(%s=%s) did return %d",tosend->name, tosend->value,ret);
			data = (pairlist_st *)freePairList((pairlist_st *)data);
			exit(0);
		}
		tosend = (pair_st *)tosend->next;
	}

	if ( (ret = execl(checklog->script, checklog->script, (char *)0)) != 0 ) {
		syslog (LOG_ERR,"logtrigger: run script (%s) did return %d", checklog->script,ret);
		data = (pairlist_st *)freePairList((pairlist_st *)data);
		exit(0);
	}

	data = (pairlist_st *)freePairList((pairlist_st *)data);
	exit(0);
}


void  processMsg(char *msglog/*, file_st *file*/)
{
	char *sep = "\n";
	char *message, *brkt;
	char success;

	for (message = strtok_r(msglog, sep, &brkt);
		message;
		message = strtok_r(NULL, sep, &brkt))
	{
		if (message == NULL) break;
		if(DEBUG>1){
			printf("\033[1mMsg :\t%s\033[0m\n", message);
		}
		uci_logcheck *checklog = listlogcheck->first;

		while (checklog != NULL){
			if (!checklog->logfile && !checklog->id) {
				if (DEBUG>5){
					printf("\033[1mCheck\033[0m");
					printf("\tRuleName   : \033[1m%s\033[0m\n", checklog->name);
					//printf("\tRuleLogfile: \033[1m%s\033[0m / logfile : \033[1m%s\033[0m\n", checklog->logfile, file->name);
					printf("\tRuleId     : \033[1m%s\033[0m\n", checklog->id);
				}
				success = 0;
				match_t *matchst = match(message, checklog, checklog->pattern);
				if (DEBUG > 2)
					showMatch(matchst);
				if (!matchst->string && checklog->pattern_ok) {
					success = 1;
					if (matchst)
						matchst = matchFree(matchst);
					matchst = match(message, checklog, checklog->pattern_ok);
					if (DEBUG > 2)
						showMatch(matchst);
				}
				if (matchst->string)
				{
					if (DEBUG>1)
						printf("processMsg. Pattern found: %d\n", success);
					if (success) {
						//Successful connection
						struct ban_element *elem = ban_get_elem(checklog->bans, matchst, "LT_ip");
						if (elem) {
							list_delete(checklog->bans, elem);
						}
					} else {
						//Failed connection
						struct ban_element *elem = ban_get_elem(checklog->bans, matchst, "LT_ip");
						if (elem) {
							//Increment fail counter
							if (++elem->fail >= checklog->maxfail) {
								prepare_runscript(checklog, matchst, message, elem->fail);
								list_delete(checklog->bans, elem);
							}
								
						} else if (checklog->maxfail <= 1) {
							//Run script every time
							prepare_runscript(checklog, matchst, message, 1);
						} else {
							//Start fail counter
							ban_add_elem(checklog->bans, matchst, "LT_ip");
						}

					}
					if (DEBUG>4)
						list_print(checklog->bans);
				}
				matchst = matchFree(matchst);
			}
			checklog = checklog->next;
		}
	}
}

void logtrigger_main()
{
	listlogcheck = listNew();
	files = newFileList();
	//long checkfile;
	//file_st *file = NULL;
	addFile(files,"OpenWrtLogSharedMemory",NULL,0);
	read_conf_uci("logtrigger");
	//int active = files->count;
	logread_start();
	
	printf("Logtrigger END\n");
}
