/*********************************
    数据打包，以及串口接�?
**********************************/
#include "platform_def.h"
#include <stdlib.h>
#include "serialif.h"
#include "download.h"
#include "file.h"
#include <stdio.h>
#include <time.h>
#ifdef TARGET_OS_WINDOWS
#include "os_windows.h"
#endif

#if defined(TARGET_OS_LINUX) ||defined(TARGET_OS_ANDROID)
#include <string.h>
#include "os_linux.h"
#endif 

HANDLE g_hCom; //串口句柄

#define ASYNC_HDLC_FLAG 0x7E
#define ASYNC_HDLC_ESC 0x7D
#define ASYNC_HDLC_ESC_MASK 0x20
#define MAX_RECEIVE_BUFFER_SIZE 2048   //一个数据包的最大的size
#define MAX_SEND_BUFFER_SIZE 2048

byte  dloadbuf[250]; //临时缓存一个buffer
byte g_Receive_Buffer[MAX_RECEIVE_BUFFER_SIZE];     //收到的buf
int g_Receive_Bytes;                            //收到的buffer大小

byte g_Transmit_Buffer[MAX_SEND_BUFFER_SIZE];    //发送的代码
int g_Transmit_Length;                            //发送的buffer大小

//CRC 校验代码

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

uint16 crc_16_l_calc
(
 byte *buf_ptr,
 /* Pointer to bytes containing the data to CRC.  The bit stream starts
 ** in the LS bit of the first byte.
 */

 uint16 len
 /* Number of data bits to calculate the CRC over */
 )
{
    uint16 data, crc_16;

    /* Generate a CRC-16 by looking up the transformation in a table and
    ** XOR-ing it into the CRC, one byte at a time.
    */
    for (crc_16 = CRC_16_L_SEED ; len >= 8; len -= 8, buf_ptr++) {
        crc_16 = crc_16_l_table[ (crc_16 ^ *buf_ptr) & 0x00ff ] ^ (crc_16 >> 8);
    }

    /* Finish calculating the CRC over the trailing data bits
    **
    ** XOR the MS bit of data with the MS bit of the CRC.
    ** Shift the CRC and data left 1 bit.
    ** If the XOR result is 1, XOR the generating polynomial in with the CRC.
    */
    if (len != 0) {

        data = ((uint16) (*buf_ptr)) << (16-8); /* Align data MSB with CRC MSB */

        while (len-- != 0) {
            if ( ((crc_16 ^ data) & 0x01) != 0 ){   /* Is LSB of XOR a 1 */

                crc_16 >>= 1;                   /* Right shift CRC         */
                crc_16 ^= CRC_16_L_POLYNOMIAL;  /* XOR polynomial into CRC */

            } else {

                crc_16 >>= 1;                   /* Right shift CRC         */

            }

            data >>= 1;                       /* Right shift data        */
        }
    }

    return( ~crc_16 );            /* return the 1's complement of the CRC */

} /* end of crc_16_l_calc */

void  compute_reply_crc ()
{
    uint16 crc = crc_16_l_calc (g_Transmit_Buffer, g_Transmit_Length * 8);
    g_Transmit_Buffer[g_Transmit_Length] = crc & 0xFF;
    g_Transmit_Buffer[g_Transmit_Length + 1] = crc >> 8;
    g_Transmit_Length += 2;
}

static void compose_packet(byte cmd, byte *parameter, uint32 parameter_len, byte *data, uint32 data_len) {
    int i;

    g_Transmit_Buffer[0] = cmd;
    if (parameter == NULL) parameter_len = 0;
    if (data == NULL) data_len = 0;
    for (i = 0; i < parameter_len; i++) {
        g_Transmit_Buffer[1 + i] = parameter[i];
    }
    for (i = 0; i < data_len; i++) {
        g_Transmit_Buffer[1 + parameter_len + i] = data[i];
    }
    g_Transmit_Length = 1 + parameter_len + data_len;
    g_Transmit_Buffer[g_Transmit_Length] = 0;
}

static unsigned char send_tmp[2500];
static int send_tmp_length = 0;

static int send_packet(int flag)
{
    int i;
    int ch;
    int bytes_sent = 0;

    memset(send_tmp, 0,  2500);
    send_tmp_length = 0;
    
    /* Since we don't know how long it's been. */
    if(flag == 1){
        //send_transmit (0x7e);
        send_tmp[send_tmp_length++] = 0x7e;
    }
    
    for (i = 0; i < g_Transmit_Length; i++)
    {
        
        ch = g_Transmit_Buffer[i];
        
        if (ch == 0x7E || ch == 0x7D)
        {
            //send_transmit (0x7D);
            //send_transmit (0x20 ^ ch);        /*lint !e734 */
            send_tmp[send_tmp_length++] = 0x7d;
            send_tmp[send_tmp_length++] = 0x20^ ch;
            
            //printf("write data get 0x7E[%x]\r\n", (byte) ch);
        }
        else
        {
            //send_transmit (ch);       /*lint !e734 */
            send_tmp[send_tmp_length++] = ch;
        }
    }
    
    //send_transmit (0x7E);
    send_tmp[send_tmp_length++] = 0x7e;

    bytes_sent=WriteABuffer(g_hCom, send_tmp, send_tmp_length);

    if(bytes_sent == send_tmp_length)
        return TRUE;
    else
    {
        QdlContext->logfile_cb("send_pck, want :%d, sent :%d", send_tmp_length, bytes_sent);
        return FALSE;
    }

}
static void clean_buffer(void)
{
    memset(g_Receive_Buffer,0,sizeof(g_Receive_Buffer));
    g_Receive_Bytes=0;
}
#ifdef FEATURE_FAST_DOWNLOAD
#define MAX_TIMEOUT_FOR_RECV_PKT     (3000)
#define MAX_RETRY_CNT_FOR_RECV_PKT    (50)
#endif


