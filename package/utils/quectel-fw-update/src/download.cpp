/*****************************************
To complete the upgrade process
*****************************************/
#include "download.h"
#include "file.h"
#include <stdio.h>
#include <stdarg.h>
#include <string.h>
#include<time.h>
#include <stdlib.h>
#include "os_linux.h"
#include "serialif.h"
#include "qcn.h"

#include <stdio.h>
#include <ctype.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

FILE *log_file;  //Log Handle define
int g_port_temp=0;
int g_upgrade_fastboot=0;
int g_upgrade_fastboot_last=0;
int create_log(void) {
    struct tm *ptm;
    long ts;
    int y, m, d, h, n, s;
    ts = time(NULL);
    ptm = localtime(&ts);
    y = ptm->tm_year + 1900; //�?
    m = ptm->tm_mon + 1; //�?
    d = ptm->tm_mday; //�?
    h = ptm->tm_hour; //�?
    n = ptm->tm_min; //�?
    s = ptm->tm_sec; //�?
    char filename[200];
    sprintf(filename, "UPGRADE%d%02d%02d%02d%02d%02d.log", y, m, d, h, n, s);
    printf("Log name is %s\n", filename);
    log_file = fopen(filename, "wt");
    return (log_file != NULL);
}

int close_log(void) {
    if (log_file != NULL)
        fclose(log_file);
    log_file = NULL;
    return TRUE;
}
int save_log(const char *fmt,...)
{
	va_list args;
	int len;
	int result = false;
	struct tm *ptm;
	long ts;
	int y, m, d, h, n, s;
	ts = time(NULL);
	ptm = localtime(&ts);
	y = ptm->tm_year + 1900; //�?
	m = ptm->tm_mon + 1; //�?
	d = ptm->tm_mday; //�?
	h = ptm->tm_hour; //�?
	n = ptm->tm_min; //�?
	s = ptm->tm_sec; //�?
	char* newfmt = (char*) malloc(strlen(fmt) + 30);
	sprintf(newfmt, "[%d-%02d-%02d %02d:%02d:%02d]%s", y, m, d, h, n, s, fmt);
	va_start(args, fmt);
	char* buffer = (char*) malloc(500);
	vsprintf(buffer, newfmt, args);
	strcat(buffer, "\r\n");
	va_end(args);
	free(newfmt);
	newfmt = NULL;

	if (buffer == NULL)
		return result;

        //printf("%s", buffer);   
    
	if (log_file != NULL) {
		int result = fwrite((void *) buffer, sizeof(char),
				strlen((const char *) buffer), log_file);
		free(buffer);
		buffer = NULL;
		fflush(log_file);
		result = true;
	}
	return result;
}

int ProcessInit(qdl_context *pQdlContext) {
    pQdlContext->logfile_cb = save_log;
    //create_log();
    
    if (!image_read(pQdlContext)) {
        printf("Parse file error\n");
        return 0;
    }
    return 1;
}

int ProcessUninit(qdl_context *pQdlContext) {
	close_log();
	image_close();
	return 1;
}

int module_state(qdl_context *pQdlContext)
{
	int timeout = 5;
	while (timeout--) {
		pQdlContext->TargetState = send_sync();
		if (pQdlContext->TargetState == STATE_UNSPECIFIED) {
			if (timeout == 0) {
				pQdlContext->text_cb(
						"Module status is unspecified, download failed!");
				pQdlContext->logfile_cb(
						"Module status is unspecified, download failed!");
				return FALSE;
			}
			pQdlContext->logfile_cb("Module state is unspecified, try again");
			qdl_sleep(2000);
		} else {
			break;
		}
	}
	return TRUE;
}
int open_port_operate()
{
	int timeout = 5;
	while (timeout--) {
		qdl_sleep(1000);
		if (!openport()) {
			qdl_sleep(1000);
			if (timeout == 0) {

				return 0;
			} else
				continue;
		} else {
			return 1;
			break;
		}
	}
}

