
#include "file.h"
#include "download.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "os_linux.h"
#include <string.h>
#include <linux/errno.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h> /*mmap munmap*/

void ENPRG9x15_handle(qdl_context *ctx);
void NPRG9x15_handle(qdl_context *ctx);

//---------------------------------
#define CRC_16_L_SEED           0xFFFF

#define CRC_TAB_SIZE    256             /* 2^CRC_TAB_BITS      */

const uint16 crc_16_l_table[ CRC_TAB_SIZE ] = {
	0x0000, 0x1189, 0x2312, 0x329b, 0x4624, 0x57ad, 0x6536, 0x74bf,
	0x8c48, 0x9dc1, 0xaf5a, 0xbed3, 0xca6c, 0xdbe5, 0xe97e, 0xf8f7,
	0x1081, 0x0108, 0x3393, 0x221a, 0x56a5, 0x472c, 0x75b7, 0x643e,
	0x9cc9, 0x8d40, 0xbfdb, 0xae52, 0xdaed, 0xcb64, 0xf9ff, 0xe876,
	0x2102, 0x308b, 0x0210, 0x1399, 0x6726, 0x76af, 0x4434, 0x55bd,
	0xad4a, 0xbcc3, 0x8e58, 0x9fd1, 0xeb6e, 0xfae7, 0xc87c, 0xd9f5,
	0x3183, 0x200a, 0x1291, 0x0318, 0x77a7, 0x662e, 0x54b5, 0x453c,
	0xbdcb, 0xac42, 0x9ed9, 0x8f50, 0xfbef, 0xea66, 0xd8fd, 0xc974,
	0x4204, 0x538d, 0x6116, 0x709f, 0x0420, 0x15a9, 0x2732, 0x36bb,
	0xce4c, 0xdfc5, 0xed5e, 0xfcd7, 0x8868, 0x99e1, 0xab7a, 0xbaf3,
	0x5285, 0x430c, 0x7197, 0x601e, 0x14a1, 0x0528, 0x37b3, 0x263a,
	0xdecd, 0xcf44, 0xfddf, 0xec56, 0x98e9, 0x8960, 0xbbfb, 0xaa72,
	0x6306, 0x728f, 0x4014, 0x519d, 0x2522, 0x34ab, 0x0630, 0x17b9,
	0xef4e, 0xfec7, 0xcc5c, 0xddd5, 0xa96a, 0xb8e3, 0x8a78, 0x9bf1,
	0x7387, 0x620e, 0x5095, 0x411c, 0x35a3, 0x242a, 0x16b1, 0x0738,
	0xffcf, 0xee46, 0xdcdd, 0xcd54, 0xb9eb, 0xa862, 0x9af9, 0x8b70,
	0x8408, 0x9581, 0xa71a, 0xb693, 0xc22c, 0xd3a5, 0xe13e, 0xf0b7,
	0x0840, 0x19c9, 0x2b52, 0x3adb, 0x4e64, 0x5fed, 0x6d76, 0x7cff,
	0x9489, 0x8500, 0xb79b, 0xa612, 0xd2ad, 0xc324, 0xf1bf, 0xe036,
	0x18c1, 0x0948, 0x3bd3, 0x2a5a, 0x5ee5, 0x4f6c, 0x7df7, 0x6c7e,
	0xa50a, 0xb483, 0x8618, 0x9791, 0xe32e, 0xf2a7, 0xc03c, 0xd1b5,
	0x2942, 0x38cb, 0x0a50, 0x1bd9, 0x6f66, 0x7eef, 0x4c74, 0x5dfd,
	0xb58b, 0xa402, 0x9699, 0x8710, 0xf3af, 0xe226, 0xd0bd, 0xc134,
	0x39c3, 0x284a, 0x1ad1, 0x0b58, 0x7fe7, 0x6e6e, 0x5cf5, 0x4d7c,
	0xc60c, 0xd785, 0xe51e, 0xf497, 0x8028, 0x91a1, 0xa33a, 0xb2b3,
	0x4a44, 0x5bcd, 0x6956, 0x78df, 0x0c60, 0x1de9, 0x2f72, 0x3efb,
	0xd68d, 0xc704, 0xf59f, 0xe416, 0x90a9, 0x8120, 0xb3bb, 0xa232,
	0x5ac5, 0x4b4c, 0x79d7, 0x685e, 0x1ce1, 0x0d68, 0x3ff3, 0x2e7a,
	0xe70e, 0xf687, 0xc41c, 0xd595, 0xa12a, 0xb0a3, 0x8238, 0x93b1,
	0x6b46, 0x7acf, 0x4854, 0x59dd, 0x2d62, 0x3ceb, 0x0e70, 0x1ff9,
	0xf78f, 0xe606, 0xd49d, 0xc514, 0xb1ab, 0xa022, 0x92b9, 0x8330,
	0x7bc7, 0x6a4e, 0x58d5, 0x495c, 0x3de3, 0x2c6a, 0x1ef1, 0x0f78
};
#define CRC_16_L_POLYNOMIAL     0x8408
uint16 crc_16_l_calc(char *buf_ptr, int len) {
	int data, crc_16;
	for (crc_16 = CRC_16_L_SEED; len >= 8; len -= 8, buf_ptr++) {
		crc_16 = crc_16_l_table[(crc_16 ^ *buf_ptr) & 0x00ff] ^ (crc_16 >> 8);
	}
	if (len != 0) {

		data = ((int) (*buf_ptr)) << (16 - 8);

		while (len-- != 0) {
			if (((crc_16 ^ data) & 0x01) != 0) {

				crc_16 >>= 1;
				crc_16 ^= CRC_16_L_POLYNOMIAL;

			} else {

				crc_16 >>= 1;

			}

			data >>= 1;
		}
	}
	return (~crc_16);
}
//------------------------------
void rtrim(char *inbuff, int i) {
	int l;
	char *p = inbuff;
	char outbuff[255] = { 0 };
	p += (strlen(inbuff) - 1);
	while (p > inbuff) {
		if (32 != (char) *p)
			break;
		p--;
	}
	strcpy(outbuff, inbuff);
	outbuff[p - inbuff + 1] = '\0';
	memset(inbuff, 0, sizeof(inbuff));
	memcpy(inbuff, outbuff, sizeof(outbuff));
} 