UINT_PTR GetTickCount()
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return (ts.tv_sec * 1000 + ts.tv_nsec / 1000000);
}


int receive_packet(void)
{
#ifdef FEATURE_FAST_DOWNLOAD
    int timeout=MAX_TIMEOUT_FOR_RECV_PKT;
    int retry_cnt = MAX_RETRY_CNT_FOR_RECV_PKT;
#else
    int timeout = 30000;
#endif 
    int result = false;
    BOOL bBool;
    uint32 BeReceiveBytes;
    byte * ReceiveByte = g_Receive_Buffer;
    byte escape_state = 0;
    clean_buffer();

#ifdef FEATURE_FAST_DOWNLOAD
    start_to_recv:
#endif 

    BeReceiveBytes = ReadABuffer(g_hCom, ReceiveByte, 1);

    if (BeReceiveBytes == 1 && (*ReceiveByte != ASYNC_HDLC_FLAG)) {

        ReceiveByte += BeReceiveBytes;
    }
    UINT_PTR t_read_s, t_read_e;
    t_read_s = t_read_e = GetTickCount();
    while (timeout > 0) {
        t_read_e = GetTickCount();
        if ((t_read_e - t_read_s) > 5000) {
            //QdlContext->text_cb("Receive data timeout");
            QdlContext->logfile_cb("Receive data timeout");
            return 0;
        }
        BeReceiveBytes = ReadABuffer(g_hCom, ReceiveByte, 1);
#ifdef FEATURE_FAST_DOWNLOAD
        if((int)BeReceiveBytes <= 0)
        {
            extern int errno;
            printf("errno=%d\n",errno);
            char *mesg=strerror(errno);
            printf("Mesg:%s\n",mesg);
            timeout--;
            if(timeout <= 2980)
            {
                if(retry_cnt == MAX_RETRY_CNT_FOR_RECV_PKT) /*first time to retry*/
                {
                    QdlContext->text_cb("\nno response, try to re-send the packet![%d]", retry_cnt);
                    retry_cnt--;
                }
                else if(retry_cnt == 0)
                {
                    QdlContext->text_cb("reach the max retry count, error happened!");

                    return 0;
                }
                else
                {
                    QdlContext->text_cb("no response, try to re-send the packet![%d]", retry_cnt);
                    retry_cnt--;
                }

                send_packet(1);
                qdl_sleep(2000);
                goto start_to_recv;
            }
            continue;
        }
#else
        if ((int) BeReceiveBytes <= 0) {
            timeout--;
            continue;
        }
#endif 
        if (BeReceiveBytes == 1) {
            if (*ReceiveByte == ASYNC_HDLC_FLAG) {
                //timeout=0;
                result = true;
                break;
            }

            switch (*ReceiveByte) {
            //deal with some change data come from target
            case 0x7D:
                escape_state = 1;
                break;

            default:
                if (escape_state) {
                    (*ReceiveByte) ^= 0x20;
                    escape_state = 0;
                }
                ReceiveByte += BeReceiveBytes;
                //break;
            }
        } else {
            return false;
        }

        timeout--;
    }

    if (timeout == 0) {
        QdlContext->logfile_cb("timeout");
        return 0;
    }

    g_Receive_Bytes = ReceiveByte - g_Receive_Buffer;
    if (g_Receive_Buffer[0] == ASYNC_HDLC_FLAG) {
        return 0;
    }
    return result;
}

