

#define __OS_LINUX_CPP_H__

#include "platform_def.h"

#if defined(TARGET_OS_LINUX) || defined(TARGET_OS_ANDROID)
#include <unistd.h>
#include <sys/time.h>
#include <termios.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <stdlib.h>
#include <string.h>
#include "os_linux.h"
#include <stdio.h>
#include <assert.h>
#include <time.h>
#include "os_linux.h"
#include "stdarg.h"
#include "download.h"
#include <libusb-1.0/libusb.h>
#define MAX_TRACE_LENGTH      (256)
#define MAX_PATH 260
const char PORT_NAME_PREFIX[] = "/dev/ttyUSB";
static char log_trace[MAX_TRACE_LENGTH];
int g_default_port=0;//默认usb端口
int g_default_port_bak=-1;//备用端口
int g_upgrade_baudrate=115200;//设置默认的波特率
int g_port_type=0;//端口类型???表示普通端口，1表示uart???
int g_baudrate_temp;//临时存储波特???
int g_upgrade_type=0;//升级类型0代表at升级1代表diag升级
int g_download_mode=0;//下载模式判断，默认为0，正常下载，1为异常下???异常下载模块无法自动重启，所以无法还原QQB
void show_log(const char *msg, ...)
{
    va_list ap;
        
    va_start(ap, msg);
    vsnprintf(log_trace, MAX_TRACE_LENGTH, msg, ap);
    va_end(ap);
    
    printf("%s\n", log_trace);
}
void prog_log(int writesize,int size,int clear)
{
   unsigned int progress = (unsigned int)(writesize * 100)/ size;
    if(progress==100)
    {
        printf( "progress : %d%% finished\n", progress);
        fflush(stdout);
    }
    else
    {
        printf( "progress : %d%% finished\r", progress);
        fflush(stdout);
    }
}

void qdl_msg_log(int msgtype,char *msg1,char * msg2)
{
}

int qdl_log(char *msg,...)
{
}

static int config_uart(int fd)
{
    /*set UART configuration*/
    struct termios newtio;
    if (tcgetattr(fd, &newtio) != 0)
        return -1;
    cfmakeraw(&newtio);

    //newtio.c_cflag &= ~CIGNORE;
    /*set baudrate*/
    QdlContext->logfile_cb("g_upgrade_baudrate is %d\n", g_upgrade_baudrate);
    if (g_upgrade_baudrate == 115200) {
        cfsetispeed(&newtio, B115200);
        cfsetospeed(&newtio, B115200);
    }
    if (g_upgrade_baudrate == 9600) {
        cfsetispeed(&newtio, B9600);
        cfsetospeed(&newtio, B9600);
    }
    if (g_upgrade_baudrate == 19200) {
        cfsetispeed(&newtio, B19200);
        cfsetospeed(&newtio, B19200);
    }
    if (g_upgrade_baudrate == 38400) {
        cfsetispeed(&newtio, B38400);
        cfsetospeed(&newtio, B38400);
    }
    if (g_upgrade_baudrate == 57600) {
        cfsetispeed(&newtio, B57600);
        cfsetospeed(&newtio, B57600);
    }
    if (g_upgrade_baudrate == 230400) {
        cfsetispeed(&newtio, B230400);
        cfsetospeed(&newtio, B230400);
    }
    if (g_upgrade_baudrate == 460800) {
        cfsetispeed(&newtio, B460800);
        cfsetospeed(&newtio, B460800);
    }
    /*set char bit size*/
    newtio.c_cflag &= ~CSIZE;
    newtio.c_cflag |= CS8;

    /*set check sum*/
    //newtio.c_cflag &= ~PARENB;
    //newtio.c_iflag  &= ~INPCK;
    /*set stop bit*/
    newtio.c_cflag &= ~CSTOPB;
    newtio.c_cflag |= CLOCAL | CREAD;
    newtio.c_cflag &= ~(PARENB | PARODD);

    newtio.c_iflag &=
            ~(INPCK | BRKINT | PARMRK | ISTRIP | INLCR | IGNCR | ICRNL);
    newtio.c_iflag |= IGNBRK;
    newtio.c_iflag &= ~(IXON | IXOFF | IXANY);
    //newtio.c_iflag |= (INPCK | ISTRIP);

    newtio.c_lflag = 0;
    newtio.c_oflag = 0;

    //newtio.c_lflag &= ~(ECHO | ECHONL |ICANON|ISIG|IEXTEN);
    //newtio.c_iflag |= (INPCK | ISTRIP);

    /*set wait time*/
    newtio.c_cc[VMIN] = 0;
    newtio.c_cc[VTIME] = 20;

    tcflush(fd, TCIFLUSH);
    tcflush(fd, TCOFLUSH);

    if (tcsetattr(fd, TCSANOW, &newtio) != 0)
        return -1;

    return 0;
}

