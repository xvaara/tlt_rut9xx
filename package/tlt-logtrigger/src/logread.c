/*
 * Copied from ubox package
 */

/*
 * Copyright (C) 2013 Felix Fietkau <nbd@openwrt.org>
 * Copyright (C) 2013 John Crispin <blogic@openwrt.org>
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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <signal.h>

#include <malloc.h>
#include <sys/types.h>
#include <errno.h>


#include "logread.h"

extern int errno;
extern int DEBUG;

#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <sys/socket.h>
#define SYSLOG_NAMES
#define SYSLOG_NAMES_CONST
#include <syslog.h>
#include <unistd.h>

#include <libubox/ustream.h>
#include <libubox/blobmsg_json.h>
#include <libubox/usock.h>
#include <libubox/uloop.h>
#include "libubus.h"
#include "confreg.h"
#include "trigger.h"

enum {
	LOG_STDOUT,
	LOG_FILE,
	LOG_NET,
	LOG_BUFF
};

enum {
	LOG_MSG,
	LOG_ID,
	LOG_PRIO,
	LOG_SOURCE,
	LOG_TIME,
	__LOG_MAX
};

enum {
	SOURCE_KLOG = 0,
	SOURCE_SYSLOG = 1,
	SOURCE_INTERNAL = 2,
	SOURCE_ANY = 0xff,
};

static const struct blobmsg_policy log_policy[] = {
	[LOG_MSG] = { .name = "msg", .type = BLOBMSG_TYPE_STRING },
	[LOG_ID] = { .name = "id", .type = BLOBMSG_TYPE_INT32 },
	[LOG_PRIO] = { .name = "priority", .type = BLOBMSG_TYPE_INT32 },
	[LOG_SOURCE] = { .name = "source", .type = BLOBMSG_TYPE_INT32 },
	[LOG_TIME] = { .name = "time", .type = BLOBMSG_TYPE_INT64 },
};

static struct uloop_fd sender;
static int log_type = LOG_STDOUT;

static const char* getcodetext(int value, CODE *codetable) {
	CODE *i;

	if (value >= 0)
		for (i = codetable; i->c_val != -1; i++)
			if (i->c_val == value)
				return (i->c_name);
	return "<unknown>";
};

static int log_notify(struct blob_attr *msg, int log_type)
{
	struct blob_attr *tb[__LOG_MAX];
	char buf[512];
	uint32_t p;
	char *str;
	time_t t;
	char *c, *m;
	int ret = 0;

	if (sender.fd < 0)
		return 0;

	blobmsg_parse(log_policy, ARRAY_SIZE(log_policy), tb, blob_data(msg), blob_len(msg));
	if (!tb[LOG_ID] || !tb[LOG_PRIO] || !tb[LOG_SOURCE] || !tb[LOG_TIME] || !tb[LOG_MSG])
		return 1;

	m = blobmsg_get_string(tb[LOG_MSG]);
	t = blobmsg_get_u64(tb[LOG_TIME]) / 1000;
	c = ctime(&t);
	p = blobmsg_get_u32(tb[LOG_PRIO]);
	c[strlen(c) - 1] = '\0';
	str = blobmsg_format_json(msg, true);
	
	snprintf(buf, sizeof(buf), "%s %s.%s%s %s\n",
		c, getcodetext(LOG_FAC(p) << 3, (CODE *)facilitynames), getcodetext(LOG_PRI(p), (CODE *)prioritynames),
		(blobmsg_get_u32(tb[LOG_SOURCE])) ? ("") : (" kernel:"), m);
	processMsg(buf);

	free(str);
	if (log_type == LOG_FILE)
		fsync(sender.fd);

	return ret;
}

static void logread_fd_data_cb(struct ustream *s, int bytes)
{
	fprintf(stderr, "logread_fd_data_cb\n");
	while (true) {
		int len;
		struct blob_attr *a;

		a = (void*) ustream_get_read_buf(s, &len);
		if (len < sizeof(*a) || len < blob_len(a) + sizeof(*a))
			break;
		log_notify(a, log_type);
		ustream_consume(s, blob_len(a) + sizeof(*a));
	}
}

static void logread_fd_cb(struct ubus_request *req, int fd)
{
	static struct ustream_fd test_fd;
	fprintf(stderr, "logread_fd_cb\n");

	test_fd.stream.notify_read = logread_fd_data_cb;
	ustream_fd_init(&test_fd, fd);
}

static void logread_complete_cb(struct ubus_request *req, int ret)
{
}

int logread_start()
{
	static struct ubus_request req;
	struct ubus_context *ctx;
	uint32_t id;
	const char *ubus_socket = NULL;
	int ret;
	static struct blob_buf b;
	int tries = 5;
	
	
	uloop_init();
	ctx = ubus_connect(ubus_socket);
	if (!ctx) {
		fprintf(stderr, "Failed to connect to ubus\n");
		return -1;
	}
	ubus_add_uloop(ctx);

	/* ugly ugly ugly ... we need a real reconnect logic */
	do {
		ret = ubus_lookup_id(ctx, "log", &id);
		if (ret) {
			fprintf(stderr, "Failed to find log object: %s\n", ubus_strerror(ret));
			sleep(1);
			continue;
		}
		blob_buf_init(&b, 0);
		blobmsg_add_u32(&b, "lines", 0);

		sender.fd = STDOUT_FILENO;
		
		ubus_invoke_async(ctx, id, "read", b.head, &req);
		req.fd_cb = logread_fd_cb;
		req.complete_cb = logread_complete_cb;
		ubus_complete_request_async(ctx, &req);
		
		uloop_run();
		ubus_free(ctx);
		uloop_done();

	} while (ret && tries--);
	return ret;
}

unsigned get_tail()
{
	unsigned cur;
	int log_semid; /* ipc semaphore id */
	int log_shmid; /* ipc shared memory id */
	/* We need to get the segment named KEY, created by the server. */
	key_t key = KEY;
	
	INIT_G();

	/* Locate the segment. */
	if ((log_shmid = shmget(key, 0, 0)) < 0) {
		if(DEBUG>4)
			printf("shmget Error (%d): %s\n",errno,strerror(errno));
		return -1;
	}

	/* Now we attach the segment to our data space. */
	shbuf = shmat(log_shmid, NULL, SHM_RDONLY);
	if (shbuf == NULL) {
		if(DEBUG>4)
			printf("shmat Error (%d): %s\n",errno,strerror(errno));
		return -1;
	}

	log_semid = semget(key, 0, 0);
	if (log_semid == -1) {
		if(DEBUG>4)
			printf("shmat Error (%d): %s\n",errno,strerror(errno));
		return -1;
	}
	cur = shbuf->tail;
	shmdt(shbuf);
	return cur;
}
