#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <termios.h>
#include <memory.h>

struct foobar
{
	unsigned int padding:4;
	unsigned int button3:1;
	unsigned int button2:1;
	unsigned int button1:1;
	unsigned int button0:1;
	unsigned int count:32;
	unsigned char padding3[11];
} __attribute__((packed));

unsigned int byteswap(unsigned int x)
{
	unsigned int b0 = (x >> 24) & 0xFF;
	unsigned int b1 = (x >> 16) & 0xFF;
	unsigned int b2 = (x >> 8)  & 0xFF;
	unsigned int b3 = (x >> 0)  & 0xFF;
	
	return (b3 << 24) | (b2 << 16) | (b1 << 8 ) | (b0 << 0 );
}

int main(int argc, char* argv[])
{
	int hfile = open("/dev/ttyUSB0", O_RDWR);
	if(hfile < 0)
	{
		perror("couldn't open uart");
		return -1;
	}
	
	//Set flags
	termios flags;
	memset(&flags, 0, sizeof(flags));
	tcgetattr(hfile, &flags);
	flags.c_cflag = B500000 | CS8 | CLOCAL | CREAD;
	flags.c_iflag = 0;
	flags.c_cc[VMIN] = 1;
	if(0 != tcflush(hfile, TCIFLUSH))
	{
		perror("fail to flush tty");
		return -1;
	}
	if(0 != tcsetattr(hfile, TCSANOW, &flags))
	{
		perror("fail to set attr");
		return -1;
	}

	//Output VCD header
	printf("$timescale 25ns $end\n");			//25ns = period of one half-clock
	printf("$date NOT_IMPLEMENTED $end\n");
	printf("$version RED TIN v0.1 $end\n");
	printf("$var reg 1 a clk $end\n");
	printf("$var reg 4 b buttons $end\n");
	printf("$var reg 32 c count $end\n");
	printf("$enddefinition $end\n");

	unsigned char buf[8192];
	foobar* samples = (foobar*) &buf[0];
	int bytesLeft = 8192;
	for(int i=0; i<8192;)
	{
		int bytesRead = read(hfile, &buf[i], bytesLeft);
		if(bytesRead <= 0)
		{
			printf("i = %d, bytesRead = %d, bytesLeft = %d\n", i, bytesRead, bytesLeft);
			perror("read error");
			return -1;
		}
		i += bytesRead;
		bytesLeft -= bytesRead;
	}
	
	for(int i=0; i<512; i++)
	{
		foobar& sample = samples[i];
		
		char cnt[33] = {0};
		unsigned int x = byteswap(sample.count);
		for(int j=0; j<33; j++)
		{
			if( (x >> j) & 1)
				cnt[31-j] = '1';
			else
				cnt[31-j] = '0';
		}
		
		//Everything changes on the rising edge
		printf( "#%d\n"
				"1a\n"
				"b%d%d%d%d b\n"
				"b%s c\n"
				"\n",
			i*2,
			sample.button0,
			sample.button1,
			sample.button2,
			sample.button3,
			cnt
			);
			
		//then clock goes low
		printf(	"#%d\n"
				"0a\n"
				"\n",
				i*2 + 1);
	}
		
	close(hfile);
}