static int do_fastboot(const char *cmd, const char *partion, const char *filepath) {
    char *program = (char *) malloc(MAX_PATH + MAX_PATH + 32);
    char *line = (char *) malloc(MAX_PATH);
    char *self_path = (char *) malloc(MAX_PATH);
    FILE * fpin;
    int self_count = 0;
    int recv_okay = 0;
    int recv_9615 = 0;

    if (!program || !line || !self_path) {
        printf("fail to malloc memory for %s %s %s\n", cmd, partion, filepath);
        return 0;
    }

    self_count = readlink("/proc/self/exe", self_path, MAX_PATH - 1);
    if (self_count > 0) {
        self_path[self_count] = 0;
    } else {
        printf("fail to readlink /proc/self/exe for %s %s %s\n", cmd, partion, filepath);
        return 0;
    }
    
    if (!strcmp(cmd, "flash")) {
        if (!partion || !partion[0] || !filepath || !filepath[0] || access(filepath, R_OK)) {
            free(program);;free(line);free(self_path);
            return 0;
        }
        sprintf(program, "%s fastboot %s %s %s", self_path, cmd, partion, filepath);
        
    } else {
        sprintf(program, "%s fastboot %s", self_path, cmd);
    }

    fpin = popen(program, "r");

	
    if (!fpin) {
		printf("popen failed\n");
		printf("popen strerror: %s\n", strerror(errno));
        return 0;
    }

    while (fgets(line, MAX_PATH - 1, fpin) != NULL) {
        if (strstr(line, "OKAY")) {
            recv_okay++;
        } else if (strstr(line, "MDM9615")) {
            recv_9615++;
        }
    }
    
    pclose(fpin);
    free(program);free(line);free(self_path);

    if (!strcmp(cmd, "flash")){
        return (recv_okay == 2);
	}
    else if (!strcmp(cmd, "devices")){
		//printf("Found quectel module in fastboot mode\n");
        return (recv_9615 == 1);
	}
   else if (!strcmp(cmd, "continue")){
        return (recv_okay == 1);
	}
   else
        return (recv_okay > 0);
    
    return 0;
}

static int do_flash_mbn(const char *partion, const char *filepath) {
    char *program = (char *) malloc(MAX_PATH + MAX_PATH + 32);
    int result;
    byte *filebuf;
    uint32 filesize;

    if (!program) {
        printf("fail to malloc memory for %s %s\n", partion, filepath);
        return 0;
    }

    sprintf(program, "flash %s %s", partion, filepath);
    printf("%s\n", program);

    if (!partion || !filepath || !filepath[0] || access(filepath, R_OK)) {
        free(program);
        return 0;
    }

    filebuf = open_file(filepath, &filesize);
    if (filebuf == NULL) {
        free(program);
        return FALSE;
    }
 
    strcpy(program, partion);
    result = handle_openmulti(strlen(partion) + 1, (byte *)program);
    if (result == false) {
        printf("%s open failed\n", partion);
        goto __fail;
    }

    sprintf(program, "sending '%s' (%dKB)", partion, (int)(filesize/1024));
    printf("%s\n", program);
  
    result = handle_write(filebuf, filesize);
    if (result == false) {
        QdlContext->text_cb("");
        QdlContext->text_cb("%s download failed", partion);
        goto __fail;
    }
    
    result = handle_close();
    if (result == false) {
        QdlContext->text_cb("%s close failed", partion);
        goto __fail;
    }

    printf("OKAY\n");
    
    free(program);
    free_file(filebuf, filesize);
    return TRUE;

__fail:
    free(program);
    free_file(filebuf, filesize);
    return FALSE;
}

int BFastbootModel() {
    return do_fastboot("devices", NULL, NULL);
}
/*+++++++++++++++++++++++++++++++++++++++++
/	dl_ftp_do_fb
* returns 0 on successful fw file download from ftp and on successful flashing in fastboot
* pQdlContext - qdl_context  structure
* filepath - local firmware file path
* filename - address of malloc'ed char to store filename in function
* cmd -  address of malloc'ed char to store shell command in function
* partition - quectel modem partition to flash
++++++++++++++++++++++++++++++++++++++++++*/
static int dl_ftp_do_fb(qdl_context *pQdlContext, const char *filepath, char **filename, char **cmd, const char *partition){
	const char *format = "ftpget %s:%d %s firmware/%s";
	
	*filename = basename(filepath);
	sprintf(*cmd, format, pQdlContext->ftp_address, pQdlContext->ftp_port, filepath, *filename);
	if(system(*cmd) != 0){
		return 1;
	}
	
	do_fastboot("flash", partition, filepath);
	sprintf(*cmd, "rm -f %s", filepath);
	if(system(*cmd) != 0){
		return 1;
	}
	return 0;
}

