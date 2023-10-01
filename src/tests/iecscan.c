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

#include <libpng16/png.h>

int serialfd=-1;

unsigned char dbg_vals[4096]={0};
unsigned char dbg_states[4096]={0};

char *sigs[5][24]={
  {"                        ",
   "xxxxxx   xxxxx  xxxxxx  ",
   "xx   xx xx        xx    ",
   "xx   xx xx        xx    ",
   "xxxxxx   xxxxx    xx    ",
   "xx xx        xx   xx    ",
   "xx  xx       xx   xx    ",
   "xx   xx  xxxxx    xx    "},
  {"                        ",
   "  xxx   xxxxxx xx   xx ",
   " xxxxx    xx   xxx  xx ",
   "xx   xx   xx   xxxx xx ",
   "xxxxxxx   xx   xx xxxx ",
   "xx   xx   xx   xx  xxx ",
   "xx   xx   xx   xx   xx ",
   "xx   xx   xx   xx   xx "},
  {"                        ",
   " xxxxx  xx      xx  xx  ",
   "xx   xx xx      xx xx   ",
   "xx      xx      xxxx    ",
   "xx      xx      xxxx    ",
   "xx      xx      xx xx   ",
   "xx   xx xx      xx  xx  ",
   " xxxxx  xxxxxxx xx  xx  "},
  {"                        ",
   "xxxxxx  xxxxxx   xxx   ",
   "xx   xx   xx    xxxxx  ",
   "xx   xx   xx   xx   xx ",
   "xx   xx   xx   xxxxxxx ",
   "xx   xx   xx   xx   xx ",
   "xx   xx   xx   xx   xx ",
   "xxxxxx    xx   xx   xx "},
  {"                        ",
   " xxxxx  xxxxxx   xxxxx  ",
   "xx      xx   xx xx   xx ",
   "xx      xx   xx xx   xx ",
   " xxxxx  xxxxxx  xx   xx ",
   "     xx xx xx   xx  x x ",
   "     xx xx  xx  xx  xxx ",
   " xxxxx  xx   xx  xxxxxxx"}
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
  {"        ",
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

#define MAXX 320
#define MAXY 2048

unsigned int pixels[MAXY][MAXX]={0};

/*
  Our waveform displays use 8x8 blocks to show each signal,
  and the simple 8x8 font elements defined above.

  Each row has room for 1020 ~1usec ticks, and is 40 pixels 
  tall.  Thus for all 4096 ticks, we need four such rows. 
 */
void build_image(void)
{
  // Clear image to white initially
  for(int y=0;y<MAXY;y++)
    for(int x=0;x<MAXX;x++)
      pixels[y][x]=0xffffffff;
  
  // Draw signal legend down the left side
  for(int row = 0; ((row+1)*(9*8)) <= MAXY; row++) {
    for(int sig = 0; sig<5; sig++) {
      for (int charrow=0;charrow<8;charrow++) {
	char *bits=sigs[sig][charrow];
	for(int x=0;bits[x];x++) if (bits[x]!=' ') pixels[row*(9*8)+sig*8+charrow][x]=0xff000000;
      }
    }
  }
  
  int x=32;
  int y=0;

  for(int n=0;n<4096;n++) {

    // Draw state numbers under cells

    if (dbg_states[n]) {
      char num[16];
      snprintf(num,16,"%d",dbg_states[n]);
      int yy=y+5*8;
      for(int c=0;num[c];c++) {
	for(int charrow=0;charrow<8;charrow++) {
	  int d=num[c]-'0';
	  if (d>=0&&d<10) {
	    char *r=digits[d][charrow];
	    for(int col=0;col<8;col++) {
	      int pixel=0;
	      if (r[col]==' ') pixel=1; else pixel=0;
	      pixels[yy+col][x+7-charrow]
		=pixel?0xffffffff:0xff000000;
	    }
	  }
	}
	yy+=8;
      }
    }
    
    // Draw signal states
    for(int sig=0;sig<5;sig++) {
      // RST, ATN, CLK, DATA, SRQ

      int controller=5;
      int device=5;

      int v=dbg_vals[n]^0xc0;
      
      switch(sig) {
      case 0: // RST
	controller=(v&0x80);
	device=5;
	break;
      case 1: // ATN
	controller=(v&0x40);
	device=5;
	break;
      case 2: // CLK
	controller=(v&0x10);
	device=v&0x02;
	break;
      case 3: // DATA
	controller=v&0x08;
	device=v&0x01;
	break;
      case 4: // SRQ
	controller=v&0x20;
	device=v&0x04;
	break;
      }

      int colour = 0x000000;
      int voltage = 5;
      
      if (!device) {
	// Device pulling low
	colour = 0xff0000; // BLUE
	voltage=0;
      } else if (!controller) {
	// Controller pulling low
	colour = 0x0000ff; // RED
	voltage=0;
      } else {
	// Neither pulling low
	colour = 0x000000; // BLACK
	voltage=5;
      }

      // Draw colour to indicate who is pulling low
      for(int xx=0;xx<8;xx++) for(int yy=0;yy<7;yy++) pixels[y+sig*8+yy][x+xx]=0xff000000+colour;
      for(int xx=0;xx<8;xx++) pixels[y+sig*8+7][x+xx]=0xff000000;

      // Draw line at top or bottom
      if (voltage) {
	for(int xx=0;xx<8;xx++) pixels[y+sig*8+0][x+xx]=0xff00ffff; // YELLOW
	for(int xx=0;xx<8;xx++) pixels[y+sig*8+1][x+xx]=0xff00ffff; // YELLOW
      } else {
	for(int xx=0;xx<8;xx++) pixels[y+sig*8+5][x+xx]=0xff00ffff; // YELLOW
	for(int xx=0;xx<8;xx++) pixels[y+sig*8+6][x+xx]=0xff00ffff; // YELLOW
      }
    }

    x+=8;
    if (x>=MAXX) {
      x=32; y+=(9*8);
    }
    if (y>(MAXY-(9*8)+1)) break;
  }
}

void write_png(char *filename)
{
  int y;
  png_structp png = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
  if (!png) {
    fprintf(stderr,"FATAL: png_create_write_struct() failed\n");
    abort();
  }

  png_infop info = png_create_info_struct(png);
  if (!info) {
    fprintf(stderr,"FATAL: png_create_info_struct() failed\n");
    abort();
  }

  if (setjmp(png_jmpbuf(png))) {
    fprintf(stderr,"FATAL: png_jmpbuf() failed\n");
    abort();
  }

  FILE *f = fopen(filename, "wb");
  if (!f) {
    fprintf(stderr,"FATAL: Failed to open '%s' for write\n",filename);
    abort();
  }

  png_init_io(png, f);

  png_set_IHDR(
      png, info, MAXX, MAXY, 8, PNG_COLOR_TYPE_RGBA, PNG_INTERLACE_NONE, PNG_COMPRESSION_TYPE_BASE, PNG_FILTER_TYPE_DEFAULT);

  png_write_info(png, info);

  for (y = 0; y < MAXY; y++) {
    png_write_row(png, (unsigned char *)pixels[y]);
  }
  
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
  while((iec_status&0x2c)!=0x2c) {
    usleep(100000);
    getUpdate();
  }
}

int iecDataTrace(char *msg)
{
  fprintf(stderr,"DEBUG: Fetching IEC data trace...\n");
  writeReg(REG_DBG,0x00); // Reset data pointer to start of buffer
  for(int i=0;i<4096;i++) {
    getUpdate();
    printf(" $%02x/%d",iec_debug_ram,iec_debug_ram2); fflush(stdout);
    dbg_vals[i]=iec_debug_ram;
    dbg_states[i]=iec_debug_ram2;

    if(i&&(!iec_debug_ram2)) break;
    
    writeReg(REG_DBG,0x01); // Advance to next value in debug trace buffer
  }
    
  build_image();
  write_png("iectrace.png");

  printf("\n");
  return 0;
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

