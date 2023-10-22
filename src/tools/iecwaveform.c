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

FILE *f=NULL;

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


int openFile(char *port)
{
  f = fopen(port, "rb");
  if (f == NULL) {
    perror("fopen");
    return -1;
  }

  return 0;
}

long long time_val;
unsigned int atn, clk_c64, clk_1541, data_c64, data_1541, data_dummy;
unsigned int iec_state;
char time_units[8192];

int getUpdate(void)
{
  int line_len=0;
  char line[1024];

  char bytes[1024];

  while(!feof(f)) {   
    int n = fread(bytes,1,1024,f);
    if (n>0) {
      for(int i=0;i<n;i++) {
	int c=bytes[i];
	if (c=='\n'||c=='\r') {
	  if (line_len) {
	    // Parse lines like this:	    
	    // /home/paul/Projects/mega65/mega65-core/src/vhdl/tb_iec_serial.vhdl:176:9:@6173ps:(report note): IECBUSSTATE: ATN='1', CLK(c64)='1', CLK(1541)='1', DATA(c64)='1', DATA(1541)='1', DATA(dummy)='1'
	    if (sscanf(line,"/home/paul/Projects/mega65/mega65-core/src/vhdl/tb_iec_serial.vhdl:176:9:@%lld%[^:]:(report note): IECBUSSTATE: ATN='%d', CLK(c64)='%d', CLK(1541)='%d', DATA(c64)='%d', DATA(1541)='%d', DATA(dummy)='%d'",
		       &time_val,time_units,
		       &atn,&clk_c64,&clk_1541,&data_c64,&data_1541,&data_dummy) == 8)

	      // fprintf(stderr,"DEBUG: line = '%s'\n",line);
	      return 0;

	    if (sscanf(line,"/home/paul/Projects/mega65/mega65-core/src/vhdl/iec_serial.vhdl:490:9:@%lld%[^:]:(report note): iec_state = %d",
		       &time_val,time_units,&iec_state)==3) {
	      fprintf(stderr,"  iec_state = %d\n",iec_state);
	    }
	  }
	  line[0]=0; line_len=0;
	} else {
	  if (line_len<1024) { line[line_len++]=c;  line[line_len]=0; }
	}
      }
    }
  }

  return -1;

}


int iecDataTrace(char *msg)
{

  double prev_time = 0;
  
  fprintf(stderr,"DEBUG: Fetching IEC data trace...\n");
  for(int i=0;i<4096;i++) {
    if (getUpdate()) break;

    double time_norm = time_val;
    if (!strcmp(time_units,"ps")) time_norm /= 1000000.0;
    else if (!strcmp(time_units,"ns")) time_norm /= 1000.0;
    else if (!strcmp(time_units,"us")) time_norm *= 1.0;
    else {
      fprintf(stderr,"FATAL: Unknown time units '%s'\n",time_units);
    }

    double time_diff = time_norm - prev_time;
    prev_time = time_norm;
    
    printf(" % +12.3f : ATN=%d, DATA=%d/%d/%d, CLK=%d/%d\n",
	   time_diff,
	   atn,
	   data_c64,data_1541,data_dummy,
	   clk_c64,clk_1541
	   );
    fflush(stdout);
  }
    
  build_image();
  write_png("iectrace.png");

  printf("\n");
  return 0;
}

int main(int argc,char **argv)
{
  openFile(argv[1]);

  iecDataTrace("VHDL IEC Simulation");

  return 0;
}

