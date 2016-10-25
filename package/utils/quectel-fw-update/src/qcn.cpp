//*********************************************
//*
//*		QCN back up and restore 
//*
//*
//********************************************

#include "platform_def.h"
#include "qcn.h"
#include <string.h>
#include "serialif.h"
#include "download.h"
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include "file.h"
#include "tinyxml.h"
#include <assert.h>
#if defined(TARGET_OS_LINUX) || defined(TARGET_OS_ANDROID)
#include "os_linux.h"
#endif 
#define KEYVALLEN 100
const char* backupqcnxml = "backup.xml";
NVITEM s_nvItem;
FILE *qdn_file;
byte nv_pbuf[250] = {0};
int nv_pbuf_length;
boolean back_up_qcn_name = FALSE;  //when read sn or imei, just read nv but no write to QDN file
extern byte  dloadbuf[];
extern int receive_packet(void);
extern int receive_packet_amss(void);
extern byte g_Receive_Buffer[];
extern int g_Receive_Bytes;
extern byte g_Transmit_Buffer[];	
extern int g_Transmit_Length;		
byte * dload_status = dloadbuf;
unsigned int DiagFrame(byte *pInBuf, unsigned int dwInBufLen, byte *pOutBuf, unsigned int dwOutBufSize)
{
	if (pInBuf == NULL || dwInBufLen == 0 || pOutBuf == NULL || dwOutBufSize == 0)
	{
		return 0;
	}
	int accm = 1;
	unsigned short  calc_fcs = HDLC_FCS_START;
	unsigned out_index = 0;
	byte c_byte = 0;  

	for (unsigned int i = 0; i < dwInBufLen; i++)
	{
		byte c = pInBuf[i];
		calc_fcs = hdlc_fcs_16(calc_fcs,c);
		//if (SHOULD_ESC_BYTE(c,accm))
		if ((c == 0x7E) || (c == 0x7D))
		{
			pOutBuf[out_index++] = HDLC_ESC_ASYNC;
			c ^= HDLC_ESC_COMPL;
		}
		pOutBuf[out_index++] = c;

	}  

	/*-------------------------------------------------------------------------
	Escape the 2 CRC bytes if necessary, process low-order CRC byte first
	-------------------------------------------------------------------------*/
	calc_fcs ^= 0xffff;
	c_byte = calc_fcs & 0x00ff;

	if( SHOULD_ESC_BYTE(c_byte, accm) )
	{
		pOutBuf[out_index++] = HDLC_ESC_ASYNC;
		pOutBuf[out_index++]= (uint8)(c_byte ^ HDLC_ESC_COMPL);
	}
	else /* no escaping needed */
	{
		pOutBuf[out_index++] = (uint8)c_byte;
	}

	/*-------------------------------------------------------------------------
	Process high-order CRC byte
	-------------------------------------------------------------------------*/
	c_byte = (calc_fcs >> 8); 
	if( SHOULD_ESC_BYTE(c_byte, accm) )
	{
		pOutBuf[out_index++] = HDLC_ESC_ASYNC;
		pOutBuf[out_index++] = (uint8)(c_byte ^ HDLC_ESC_COMPL);
	}
	else /* no escaping needed */
	{
		pOutBuf[out_index++] = (uint8)c_byte;
	}

	pOutBuf[out_index++] = HDLC_FLAG;
	return out_index;
}
unsigned int DiagUnframe(byte *pInBuf, unsigned int dwInBufLen, byte *pOutBuf, unsigned int dwOutBufSize)
{
	byte c =pInBuf[0];
	if (pInBuf == NULL || dwInBufLen == 0 || pOutBuf == NULL || dwOutBufSize == 0)
	{
		return 0;
	}
	unsigned out_index = 0;
	for (unsigned int i = 0; i < dwInBufLen; i++)
	{
		c = pInBuf[i];
		/*if (c == 0x7D)
		{
		c = pInBuf[++i] ^ 0x20;
		}*/
		pOutBuf[out_index++] = c;
	}
	return out_index;
};



int save_nv(unsigned char * buf, int nv_pbuf_length)
{
	int result =(int)fwrite(buf,sizeof(unsigned char),nv_pbuf_length,qdn_file);
	return result;	
}

int restore_nv(unsigned char * buf, int nv_pbuf_length)
{
	int result =(int)fread(buf,sizeof(unsigned char),nv_pbuf_length,qdn_file);
	//	fseek(qdn_file,0,SEEK_CUR);
	return result;	
}