int downloadfastboot(qdl_context *pQdlContext, int type) {
	/***********upgrade fastboot==>start**********/
	//++++++++++++++
	char *cmd = (char *) malloc(MAX_PATH + MAX_PATH + 32);
	char *filename = (char *) malloc(MAX_PATH + MAX_PATH + 32);
	bool status = TRUE;

	if (!cmd || !filename){
		printf("fail to malloc memory for cmd or filename in downloadfastboot()\n");
		return FALSE;
	}

	if ((pQdlContext->update_method == 4
			|| pQdlContext->update_method == 1)
			&& pQdlContext->upgrade_fastboot != 0) {
		
        //first step:open AT port and send "at+qfastboot"
        if (type == 1) {
			printf("ENTER FASTBOOT mode\n");
        	g_default_port += 2; //+2认为端口是AT�?
        	closeport(g_hCom);
        	if (open_port_operate() == 0) {
        		pQdlContext->text_cb("Start to open port, Failed!");
        		pQdlContext->logfile_cb("Start to open port, Failed!");
        		free(cmd);
        		free(filename);
        		return FALSE;
        	}
        	if (send_QFASTBOOT() != 1) {
        		pQdlContext->text_cb("Send FASTBOOT failed");
        		pQdlContext->logfile_cb("Send FASTBOOT failed");
        		closeport(g_hCom);
        		free(cmd);
        		free(filename);
        		return FALSE;
        	}

                while(!BFastbootModel())
                    sleep(2);
        }

		if(dl_ftp_do_fb(pQdlContext, pQdlContext->system_path, &filename, &cmd, "system")){
			status = FALSE;
			goto OUT;
		}
		if(dl_ftp_do_fb(pQdlContext, pQdlContext->userdata_path, &filename, &cmd, "userdata")){
			status = FALSE;
			goto OUT;
		}
		if(dl_ftp_do_fb(pQdlContext, pQdlContext->boot_path, &filename, &cmd, "boot")){
			status = FALSE;
			goto OUT;
		}
		if(dl_ftp_do_fb(pQdlContext, pQdlContext->recovery_path, &filename, &cmd, "recovery")){
			status = FALSE;
			goto OUT;
		}
		if(dl_ftp_do_fb(pQdlContext, pQdlContext->recoveryfs_path, &filename, &cmd, "recoveryfs")){
			status = FALSE;
			goto OUT;
		}
		if(dl_ftp_do_fb(pQdlContext, pQdlContext->dsp1_path, &filename, &cmd, "dsp1")){
			status = FALSE;
			goto OUT;
		}
		if(dl_ftp_do_fb(pQdlContext, pQdlContext->dsp2_path, &filename, &cmd, "dsp2")){
			status = FALSE;
			goto OUT;
		}
		if(dl_ftp_do_fb(pQdlContext, pQdlContext->dsp3_path, &filename, &cmd, "dsp3")){
			status = FALSE;
			goto OUT;
		}

        do_fastboot("continue", NULL, NULL);
    }
    OUT:
    closeport(g_hCom);
    g_default_port -= 2;
	/***********upgrade fastboot==>end************/
	if(!status){
		printf("ftp download error\n");
		sprintf(cmd, "rm -r %s", pQdlContext->firmware_path);
		if(system(cmd) != 0)
			printf("error removing fw dir... \n");
		else
			printf("firmware dir removed... \n");
	}
	free(cmd);
	free(filename);
	return status;
}
//MDM9615	fastboot
int downloading(qdl_context *pQdlContext)
{
	int result;
	int msgresult;
	int timeout = 60;
	char StrBuff[50];
	int download_type = 2; //下载模式�?为正常模式，3为紧急模�?
	//先打开串口，进行模块状态判�?
	pQdlContext->text_cb("Module Status Detection");
	pQdlContext->logfile_cb("Module Status Detection");
	g_baudrate_temp = g_upgrade_baudrate;
	g_upgrade_baudrate = 115200; //先设置模块波特率是默认的115200

start_open:
	if (BFastbootModel()) {
		closeport(g_hCom);
		if (downloadfastboot(pQdlContext, 0) == FALSE) {
			return FALSE;
		}
		g_upgrade_fastboot=1;
		qdl_sleep(5000);
		goto start_open;
	} else if (open_port_operate() == 0) {
		printf("open_port_operate() = 0\n");
		pQdlContext->text_cb("Start to open port, Failed!");
		pQdlContext->logfile_cb("Start to open port, Failed!");
		return FALSE;	
	}
	result = 1;

	//result = send_model();//判断模式
	//-------------------------------------------------------------------DM
	if (result == 1){
		//g_upgrade_type = 1;
		pQdlContext->text_cb("In Diag Command Status");
		pQdlContext->logfile_cb("In Diag Command Status");
		//check module's mode
		int sync_timeout=15;
		while (sync_timeout--) {
			printf("sync_timeout =%d\n", sync_timeout);
			pQdlContext->TargetState = send_sync();
			if (pQdlContext->TargetState != STATE_UNSPECIFIED) {
				printf("pQdlContext->TargetState != STATE_UNSPECIFIED\n");
				break;
			} else if (sync_timeout > 0) {
				closeport(g_hCom);
				qdl_sleep(4000);
				if (open_port_operate() == 0) //修改（如果打开失败，有可能模块处于下载模式（中断下载导致），端口重新枚举，已经不是用户指定的端口，所以从0在循环打开）成打开失败直接退�?
					{
						pQdlContext->text_cb("Start to open port, Failed!");
						pQdlContext->logfile_cb("Start to open port, Failed!");
						return FALSE;
					}
				continue;
			} else if (sync_timeout == 0) {
				pQdlContext->text_cb("Sync Timeout, Failed!");
				return FALSE;
			}
		}
		if(pQdlContext->TargetState == STATE_NORMAL_MODE)
		{
			printf("pQdlContext->TargetState == STATE_NORMAL_MODE START\n");
			g_upgrade_fastboot_last=1;
			//first --upgrade fastboot
			if(g_upgrade_fastboot==0)
			{
				closeport(g_hCom);
				if (downloadfastboot(pQdlContext, 1) == FALSE) {
					return FALSE;
				}
				qdl_sleep(5000);
			}

			g_default_port += 2; //+2认为端口是AT�?
			closeport(g_hCom);
			if (open_port_operate() == 0) {
				return FALSE;
			}
			if (get_revision() != 1) //获取版本�?
					{
				pQdlContext->logfile_cb("Get revision failed");
			}
			closeport(g_hCom);
			g_default_port -= 2;
			if (g_default_port_bak != -1)
				g_default_port = g_default_port_bak;
			qdl_sleep(2000);
			printf("pQdlContext->TargetState == STATE_NORMAL_MODE END\n");
		}
		else
			goto DLOAD_MODE;
		//pQdlContext->TargetState = STATE_NORMAL_MODE;
	}

	//------------------------------------------------------------------------

	if (open_port_operate() == 0) {
		pQdlContext->text_cb("Start to open port, Failed!");
		pQdlContext->logfile_cb("Start to open port, Failed!");
		return FALSE;
	}
	qdl_sleep(3000);
	if (pQdlContext->update_method == 4
			|| pQdlContext->update_method == 2) {
		pQdlContext->logfile_cb("Sp unlocked...");
		if (handle_send_sp_code() != 1) {
			pQdlContext->text_cb("Sp unlocked failed");
			pQdlContext->logfile_cb("Sp unlocked failed");
			qdl_sleep(200);
			return FALSE;
		}

		pQdlContext->text_cb("Backup QQB...");
		pQdlContext->logfile_cb("Backup QQB...");
		result = SaveQqbThreadFunc(pQdlContext);
		if (result == false) {
			remove("backup.qqb");
			pQdlContext->text_cb("");
			pQdlContext->text_cb("Backup failed");
			pQdlContext->logfile_cb("Backup failed");
			return FALSE;
		}
	}
	/*************************************************
	* if module is in normal mode, then we should
	* switch it to download mode.
	*************************************************/
	if((pQdlContext->update_method == 4
			|| pQdlContext->update_method == 1)&&
	pQdlContext->upgrade_modem !=1)
	{
		if (pQdlContext->TargetState == STATE_NORMAL_MODE) {
			qdl_sleep(50);
			pQdlContext->text_cb("Switch to PRG status");
			pQdlContext->logfile_cb("Switch to PRG status");
			result = switch_to_dload();
			if (result == false) {
				pQdlContext->text_cb("Switch to PRG status failed");
				pQdlContext->logfile_cb("Switch to PRG status failed");
				return FALSE;
			}
			closeport(g_hCom);
			qdl_sleep(5000);
			timeout = 10;
			while (timeout--) {
				closeport(g_hCom);
				qdl_sleep(1000);
				if (!openport()) {
					qdl_sleep(2000);
					if (timeout == 0) {
						pQdlContext->text_cb(
								"Send switch to dload command failed, download error!");
						pQdlContext->logfile_cb(
								"Send switch to dload command failed, download error!");
						return FALSE;
					} else
						continue;
				}
				pQdlContext->TargetState = send_sync();
				if (pQdlContext->TargetState == STATE_DLOAD_MODE) {
					break;
				} else if (timeout > 0) {
					sprintf(StrBuff,
							"Switch to PRG status failed try again[%d]",
							timeout);
					pQdlContext->logfile_cb(StrBuff);
				} else if (timeout == 0) {
					pQdlContext->text_cb(
							"Switch to PRG status failed, download error!");
					pQdlContext->logfile_cb(
							"Switch to PRG status failed, download error!");
					return FALSE;
				}
			}
		}
		/*************************************************
		 * prepare to downloading
		 *************************************************/
		DLOAD_MODE: if (pQdlContext->TargetState == STATE_DLOAD_MODE) {
			download_model: pQdlContext->text_cb("In PRG Status");
			//-------------------------
			pQdlContext->logfile_cb("nop");
			result = send_nop();
			if (result == false) {
				pQdlContext->text_cb("Send nop command failed");
				pQdlContext->logfile_cb("Send nop command failed");
				return FALSE;
			}
			pQdlContext->logfile_cb("preq");
			if (!preq_cmd()) {
				pQdlContext->text_cb("Send preq command failed");
				pQdlContext->logfile_cb("Send preq command failed");
				return FALSE;
			}
			qdl_sleep(4000);

			pQdlContext->text_cb("Send %s.hex", pQdlContext->NPRG9x15_path);
			result = write_32bit_cmd();
			if (result == false) {
				pQdlContext->text_cb("Send %s.hex", pQdlContext->ENPRG9x15_path);
				auto_hex_download();
				result = write_32bit_cmd_emerg();
				if (result == false) {
                                return FALSE;
				}
				//return FALSE;
			}

			qdl_sleep(1000);
			pQdlContext->logfile_cb("go");
			result = go_cmd();
			if (result == false) {
				pQdlContext->text_cb("Send go command failed");
				pQdlContext->logfile_cb("Send go command failed");
				return FALSE;
			}
			closeport(g_hCom);
			/*module is rebooted*/
			qdl_sleep(3000);
			/*reopen the diag port*/
			timeout = 10;
			while (timeout--) {
				closeport(g_hCom);
				qdl_sleep(1000);
				if (!openport()) {
					if (timeout == 0) {
						pQdlContext->text_cb("Timeout,Send go command failed");
						return FALSE;
					} else
						continue;
				}
				pQdlContext->TargetState = send_sync();

				if (pQdlContext->TargetState == STATE_GOING_MODE) {
					break;
				} else if (timeout > 0) {
					sprintf(StrBuff, "Send go command failed, try again[%d]",
							timeout);
					//pQdlContext->text_cb( StrBuff);
					pQdlContext->logfile_cb(StrBuff);
				} else if (timeout == 0) {
					pQdlContext->text_cb("Timeout, Send go command failed");
					return FALSE;
				}
			}
		}

		/*************************************************
		 * start  downing
		 *************************************************/
		if (pQdlContext->TargetState == STATE_GOING_MODE) {
			pQdlContext->text_cb("Start to download firmware");
			qdl_sleep(3000);
			pQdlContext->logfile_cb("hello");
			result = handle_hello();
			if (result == false) {
				pQdlContext->text_cb("Send hello command fail");
				pQdlContext->logfile_cb("Send hello command fail");
				return FALSE;
			} else {
				char string1[64];
				int size;
				memcpy(string1, &g_Receive_Buffer[1], 32);
				string1[32] = 0;
				size = (g_Receive_Buffer[36] << 8) | g_Receive_Buffer[35];
				size = g_Receive_Buffer[43];
				memcpy(string1, &g_Receive_Buffer[44], size);
				string1[size] = 0;
			}

			result = handle_security_mode(1);
			if (result == false) {
				pQdlContext->text_cb("Send trust command fail");
				pQdlContext->logfile_cb("Send trust command fail");
				return FALSE;
			}
			int re_parti_tbl;
			re_parti_tbl = handle_parti_tbl(0);
			if (re_parti_tbl == false) {
				pQdlContext->text_cb("Partitbl mismatched");
				pQdlContext->logfile_cb("Partitbl mismatched");
			}
			//设置dl_flag命令
			pQdlContext->logfile_cb("set dl_flag");
			result = set_dl_flag();
			if (result == false) {
				pQdlContext->text_cb("Send other command failed");
				pQdlContext->logfile_cb("Send other command failed");
			}

			if (pQdlContext->TargetPlatform == TARGET_PLATFORM_9615) {
                            do_flash_mbn("0:SBL1", pQdlContext->sbl1_path);
                            do_flash_mbn("0:SBL2", pQdlContext->sbl2_path);
                            do_flash_mbn("0:RPM", pQdlContext->rpm_path);
                            do_flash_mbn("0:APPSBL", pQdlContext->appsboot_path);
                            //do_flash_mbn("0:DSP1", pQdlContext->dsp1_path);
                            //do_flash_mbn("0:DSP2", pQdlContext->dsp2_path);
                            //do_flash_mbn("0:DSP3", pQdlContext->dsp3_path);
			}
		}
		//清除dl_flag命令
		pQdlContext->logfile_cb("clear dl_flag");
		result = clear_dl_flag();
		if (result == false) {
			pQdlContext->text_cb("Send other command failed");
			pQdlContext->logfile_cb("Send other command failed");
		}
		qdl_sleep(1000);
		result = handle_reset(); /*reset the module*/
		if (result == false) {
			pQdlContext->text_cb("Send reset command failed");
			pQdlContext->logfile_cb("Send reset command failed");
			return FALSE;
		}
		closeport(g_hCom); //关闭句柄，防止模块重启后，端口被占用
		qdl_sleep(10000);
		if (g_download_mode == 0) {
			timeout = 10;
			while (timeout--) {
				closeport(g_hCom);
//			if (g_upgrade_type == 0) {
//				g_default_port = g_port_temp;
//			}
				if (!openport()) {
					qdl_sleep(1000);
					if (timeout == 0) {
						pQdlContext->text_cb("Open to com port failed...");
						return FALSE;
					} else
						continue;
				} else
					break;
			}
		}

		if (pQdlContext->qqb_EC20 != NULL) {
			pQdlContext->logfile_cb("Switch to offline mode...");
			if (handle_switch_target_ftm() != 1) {

				pQdlContext->text_cb("Switch offline mode failed");
				pQdlContext->logfile_cb("Switch offline mode failed");
				qdl_sleep(200);
				return FALSE;
			}
			pQdlContext->logfile_cb("Sp unlocked...");
			if (handle_send_sp_code() != 1) {
				pQdlContext->text_cb("Sp unlocked failed");
				pQdlContext->logfile_cb("Sp unlocked failed");
				qdl_sleep(200);
				return FALSE;
			}
			pQdlContext->text_cb("QQB downloading...");
			pQdlContext->logfile_cb("QQB downloading...");
			result = Import_Qqb_Func(pQdlContext);
			if (result == false) {
				pQdlContext->text_cb("QQB download failed");
				pQdlContext->logfile_cb("QQB download failed");
				return FALSE;
			}
		}
	}
	if(pQdlContext->update_method == 4
				|| pQdlContext->update_method == 3)
	{
		pQdlContext->text_cb("Restore QQB...");
		pQdlContext->logfile_cb("Restore QQB...");
		result = RestoreQqbThreadFunc(pQdlContext);
		if (result == false) {
			pQdlContext->text_cb("");
			pQdlContext->text_cb("Restore QQB fail");
			pQdlContext->logfile_cb("Restore QQB fail");
			return FALSE;
		}
	}
	qdl_sleep(2000);
	if (g_download_mode == 0) {
		normal_reset();
		pQdlContext->text_cb("restart...");
	}
	qdl_sleep(2000);

	//first --upgrade fastboot
	if (g_upgrade_fastboot_last == 0) {
		closeport(g_hCom);
		if (downloadfastboot(pQdlContext, 1) == FALSE) {
			return FALSE;
		}
		qdl_sleep(5000);
	}
	return TRUE;
}


