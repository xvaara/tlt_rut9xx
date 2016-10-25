#ifndef _LOGTRIGGER_TIGGEE_H
#define _LOGTRIGGER_TIGGER_H
#include "confreg.h"
#include "scan.h"

char *matchre(const char *string, const char *pattern);
int stringtimes(const char *string, const char *pattern);
void prepare_runscript(uci_logcheck *checklog, match_t *matchst, char *message, int fail);
int runscript(uci_logcheck *checklog, match_t *matchst, const char *str_ip, const char *str_mac, int fail, const char *message/*, file_st *file*/);
void  processMsg(char *msglog/*, file_st *file*/);
void logtrigger_main(void);
#endif
