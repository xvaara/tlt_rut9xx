#ifndef __FILE_H__
#define __FILE_H__

#include "platform_def.h"
#include "download.h"
byte * open_file(const char *filepath,uint32 *filesize);
void free_file(byte *filebuf,uint32 filesize);
extern int image_read(qdl_context *ctx);
extern void auto_hex_download(void);
extern int image_close();
extern int g_hex_start_addr;//获取起始地址，等于基地址+偏移地址
extern int go_hex_start_addr;//go命令执行地址
#endif /*__FILE_H__*/