int read_buildId(void) {
    compose_packet(124, NULL, 0, NULL, 0);
    compute_reply_crc();
    send_packet(0);
    do{
        if(receive_packet() == 1)
        {
            memset(dloadbuf,0,sizeof(dloadbuf));
            int i=0,index = 0;
            for(i;i<=g_Receive_Bytes;i++)
            {
                if(g_Receive_Buffer[i] != '\0') 
                {
                    dloadbuf[index++] =g_Receive_Buffer[i] ;
                }
            }
                /*memset(g_Receive_Buffer,0,sizeof(g_Receive_Buffer));
                memcpy(g_Receive_Buffer,dloadbuf,index);
                printf("Version:%s\r\n",&g_Receive_Buffer[1]);
                sprintf(dload_status,"Version:%s\r\n",&g_Receive_Buffer[1]);
                save_log(dload_status);*/
                break;
            }
        }while(1);
    
    return 1;
}
/*******获取当前模块的当前模�?*********/
target_current_state send_sync(void)        
{
       const static byte noppkt[]={0x7e,0x06,0x4e,0x95,0x7e};
    const static byte tpkt[]={0x7e,0x02,0x6a,0xd3,0x7e};

    const static byte ipkt[]={0x7e,0x0e};
    const static byte fpkt[]={0x13,0x06,0x88,0xd5,0x7e};
    target_current_state result;
    DWORD dwRead;    
    DWORD dwToRead;    
    COMSTAT ComStat;
    DWORD dwErrorFlags;
    unsigned char pBuf[100];
    int timeout=10;
    HANDLE file;
    int rl,wl;
    OVERLAPPED overlap={0};
    result=STATE_UNSPECIFIED;
    qdl_flush_fifo(g_hCom, 1, 1);
    wl=WriteABuffer(g_hCom, (unsigned char *)noppkt, sizeof(noppkt));
    if(wl==0)
    {
        QdlContext->text_cb("send_sync write failed");
        return result;
    }
    qdl_sleep(500);
    //QdlContext->text_cb( "111");
    rl=ReadABuffer(g_hCom, pBuf,sizeof(pBuf));
    //QdlContext->text_cb( "2222");
    for(int i=0;i<rl;i++)
    {
        //QdlContext->text_cb( "buf i:[%d],value is [0x%02x]",i,pBuf[i]);
    }
    if(rl==0)
    {

       
        QdlContext->text_cb("send_sync read failed");
        return result;
    }
    if(!memcmp(pBuf, tpkt, sizeof(tpkt)))
    {
        result=STATE_DLOAD_MODE;
        //QdlContext->text_cb( "in download mode");
        QdlContext->text_cb("in download mode");
    }    
    else if(!memcmp(pBuf, fpkt, sizeof(fpkt)))
    {
        result=STATE_NORMAL_MODE;
        //QdlContext->text_cb( "in normal mode");
        QdlContext->text_cb("in normal mode");
    }    
    else if(!memcmp(pBuf, ipkt, sizeof(ipkt)))
    {
        result=STATE_GOING_MODE;
        //QdlContext->text_cb( "in go mode");
        QdlContext->text_cb("in go mode");
    }        
    else
        //result=STATE_NORMAL_MODE;
        result=STATE_UNSPECIFIED;
    return result;    
}

int read_version(void) {
    compose_packet(0x00, NULL, 0, NULL, 0);
    compute_reply_crc();

    qdl_flush_fifo(g_hCom, 1, 1);
        
        send_packet(0);
        do{
            if(receive_packet() == 1){
                switch(g_Receive_Buffer[0])
                {
                case 0:
                    return 1;
                default:
                    return -1;
                }
            }
        }while(1);
    return 1;
}
#if 0
int find_char(char *p1,char *p2,int *n)//��p1�����p2
{
    int flag=0;//��־�Ƿ����?
    int loca;//��־����λ��
    int len=0;//��¼�����ߵ�λ�õ�
    int len1,len2;//�ֱ��¼�������ĳ���?
    char *t1,*t2;
    int len_2;//��־2���˵�λ��
    t1=p1;
    t2=p2;
    len1=strlen(t1);
    len2=strlen(t2);
    if(len2>len1)//�����ҵĴ���ԭ����
    {
        /*printf("\"");
        print(p1);
        printf("\"");
        printf("����:");
        printf("\"");
        print(p2);
        printf("\"");
        putchar(10);*/
        return 0;
    }
    else
    {
        while(strlen(t1)>=strlen(t2))
        {
            if(*t1!=*t2)
            {
                t1++;
                len++;
            }
            else
            {
                len_2=0;
                while(*t1==*t2&&*t2)
                {
                    t1++;
                    t2++;
                    len_2++;
                }
                if(len2==len_2)
                {
                    flag=1;//�ܲ��ҵ�
                    loca=len;//��¼��ʼλ��
                    break;
                }
                else
                {
                    len++;
                    t1=p1+len;
                    t2=p2;
                }
            }
        }
        if(flag==1)//���ҵ���
        {
            /*printf("\"");
            print(p1);
            printf("\"");
            printf("�а�\"");
            print(p2);
            printf("\"");
            putchar(10);
            printf("λ����%d����ʼ!\n",len+1);*/
            *n=len;
            return 1;
        }
    }
    return 0;
}


bool module_version(void)
{
    int result = 0;
    int mod_ver = 0;
    read_buildId();

    result = find_char(&dloadbuf[0],"6085",&mod_ver);
    if(result == 1)
    {
        is_amss_6085 = TRUE;
        target_ver = target_ver |0x0001;
    }
    result = find_char(&dloadbuf[0],"6290",&mod_ver);
    if(result == 1)
    {
        is_amss_6290 = TRUE;
        target_ver = target_ver |0x0002;
    }
    result = find_char(&dloadbuf[0],"6270",&mod_ver);
    if(result == 1)
    {
        is_amss_6270 = TRUE;
        target_ver =  target_ver |0x0004;
    }
    memcpy(&dloadbuf[mod_ver + 19] , "\r\n\0",3);
    printf("Build ID:%s\r\n",&dloadbuf[mod_ver]);
    //sprintf(dload_status,"Build ID:%s\r\n",&dloadbuf[mod_ver]);
    save_log(&dloadbuf[mod_ver]);
    if(mod_ver == NULL)
        return FALSE;
    else
        return TRUE;
}
#endif
byte* get_error_code()
{
    static byte error_code[5];
    memset(error_code,0,sizeof(error_code));
    if(strlen((const char *)g_Receive_Buffer)>5)
    {
        error_code[0]=g_Receive_Buffer[1];
        error_code[1]=g_Receive_Buffer[2];
        error_code[2]=g_Receive_Buffer[3];
        error_code[3]=g_Receive_Buffer[4];
    }
    return error_code;
}
int handle_erase_efs(void) {
    byte mode = 0x09;
    compose_packet(0x1b, &mode, 1, NULL, 0);
    compute_reply_crc();
    send_packet(1);
    do{
        if(receive_packet() == 1){
            switch(g_Receive_Buffer[0])
            {
            case 0x1c:
                return 1;
//            case 0x0D:
//                QdlContext->text_cb("efs error is %s",get_error_code());
//                QdlContext->logfile_cb("efs error is %s",get_error_code());
//                return 0;
            default:
                return 0;
            }
        }
    }while(1);
    return 1;

}