byte * open_file(const char *filepath, uint32 *filesize) {
    byte *filebuf;
    struct stat sb;
    int fd;

    if (filesize == NULL)
        return NULL;

    fd = open(filepath, O_RDONLY);
    if (fd == -1) {
        printf("fail to open %s\n", filepath);
        return NULL;
    }

    if (fstat(fd, &sb) == -1) {
        printf("fail to fstat %s\n", filepath);
        return NULL;
    }

    filebuf = (byte *)mmap(0, sb.st_size, PROT_READ, MAP_SHARED, fd, 0);
    if (filebuf == MAP_FAILED) {
        printf("fail to mmap %s\n", filepath);
        return NULL;
    }
 
    if (close(fd) == -1) {
        munmap(filebuf, sb.st_size);
        printf("fail to close %s\n", filepath);
        return NULL;
    }

    *filesize = sb.st_size;
    return filebuf;
}

void free_file(byte *filebuf,uint32 filesize) {
    if (munmap(filebuf, filesize) == -1) {
        printf("fail to munmap %p %u\n", filebuf, filesize);
    }
}

extern void qdl_pre_download(void);
extern void qdl_post_download(void);

static int download_files(qdl_context *ctx){

	char *program = (char *) malloc(MAX_PATH + MAX_PATH + 32);

	if (!program){
		printf("fail to malloc memory for program in download_files()\n");
		return 0;
	}

	const char *format = "ftpget %s:%d %s/%s firmware/%s";
	
	if(mkdir(ctx->firmware_path,S_IRWXU | S_IRWXG | S_IRWXO) != 0){
		if (errno != EEXIST){
			printf("Error:Mkdir failed!dir:%s, error: %s\n", ctx->firmware_path, strerror( errno ));
			return 0;
		}
	}
	
	sprintf(program, format, ctx->ftp_address, ctx->ftp_port, ctx->firmware_path, "partition.mbn", "partition.mbn");
	system(program);
	
	sprintf(program, format, ctx->ftp_address, ctx->ftp_port, ctx->firmware_path, "partition2.mbn", "partition2.mbn");
	system(program);
	
	sprintf(program, format, ctx->ftp_address, ctx->ftp_port, ctx->firmware_path, "NPRG9x15.hex", "NPRG9x15.hex");
	system(program);
	
	sprintf(program, format, ctx->ftp_address, ctx->ftp_port, ctx->firmware_path, "sbl1.mbn", "sbl1.mbn");
	system(program);
	
	sprintf(program, format, ctx->ftp_address, ctx->ftp_port, ctx->firmware_path, "sbl2.mbn", "sbl2.mbn");
	system(program);
	
	sprintf(program, format, ctx->ftp_address, ctx->ftp_port, ctx->firmware_path, "rpm.mbn", "rpm.mbn");
	system(program);
	
	sprintf(program, format, ctx->ftp_address, ctx->ftp_port, ctx->firmware_path, "appsboot.mbn", "appsboot.mbn");
	system(program);
	
	free(program);
	return 1;
}

