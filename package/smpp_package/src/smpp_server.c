/* 
 * tcpserver.c - A simple TCP echo server 
 * usage: tcpserver <port>
 */

#include <stdio.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <netdb.h>
#include <sys/types.h> 
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <errno.h>
#include <sys/time.h> //FD_SET, FD_ISSET, FD_ZERO macros

#define BUFSIZE 1024
#define TRUE   1
#define FALSE  0
#define PORT 7777

/* Smpp headerio struktura */
struct smpp_header {
	int ilgis;
	int komanda;
	int id;
	int seka;
};


#if 0
/* 
 * Structs exported from in.h
 */

/* Internet address */
struct in_addr {
  unsigned int s_addr; 
};



/* Internet style socket address */
struct sockaddr_in  {
  unsigned short int sin_family; /* Address family */
  unsigned short int sin_port;   /* Port number */
  struct in_addr sin_addr;	 /* IP address */
  unsigned char sin_zero[...];   /* Pad to size of 'struct sockaddr' */
};

/*
 * Struct exported from netdb.h
 */

/* Domain name service (DNS) host entry */
struct hostent {
  char    *h_name;        /* official name of host */
  char    **h_aliases;    /* alias list */
  int     h_addrtype;     /* host address type */
  int     h_length;       /* length of address */
  char    **h_addr_list;  /* list of addresses */
}
#endif

/*
 * error - wrapper for perror
 */
void error(char *msg) {
  perror(msg);
  exit(1);
}