int normal_reset(void) {
    byte mode[2] = {2, 0};
    compose_packet(0x29, mode, sizeof(mode), NULL, 0);
    compute_reply_crc();
    send_packet(1);
    //printf("reset to normal mode...\r\n");
    //save_log("reset to normal mode\r\n");
    return 1;

}


int handle_switch_target_ftm(void) {
    byte mode[2] = {1, 0};
    compose_packet(0x29, mode, sizeof(mode), NULL, 0);
    compute_reply_crc();
    send_packet(1);
    do{
        //printf("switch to offline mode, please wait...\r\n");
        //save_log("switch to offline mode, please wait...\r\n");
        qdl_sleep(5000);
        if(receive_packet() == 1){
            switch(g_Receive_Buffer[0])
            {
            case 0x29:
            //    printf("target is in offline mode \r\n");
            //    save_log("target is in offline mode\r\n");
                return 1;
            default:
            //    printf("NV: SwitchToOffline failed !!!\r\n");
            //    save_log("NV: SwitchToOffline failed!!!\r\n");
                return -1;
            }
        }
    }while(1);
    return 1;

}
//AT+QDL
int handle_send_sp_code(void)
{
    int i = 0;
    int loop = 2;
    memset(&g_Transmit_Buffer[0],0,sizeof(g_Transmit_Buffer));
    g_Transmit_Buffer[0] = 0x41;
    for( i = 1; i < 7; i++ )
        g_Transmit_Buffer[i] = 0x30;    

    g_Transmit_Length = i ;
    compute_reply_crc();
try_again:
    send_packet(1);
    loop--;
    do{
        //printf("set sp unlocked, please wait...\r\n");
        //save_log("set sp unlocked, please wait...\r\n");
        qdl_sleep(2000);
        if(receive_packet() == 1){
            switch(g_Receive_Buffer[0])
            {
            case 0x41:
                if(1 == g_Receive_Buffer[1] )
                {
                    //printf("sp unlocked \r\n");
                    //save_log("sp unlocked\r\n");
                    return 1;
                }
                else
                {
                    //printf(" SP is still locked \r\n");
                    //save_log(" SP is still locked\r\n");
                    if(loop!=0)
                        goto try_again;
                    
                    return 0;//Code was incorrect and SP is still locked
                }
            default:
                return 0;
            }
        }
    }while(1);
    return 1;

}

int switch_to_dload(void) {
    compose_packet(0x3a, NULL, 0, NULL, 0);
    compute_reply_crc();

    qdl_flush_fifo(g_hCom, 1, 1);
        
    int re=send_packet(0);
    return re;
}

/******nop����*******/
int send_nop(void) {
    compose_packet(0x06, NULL, 0, NULL, 0);
    compute_reply_crc();

    qdl_flush_fifo(g_hCom, 1, 1);
        
    send_packet(1);
    do{
        if(receive_packet() == 1){
            switch(g_Receive_Buffer[0])
            {
            case 0x02:
                return 1;
            case 0x0d:
                continue;
            default:
                return 0;
            }
        }
    }while(1);
}