void get_meid_number(unsigned char * meid,char * meid_ptr)
{
	byte info[16];
	//byte info1[2];
	int info1;
	int i = 0;
	itoa(0,(meid_ptr+0),16) ;
	itoa(0,(meid_ptr+1),16) ;
	for(i;i<g_Receive_Bytes;i++)
	{
		if(*(meid+i)=='\0')
		{
			break;
		}
		info1=(int)(*(meid+i));
		itoa(info1,(char *)&info[i],16);
		strcat(&meid_ptr[2],(const char *)&info[i]);

	}
#if 0 
	i=0;
	dsatutil_itoa(meid_hi, info, 16);
	int  n = strlen((char *)(info));
	if (n<8)
	{
		for (i=0;i<(8-n);i++)
		{
			buf_hi[i] = '0';
		}
	}
	memcpy(buf_hi+i, info, n);
	memcpy(meid_ptr,buf_hi+i,n);
	i=0;	
	dsatutil_itoa(meid_lo, info, 16);
	n = strlen((char *)(info));
	if (n<8)
	{
		for (i=0;i<(8-n);i++)
		{
			buf_lo[i] = '0';
		}
	}
	memcpy(buf_lo+i, info, n);
	/* Convert the high 32 bit unsigned number to hex */
	memset(dloadbuf,0,sizeof(dloadbuf));
	sprintf(dloadbuf,"%s%s",buf_hi+i,buf_lo+i);
	memcpy(meid_ptr,dloadbuf,i+i);
#endif
}

int dsat_get_imei
(
 unsigned char * ue_imei,                  /* Pointer to return buffer */
 char* rb_ptr
 )
{
	unsigned char imei_bcd_len = 0, n = 0, digit;
	char imei_ascii[(NV_UE_IMEI_SIZE-1)*2];


	/* Convert it to ASCII */
	imei_bcd_len = ue_imei[0];

	if( imei_bcd_len <= (NV_UE_IMEI_SIZE-1) )
	{
		/* This is a valid IMEI */
		memset(imei_ascii, 0, (NV_UE_IMEI_SIZE-1)*2);

		for( n = 1; n <= imei_bcd_len; n++ )
		{
			digit = ue_imei[n] & 0x0F;
			if( ( digit <= 9 ) || ( n <= 1 ) )
			{
				imei_ascii[ (n - 1) * 2 ] = digit + '0';
			}
			else
			{
				imei_ascii[ (n - 1) * 2 ] = '\0';
				break;
			}

			digit = ue_imei[n] >> 4;
			if( ( digit <= 9 ) || ( n <= 1 ) )
			{
				imei_ascii[ ((n - 1) * 2) + 1 ] = digit + '0';
			}
			else
			{
				imei_ascii[ ((n - 1) * 2) + 1 ] = '\0';
				break;
			}
		}

		/* Lose the first byte because it is just the ID */
		memcpy( rb_ptr, imei_ascii + 1, (NV_UE_IMEI_SIZE-1)*2-1 );
		rb_ptr[15]='\0';
		return 1;
	}
	else
	{
		/* This is an invalid IMEI */
		return 0;
	} 
}

