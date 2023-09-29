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

#define PNG_DEBUG 3
#include <png.h>

int serialfd=-1;

char *sigs[5][24]={
  {"                        ",
   "  xxxx   xxxxxx xx   xx ",
   " xxxxxx    xx   xxx  xx ",
   "xx    xx   xx   xxxx xx ",
   "xxxxxxxx   xx   xx xxxx ",
   "xx    xx   xx   xx  xxx ",
   "xx    xx   xx   xx   xx ",
   "xx    xx   xx   xx   xx "},
  {"                        ",
   " xxxxx  xx      xx  xx  ",
   "xx   xx xx      xx xx   ",
   "xx      xx      xxxx    ",
   "xx      xx      xxxx    ",
   "xx      xx      xx xx   ",
   "xx   xx xx      xx  xx  ",
   " xxxxx  xxxxxxx xx  xx  "},
  {"                        ",
   "xxxxxx  xxxxxx   xxxx   ",
   "xx   xx   xx    xxxxxx  ",
   "xx   xx   xx   xx    xx ",
   "xx   xx   xx   xxxxxxxx ",
   "xx   xx   xx   xx    xx ",
   "xx   xx   xx   xx    xx ",
   "xxxxxx    xx   xx    xx "},
  {"                        ",
   " xxxxx  xxxxxx   xxxxx  ",
   "xx      xx   xx xx   xx ",
   "xx      xx   xx xx   xx ",
   " xxxxx  xxxxxx  xx   xx ",
   "     xx xx xx   xx  x x ",
   "     xx xx  xx  xx  xxx ",
   " xxxxx  xx   xx  xxxxxxx"},
  {"                        ",
   "xxxxxx   xxxxx  xxxxxx  ",
   "xx   xx xx        xx    ",
   "xx   xx xx        xx    ",
   "xxxxxx   xxxxx    xx    ",
   "xx xx        xx   xx    ",
   "xx  xx       xx   xx    ",
   "xx   xx  xxxxx    xx    "}
};

char *digits[10][8]={
  {"        ",
   " xxxxx  ",
   "x    xx ",
   "x   x x ",
   "x  x  x ",
   "x x   x ",
   "xx    x ",
   " xxxxx  "},
  {"        ",
   "  xxx   ",
   " xxxx   ",
   "   xx   ",
   "   xx   ",
   "   xx   ",
   "   xx   ",
   " xxxxxx "},
  {"        "
   "  xxxx  ",
   " xx  xx ",
   "    xx  ",
   "   xx   ",
   "  xx    ",
   " xx     ",
   "xxxxxxx "},
  {"        ",
   " xxxxx  ",
   "xx   xx ",
   "     xx ",
   "  xxxxx ",
   "     xx ",
   "xx   xx ",
   " xxxxx  "},
  {"        ",
   "xx  xx  ",
   "xx  xx  ",
   "xx  xx  ",
   "xxxxxx  ",
   "    xx  ",
   "    xx  ",
   "    xx  "},
  {"        ",
   "xxxxxxx ",
   "xx      ",
   "xxxxxx  ",
   "     xx ",
   "     xx ",
   "     xx ",
   "xxxxxx  "},
  {"        ",
   " xxxxx  ",
   "xx   xx ",
   "xx      ",
   "xxxxxx  ",
   "xx   xx ",
   "xx   xx ",
   " xxxxx  "},
  {"        ",
   " xxxxx  ",
   "    xx  ",
   "    xx  ",
   "   xx   ",
   "   xx   ",
   "  xx    ",
   "  xx    "},
  {"        ",
   " xxxxx  ",
   "xx   xx ",
   "xx   xx ",
   " xxxxx  ",
   "xx   xx ",
   "xx   xx ",
   " xxxxx  "},
  {"        ",
   " xxxxx  ",
   "xx   xx ",
   "xx   xx ",
   " xxxxxx ",
   "     xx ",
   "xx   xx ",
   " xxxxx  "}
};

void write_png(char *filename)
{
  int y;
  png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  if (!png)
    abort();

  png_infop info = png_create_info_struct(png);
  if (!info)
    abort();

  if (setjmp(png_jmpbuf(png)))
    abort();

  FILE *f = fopen(filename, "wb");
  if (!f)
    abort();

  png_init_io(png, f);

  int MAXX = 1024;
  int MAXY = 768;

  unsigned int image[MAXY][MAXX];
  
  png_set_IHDR(
      png, info, MAXX, MAXY, 8, PNG_COLOR_TYPE_RGBA, PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_DEFAULT);

  png_write_info(png, info);

#if 0
  for (y = 0; y < maxy; y++) {
    printf("  writing y=%d\n", y);
    fflush(stdout);
    png_write_row(png, frame[y]);
  }
#endif
  
  png_write_end(png, info);
  png_destroy_write_struct(&png, &info);

  fclose(f);

  return;
}


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
unsigned int iec_irq,iec_status,iec_data,iec_devinfo,iec_state,iec_state_reached,write_val,msec,usec,waits,iec_debug_ram,iec_debug_ram2,iec_debug_raddr;

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
	    if (sscanf(line,"%x=%x %x %x %x %x %x %x State:%x/%x %x %x.%x,%x %x:%x:%x",
		       &icapereg,&icapeval,
		       &iec_irq,&iec_status,&iec_data,&iec_devinfo,
		       &val,&write_count,
		       &iec_state,&iec_state_reached,
		       &write_val,&msec,&usec,&waits,&iec_debug_ram,&iec_debug_ram2,&iec_debug_raddr)
		== 17 ) {
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
    printf(" $%02x/%d",iec_debug_ram,iec_debug_ram2); fflush(stdout);
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
    writeReg(REG_DATA,0x20+dev);  // TALK + device
    getUpdate();
    writeReg(REG_CMD,0x30);       // Command device to talk
    getUpdate();
    usleep(100000); // Allow time for job to complete
    getUpdate();
    iecDataTrace("After sending $2x under attention");
  }

  return 0;
}