int preq_cmd(void) {
    compose_packet(0x07, NULL, 0, NULL, 0);
    compute_reply_crc();

    qdl_flush_fifo(g_hCom, 1, 1);
    
    send_packet(1);
    do{
        if(receive_packet() == 1){
            switch(g_Receive_Buffer[0])
            {
            case 0x08:
                return 1;
            default:
                return 0;
            }
        }
    }while(1);
}
/*******write_32bit_cmd******/
int write_32bit_cmd(void)
{
    unsigned int base = g_hex_start_addr;
    int i,j;
    unsigned char *pdst = NULL;
    unsigned char *pscr = NULL;
    int packet_length;
    pscr = (unsigned char *)QdlContext->NPRG9x15_EC20;
    packet_length = QdlContext->NPRG9x15_EC20_length;
    int size = 0x03f9;
    int loop = 1;

    qdl_flush_fifo(g_hCom, 1, 1);
    g_Transmit_Length = 0;
    for(i=0;i<packet_length;)
    {
        memset(&g_Transmit_Buffer[0], 0, sizeof(g_Transmit_Buffer));
        
        
        g_Transmit_Buffer[0] = 0x0f;
        g_Transmit_Buffer[1] = (base>>24)&0xff;
        g_Transmit_Buffer[2] = (base>>16)&0xff;
        g_Transmit_Buffer[3] = (base>>8)&0xff;
        g_Transmit_Buffer[4] = (base)&0xff;

        if((i+size)>packet_length){
            size = packet_length - i;
        }
        g_Transmit_Buffer[5] = (size>>8)&0xff;
        g_Transmit_Buffer[6] = (size)&0xff;
        
        pdst = &g_Transmit_Buffer[7];
        for(j=0; j<size; j++){
            *pdst++ = *pscr++;    
        }
        
        base += size;
        i += size;
        g_Transmit_Length = 7+size;
        compute_reply_crc();
        send_packet(1);
        loop = 1;
        int timeout=5;
        do{
            if(receive_packet() == 1){
                //    for(int i=0;i<rl;i++)
                //    {
                //        QdlContext->text_cb( "buf i:[%d],value is [0x%02x]",i,pBuf[i]);
                //    }
                //QdlContext->text_cb( "value is [0x%02x]",g_Receive_Buffer[0]);
                switch(g_Receive_Buffer[0])
                {
                case 0x02:
                    QdlContext->prog_cb(i, packet_length,0);
                    loop = 0;
                    break;
                default:
                    return 0;
                    break;
                }
            }
            else {
                timeout--;
                //QdlContext->text_cb("read packet error, try again");
                QdlContext->logfile_cb("read packet error, try again");
                if (timeout == 0) {
                    return 0;
                    break;
                }
            }

        }while(loop == 1);    
    }

    QdlContext->text_cb(""); 
    
    return 1;
}
/*******write_32bit_cmd_emerg******/
int write_32bit_cmd_emerg(void)
{
    unsigned int base = g_hex_start_addr;
    int i,j;
    unsigned char *pdst = NULL;
    unsigned char *pscr = NULL;
    int packet_length;
    pscr = (unsigned char *)QdlContext->ENPRG9x15_EC20;
    packet_length = QdlContext->ENPRG9x15_EC20_length;
    int size = 0x03f9;
    int loop = 1;

    qdl_flush_fifo(g_hCom, 1, 1);
    g_Transmit_Length = 0;
    for(i=0;i<packet_length;)
    {
        memset(&g_Transmit_Buffer[0], 0, sizeof(g_Transmit_Buffer));
        
        
        g_Transmit_Buffer[0] = 0x0f;
        g_Transmit_Buffer[1] = (base>>24)&0xff;
        g_Transmit_Buffer[2] = (base>>16)&0xff;
        g_Transmit_Buffer[3] = (base>>8)&0xff;
        g_Transmit_Buffer[4] = (base)&0xff;

        if((i+size)>packet_length){
            size = packet_length - i;
        }
        g_Transmit_Buffer[5] = (size>>8)&0xff;
        g_Transmit_Buffer[6] = (size)&0xff;
        
        pdst = &g_Transmit_Buffer[7];
        for(j=0; j<size; j++){
            *pdst++ = *pscr++;    
        }
        
        base += size;
        i += size;
        g_Transmit_Length = 7+size;
        compute_reply_crc();
        send_packet(1);
        loop = 1;
        int timeout=5;
        do{
            if(receive_packet() == 1){
                switch(g_Receive_Buffer[0])
                {
                case 0x02:
                    QdlContext->prog_cb(i, packet_length,0);
                    loop = 0;
                    break;
                default:
                    return 0;
                    break;
                }
            }
            else
            {
                timeout--;
                QdlContext->text_cb("read packet error, try again");
                QdlContext->logfile_cb("read packet error, try again");
                if(timeout==0)
                {
                    return 0;
                    break;
                }
            }


        }while(loop == 1);    
    }
    return 1;
}
/******go cmd*******/
int go_cmd(void) {
    unsigned int base = go_hex_start_addr;
    byte parameter[4] = {(byte)(base>>24)&0xff, (byte)(base>>16)&0xff, (byte)(base>>8)&0xff, (byte)(base)&0xff};
    compose_packet(0x05, parameter, 4, NULL, 0);
    compute_reply_crc();

    qdl_flush_fifo(g_hCom, 1, 1);

    send_packet(1);

    return 1;
}

int handle_hello(void)
{
    static const byte host_header[] = "QCOM fast download protocol host";
    char string1[64];
    int size;
    int err;
    memset(&g_Transmit_Buffer[0],0,sizeof(g_Transmit_Buffer));
    g_Transmit_Buffer[0] = 0x01;        
    memcpy(&g_Transmit_Buffer[1],host_header,32);
    g_Transmit_Buffer[33] = 3;
    g_Transmit_Buffer[34] = 3;
    g_Transmit_Buffer[35] = 9;    
    g_Transmit_Length = 36;
    compute_reply_crc();

    qdl_flush_fifo(g_hCom, 1, 1);
    
    send_packet(1);
    int timeout = 2000;
    do{
        err = receive_packet();
        if(err == 1){
            switch(g_Receive_Buffer[0])
            {
            case 0x02:
                return 1;
            case 0x0d:
                continue;
            default:
                return 0;
            }
        }
        else if(err == -1){
            return 0;
        }
        timeout--;
    }while(timeout);
    return 1;
}

int handle_security_mode(byte trusted) {
    compose_packet(0x17, &trusted, 1, NULL, 0);
    compute_reply_crc();
    send_packet(1);

    do{
        if(receive_packet() == 1){
            switch(g_Receive_Buffer[0])
            {
            case 0x18:
                return 1;
            default:
                return 0;
            }
        }
    }while(1);
}

int handle_parti_tbl(byte override) {
    uint32 filesize;
    byte *partition=NULL;
	int type=0;
try_send_packet:
	if(type==0) //send partition2
	{
		partition= open_file(QdlContext->partition2_path, &filesize);
	}
	else
		partition= open_file(QdlContext->partition_path, &filesize);
    if (partition == NULL)
        return 0;
    compose_packet(0x19, &override, 1, partition, filesize);
    free_file(partition, filesize);
    compute_reply_crc();
    send_packet(1);
    
    do{
        if(receive_packet() == 1){
            printf("handle_parti_tbl command = %02x, status = %02x\n", g_Receive_Buffer[0], g_Receive_Buffer[1]);
            switch(g_Receive_Buffer[0])
            {
            case 0x1a:
                switch( g_Receive_Buffer[1] ){
                    case 0x00: //0x0 �C Partition table accepted
                        return 1;   //����
                    case 0x01: //0x1 this means that the original partition is different from the current partition,try to send partition
						type=1;
                        goto try_send_packet; //����
                    case 0x02: //0x2 �C Partition table format not recognized, does not accept override
                        return 0;
                    case 0x03: //0x3 �C Erase operation failed
                        return 0;
                    break;
            default:
                return 0;
            }
            default:
                return 0;
            }
        }
    }while(1);
}