int main(int argc, char **argv) {
  int parentfd; /* parent socket */
  int childfd; /* child socket */
  int portno; /* port to listen on */
  int clientlen; /* byte size of client's address */
  struct sockaddr_in serveraddr; /* server's addr */
  struct sockaddr_in clientaddr; /* client addr */
  struct hostent *hostp; /* client host info */
  char buf[BUFSIZE]; /* message buffer */
  char answer[BUFSIZE];
  int answer_len;
  char *hostaddrp; /* dotted decimal host addr string */
  int optval; /* flag value for setsockopt */
  int n; /* message byte size */
  struct smpp_header *headeris;
  char *buf_id;
  char *buf_password;
  char *system_type;
  char *protocol_version;
  char *type_of_number;
  char *num_plan_indicator;
  char *service_type;
  int pass_valid;
  int id_valid;
  int version_valid;
  int i;
  int return_val_system;
  char str2[32];
  char str1[32];
  char str3[8];
  char *originator_address;
  char *recipient_address;
  char *message_text;
  char *message_text_part1;
  char *message_text_part2;
  char *message_text_part3;
  char *schedule_delivery_time;
  char *validity_period;
  char message_part1[160];
  char message_part2[160];
  char message_part3[160];
  int message_resp_id = 1;
  unsigned int message_length;
  char *command;
  int udh_message_idetifier;
  int udh_message_parts;
  int udh_message_part_nr;
  int max_clients = 5, client_socket[30], max_sd, activity;
  int debug; // 0 for normal, 1 for debug mode with prints
  char *server_username;
  char *server_password;
  
  
  
  char* concat(char *s1, char *s2)
		{
			char *result = malloc(strlen(s1)+strlen(s2)+1);//+1 for the zero-terminator
			strcpy(result, s1);
			strcat(result, s2);
			return result;
		};

  
  /* 
   * check command line arguments 
   */
  if (argc != 5) {
    fprintf(stderr, "usage: %s <user name> <password> <port> <debug>\n", argv[0]);
    exit(1);
  }
  portno = atoi(argv[3]);
  debug = atoi(argv[4]);
  server_username = argv[1];
  server_password = argv[2];
  
  
	//set of socket descriptors
	fd_set readfds;
	//initialise all client_socket[] to 0 so not checked
	for (i = 0; i < max_clients; i++) 
	{
		client_socket[i] = 0;
	}

  /* 
   * socket: create the parent socket 
   */
  parentfd = socket(AF_INET, SOCK_STREAM, 0);
  if (parentfd < 0) 
    error("ERROR opening socket");

  /* setsockopt: Handy debugging trick that lets 
   * us rerun the server immediately after we kill it; 
   * otherwise we have to wait about 20 secs. 
   * Eliminates "ERROR on binding: Address already in use" error. 
   */
  optval = 1;
  setsockopt(parentfd, SOL_SOCKET, SO_REUSEADDR, 
	     (const void *)&optval , sizeof(int));

  /*
   * build the server's Internet address
   */
  bzero((char *) &serveraddr, sizeof(serveraddr));

  /* this is an Internet address */
  serveraddr.sin_family = AF_INET;

  /* let the system figure out our IP address */
  serveraddr.sin_addr.s_addr = htonl(INADDR_ANY);

  /* this is the port we will listen on */
  serveraddr.sin_port = htons((unsigned short)portno);

  /* 
   * bind: associate the parent socket with a port 
   */
  if (bind(parentfd, (struct sockaddr *) &serveraddr, 
	   sizeof(serveraddr)) < 0) 
    error("ERROR on binding");

  /* 
   * listen: make this socket ready to accept connection requests 
   */
  if (listen(parentfd, 10) < 0) /* allow 7 requests to queue up */ 
    error("ERROR on listen");

  /* 
   * main loop: wait for a connection request, echo input line, 
   * then close connection.
   */
  clientlen = sizeof(clientaddr);
  
  while (1) {
	
	
	//clear the socket set
	FD_ZERO(&readfds);
	//add master socket to set
	FD_SET(parentfd, &readfds);
	max_sd = parentfd;
	
	//add child sockets to set
	for ( i = 0 ; i < max_clients ; i++) 
	{
		//socket descriptor
		childfd = client_socket[i];
		//if valid socket descriptor then add to read list
		if(childfd > 0)
			FD_SET( childfd , &readfds);
		//highest file descriptor number, need it for the select function
		if(childfd > max_sd)
			max_sd = childfd;
	}
	//wait for an activity on one of the sockets , timeout is NULL , so wait indefinitely
	activity = select( max_sd + 1 , &readfds , NULL , NULL , NULL);
	if ((activity < 0) && (errno!=EINTR)) 
	{
		if(debug == 1)
			printf("select error");
	}
	//If something happened on the master socket , then its an incoming connection
	if (FD_ISSET(parentfd, &readfds)) 
	{
		//accept: wait for a connection request 
		childfd = accept(parentfd, (struct sockaddr *) &clientaddr, &clientlen);
		if (childfd < 0) 
			close( childfd ); //disconnect the client
			client_socket[i] = 0;  //remove client from list  
		//add new socket to array of sockets
		for (i = 0; i < max_clients; i++) 
		{
			//if position is empty
			if( client_socket[i] == 0 )
			{
			client_socket[i] = childfd;
			if(debug == 1)
				printf("Adding to list of sockets as %d\n" , i);
			break;
			}
		}
	}
	//else its some IO operation on some other socket :)
	for (i = 0; i < max_clients; i++) 
	{
		childfd = client_socket[i];
		if (FD_ISSET( childfd , &readfds)) 
			{
		
    /* 
     * gethostbyaddr: determine who sent the message 
     */
    hostp = gethostbyaddr((const char *)&clientaddr.sin_addr.s_addr, 
			  sizeof(clientaddr.sin_addr.s_addr), AF_INET);
    if (hostp == NULL)
      error("ERROR on gethostbyaddr");
    hostaddrp = inet_ntoa(clientaddr.sin_addr);
    if (hostaddrp == NULL)
      error("ERROR on inet_ntoa\n");
    if(debug == 1)
		printf("\nserver established connection with %s (%s)\n", hostp->h_name, hostaddrp);
    
    /* 
     * read: read input string from the client
     */
    bzero(buf, BUFSIZE);
    n = read(childfd, buf, BUFSIZE);
    
	if (n == 0 || n < 0){
		//Close the socket and mark as 0 in list for reuse
		close( childfd );
		client_socket[i] = 0;
	}
	else{
	
	//if (n < 0) 
		//error("ERROR reading from socket");
    headeris = (struct smpp_header *)buf;
    //komanda 9=transceiver, 2=transmiter, 1=receiver
    if(debug == 1)
		printf("=======header data=======\nlength=%d\noperation=%d\nid=%d\nsequece=%d\n\n", headeris->ilgis, headeris->komanda, headeris->id, headeris->seka);
    
    if(headeris->komanda == 2){ //bind transmiter
		
		if(debug == 1){
			printf("portno=%d, debug=%d, server_username=%s, server_password=%s", portno, debug, server_username, server_password);
			printf("\nClient receiver bind as transmitter request\n\n");
			printf("comand_id=%d\n",headeris->komanda);
		}
		buf_id = buf+16;
		buf_password = buf_id + strlen(buf_id) + 1;
		system_type = buf_password + strlen(buf_password) + 1;
		protocol_version = buf[19+strlen(buf_id)+strlen(buf_password)+strlen(system_type)];
		type_of_number = system_type+strlen(system_type)+2;
		num_plan_indicator = type_of_number +1;
		if(debug == 1){
			printf("=======body data=======\nSystem ID=%s\nSystem password=%s\nSystem type=%s\nSystem protocol=%x\ntype of number=%s\nnum_plan_indicator=%s\n", buf_id, buf_password, system_type, protocol_version, type_of_number, num_plan_indicator);
			printf("\n====whole pdu hex========\n");
		
		for(i=0; i<headeris->ilgis; i++){
			printf("%x ", buf[i]);
			fflush( stdout );
		}
		}
		strcpy(str1, server_username);
		id_valid = strcmp(buf_id, str1);
		if(id_valid == 0 && debug == 1)
			printf("\nsystem id match\n");

		strcpy(str2, server_password);
		pass_valid = strcmp(buf_password, str2);
		if(pass_valid == 0 && debug == 1)
			printf("password match\n");
			
		
		if(protocol_version == 0x00000034 && debug == 1)
			printf("client version match\n");

		// write: echo the input string back to the client 
		headeris->komanda = 0x80000002; //transmitter response
		answer_len = 16 + strlen(buf_id) + 1;
		headeris->ilgis = answer_len;

		if(id_valid != 0){					//id tikrinimas
			headeris->id = 0x0000000F;
			n = write(childfd, buf, headeris->ilgis);
			close( childfd ); //disconnect the client
			client_socket[i] = 0;  //remove client from list
			if(debug == 1){  
				printf("\nWRONG SYSTEM ID, DISCONECTED\n");
				printf("\nreply sent\n");
			}
		}
		
		else if(pass_valid != 0){				//pass tikrinimas
			headeris->id = 0x0000000E;
			n = write(childfd, buf, headeris->ilgis);
			close( childfd ); //disconnect the client
			client_socket[i] = 0;  //remove client from list
			if(debug == 1){  
				printf("\nWRONG SYSTEM PASSWORD, DISCONECTED\n");
				printf("\nreply sent\n");
			}
		}
		
		else if(protocol_version != 0x00000034){				//invalid service type
			headeris->id = 0x00000015;
			n = write(childfd, buf, headeris->ilgis);
			close( childfd ); //disconnect the client
			client_socket[i] = 0;  //remove client from list
			if(debug == 1){  
				printf("\nWRONG SYSTEM PROTOCOL, DISCONECTED\n");
				printf("\nreply sent\n");
			}
		}
		
		else {
			n = write(childfd, buf, headeris->ilgis); // response OK
			if (n < 0){ 
				close( childfd ); //disconnect the client
				client_socket[i] = 0;  //remove client from list
			}  
			//close(childfd);    //disconnect the client
			if(debug == 1){
				printf("\nCONNECTED TO SMPP SERVER\n");
				printf("\nreply sent\n");
			}
		}
	}
		
	else if(headeris->komanda == 21){ //enquire_link
		headeris->komanda = 0x80000015; //enquire_link response
		if(debug == 1)
			printf("\nClient enquire_link request\n\n");
		n = write(childfd, buf, headeris->ilgis);
		if (n < 0) {
			close( childfd ); //disconnect the client
			client_socket[i] = 0;  //remove client from list
		}  
		//close(childfd);    //disconnect the client
		if(debug == 1)
			printf("\nreply sent\n");
		}

	else if(headeris->komanda == 9){
		if(debug == 1)
			printf("\nClient receiver bind as transceiver request\n\n");
		headeris->komanda = 0x80000009; //bind transceiver response 
		headeris->id = 0x0000000D; //(Bind failed)
		n = write(childfd, buf, headeris->ilgis);
		close( childfd ); //disconnect the client
		client_socket[i] = 0;  //remove client from list
		if(debug == 1)  
			printf("\nreply sent: Bind failed\n");
		}
		
	else if(headeris->komanda == 1){
		if(debug == 1)
			printf("\nClient receiver bind as receiver request\n\n");
		headeris->komanda = 0x80000001; //bind receiver response 
		headeris->id = 0x0000000D; //(Bind failed)
		n = write(childfd, buf, headeris->ilgis); 
		close( childfd ); //disconnect the client
		client_socket[i] = 0;  //remove client from list 
		if(debug == 1) 
			printf("\nreply sent: Bind failed\n");
		}
		
	else if(headeris->komanda == 4){ //submit_sm
		if(debug == 1){
			printf("\nClient submit sms request\n\n");
			printf("\n====visas pdu hex========\n");
		
		for(i=0; i<headeris->ilgis; i++){
			printf("%x ", buf[i]);
			fflush( stdout );
		}
		}
		service_type = buf+16;
		originator_address = service_type+strlen(service_type)+3;
		recipient_address = originator_address+strlen(originator_address)+3;
		schedule_delivery_time = recipient_address + strlen(recipient_address) +4;
		validity_period = schedule_delivery_time +strlen(schedule_delivery_time) +1;
		message_length = *(int *)(buf+29+strlen(service_type)+strlen(originator_address)+strlen(recipient_address)+strlen(schedule_delivery_time)+strlen(validity_period));

		if(message_length == 0){
			headeris->ilgis = 17;
			headeris->komanda = 0x80000004;
			headeris->id = 0x00000001; //message length invalid
			n = write(childfd, buf, headeris->ilgis);
			if (n < 0) {
				close( childfd ); //disconnect the client
				client_socket[i] = 0;  //remove client from list
			}  
			if(debug == 1){
				printf("\nMESSAGE LENGTH INVALID 0\n");
				printf("\nreply sent: message sent\n");
			}
		}
		else{
		
		if (buf[33+strlen(originator_address)+ strlen(recipient_address) +strlen(service_type)+strlen(schedule_delivery_time)+strlen(validity_period)] == 5){
			
			udh_message_idetifier = buf[36+strlen(originator_address)+strlen(recipient_address)+strlen(service_type)+strlen(schedule_delivery_time)+strlen(validity_period)];
			udh_message_parts = buf[37+strlen(originator_address)+strlen(recipient_address)+strlen(service_type)+strlen(schedule_delivery_time)+strlen(validity_period)];
			udh_message_part_nr = buf[38+strlen(originator_address)+strlen(recipient_address)+strlen(service_type)+strlen(schedule_delivery_time)+strlen(validity_period)];
			
			if(udh_message_parts > 3){
					headeris->ilgis = 17;
					headeris->komanda = 0x80000004;
					headeris->id = 0x00000001; //message length invalid
					n = write(childfd, buf, headeris->ilgis);
					if (n < 0) {
						close( childfd ); //disconnect the client
						client_socket[i] = 0;  //remove client from list 
					} 
					if(debug == 1){
						printf("\nMESSAGE LENGTH INVALID >3parts\n");
						printf("\nreply sent\n");
					}
				}
				else{

			if(debug == 1)
				printf("\nLONG MESSAGE DETECTED Reading UDH\nudh_message_idetifier=%d\nudh_message_parts=%d\nudh_message_part_nr=%d\n ", udh_message_idetifier, udh_message_parts, udh_message_part_nr);//first message symbol
		
			if(udh_message_parts <= 3 && udh_message_part_nr == 1){
				message_text_part1 = recipient_address + strlen(recipient_address)+strlen(schedule_delivery_time)+strlen(validity_period)+ 17;
				strcpy(message_part1, message_text_part1);
				message_text = message_text_part1;
				if(debug == 1){
					printf("message_text_part1=%s\n", message_part1);
					printf("1whole message text=%s\n", message_text);
				}
			}
			if(udh_message_parts <= 3 && udh_message_part_nr == 2){
				message_text_part2 = recipient_address + strlen(recipient_address)+strlen(schedule_delivery_time)+strlen(validity_period)+ 17;
				strcpy(message_part2, message_text_part2);
				message_text = concat(message_part1, message_text_part2);
				if(debug == 1){
					printf("message_text_part1=%s\n", message_part1);
					printf("message_text_part2=%s\n", message_part2);
					printf("2whole message text=%s\n", message_text);
				}
			}
			if(udh_message_parts <= 3 && udh_message_part_nr == 3){
				message_text_part3 = recipient_address + strlen(recipient_address)+strlen(schedule_delivery_time)+strlen(validity_period)+ 17;
				strcpy(message_part3, message_text_part3);
				message_text = concat(message_part1, message_part2);
				message_text = concat(message_text, message_part3);
				if(debug == 1){
					printf("message_text_part1=%s\n", message_part1);
					printf("message_text_part2=%s\n", message_part2);
					printf("message_text_part3=%s\n", message_part3);
					printf("3whole message text=%s\n", message_text);
				}
			}

			if(udh_message_parts == udh_message_part_nr){
				command = "gsmctl -S -s \"\0";
				command = concat(command, recipient_address);
				command = concat(command, " ");
				command = concat(command, message_text);
				command = concat(command, "\"");
				return_val_system = system(command); //sms siuntimas
				if(debug == 1)
					printf("\ncommand=%s\n",command);
				headeris->ilgis = 17;
					if(return_val_system == 0){
						headeris->komanda = 0x80000004;
						n = write(childfd, buf, headeris->ilgis);
						if (n < 0){ 
							close( childfd ); //disconnect the client
							client_socket[i] = 0;  //remove client from list 
						}
						if(debug == 1)
							printf("\nreply sent\n");
					}
					else{
						headeris->komanda = 0x80000004;
						headeris->id = 0x00000008;
						n = write(childfd, buf, headeris->ilgis);
						if (n < 0) {
							close( childfd ); //disconnect the client
							client_socket[i] = 0;  //remove client from list 
						} 
						if(debug == 1)
							printf("\nreply sent: message not sent\n");
					}
				}
			}
		}
		else {
		message_text = validity_period +strlen(validity_period) +6;
		if(debug == 1)
			printf("\n=======body data=======\noriginator_address=%s\nrecipient_address=%s\nmessage_length=%d\nmessage_text=%s\n",originator_address, recipient_address, message_length, message_text);
		headeris->ilgis = 17;
		headeris->komanda = 0x80000004;
		command = "gsmctl -S -s \"\0";
		command = concat(command, recipient_address);
		command = concat(command, " ");
		command = concat(command, message_text);
		command = concat(command, "\"");
		return_val_system = system(command); //sms siuntimas
		if(debug == 1){
			printf("\ncommand=%s\n",command);
			printf("return_val_system=%d\n",return_val_system);
			}
					if(return_val_system == 0){
						n = write(childfd, buf, headeris->ilgis);
						if (n < 0) {
							close( childfd ); //disconnect the client
							client_socket[i] = 0;  //remove client from list
						} if(debug == 1) 
							printf("\nreply sent\n");
						}
					else{
						headeris->id = 0x00000008;
						n = write(childfd, buf, headeris->ilgis);
						if (n < 0){ 
							close( childfd ); //disconnect the client
							client_socket[i] = 0;  //remove client from list
						} if(debug == 1)
							printf("\nreply sent\n");
						}
				}
			}
		}

	else if(headeris->komanda == 6){ //unbind request
		headeris->ilgis = 16;
		headeris->komanda = 0x80000006;
		headeris->id = 0; //no error
		n = write(childfd, buf, headeris->ilgis);
		if (n < 0) {
			close( childfd ); //disconnect the client
			client_socket[i] = 0;  //remove client from list 
		} if(debug == 1){
			printf("\nUNBINDED SUCCESSFULLY\n");
			printf("\nreply sent\n");
			}
		}
	else {
		if(debug == 1)
			printf("\nGOT AN UNKNOWN COMMAND!\nGOT AN UNKNOWN COMMAND!\nGOT AN UNKNOWN COMMAND!\n");
		headeris->ilgis = 16;
		headeris->komanda = 0x80000000;
		headeris->id = 0x000000FF;
		n = write(childfd, buf, headeris->ilgis);
		close( childfd ); //disconnect the client
		client_socket[i] = 0;  //remove client from list 
		if(debug == 1) 
			printf("\nreply GENERIC_NACK sent\n");
		}
	}
	}
}
}
return 0;
}