#ifdef FEATURE_NEW_QCN_BACKUP
int NV_READ_F(unsigned short  _iNV_Item,unsigned char * _iNV_Data, int array_index,int array_size,int &array_tmp)
{
	unsigned short nv_status = 0;
	g_Transmit_Buffer[0] = 38;
	g_Transmit_Buffer[1] = _iNV_Item&0xFF;
	g_Transmit_Buffer[2] = (_iNV_Item>>8)&0xFF;
	if(array_size==0)
		memcpy((&g_Transmit_Buffer[3]),_iNV_Data,128);
	else
	{
		g_Transmit_Buffer[3]=array_index;
		memcpy((&g_Transmit_Buffer[4]),_iNV_Data,127);
	}
	g_Transmit_Buffer[131]=0;
	g_Transmit_Buffer[132]=0;
	g_Transmit_Length= 133;  
	memset(nv_pbuf,0,250);
	nv_pbuf_length =DiagFrame(g_Transmit_Buffer,g_Transmit_Length,nv_pbuf,128);
	WriteABuffer(g_hCom,(unsigned char*)nv_pbuf,nv_pbuf_length);
	do{
		if(receive_packet() == 1){
			DiagUnframe(g_Receive_Buffer, g_Receive_Bytes, nv_pbuf, 123);
			nv_pbuf_length=131;
			array_tmp=int(nv_pbuf[3]);
			switch (nv_pbuf[0]) {
			case 38:
				nv_status = (unsigned short) (nv_pbuf[132]) << 8 | nv_pbuf[131];
				if (nv_status == NV_DONE_S) {
					if(array_index==0)
						save_nv(nv_pbuf, nv_pbuf_length);
					else if(array_tmp==array_index)
						save_nv(nv_pbuf, nv_pbuf_length);
				}
				return nv_status;
			case 20: //this nv is not allowed to be read
				//printf("NV %d do not exist\r\n",_iNV_Item);
				return NV_BADPARM_S;
			case 66: //this nv is a sp item and it's locked
				//printf("NV %d do not exist\r\n",_iNV_Item);
				return NV_BADPARM_S;
			default:
				return NV_FAIL_S;
			}
		} else {

			return -1;//收不到数据，退出

		}
	} while (1);
}
//---------------------------读取ini文件方法
char * l_trim(char * szOutput, const char *szInput) {
	assert(szInput != NULL);
	assert(szOutput != NULL);
	assert(szOutput != szInput);
	for (NULL; *szInput != '\0' && isspace(*szInput); ++szInput) {
		;
	}
	return strcpy(szOutput, szInput);
}

/* 删除右边的空格 */
char *r_trim(char *szOutput, const char *szInput) {
	char *p = NULL;
	assert(szInput != NULL);
	assert(szOutput != NULL);
	assert(szOutput != szInput);
	strcpy(szOutput, szInput);
	for (p = szOutput + strlen(szOutput) - 1; p >= szOutput && isspace(*p); --p) {
		;
	}
	*(++p) = '\0';
	return szOutput;
}

/* 删除两边的空格 */
char * a_trim(char * szOutput, const char * szInput) {
	char *p = NULL;
	assert(szInput != NULL);
	assert(szOutput != NULL);
	l_trim(szOutput, szInput);
	for (p = szOutput + strlen(szOutput) - 1; p >= szOutput && isspace(*p); --p) {
		;
	}
	*(++p) = '\0';
	return szOutput;
}

