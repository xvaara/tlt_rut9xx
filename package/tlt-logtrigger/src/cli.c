/*
 * cli - Command Line Interface for the logtrigger 
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
#include <string.h>
#include <stdlib.h>
#include <stdint.h>
#include <getopt.h>
#include "trigger.h"
#include "uci.h"
#include "config.h"

enum {
	CMD_NONE,
	CMD_GET,
	CMD_SET,
	CMD_LOAD,
	CMD_HELP,
	CMD_SHOW,
};


int DEBUG;
static void print_usage(void)
{
	printf("Application for reading log messages and performing specified actions for found patterns\n");
	printf("Configuration is stored in /etc/confgi/logtrigger\n");
	printf("Usage: logtrigger <params>\n");
	printf(" -D <level>\tspecify loglevel\n");
	exit(1);
}

int main(int argc, char **argv)
{
	DEBUG=0;
	
	if (argc == 1){
		logtrigger_main();
	} else {
		int i;
		int cmd = CMD_HELP;
		for (i=0; i < argc; i++){
			char *arg = argv[i];
			if (!strcmp(arg, "help")) {
				cmd = CMD_HELP;
			} else if (!strcmp(arg, "-D")) {
				int level = 1;
				if (i+1 < argc)
					level = atoi(argv[i+1]);
				if (level > 1){
					DEBUG = level;
					i++;
				}else
					DEBUG = 1;
				printf("Run DEBUG = %d\n",DEBUG);
				logtrigger_main();
			}
		}
		switch(cmd) {
		case CMD_SET:
			break;
		case CMD_GET:
			break;
		case CMD_LOAD:
			break;
		case CMD_HELP:
			print_usage();
			break;
		case CMD_SHOW:
			break;
		default:
			print_usage();
			break;
		}
	}
	return 0;
}