char *itoa( int val, char *buf, unsigned radix )
{
    char *p; /* pointer to traverse string */
    char *firstdig; /* pointer to first digit */
    char temp; /* temp char */
    unsigned digval; /* value of digit */
    p = buf;
    if (val < 0) {
        /* negative, so output '- ' and negate */
        *p++ = '-';
        val = (unsigned long) (-(long) val);
    }
    firstdig = p; /* save pointer to first digit */
    do {
        digval = (unsigned) (val % radix);
        val /= radix; /* get next digit */

        /* convert to ascii and store */
        if (digval > 9)
            *p++ = (char) (digval - 10 + 'a'); /* a letter */
        else
            *p++ = (char) (digval + '0'); /* a digit */
    } while (val > 0);

    /* We now have the digit of the number in the buffer, but in reverse
     order. Thus we reverse them now. */
    *p-- = '\0'; /* terminate string; p points to last digit */
    do {
        temp = *p;
        *p = *firstdig;
        *firstdig = temp; /* swap *p and *firstdig */
        --p;
        ++firstdig; /* advance to next two digits */
    } while (firstdig < p); /* repeat until halfway */
    return buf;
}
/*+++++++++++++++++++++++++++++++++++++++++
*函数??? openport
*功能: 打开串口
*输入参数: upgrade_model 升级模式 0->AT,1->USB
          AT命令升级时，tmp_port默认???开始重新枚???

++++++++++++++++++++++++++++++++++++++++++*/
int openport()
{
    int tmp_port;
    tmp_port= g_default_port;
    int retry = 6;
    char pc_comport[32];    
    if(g_hCom)
    {
        //QdlContext->text_cb("in openport, but already opened!");
        QdlContext->logfile_cb("in openport, but already opened!");
        return TRUE;  /*already opened*/
    }
start_probe_port:
    memset(pc_comport,0,sizeof(pc_comport));
    sprintf(pc_comport, "%s%d", PORT_NAME_PREFIX, tmp_port);
    if(access(pc_comport, F_OK))
    {
        //QdlContext->text_cb("start to open com port: %s, but no such device, try again[%d]", pc_comport, retry);
        QdlContext->logfile_cb("start to open com port: %s, but no such device, try again[%d]", pc_comport, retry);
            tmp_port++;
            retry--;
            if(retry > 0)
                goto start_probe_port;
            else
                return FALSE;
    }
    //QdlContext->text_cb("start to open com port: %s", pc_comport);
    QdlContext->logfile_cb("start to open com port: %s", pc_comport);
    g_hCom = (HANDLE) open(pc_comport, O_RDWR | O_NOCTTY);
    //g_hCom = (HANDLE) open(pc_comport, O_RDWR | O_NOCTTY|O_NONBLOCK);
    if(g_hCom == (HANDLE)-1)
    {
        g_hCom = 0;
        return FALSE;
    }
    else
        config_uart((int)g_hCom) ;
    return TRUE;
}

int closeport(HANDLE com_fd)
{
    //QdlContext->text_cb("start to close com port");
    QdlContext->logfile_cb("in openport, but already opened!");
    if(!com_fd)
        return 1;
    close(com_fd);
    g_hCom = 0;
    return 1;
}

int WriteABuffer(HANDLE file, const byte * lpBuf, int dwToWrite)
{
    int written = 0;
    assert(file != (HANDLE) -1);
    assert(lpBuf);
    if(dwToWrite <= 0)
        return dwToWrite;
    written = write(file, lpBuf, dwToWrite);
    if(written < 0)   
    {
        qdl_text_cb("write error!");
        printf("write strerror: %s\n", strerror(errno));

        return 0;
    }
    else 
        return written;
}

int ReadABuffer(HANDLE file, byte * lpBuf, int dwToRead)
{
    int read_len = 0;
    
    assert(lpBuf);
    
    if(dwToRead <= 0)
        return 0;
    read_len = read(g_hCom, lpBuf, dwToRead);
//    if(read_len==0)
//    {
//        printf("read strerror: %s\n", strerror(errno));
//    }
    if(read_len < 0)
        {
        // QdlContext->text_cb("read com error :%d", read_len);
         read_len = 0;
    }
    return read_len;
}

void qdl_flush_fifo(HANDLE fd, int tx_flush, int rx_flush)
{
    if(tx_flush)
        tcflush(fd, TCOFLUSH);

    if(rx_flush)
        tcflush(fd, TCIFLUSH);
}