int GetProfileString(const char *profile, const char *AppName, const char *KeyName, char *KeyVal) {
	char appname[32], keyname[32];
	char *buf, *c;
	char buf_i[KEYVALLEN], buf_o[KEYVALLEN];
	FILE *fp;
	int found = 0; /* 1 AppName 2 KeyName */
	if ((fp = fopen(profile, "r")) == NULL) {
		printf("openfile [%s] error [%s]\n", profile, strerror(errno));
		return (-1);
	}
	fseek(fp, 0, SEEK_SET);
	memset(appname, 0, sizeof(appname));
	sprintf(appname, "[%s]", AppName);

	while (!feof(fp) && fgets(buf_i, KEYVALLEN, fp) != NULL) {
		l_trim(buf_o, buf_i);
		if (strlen(buf_o) <= 0)
			continue;
		buf = NULL;
		buf = buf_o;

		if (found == 0) {
			if (buf[0] != '[') {
				continue;
			} else if (strncmp(buf, appname, strlen(appname)) == 0) {
				found = 1;
				continue;
			}

		} else if (found == 1) {
			if (buf[0] == '#') {
				continue;
			} else if (buf[0] == '[') {
				break;
			} else {
				if ((c = (char*) strchr(buf, '=')) == NULL)
					continue;
				memset(keyname, 0, sizeof(keyname));

				sscanf(buf, "%[^=|^ |^\t]", keyname);
				if (strcmp(keyname, KeyName) == 0) {
					sscanf(++c, "%[^\n]", KeyVal);
					char *KeyVal_o = (char *) malloc(strlen(KeyVal) + 1);
					if (KeyVal_o != NULL) {
						memset(KeyVal_o, 0, sizeof(KeyVal_o));
						a_trim(KeyVal_o, KeyVal);
						if (KeyVal_o && strlen(KeyVal_o) > 0)
							strcpy(KeyVal, KeyVal_o);
						free(KeyVal_o);
						KeyVal_o = NULL;
					}
					found = 2;
					break;
				} else {
					continue;
				}
			}
		}
	}
	fclose(fp);
	if (found == 2)
		return (0);
	else
		return (-1);
}
int vertify_NV(int _iNV_Item)
{
	char NV_Value[40];
	const char *name = "NVID_exclude_";
	char key_name[128] = { 0 };
	char NV_Items[2048] = { 0 };
	int index = 1;
	while (1) {
		memset(NV_Value, 0, 40);
		sprintf(key_name, "%s%d", name, index);
		int re = GetProfileString("config.ini", "NVID_EXCLUDE", key_name,
				NV_Value);
		if(_iNV_Item==atoi(NV_Value)&&_iNV_Item!=0)
		{
//					printf("%s\r\n",NV_Value);
//					printf("%d\r\n",_iNV_Item);
//					printf("\r\n");
			return 1;
		}
		if (re == -1)
			break;
		index++;
	}
	return 0;
}
//-----------------------------------
int  SaveQqbThreadFunc(qdl_context *pQdlContext)
{
	if(qdn_file!=NULL)
		qdn_file =NULL;

	qdn_file = fopen("backup.qqb","wb+");
	if(qdn_file == NULL)
	{  
		pQdlContext->text_cb("can't open backup.qqb");
		pQdlContext->msg_cb(1,"can't create the file \"backup.qqb\"","Error");
		qdl_sleep(2000);
		return 0;
	}
	//pQdlContext->prog_cb(0,100, 0);
	// Get the item number
	unsigned short _iStatus = NV_DONE_S;
	int array_size = 0;
	unsigned short _iNV_Item = 0;
	const unsigned short c_iSizeRequest = 128;
	unsigned char _iNV_Data[ c_iSizeRequest ];
	int array_index;
	int nv_item_index = NV_MAX_I;//自定义最大的nv项
	//int nv_item_index=5;
	for( _iNV_Item = 0; _iNV_Item < nv_item_index; _iNV_Item++ ){

//		if(vertify_NV(_iNV_Item))
//		{
//			continue;
//		}
		array_size=255;//数组默认最大是255
		array_index=0;

		while(array_index<=array_size)
		{

			int array_tmp=0;
			memset( _iNV_Data, 0, c_iSizeRequest );//初始化
			_iStatus = NV_READ_F(_iNV_Item,_iNV_Data,array_index,array_size,array_tmp);

			if(_iStatus==-1||_iStatus==65535)
				{

				fclose(qdn_file);
								if(qdn_file!=NULL)
									qdn_file =NULL;
							return 0;
				}
			if(array_tmp!=array_index)
				break;
			if(NV_DONE_S!=_iStatus)
				break;

			array_index++;
		}
		pQdlContext->prog_cb((_iNV_Item+1),nv_item_index, 0);
		if(_iNV_Item == 550)
		{
			s_nvItem._iNV_Item = 550;
			memcpy(s_nvItem._iNV_Data,&nv_pbuf[3],128);
		}

	}
	fclose(qdn_file);
	if(qdn_file!=NULL)
		qdn_file =NULL;
	qdl_sleep(1000);
	return 1;
}


int NV_WRITE_F(unsigned short  _iNV_Item)
{
	//printf("nv_item is %d\n",_iNV_Item);
	QdlContext->logfile_cb("nv_item is %d",_iNV_Item);
	g_Transmit_Buffer[0]=39;
	memset(nv_pbuf,0,250);
	g_Transmit_Buffer[131]=0;
	g_Transmit_Buffer[132]=0;
	g_Transmit_Length= 133;
	nv_pbuf_length =DiagFrame(g_Transmit_Buffer,g_Transmit_Length,nv_pbuf,128);
	WriteABuffer(g_hCom,(unsigned char*)nv_pbuf,nv_pbuf_length);
	do{
		if(receive_packet() == 1){
			nv_pbuf_length = DiagUnframe(g_Receive_Buffer, g_Receive_Bytes, nv_pbuf, 123);
			switch(nv_pbuf[0])
			{
			case 39:

				return NV_DONE_S;
			case 20:   //this nv is not allowed to be read
				//printf("NV %d do not exist\r\n",_iNV_Item);
				//printf("NV_BADPARM_S,20\n");
				QdlContext->logfile_cb("NV_BADPARM_S,20\n");
				return NV_BADPARM_S;
			case 66:  //this nv is a sp item and it's locked 
				//printf("NV %d do not exist\r\n",_iNV_Item);
				QdlContext->logfile_cb("NV_BADPARM_S,66\n");
				return NV_BADPARM_S;
			default:
				QdlContext->text_cb("\r\nrestore QDN:NV %d restore failed \r\n",_iNV_Item);
				return NV_FAIL_S;
			}
		}
		else
		{
			return -1;//收不到数据退出
		}
	}while(1);
}