int image_read(qdl_context *ctx) {
    struct dirent *dp;
    DIR *dfd;

	if(!download_files(ctx)){
		 printf("Error:Lost upgrade files\n");
		return 0;
	}

	asprintf(&ctx->system_path, "%s/%s", ctx->firmware_path, "msm-9615-cdp-image--ipk-9615-cdp.rootfs.yaffs2");
	//printf("system: %s\n", ctx->system_path);
	ctx->upgrade_fastboot++;

	asprintf(&ctx->userdata_path, "%s/%s", ctx->firmware_path, "9615-cdp-usr-image.usrfs.yaffs2");
	//printf("userdata: %s\n", ctx->userdata_path);
	ctx->upgrade_fastboot++;


	asprintf(&ctx->boot_path, "%s/%s", ctx->firmware_path, "boot-oe-msm9615.img");
	//printf("boot: %s\n", ctx->boot_path);
	ctx->upgrade_fastboot++;


	asprintf(&ctx->recovery_path, "%s/%s", ctx->firmware_path, "recovery-boot-oe-msm9615.img");
	//printf("recovery: %s\n", ctx->recovery_path);
	ctx->upgrade_fastboot++;


	asprintf(&ctx->recoveryfs_path, "%s/%s", ctx->firmware_path, "9615-cdp-recovery-image-9615-cdp.yaffs2");
	//printf("recoveryfs: %s\n", ctx->recoveryfs_path);
	ctx->upgrade_fastboot++;


	asprintf(&ctx->dsp1_path, "%s/%s", ctx->firmware_path, "dsp1.mbn");
	//printf("dsp1: %s\n", ctx->dsp1_path);
	ctx->upgrade_fastboot++;


	asprintf(&ctx->dsp2_path, "%s/%s", ctx->firmware_path, "dsp2.mbn");
	//printf("dsp2: %s\n", ctx->dsp2_path);
	ctx->upgrade_fastboot++;


	asprintf(&ctx->dsp3_path, "%s/%s", ctx->firmware_path, "dsp3.mbn");
	//printf("dsp3: %s\n", ctx->dsp3_path);
	ctx->upgrade_fastboot++;

	if((dfd=opendir(ctx->firmware_path))==NULL) {
		printf("Error:Open dir failed!dir:%s\n", ctx->firmware_path);
		return 0;
	}
	for(dp=readdir(dfd); NULL != dp; dp=readdir(dfd)) {
        if (strstr(dp->d_name, "appsboot.mbn") == dp->d_name) {
            asprintf(&ctx->appsboot_path, "%s/%s", ctx->firmware_path, dp->d_name);
            //printf("appsboot: %s\n", ctx->appsboot_path);
            ctx->upgrade_modem++;
        }
        else if (strstr(dp->d_name, "NPRG9x15.hex") == dp->d_name) {
            asprintf(&ctx->NPRG9x15_path, "%s/%s", ctx->firmware_path, dp->d_name);
            //printf("NPRG9x15: %s\n", ctx->NPRG9x15_path);
            ctx->upgrade_modem++;
        }
        else if (strstr(dp->d_name, "partition.mbn") == dp->d_name) {
            asprintf(&ctx->partition_path, "%s/%s", ctx->firmware_path, dp->d_name);
            //printf("partition: %s\n", ctx->partition_path);
            ctx->upgrade_modem++;
        } 
        else if (strstr(dp->d_name, "partition2.mbn") == dp->d_name) {
            asprintf(&ctx->partition2_path, "%s/%s", ctx->firmware_path, dp->d_name);
            //printf("partition2: %s\n", ctx->partition2_path);
            ctx->upgrade_modem++;
        } 
        else if (strstr(dp->d_name, "rpm.mbn") == dp->d_name) {
            asprintf(&ctx->rpm_path, "%s/%s", ctx->firmware_path, dp->d_name);
            //printf("rpm: %s\n", ctx->rpm_path);
            ctx->upgrade_modem++;
        }
        else if (strstr(dp->d_name, "sbl1.mbn") == dp->d_name) {
            asprintf(&ctx->sbl1_path, "%s/%s", ctx->firmware_path, dp->d_name);
            //printf("sbl1: %s\n", ctx->sbl1_path);
            ctx->upgrade_modem++;
        }   
        else if (strstr(dp->d_name, "sbl2.mbn") == dp->d_name) {
            asprintf(&ctx->sbl2_path, "%s/%s", ctx->firmware_path, dp->d_name);
            //printf("sbl2: %s\n", ctx->sbl2_path);
            ctx->upgrade_modem++;
        } else {
            if (dp->d_name[0] != '.')
                printf("unknow file %s in firmware path\n", dp->d_name);
        }
	}
    closedir(dfd);


    if (ctx->NPRG9x15_path != NULL) {
        NPRG9x15_handle(ctx);
    }
    if (ctx->update_path != NULL) {
		printf("update path exists\n");
        ctx->qqb_EC20 = open_file(ctx->update_path, &ctx->qqb_EC20_length);
    }
    else
		printf("update path does not exists\n");

    if (ctx->upgrade_fastboot == 0 && ctx->upgrade_modem ==  0) {
        printf("Error:Lost upgrade files\n");
        return 0;
    }
     
    return 1;
}

