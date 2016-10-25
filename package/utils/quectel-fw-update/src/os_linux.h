#ifndef __OS_LINUX_H__
#define __OS_LINUX_H__
#include "platform_def.h"
#include "download.h"
#if defined(TARGET_OS_LINUX) || defined(TARGET_OS_ANDROID)
int openport();
int closeport(HANDLE com_fd);
int WriteABuffer(HANDLE file, const unsigned char * lpBuf, int dwToWrite);
int ReadABuffer(HANDLE file, unsigned char * lpBuf, int dwToRead);
void show_log(char *msg, ...);
void qdl_sleep(int millsec);
void qdl_pre_download(qdl_context *pQdlContext);
void qdl_post_download(qdl_context *pQdlContext, int result);
void qdl_start_download(qdl_context *pQdlContext);
char *itoa( int val, char *buf, unsigned radix );
extern int g_upgrade_baudrate;
extern int g_baudrate_temp;
extern int g_default_port;
extern int g_default_port_bak;//（备用）记录第二个端口
extern int g_upgrade_type;
extern int g_download_mode;//下载模式判断，默认为0，正常下载，1为异常下载
#endif
#endif  /*TARGET_OS_LINUX*/