int RestoreQqbThreadFunc(qdl_context *pQdlContext)
{
	char rb_ptr[40];
	if (qdn_file != NULL)
		qdn_file = NULL;
	char pathtemp[1024]={0};
	getcwd(pathtemp,1024);
	strcat(pathtemp, "/backup.qqb");
	qdn_file = fopen(pathtemp, "rb");

	//qdn_file = fopen( pQdlContext->qqbpath,"rb");
	if(qdn_file == NULL)
	{
		//pQdlContext->text_cb("pathtemp:%s",pathtemp);
		char qqbpath[1024] = { 0 };
		strcpy(qqbpath, pQdlContext->firmware_path);
		strcat(qqbpath, "backup.qqb");
		qdn_file = fopen(qqbpath, "rb");
		if(qdn_file == NULL)
		{
			pQdlContext->text_cb("qqbpath:%s",qqbpath);
			pQdlContext->text_cb("can't open restore file.qqb");
			qdl_sleep(1000);
			return 0;
		}

	}
	fseek(qdn_file,0 ,SEEK_END);
	int file_size = ftell(qdn_file);
	fseek(qdn_file,0 ,SEEK_SET);
	// Get the item number
	unsigned short _iStatus = NV_DONE_S;
	unsigned short _iNV_Item = 0;
	int result = 0;
	int file_read = 0;
	//int nv_item_index = sizeof(nvim_item_info_table)/sizeof(nvim_item_info_type);

	while(1){
		memset(g_Transmit_Buffer,0,300);
		result = restore_nv(g_Transmit_Buffer,131);
		file_read += result;
		if(result == 0)
		{
			//restore success
			break;
		}
		_iNV_Item = ((unsigned short)(g_Transmit_Buffer[2])<<8)|g_Transmit_Buffer[1];

		_iStatus = NV_WRITE_F( _iNV_Item);
		if(NV_DONE_S == _iStatus)
		{
			pQdlContext->prog_cb(file_read,file_size, 0);
		}
		else if(-1 == _iStatus)
		{
						fclose(qdn_file);
						if(qdn_file!=NULL)
							qdn_file =NULL;
						return 0;
		}
		else
		{

			continue;
		}
	}
	fclose(qdn_file);
	if(qdn_file!=NULL)
		qdn_file =NULL;
	return 1;
}

int getQQBdata(int size,int start_size)
{
	for(int i= 0; i < size; i++ )
	{
		if(QdlContext->qqb_EC20_length==(start_size+i))
		{
			return i;
			break;
		}
		else
		{
			g_Transmit_Buffer[i] = QdlContext->qqb_EC20[start_size+i];
		}

	}
	return size;
} 
int Import_Qqb_Func(qdl_context *pQdlContext)
{
	char rb_ptr[40];
	int file_size = QdlContext->qqb_EC20_length;
	// Get the item number
	unsigned short _iStatus = NV_DONE_S;
	unsigned short _iNV_Item = 0;
	int result = 0;
	int file_read = 0;
	//int nv_item_index = sizeof(nvim_item_info_table)/sizeof(nvim_item_info_type);

	while(1){
		memset(g_Transmit_Buffer,0,300);
		result = getQQBdata(131,file_read);
		file_read += result;
		if(result ==0)
		{
			break;
		}
		_iNV_Item = ((unsigned short)(g_Transmit_Buffer[2])<<8)|g_Transmit_Buffer[1];

		_iStatus = NV_WRITE_F( _iNV_Item);
		if(NV_DONE_S == _iStatus)
		{
			pQdlContext->prog_cb(file_read,file_size, 0);
		}
		else
			return 0;
	}
	return 1;
}