/******�����reset*******/

int handle_reset(void) {
    compose_packet(0x0b, NULL, 0, NULL, 0);
    compute_reply_crc();
    send_packet(1);
    int timeout=5;
    do{
        if(receive_packet() == 1){
            switch(g_Receive_Buffer[0])
            {
            case 0x0c:
                return 1;
            case 0x0d:
                    continue;
            default:
                return 0;
            }
        }
        else
                {

                    timeout--;
                    if(timeout==0)
                    {
                        return 0;
                    }
                }
    }while(1);

}

/******pkt_open_multi_image*******/

void pkt_open_multi_image (byte mode, byte *data, uint32 size) {
    compose_packet(0x1b, &mode, 1, data, size);
    compute_reply_crc();
}
int handle_openmulti(uint32 size,byte* data)
{    
    byte mode=0x0e;
    qdl_flush_fifo(g_hCom, TRUE, TRUE);
    pkt_open_multi_image(mode, data, size);
    send_packet(1);
    do {
        if (receive_packet() == 1) {
            switch (g_Receive_Buffer[0]) {
            case 0x1c:
                return 1;
            case 0x0d:
                continue;
            default:
                return 0;
            }
        }
    } while (1);
    return 1;    
}

/******pkt_write_multi_image*******/
void pkt_write_multi_image(uint32 addr, byte*data, uint16 size) {
    byte parameter[4] = {(byte)(addr)&0xff, (byte)(addr>>8)&0xff, (byte)(addr>>16)&0xff, (byte)(addr>>24)&0xff};
    compose_packet(0x07, parameter, 4, data, size);
    compute_reply_crc();
}

int handle_write(byte *data, uint32 size)
{    
    uint32 total_size;
    uint32 addr=0;
    uint32 writesize;
    uint32 buffer_size = QdlContext->cache;

    int loop = 1;
    int retry_cnt=0;

    total_size = size;
        
    while(size)
    {
        writesize=(size<buffer_size)?size:buffer_size;
        pkt_write_multi_image(addr, data, writesize);
start_send_packet:
        send_packet(1);

        if(receive_packet() == 1){
            switch(g_Receive_Buffer[0])
            {
            case 0x08:
                size-=writesize;
                addr+=writesize;
                data+=writesize;
                //QdlContext->text_cb( "addr:[%d],total_size:[%d]",addr,total_size);
                QdlContext->prog_cb(addr, total_size,0);
                //retry_cnt=5;
                break;
            default:
                goto retry_send_packet;
                return 0;
            }
        }
        else
        {

         retry_send_packet:
            retry_cnt--;
            if(retry_cnt>0)
            {
                //QdlContext->text_cb( "Send packet error,try again:[%d]",retry_cnt);
                QdlContext->logfile_cb("Send packet error,try again:[%d]",retry_cnt);
                qdl_flush_fifo(g_hCom,1,1);
                qdl_sleep(1000);
                goto start_send_packet;
            }
            else
             {
                QdlContext->logfile_cb("Send packet failed");
                return 0;
            }
        }
    
    }
    return 1;    
}
/******PARTITION*******/
int handle_close(void) {
    compose_packet(0x15, NULL, 0, NULL, 0);
    compute_reply_crc();

    qdl_flush_fifo(g_hCom, 1, 1);
    
    send_packet(1);
    do{
        if(receive_packet() == 1){
            switch(g_Receive_Buffer[0])
            {
            case 0x16:
                return 1;
            default:
                return 0;
            }
        }
    }while(1);

}
//获取版本�?
int get_revision (void)
{
    int re=0;
    const char* send_at="ATI\r\n";
    qdl_flush_fifo(g_hCom, 1, 1);
    WriteABuffer(g_hCom, (byte *)send_at,strlen(send_at));
    unsigned char buff[128];
    memset(buff,0,sizeof(buff));
    int nread;
    char atibuf[200]={0};
    int len_v=0;
    int timeout=5;
    //qdl_sleep(500);
    while(1)
    {

        if((nread=ReadABuffer(g_hCom,buff,128))>0)
        {
            for(int i=0;i<nread;i++)
            {
                atibuf[len_v]=buff[i];
                len_v++;
            }
            if(strstr(atibuf,"OK")!=NULL)
            {
                break;
            }
            
        }

        else
        {
            timeout--;
            if(timeout==0)
                break;
        }
    }
    if(len_v!=0)
    {
        atibuf[len_v]='\0';
        QdlContext->logfile_cb("atibuf is %s",atibuf);
        //QdlContext->logfile_cb("len_v222 is %d",len_v);
        char bufversion[50];
        char *p=NULL;
        char *p1=NULL;
         p=strstr(atibuf,"Revision:");
         if(p!=NULL)
             p1=strstr(p,"\r\n");
        if(p!=NULL&&p1!=NULL)
        {
            memset(bufversion,0,sizeof(bufversion));
            memcpy(bufversion,p+9,p1-p-9);
            printf("Old version is %s\n",bufversion);
            QdlContext->logfile_cb("Old version is %s",bufversion);
            re=1;
        }
    }
    return re;
}

