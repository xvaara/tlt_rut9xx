
#ifndef __PLATFORM_DEF_H__
#define __PLATFORM_DEF_H__

/*
* platform which QDL running on
*/
//#define TARGET_OS_WINDOWS
//#define TARGET_OS_LINUX
/*#define TARGET_OS_VXWORKS*/
#define TARGET_OS_ANDROID
/*....*/

#ifdef TARGET_OS_WINDOWS    /*windows OS*/
#include "windows.h"
#include <direct.h>
#include <string.h>
#include <stdio.h>
#define F_OK                          (0x0)  /*file existed check*/
typedef unsigned short         uint16;

#elif defined(TARGET_OS_LINUX)  ||defined TARGET_OS_ANDROID
#include <string.h>
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <time.h>
#include <termios.h>
#include <unistd.h>
#include <ctype.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <dirent.h>
#include <linux/errno.h>
//#define FEATURE_FAST_DOWNLOAD 

/*-------------------------------------------------------------------------*/
/*           LINUX OS													   */
/*-------------------------------------------------------------------------*/

//#define uint32      unsigned int
typedef unsigned int 	   uint32;
typedef bool  			   BOOL;
typedef bool    	 	   boolean;
typedef unsigned int   	   DWORD;
typedef void *             LPVOID;
typedef unsigned short	   uint16;		
typedef unsigned char         byte;

#define MAX_PATH   260
#define TRUE          true
#define FALSE        false
#ifdef TARGET_OS_LINUX
#define NULL          ((void *)0)
#else
#ifndef NULL
#define NULL          (0)
#endif
#endif 

typedef char *              LPSTR;
typedef const char *         LPCSTR;
typedef wchar_t            WCHAR;
typedef WCHAR *              LPWSTR;
typedef const WCHAR *        LPCWSTR;
typedef DWORD *             LPDWORD;
typedef unsigned long      UINT_PTR;
typedef UINT_PTR           SIZE_T;

/*
* macros just for compatible with windows
*/
#define WINAPI 
#define SIM_API
#define QLIB_API 
#define HANDLE        uint32
#define HWND           uint32
#define _MSC_VER   2000
#define COMSTAT     uint32
#define OVERLAPPED  uint32 
#endif /*TARGET_OS_WINDOWS*/

#define FEATURE_NEW_QCN_BACKUP
//#define FEATURE_QDN_SN_NAME    //QDN will be named as SN.QDN after restore qdn to module

typedef enum
{	
	STATE_NORMAL_MODE ,		
	STATE_DLOAD_MODE ,	
	STATE_GOING_MODE ,	
	STATE_UNSPECIFIED,
}target_current_state;
typedef struct file_pathname{
char mini_pathname[1024]; /*文件的路径和名字(不带扩展名)*/
char fdir[1024]; /*文件所在的目录*/
char mini_fname[256]; /*文件的名字(不带扩展名)*/
char suffix[30]; /*文件的扩展名*/
}fpn; 
typedef enum
{
	TARGET_PLATFORM_6270 ,		
	TARGET_PLATFORM_6290 ,		
	TARGET_PLATFORM_6085 ,	
    TARGET_PLATFORM_9615 ,
}target_platform;

//typedef enum
//{
//  OPEN_MULTI_MODE_NONE        = 0x00,    /* Not opened yet                       */
//  OPEN_MULTI_MODE_PBL         = 0x01,    /* Primary Boot Loader                  */
//  OPEN_MULTI_MODE_QCSBLHDCFG  = 0x02,    /* QC 2ndary Boot Loader Header and     */
//                                   /*      Config Data                     */
//  OPEN_MULTI_MODE_QCSBL       = 0x03,    /* QC 2ndary Boot Loader                */
//  OPEN_MULTI_MODE_OEMSBL      = 0x04,    /* OEM 2ndary Boot Loader               */
//  OPEN_MULTI_MODE_AMSS        = 0x05,    /* AMSS modem executable                */
//  OPEN_MULTI_MODE_APPS        = 0x06,    /* APPS executable                      */
//  OPEN_MULTI_MODE_OBL         = 0x07,    /* OTP Boot Loader                      */
//  OPEN_MULTI_MODE_FOTAUI      = 0x08,    /* FOTA UI binarh                       */
//  OPEN_MULTI_MODE_CEFS        = 0x09,    /* Modem CEFS image                     */
//  OPEN_MULTI_MODE_APPSBL      = 0x0A,    /* APPS Boot Loader                     */
//  OPEN_MULTI_MODE_APPS_CEFS   = 0x0B,    /* APPS CEFS image                      */
//  OPEN_MULTI_MODE_APPS_WM60   = 0x0C,    /* Flash.bin image for Windows mobile 6 */
//  OPEN_MULTI_MODE_DSP1        = 0x0D,    /* DSP1 runtime image                   */
//  OPEN_MULTI_MODE_CUSTOM      = 0x0E,    /* Image for user defined partition     */
//  OPEN_MULTI_MODE_DBL         = 0x0F,    /* Device Boot Loader                   */
//  OPEN_MULTI_MODE_OSBL        = 0x10,    /* Fail Safe Boot Loader                */
//  OPEN_MULTI_MODE_FSBL        = 0x11,    /* OS Boot Loader                       */
//  OPEN_MULTI_MODE_DSP2        = 0x12,    /* DSP2 runtime image                   */
//  OPEN_MULTI_MODE_RAW         = 0x13,    /* APPS Raw image */
//  OPEN_MULTI_MODE_LFS         = OPEN_MULTI_MODE_APPSBL,    //for titans FTL partition
//} open_multi_mode_type;
typedef enum
{
  OPEN_MULTI_MODE_SBL1        = 0x00,
  OPEN_MULTI_MODE_SBL2        = 0x01,
  OPEN_MULTI_MODE_RPM         = 0x02,
  OPEN_MULTI_MODE_APPSBL      = 0x03,
  OPEN_MULTI_MODE_DSP1        = 0x04,
  OPEN_MULTI_MODE_DSP2        = 0x05,
  OPEN_MULTI_MODE_DSP3        = 0x06,

} open_multi_mode_type_EC20;
typedef void (*qdl_text_cb)(const char *msg,...);

void qdl_flush_fifo(HANDLE fd, int tx_flush, int rx_flush);

extern HANDLE g_hCom;
#endif /*__PLATFORM_DEF_H__*/