uint8 chartohex(char* tmp)
{
	int retdata = 0;
	int d_1 = 0;
	int d_2 = 0;
	if (*tmp >= '0' && *tmp <= '9')//0-9
		d_1 = (*tmp - 48);
	else if (*tmp >= 'A' && *tmp <= 'F')//a-f
		d_1 = (*tmp - 65) + 10;

	if (*(tmp + 1) >= '0' && *(tmp + 1) <= '9')
		d_2 = ((*(tmp + 1) - 48));
	else if (*(tmp + 1) >= 'A' && *(tmp + 1) <= 'F')
		d_2 = ((*(tmp + 1) - 65)) + 10;

	retdata = d_1 * 16 + d_2;
	return (uint8(retdata));
}
int  SaveQqbThreadFunc_AT(qdl_context *pQdlContext)//AT口备份qqb
{
	int offset, datacount = 0;
	if (qdn_file != NULL)
		qdn_file = NULL;
	qdn_file = fopen("backup.qqb", "wb+");
	if (qdn_file == NULL) {
		pQdlContext->text_cb("can't open backup.qqb");
		pQdlContext->msg_cb(1, "can't create the file \"backup.qqb\"", "Error");
		qdl_sleep(2000);
		return 0;
	}
	pQdlContext->prog_cb(0, 100, 0);
	int NV_MAX_Count = get_NV_Count();//获取MAX NVID
	//int NV_MAX_Count=11;
	for (int i = 0; i <=NV_MAX_Count; i++) {
		int array_index = 0;
		while (array_index <= 255) {
			char NV_value[400];//保存nv的值
			memset(NV_value, 0, sizeof(NV_value));
			int re = get_NV_value(i, array_index, NV_value);//send AT+QNVR=nv_id,index
			if (re == 1)//按照格式转成qqb格式
			{
				//				pQdlContext->text_cb("item is %d,index is %d,value is %s",i,array_index,NV_value);
				if (GetOffset_DataCount(i, &offset, &datacount)) {
					unsigned char qqb_buffer[132] = { 0 };
					qqb_buffer[0] = 0x26;
					qqb_buffer[1] = (uint8) i;
					qqb_buffer[2] = (uint8) (i >> 8);
					int write_index = 3;
					if (offset > 0)//表示nv是个数组
					{
						qqb_buffer[write_index] = (uint8) array_index;
						write_index++;
					}
					int nv_value_length = strlen(NV_value);
					//pQdlContext->text_cb("nv_value_length is %d",nv_value_length);
					for (int nl = 0; nl < nv_value_length; nl += 2) {
						char buf_tmp[2] = { 0 };
						memcpy(buf_tmp, NV_value + nl, 2);
						qqb_buffer[write_index++] = chartohex(buf_tmp);

						if (write_index > 131) {
							fclose(qdn_file);
							if (qdn_file != NULL)
								qdn_file = NULL;
							return 0;
						}

					}
					qqb_buffer[131] = '\0';
					save_nv(qqb_buffer, 131);
				} else {
					fclose(qdn_file);
					if (qdn_file != NULL)
						qdn_file = NULL;
					return 0;
				}
				array_index++;
			} else if (re == -1)//发送超时，直接退出
			{
				fclose(qdn_file);
				if (qdn_file != NULL)
					qdn_file = NULL;
				return 0;
			} else//返回error，跳出循环
			{
				break;
			}
		}
		pQdlContext->prog_cb(i , NV_MAX_Count, 0);
	}
	fclose(qdn_file);
	if (qdn_file != NULL)
		qdn_file = NULL;
	qdl_sleep(1000);
	return 1;
}
int  RestoreQqbThreadFunc_AT(qdl_context *pQdlContext)//AT口还原qqb
{

	int array_index = 0;
	unsigned short _iNV_Item = 0;
	if (qdn_file != NULL)
		qdn_file = NULL;
	pQdlContext->prog_cb(0, 100, 0);
	char qqbpath[1024]={0};
	strcpy(qqbpath, pQdlContext->firmware_path);
	strcat(qqbpath,"backup.qqb");
	qdn_file = fopen(qqbpath, "rb");
	if (qdn_file == NULL) {
		pQdlContext->text_cb("can't open restore file.qcn");
		qdl_sleep(1000);
		return 0;
	}
	fseek(qdn_file, 0, SEEK_END);
	int file_size = ftell(qdn_file);
	fseek(qdn_file, 0, SEEK_SET);
	int result = 0;
	int file_read = 0;
	while (1) {
		int offset, datacount = 0;
		memset(g_Transmit_Buffer, 0, 300);
		result = restore_nv(g_Transmit_Buffer, 131);
		file_read += result;
		if (result == 0) {
			break;
		}
		_iNV_Item = ((unsigned short) (g_Transmit_Buffer[2]) << 8)
				| g_Transmit_Buffer[1];//获取NV_ID

		if (GetOffset_DataCount(_iNV_Item, &offset, &datacount)) {
			//pQdlContext->text_cb("offset is %d,datacount is %d",offset,datacount);
			if (offset > 0)//表示nv是个数组
			{
				array_index = int(g_Transmit_Buffer[3]);
			}
			char hex_date[400] = { 0 };
			for (int i = 0; i < datacount; i++) {
				char temp[3] = { 0 };
				if (offset > 0) {
					sprintf(temp, "%02X", g_Transmit_Buffer[4 + i]);
				} else {

					sprintf(temp, "%02X", g_Transmit_Buffer[3 + i]);
				}
				temp[2] = '\0';
				memcpy(hex_date + i * 2, temp, 2);
			}

			//AT写入NV
			int re=Write_NV(_iNV_Item, array_index, hex_date);
			if (!re) {
				//pQdlContext->text_cb("re is %d",re);
				pQdlContext->logfile_cb("AT+QNVW=%d,%d,\"%s\"\r\n", _iNV_Item,
						array_index, hex_date);
				//pQdlContext->text_cb("AT+QNVW=%d,%d,\"%s\"\r\n", _iNV_Item,array_index, hex_date);
				fclose(qdn_file);
				if (qdn_file != NULL)
					qdn_file = NULL;
				//pQdlContext->text_cb("1");
				return 0;
			}
			if(re==-1)
			{
				pQdlContext->logfile_cb("AT+QNVW=%d,%d,\"%s\"\r\n", _iNV_Item,
														array_index, hex_date);
				continue;

			}
		} else {
//			fclose(qdn_file);
//			if (qdn_file != NULL)
//				qdn_file = NULL;
//			//pQdlContext->text_cb("2");
//			return 0;
			continue;
		}
		pQdlContext->prog_cb(file_read, file_size, 0);
	}
	fclose(qdn_file);
	if (qdn_file != NULL)
		qdn_file = NULL;
	return 1;
}
int  Import_Qqb_Func_AT(qdl_context *pQdlContext)//AT口导入qcn
{

	int array_index = 0;
	unsigned short _iNV_Item = 0;
	pQdlContext->prog_cb(0, 100, 0);
	int file_size = QdlContext->qqb_EC20_length;
	int result = 0;
	int file_read = 0;
	while (1) {
		int offset, datacount = 0;
		memset(g_Transmit_Buffer, 0, 300);
		result = getQQBdata(131, file_read);
		file_read += result;
		if (result == 0) {
			break;
		}
		_iNV_Item = ((unsigned short) (g_Transmit_Buffer[2]) << 8)
				| g_Transmit_Buffer[1];//获取NV_ID

		if (GetOffset_DataCount(_iNV_Item, &offset, &datacount)) {
			//pQdlContext->text_cb("offset is %d,datacount is %d",offset,datacount);
			if (offset > 0)//表示nv是个数组
			{
				array_index = int(g_Transmit_Buffer[3]);
			}
			char hex_date[400] = { 0 };
			for (int i = 0; i < datacount; i++) {
				char temp[3] = { 0 };
				if (offset > 0) {
					sprintf(temp, "%02X", g_Transmit_Buffer[4 + i]);
				} else {

					sprintf(temp, "%02X", g_Transmit_Buffer[3 + i]);
				}
				temp[2] = '\0';
				memcpy(hex_date + i * 2, temp, 2);
			}
//			pQdlContext->text_cb("xxxxxxxxxxxxxxxxxx");
			//AT写入NV
			int re = Write_NV(_iNV_Item, array_index, hex_date);
			if (!re) {
				pQdlContext->logfile_cb("AT+QNVW=%d,%d,\"%s\"\r\n", _iNV_Item,
						array_index, hex_date);
				return 0;
			}
			if (re == -1) {
				pQdlContext->logfile_cb("AT+QNVW=%d,%d,\"%s\"\r\n", _iNV_Item,
						array_index, hex_date);
				continue;

			}
		} else {

			return 0;
		}
		pQdlContext->prog_cb(file_read, file_size, 0);
	}
	return 1;
}
#endif