void auto_hex_download(void)
{
	g_hex_start_addr=0;
	go_hex_start_addr=0;
	ENPRG9x15_handle(QdlContext);
}
int image_close()
{
	//free_file();
	return 1;
}
int convert_asc_to_hex(unsigned char asc1,unsigned char asc2)
{
	int hex1 = 0, hex2 = 0;
	int ret_val = 0;
	if (asc1 >= 0x30 && asc1 <= 0x39) {
		hex1 = asc1 - 0x30;
	} else if (asc1 >= 0x41 && asc1 <= 0x46) {
		hex1 = asc1 - 0x41 + 0x0A;
	} else if (asc1 >= 0x61 && asc1 <= 0x66) {
		hex1 = asc1 - 0x61 + 0x0A;
	} else {
		return 9999;
	}
	if (asc2 >= 0x30 && asc2 <= 0x39) {
		hex2 = asc2 - 0x30;
	} else if (asc2 >= 0x41 && asc2 <= 0x46) {
		hex2 = asc2 - 0x41 + 0x0A;
	} else if (asc1 >= 0x61 && asc1 <= 0x66) {
		hex2 = asc2 - 0x61 + 0x0A;
	} else {
		return 9999;
	}
	ret_val = ((hex1 << 4) & 0xF0) + hex2;
	return ret_val;
}

