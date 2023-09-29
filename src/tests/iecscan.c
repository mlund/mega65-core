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
  usleep(10000);
  int r=read(serialfd,buf,1024);
  while(r>0) {
    usleep(1000);
    r=read(serialfd,buf,1024);
  }
}

unsigned int icapereg,icapeval,val,write_count;
unsigned int iec_irq,iec_status,iec_data,iec_devinfo,iec_state,iec_state_reached,write_val,msec,usec,waits,iec_debug_ram;

int getUpdate(void)
{
  int line_len=0;
  char line[1024];

  char bytes[1024];

  purge_serial();
  
  while(1) {
    int n = read(serialfd,bytes,1024);
    if (n>0) {
      for(int i=0;i<n;i++) {
	int c=bytes[i];
	if (c=='\n'||c=='\r') {
	  if (line_len) {
	    if (sscanf(line,"%x=%x %x %x %x %x %x %x State:%x/%x %x %x.%x,%x %x",
		       &icapereg,&icapeval,
		       &iec_irq,&iec_status,&iec_data,&iec_devinfo,
		       &val,&write_count,
		       &iec_state,&iec_state_reached,
		       &write_val,&msec,&usec,&waits,&iec_debug_ram)
		== 15 ) {
	      // fprintf(stderr,"DEBUG: line = '%s'\n",line);
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


#define REG_DBG 4
#define REG_IRQ 7
#define REG_CMD 8
#define REG_DATA 9
#define REG_DEVINFO 10
void writeReg(int reg, unsigned int val)
{
  char cmd[5];
  snprintf(cmd,5,"%x%02x\r",reg&0xf,val);
  write(serialfd,cmd,4);
  // fprintf(stderr,"DEBUG: POKE $D69%1X,$%02X\n",reg,val);
  return;
}

void iecReset(void)
{
  fprintf(stderr,"INFO: Resetting IEC bus\n");

  writeReg(REG_CMD,0x00);  // Reset IEC state machine
  getUpdate();
  writeReg(REG_CMD,0x72); // Pull /RESET low
  getUpdate();
  // Wait a little
  usleep(100000);
  // Release /RESET
  writeReg(REG_CMD,0x52);
  getUpdate();
  // Wait until all lines are released by drive
  while(iec_status&0x2c!=0x2c) {
    usleep(100000);
    getUpdate();
  }
}

iecDataTrace(char *msg)
{
  fprintf(stderr,"DEBUG: Fetching IEC data trace...\n");
  writeReg(REG_DBG,0x00); // Reset data pointer to start of buffer
  for(int i=0;i<4096;i++) {
    getUpdate();
    printf(" $%02x",iec_debug_ram); fflush(stdout);
    writeReg(REG_DBG,0x01); // Advance to next value in debug trace buffer
  }
  printf("\n");
}

int main(int argc,char **argv)
{
  openSerialPort(argv[1]);

  iecReset();
  
  for(int dev=8;dev<10;dev++) {
    fprintf(stderr,"INFO: Probing device #%d\n",dev);
    iecReset();
    getUpdate();
    writeReg(9,0x20+dev);  // TALK + device
    iecDataTrace("After sending $2x under attention");
    getUpdate();
    writeReg(8,'0');       // Command device to talk
    getUpdate();
    usleep(100000); // Allow time for job to complete
    getUpdate();
  }

  return 0;
}