int set_dl_flag(void) {
    byte mode = 1;
    compose_packet(0x60, &mode, 1, NULL, 0);
    compute_reply_crc();
    send_packet(1);
    int timeout=5;
        do{
            if(receive_packet() == 1){
                switch(g_Receive_Buffer[0])
                {
                    case 0x61:
                        switch( g_Receive_Buffer[1] )
                        {
                            case 0x00:
                                return 1;
                            default:
                                return 0;
                        }
                    case 0x0E:

                        QdlContext->logfile_cb("Invalid command");
                        return 2;
                    default:
                        return 0;
                }
            }
            else
                                {
                                    timeout--;
                                    if(timeout==0)
                                    {
                                        return 0;
                                    }
                                }
        }while(1);
}

int clear_dl_flag(void) {
    byte mode = 0;
    compose_packet(0x60, &mode, 1, NULL, 0);
    compute_reply_crc();
    send_packet(1);
    
        int timeout=5;
        do{
                    if(receive_packet() == 1){
                        switch(g_Receive_Buffer[0])
                        {
                            case 0x61:
                                switch( g_Receive_Buffer[1] )
                                {
                                    case 0x00:
                                        return 1;

                                    default:
                                        return 0;
                                }
                                case 0x0E:
                                QdlContext->logfile_cb("Invalid command");
                                return 2;
                            default:
                                return 0;
                        }
                    }
                    else
                    {
                        timeout--;
                        if(timeout==0)
                        {
                            return 0;
                        }
                    }
                }while(1);
}
//发送AT+QDL命令
int send_QDL(int baudrate)
{
    int re=0;
    int timeout=5;
    char* atqdl=NULL;
    atqdl=(char*)malloc(32);
    sprintf(atqdl,"AT+QDL=%d\r\n",baudrate);
    QdlContext->logfile_cb("AT+QDL is %s",atqdl);
    qdl_flush_fifo(g_hCom, 1, 1);
    WriteABuffer(g_hCom, (const byte*)atqdl, strlen(atqdl));
    free(atqdl);
                atqdl=NULL;
    char buff[128];
    //qdl_sleep(500);
    for(int i=0;i<timeout;i++)
    {
        int r_size=ReadABuffer(g_hCom, (byte *)buff, 128);
        QdlContext->logfile_cb("buff is %s",buff);
        if(strstr(buff,"OK")!=NULL)
        {

            return 1;
        }
    }
    return re;
}

