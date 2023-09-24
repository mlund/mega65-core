#include <stdio.h>

#include <stdlib.h>
#include <unistd.h>
#include <errno.h>
#include <sys/socket.h>
// #include <sys/filio.h>
#include <sys/ioctl.h>
#include <fcntl.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netinet/if_ether.h>
#include <netinet/tcp.h>
#include <netinet/ip.h>
#include <string.h>
#include <signal.h>
#include <netdb.h>
#include <time.h>
#include <poll.h>
#include <termios.h>

int serialfd=-1;

int openSerialPort(char *port)
{
  serialfd = open(port, O_RDWR);
  if (serialfd == -1) {
    perror("open");
    return -1;
  }
  fcntl(serialfd, F_SETFL, fcntl(serialfd, F_GETFL, NULL) | O_NONBLOCK);
  struct termios t;
  if (cfsetospeed(&t, B2000000))
    perror("Failed to set output baud rate");
  if (cfsetispeed(&t, B2000000))
    perror("Failed to set input baud rate");
  t.c_cflag &= ~PARENB;
  t.c_cflag &= ~CSTOPB;
  t.c_cflag &= ~CSIZE;
  t.c_cflag &= ~CRTSCTS;
  t.c_cflag |= CS8 | CLOCAL;
  t.c_lflag &= ~(ICANON | ISIG | IEXTEN | ECHO | ECHOE);
  t.c_iflag &= ~(BRKINT | ICRNL | IGNBRK | IGNCR | INLCR | INPCK | ISTRIP | IXON | IXOFF | IXANY | PARMRK);
  t.c_oflag &= ~OPOST;
  if (tcsetattr(serialfd, TCSANOW, &t))
    perror("Failed to set terminal parameters");
  perror("F");

  return 0;
}

void purge_serial(void)
{
  char buf[1024];
  int r=read(serialfd,buf,1024);
  while(r>0) {
    usleep(1000);
    r=read(serialfd,buf,1024);
  }
}

unsigned int icapereg,icapeval,val,write_count;
unsigned int iec_irq,iec_status,iec_data,iec_devinfo,iec_state,iec_state_reached,write_val,msec,usec,waits;

int main(int argc,char **argv)
{
  openSerialPort(argv[1]);

  int line_len=0;
  char line[1024];

  char bytes[1024];

  while(1) {
    int n = read(serialfd,bytes,1024);
    if (n>0) {
      for(int i=0;i<n;i++) {
	int c=bytes[i];
	if (c=='\n'||c=='\r') {
	  if (line_len) {
	    if (sscanf(line,"%x=%x %x %x %x %x %x %x State:%x/%x %x %x.%x,%x",
		       &icapereg,&icapeval,
		       &iec_irq,&iec_status,&iec_data,&iec_devinfo,
		       &val,&write_count,
		       &iec_state,&iec_state_reached,
		       &write_val,&msec,&usec,&waits)
		== 14 ) {
	      fprintf(stderr,"DEBUG: line = '%s'\n",line);
	      return 0;
	    }
	  }
	  line[0]=0; line_len=0;
	} else {
	  if (line_len<1024) { line[line_len++]=c;  line[line_len]=0; }
	}
      }
    }
  }

  return 0;
}
