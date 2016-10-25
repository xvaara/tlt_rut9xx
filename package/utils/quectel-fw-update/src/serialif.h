
#ifndef __SERIALIF_H__
#define __SERIALIF_H__

#include "platform_def.h"

extern byte  dloadbuf[]; 
extern byte g_Receive_Buffer[]; 
extern int g_Receive_Bytes;							

extern byte g_Transmit_Buffer[];	
extern int g_Transmit_Length;

target_current_state send_sync(void);
int read_buildId(void);
int read_version(void);
int handle_erase_efs(void);
int normal_reset(void);
int handle_switch_target_ftm(void);
int handle_send_sp_code(void);
int switch_to_dload(void);
/******nop*******/
int send_nop(void);
/******preq*******/
int preq_cmd(void);
/******hex*******/
int write_32bit_cmd(void);
/******hex紧急*******/
int write_32bit_cmd_emerg(void);
/******go model*******/
int go_cmd(void);

/******hello*******/
int handle_hello(void);
/******go_cmd_6085*******/
int go_cmd_6085(void);

/******handle_hello_6085*******/
int handle_hello_6085(void);
/******°²È«Ä£Êœ*******/
int handle_security_mode(byte trusted);
/******·¢ËÍ·ÖÇø±í£¬erase=0 :²»²Á£¬erase=1:²Á³ý*******/
int handle_parti_tbl(byte override);
/******ÉýŒ¶Íê³Éreset*******/
int handle_reset(void);
/******Žò¿ª·ÖÇø*******/
int handle_openmulti(uint32 size,byte* data);
/******ÐŽ·ÖÇø*******/
int handle_write(byte *data, uint32 size);
/******¹Ø±ÕPARTITION*******/
int handle_close(void);
int get_revision (void);//获取版本号
int set_dl_flag(void);
int clear_dl_flag(void);
int send_QDL(int baudrate);
int send_QFASTBOOT();
byte* get_error_code();//获取错误码
int send_model(void);//判断下载模式
int get_NV_Count(void);//获取最大nv的值
int get_NV_value(int id,int index,char *NV_value);//获取nv的值
int GetOffset_DataCount(int id, int*offset, int* datacount);//获取偏移和数组大小
//AT写入NV
int Write_NV(int iNV_Item,int array_index,char* hex_date);
#endif /*__SERIALIF_H__*/