void qdl_sleep(int millsec)
{
    int second = millsec / 1000;
    if(millsec % 1000)
        second += 1;
    sleep(second);
}
    
void qdl_pre_download(qdl_context *pQdlContext) {
    time_t tm;
    time(&tm);
    show_log("Module upgrade tool, %s", ctime(&tm));

    pQdlContext->TargetPlatform = TARGET_PLATFORM_9615;//EC20 Platform
    pQdlContext->ComPortNumber = 0;

    int result = ProcessInit(pQdlContext);
    if (result) {
        result = downloading(pQdlContext);
    }
    qdl_post_download(pQdlContext, result);
}

void qdl_post_download(qdl_context *pQdlContext, int result)
{
    time_t tm;
    time(&tm);
    if(g_hCom != 0)
        closeport(g_hCom);
    if(result==1)
    {
        pQdlContext->text_cb("");
        pQdlContext->text_cb("Upgrade module successfully, %s", ctime(&tm));
    }
    else
    {
        pQdlContext->text_cb("");
        pQdlContext->text_cb("Upgrade module unsuccessfully, %s", ctime(&tm));
    }
    ProcessUninit(pQdlContext);
}

static qdl_context s_QdlContext;
qdl_context *QdlContext = &s_QdlContext;

void qdl_start_download(qdl_context *pQdlContext) {
    pQdlContext->text_cb = show_log;
    pQdlContext->prog_cb = prog_log;
    qdl_pre_download(pQdlContext);
}
/*+++++++++++++++++++++++++++++++++++++++++
*函数??? vertifyAllnum
*功能: 验证是否字符串是否全是数???
++++++++++++++++++++++++++++++++++++++++++*/
int vertifyAllnum(char* ch)
{
    int re=1;
    int i;
    for (i=0;i<strlen(ch);i++)
    {
        if(isdigit(*(ch+i))==0)
        {
            return 0;
        }
    }
    return re;
}
/*+++++++++++++++++++++++++++++++++++++++++
*函数??? Resolve_port
*功能: 解析普通的串口
*输入参数: chPort - 解析的字符串
*输出参数: nPort - 端口的???
*返回???
1 - 包含
0 - 不包???
++++++++++++++++++++++++++++++++++++++++++*/
void Resolve_port(char *chPort,int* nPort )
{
    *nPort=-1;
    char string[7];
    char chPortNum[10];
    strncpy(string,chPort,(sizeof("ttyUSB")-1));
    string[(sizeof("ttyUSB")-1)]='\0';

    if(strlen(chPort)<sizeof("ttyUSB**"))
    {
        if(strcmp(string,"ttyUSB")==0)
        {
            memset(chPortNum,0,sizeof(chPortNum));
            memcpy(chPortNum,chPort+(sizeof("ttyUSB")-1),(strlen(chPort)-(sizeof("ttyUSB")-1)));
            if(vertifyAllnum(chPortNum)&&*chPortNum!=0)
            {
                *nPort=atoi(chPortNum);
            }
        }
    }
}
/*+++++++++++++++++++++++++++++++++++++++++
/	get_tty_nr
* returns Quectel DM usb port number
* filepath - path of usb port in sys dir
++++++++++++++++++++++++++++++++++++++++++*/
int get_tty_nr(char *filepath){
	struct dirent *dp;
	DIR *dfd;
	int port;
	if((dfd=opendir(filepath))==NULL) {
		printf("Error:Open dir failed!dir:%s\n", filepath);
		return -1;
	}
	for(dp=readdir(dfd); NULL != dp; dp=readdir(dfd)) {
		if (strstr(dp->d_name, "ttyUSB") != NULL) {
			Resolve_port(dp->d_name, &port);
			if (port == -1) {
				printf("Error:Port format error\n");
				closedir(dfd);
				return -1;
			}
			closedir(dfd);
			return port;
		}
	}
	closedir(dfd);
	return -1;
}
/*+++++++++++++++++++++++++++++++++++++++++
/	get_port_name
* returns Quectel DM usb port number
* portName - reference to parameter for storing port number
++++++++++++++++++++++++++++++++++++++++++*/
void get_port_name (int *portName){
	int r, bus, port, port_numbers_count, ret, found = 0;		//for return values
	libusb_device **usbDevices = NULL;				// usb device list pointer
	libusb_context *ctx = NULL;
	uint8_t port_numbers[7];
	int i = 0, j = 0;


	char *filepath;

	r = libusb_init(&ctx);
	if (r < 0)
		fprintf(stderr, "failed initialize libusb (%d)\n", r);
	else if	((r = libusb_get_device_list(ctx, &usbDevices)) < 0) {
		fprintf(stderr, "failed get device list (%d)\n", r);
		goto err_free_ctx;
	} else {
		for (i = 0; i < r && found != 1; i++) {
			struct libusb_device_descriptor desc;
			if ((ret = libusb_get_device_descriptor(usbDevices[i], &desc)) < 0) {
				fprintf(stderr, "failed to get device descriptor (%d)\n", ret);
			} else {
				if (desc.idVendor == 0x05C6 && desc.idProduct == 0x9215) {
					found = 1;
					bus = libusb_get_bus_number(usbDevices[i]);

					port_numbers_count = libusb_get_port_numbers(usbDevices[i], port_numbers, sizeof(port_numbers));

					filepath = (char *) malloc(MAX_PATH + MAX_PATH + 32);

					if (!filepath){
						libusb_free_device_list(usbDevices, 1);
						printf("fail to malloc memory for cmd or filepath in downloadfastboot()\n");
						goto err_free_ctx;
					}
					if(port_numbers_count > 1)
						sprintf(filepath,"/sys/devices/platform/ehci-platform/usb1/1-1/1-%d.%d/1-%d.%d:1.0/", port_numbers[0],port_numbers[1], port_numbers[0],port_numbers[1]);
					else
						sprintf(filepath,"/sys/devices/platform/ehci-platform/usb1/1-1/1-%d:1.0/", port_numbers[0]);

					port = get_tty_nr(filepath);
					if(port != -1){
						*portName = port;
					}
					else
						*portName = -1;
				}
			}
		}
	}

	libusb_free_device_list(usbDevices, 1);
err_free_ctx:
	libusb_exit(ctx);
}
#ifndef FEATURE_USE_UI
extern "C" int fastboot_main(int argc, char **argv);
int main(int argc, char *argv[]) {
    if ((argc > 1) && (!strcmp(argv[1], "fastboot"))) {
        return fastboot_main(argc - 1, argv + 1);
    }

    printf("%s V01\n", argv[0]);	

    qdl_context *pQdlContext = &s_QdlContext;
    pQdlContext->firmware_path = NULL;
    pQdlContext->cache = 1024;
    pQdlContext->update_method = 1;
    g_default_port=0;
    int portName;

    int opt;
    int bFile=0;
    while((opt=getopt(argc,argv,"f:b:m:s:h:P:"))>0)
    {
        switch (opt) {
        case 'f':
            bFile=1;
                if (optarg[0] != '/') {
                    char cwd[MAX_PATH] = {0};
                    getcwd(cwd, sizeof(cwd));
                    printf("firmware path: %s/%s\n", cwd, optarg);
                    asprintf(&pQdlContext->firmware_path, "%s/%s", cwd, optarg);      
                } else {
                    asprintf(&pQdlContext->firmware_path, "%s", optarg);           
                }
                printf("firmware path: %s\n", pQdlContext->firmware_path);

            break;
        case 'b':
            if(
                strcmp(optarg,"9600")==0||
                strcmp(optarg,"19200")==0||
                strcmp(optarg,"38400")==0||
                strcmp(optarg,"57600")==0||
                strcmp(optarg,"115200")==0||
                strcmp(optarg,"230400")==0||
                strcmp(optarg,"460800")==0
                )
            {
                g_upgrade_baudrate=atoi(optarg);
            }
            else
            {
                printf("Error:Baudrate format error\n");
                return 1;
            }
            break;
        case 'm':
            if(atoi(optarg)==1||atoi(optarg)==2||atoi(optarg)==3||atoi(optarg)==4)
            {
                pQdlContext->update_method=atoi(optarg);
            }
            else
            {
                printf("Error:Upgrade method format error\n");
                return 1;
            }
            break;
        case 's':
            if(atoi(optarg)>=128&&atoi(optarg)<=1204)
            {
                pQdlContext->cache=atoi(optarg);
            }
            else
            {
                printf("Error:Transport block size format error\n");
                return 1;
            }
            break;
        case 'h':
                pQdlContext->ftp_address=optarg;
            break;
        case 'P':
                pQdlContext->ftp_port=atoi(optarg);
            break;
        }
    }
    if(bFile==0)
    {
        printf("Error:Missing file parameter\n");
        return 1;
    }

	get_port_name(&portName);
	g_default_port = portName;
	if (g_default_port == -1) {
		printf("Error:Port format error\n");
		return 1;
	}
	printf("default port: %d\n",g_default_port);

    qdl_start_download(pQdlContext);
    return 0;
}
#endif  /*FEATURE_USE_UI*/
#endif/*TARGET_OS_LINUX*/