int	g_hex_start_addr = 0; 
int go_hex_start_addr=0;
int decode_hexfile(unsigned char* srcHexFile, int srcFileSize, unsigned char** pbinfile )
{
	int i = 0, j;
	int addr1, addr2, len = 0;
	int tmpbuf;
	int nbinfile = 0;
	int isrecord = 0;
	int isstart = 0;
	*pbinfile = (unsigned char*) malloc(srcFileSize / 2);
	while (i <= srcFileSize) {
		if (srcHexFile[i] == 0x3a) {
			if (srcHexFile[i + 7] == 0x30 && srcHexFile[i + 8] == 0x34) //记录类型04
					{
				if ((addr1 = convert_asc_to_hex(srcHexFile[i + 9],
						srcHexFile[i + 10])) == 9999)
					return -1;
				if ((addr2 = convert_asc_to_hex(srcHexFile[i + 11],
						srcHexFile[i + 12])) == 9999)
					return -1;
				if (isstart == 0) {
					g_hex_start_addr = ((addr1 << 24) & 0xFF000000)
							+ ((addr2 << 16) & 0x00FF0000);
					isstart = 1;
				}
			} else if (srcHexFile[i + 7] == 0x30 && srcHexFile[i + 8] == 0x30) //记录类型00
					{
				if ((len = convert_asc_to_hex(srcHexFile[i + 1],
						srcHexFile[i + 2])) == 9999)
					return -1;
				for (j = 0; j < len; j++) {
					if ((tmpbuf = convert_asc_to_hex(srcHexFile[i + 9 + j * 2],
							srcHexFile[i + 10 + j * 2])) == 9999)
						return -1;
					(*pbinfile)[nbinfile++] = tmpbuf;
				}
				if (isrecord == 0) {
					if ((addr1 = convert_asc_to_hex(srcHexFile[i + 3],
							srcHexFile[i + 4])) == 9999)
						return -1;
					if ((addr2 = convert_asc_to_hex(srcHexFile[i + 5],
							srcHexFile[i + 6])) == 9999)
						return -1;
					int linear_addr = ((addr1 << 8) & 0xFF00) + addr2;
					g_hex_start_addr += linear_addr;
					isrecord = 1;
				}
			} else if (srcHexFile[i + 7] == 0x30 && srcHexFile[i + 8] == 0x35) //获取go命令发送的地址
					{
				int go_addr1, go_addr2, go_addr3, go_addr4 = 0;
				if ((go_addr1 = convert_asc_to_hex(srcHexFile[i + 9],
						srcHexFile[i + 10])) == 9999)
					return -1;
				if ((go_addr2 = convert_asc_to_hex(srcHexFile[i + 11],
						srcHexFile[i + 12])) == 9999)
					return -1;
				if ((go_addr3 = convert_asc_to_hex(srcHexFile[i + 13],
						srcHexFile[i + 14])) == 9999)
					return -1;
				if ((go_addr4 = convert_asc_to_hex(srcHexFile[i + 15],
						srcHexFile[i + 16])) == 9999)
					return -1;
				go_hex_start_addr = ((go_addr1 << 24) & 0xFF000000)
						+ ((go_addr2 << 16) & 0x00FF0000)
						+ ((go_addr3 << 8) & 0xFF00) + go_addr4;
			} else if (srcHexFile[i + 7] == 0x30 && srcHexFile[i + 8] == 0x31) //记录类型01，表示结???
					{

			}
		}
		i++;
	}
	return nbinfile;
}
void ENPRG9x15_handle(qdl_context *ctx) {
    byte *tempbuf = NULL;
    int temp_length = 0;
    byte *filebuf;
    uint32 filesize;

    if (ctx->ENPRG9x15_EC20 != NULL)
        return;

    filebuf = open_file(ctx->ENPRG9x15_path, &filesize);
    if (filebuf == NULL)
        return;
    
    temp_length = decode_hexfile(filebuf, filesize, &tempbuf);
    free_file(filebuf, filesize);
    ctx->ENPRG9x15_EC20 = tempbuf;
    ctx->ENPRG9x15_EC20_length = temp_length;
}

void NPRG9x15_handle(qdl_context *ctx) {
    byte *tempbuf = NULL;
    int temp_length = 0;
    byte *filebuf;
    uint32 filesize;

    if (ctx->NPRG9x15_EC20 != NULL)
        return;

    filebuf = open_file(ctx->NPRG9x15_path, &filesize);
    if (filebuf == NULL)
        return;
    
    temp_length = decode_hexfile(filebuf, filesize, &tempbuf);
    free_file(filebuf, filesize);
    ctx->NPRG9x15_EC20 = tempbuf;
    ctx->NPRG9x15_EC20_length = temp_length;
}