int send_model(void) {
    const static byte fpkt[]={0x13,0x0c,0xd2,0x7a,0x7e};
    compose_packet(0x0c, NULL, 0, NULL, 0);
    compute_reply_crc();
    send_packet(1);
    do{
            if(receive_packet() == 1){

                if(!memcmp(g_Receive_Buffer, fpkt, sizeof(fpkt)))
                {
                    return 1;//使用diag升级
                }
                else if(strstr((char*)g_Receive_Buffer,"OSBL")!=NULL)
                {
                    return 2;//正常下载模式
                }
                else if(strstr((char*)g_Receive_Buffer,"PBL")!=NULL)
                {
                    return 3;//紧急下载模�?
                }
                else
                    return -1;
            }
            else
            {
                return 0;//使用AT升级
            }
    }while(1);
}
int get_NV_Count(void)
{
        int re=0;
        const char* send_at="AT+QNVR=?\r\n";
        WriteABuffer(g_hCom, (const byte*)send_at, strlen(send_at));
        unsigned char buff[128];
        memset(buff,0,sizeof(buff));
        int nread;
        char NV_count_buf[100];
        int len_v=0;
        int timeout=25;
        //qdl_sleep(500);
        while(1)
        {

            if((nread=ReadABuffer(g_hCom,buff,128))>0)
            {

                for(int i=0;i<nread;i++)
                {
                    NV_count_buf[len_v]=buff[i];
                    len_v++;
                }
                if(strstr(NV_count_buf,"OK")!=NULL)
                {
                    break;
                }

            }
            else
            {
                timeout--;
                if(timeout==0)
                    break;
            }
        }
        if(len_v!=0)
        {
            NV_count_buf[len_v]='\0';
            QdlContext->logfile_cb("NV_count_buf is %s",NV_count_buf);
            QdlContext->logfile_cb("len_v is %d",len_v);
            char NV_count[50];
            char *p=strstr(NV_count_buf,"-");
            char *p1=strstr(p,")");
            if(p!=NULL&&p1!=NULL)
            {
                memset(NV_count,0,sizeof(NV_count));
                memcpy(NV_count,p+1,p1-p-1);
                re=atoi(NV_count);
            }
        }
        return re;
}
int get_NV_value(int id,int index,char *value)
{
        int nread;
        char NV_value_buf[400];
        memset(NV_value_buf,0,sizeof(NV_value_buf));
        int len_v=0;
        int timeout=25;
        unsigned char buff[10];
        char send_at[64]={0};
        sprintf(send_at,"AT+QNVR=%d,%d\r\n",id,index);
        qdl_flush_fifo(g_hCom, 1, 1);
        WriteABuffer(g_hCom, (const byte*)send_at, strlen(send_at));
        while(1)
        {
            memset(buff,0,sizeof(buff));
            if(ReadABuffer(g_hCom,buff,1)==1)
            {
                    NV_value_buf[len_v]=buff[0];
                    len_v++;
                if(strstr(NV_value_buf,"OK")!=NULL)
                {
                    NV_value_buf[len_v]='\0';
                    break;
                }
                if(strstr(NV_value_buf,"ERROR")!=NULL)
                {
                    NV_value_buf[len_v]='\0';
                    //QdlContext->text_cb( "[BUF]%s",NV_value_buf);
                    return 0;
                }

            }
            else
            {
                timeout--;
                QdlContext->logfile_cb("timeout");
                if(timeout==0)
                {
                    return -1;
                }
            }
        }
        if(len_v!=0)
        {
            if(len_v>400)
            {
                QdlContext->text_cb( "[BUF]%s,i is %d",NV_value_buf,id);
            }
            char NV_value[400];
            memset(NV_value,0,sizeof(NV_value));
            char*p=NULL;
            char*p1=NULL;
            p=strstr(NV_value_buf,"\"");
            p1=strstr(p+1,"\"");
            if(p!=NULL&&p1!=NULL)
            {
                memcpy(NV_value,p+1,p1-p-1);
                QdlContext->logfile_cb("NV id is %d,Index is %d,value is %s",id,index,NV_value);
                strcpy(value,NV_value);
            }

        }
        return 1;
}
int GetOffset_DataCount(int id, int* offset, int* datacount) {
    int timeout = 25;
    int nread;
    int len_v=0;
    char receivebuf[64] = { 0 };
    char send_at[64] = { 0 };
    unsigned char buff[64];
    sprintf(send_at, "AT+QNVR=%d\r\n", id);
    QdlContext->logfile_cb("AT+QNVR=NV(send) %s",send_at);
    qdl_flush_fifo(g_hCom, 1, 1);
    WriteABuffer(g_hCom, (const byte*)send_at, strlen(send_at));
    memset(buff, 0, sizeof(buff));
    while (1) {
        if ((nread = ReadABuffer(g_hCom, buff, 64)) > 0) {
            for (int i = 0; i < nread; i++) {
                receivebuf[len_v] = buff[i];
                len_v++;
            }
            if (strstr(receivebuf, "OK") != NULL) {
                break;
            }
            if (strstr(receivebuf, "ERROR") != NULL) {
                QdlContext->logfile_cb("AT+QNVR=%d error(receive)",id);
                return 0;
            }

        }
        else {
            timeout--;
            if (timeout == 0)
                return 0;
        }
    }
    receivebuf[len_v] = '\0';

    if (len_v != 0) {
        QdlContext->logfile_cb("AT+QNVR=%d (receive) %s",id,receivebuf);
        char *p, *p1 = NULL;
        p = strstr(receivebuf, "+QNVR:");
        p1 = strstr(p, "\r\n");
        char buf_value[64] = { 0 };
        if (p != NULL && p1 != NULL) {
            memcpy(buf_value, p+7, p1-p-7);
            char* str = NULL;
            str = strtok(buf_value, ",");
            int index = 0;
            while (str != NULL) {
                index++;
                str = strtok(NULL, ",");

                if (index == 2) {
                    *offset = atoi(str);
                }
                if (index == 3) {
                    *datacount = atoi(str);
                }
            }
        }
        else
        {
            return 0;
        }
    }
    return 1;
}
//AT写入NV
int Write_NV(int _iNV_Item,int array_index,char* hex_date)
{
    int re=0;
    int timeout=25;
    char* atQNVW=NULL;
    atQNVW=(char*)malloc(400);
    sprintf(atQNVW, "AT+QNVW=%d,%d,\"%s\"\r\n",_iNV_Item,array_index,hex_date);
    QdlContext->logfile_cb("AT+QNVW(send) %s",atQNVW);
    qdl_flush_fifo(g_hCom, 1, 1);
    WriteABuffer(g_hCom, (const byte*)atQNVW, strlen(atQNVW));
    free(atQNVW);
    atQNVW=NULL;
    char buff[128]={0};
    //qdl_sleep(500);
    for(int i=0;i<timeout;i++)
    {
        int r_size=ReadABuffer(g_hCom, (byte *)buff, 128);

        if(strstr(buff,"OK")!=NULL)
        {
            QdlContext->logfile_cb("AT+QNVW(receive) %s",buff);
            return 1;
        }
        if(strstr(buff,"ERROR")!=NULL)
        {
            QdlContext->logfile_cb("AT+QNVW(receive) %s",buff);
            return -1;
        }
    }
    return re;
}
int send_QFASTBOOT()
{
    int re=0;
    int timeout=5;
    char* atqdl=NULL;
    atqdl=(char*)malloc(32);
    strcpy(atqdl,"AT+QFASTBOOT\r\n");
    qdl_flush_fifo(g_hCom, 1, 1);
    WriteABuffer(g_hCom, (const byte*)atqdl, strlen(atqdl));
    free(atqdl);
        atqdl=NULL;
    char buff[128]={0};
    //qdl_sleep(500);
    for(int i=0;i<timeout;i++)
    {
        int r_size=ReadABuffer(g_hCom, (byte *)buff, 128);
        QdlContext->text_cb("buff is %s",buff);
        if(strstr(buff,"OK")!=NULL)
        {
            return 1;
        }
        if (strstr(buff, "ERROR") != NULL) {
            return 0;
        }
    }
    return re;
}
