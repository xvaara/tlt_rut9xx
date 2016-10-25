
#ifndef __DOWNLOAD_H__
#define __DOWNLOAD_H__
#include "platform_def.h"

typedef void (*qdl_msg_cb)(int msgtype,const char *msg1,const char * msg2); 
typedef void (*qdl_prog_cb)(int writesize,int size,int clear);  
typedef int  (*qdl_log_cb)(const char *msg,...);
typedef struct {
    qdl_text_cb text_cb;	
    qdl_msg_cb msg_cb;	
    qdl_prog_cb prog_cb;	
    qdl_log_cb logfile_cb;

    target_current_state  TargetState;
    target_platform       TargetPlatform;
    int         ComPortNumber;

    int update_method; //for:1(upgrade only),2(Backup only),3(restore only),4(backup,upgrade,restore )
    int cache;
    char *firmware_path;//save the path of the upgrade files
    char *system_path;
    char *userdata_path;
    char *boot_path;
    char *recovery_path;
    char *recoveryfs_path;
    char *dsp1_path;
    char *dsp2_path;
    char *dsp3_path;
    char *appsboot_path;
    char *ENPRG9x15_path;
    char *NPRG9x15_path;
    char *partition_path;
    char *partition2_path;
    char *update_path;
    char *rpm_path;
    char *sbl1_path;
    char *sbl2_path;
    int upgrade_fastboot;
    int upgrade_modem;
    char *ftp_address;
    int ftp_port;

    byte *ENPRG9x15_EC20;
    uint32 ENPRG9x15_EC20_length;
    byte *NPRG9x15_EC20;
    uint32 NPRG9x15_EC20_length;
    byte *qqb_EC20;
    uint32 qqb_EC20_length;
}qdl_context, *p_qdl_context;
extern qdl_context *QdlContext;
#define QDL_LOGFILE_NAME	"qdl.txt"
int downloading(qdl_context *pQdlContext);
int ProcessInit(qdl_context *pQdlContext);
int save_log(char *fmt,...);
int ProcessUninit(qdl_context *pQdlContext);
void Processing(qdl_context *pQdlContext);
#endif /*__DOWNLOAD_H__*/
