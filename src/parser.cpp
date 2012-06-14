#include <stdio.h>
#include <stdlib.h>

struct foobar
{
	unsigned int padding:3;
	unsigned int button3:1;
	unsigned int button2:1;
	unsigned int button1:1;
	unsigned int button0:1;
	unsigned int clk:1;
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
	//Open the UART
	system("stty -F /dev/ttyUSB0 speed 115200 > /dev/null");
	FILE* fp = fopen("/dev/ttyUSB0", "rw");
	
	//Output VCD header
	printf("$timescale 50ns $end\n");
	printf("$date NOT_IMPLEMENTED $end\n");
	printf("$version RED TIN v0.1 $end\n");
	printf("$var reg 1 a clk $end\n");
	printf("$var reg 4 b buttons $end\n");
	printf("$var reg 32 c count $end\n");
	printf("$enddefinition $end\n");

	for(int i=0; i<512; i++)
	{
		//Wait for sync header every 16 data frames
		//Consists of 15 0x55 then a 0xAA.
		if( ((i & 0xF) == 0xF) || i == 0)
		{
			//Read 0x55s
			unsigned char tmp = 0;
			//printf("Waiting for 55\n");
			while(tmp != 0x55)
			{
				fread(&tmp, 1, 1, fp);
				//printf("   tmp = %x\n", tmp & 0xFF);
			}
				
			//Wait until we get an AA
			//printf("Waiting for AA\n");
			while(tmp != 0xaa)
			{
				fread(&tmp, 1, 1, fp);
				//printf("   tmp = %x\n", tmp & 0xFF);
			}
				
			//Send an AA back
			//printf("Sending ACK\n");
			fwrite(&tmp, 1, 1, fp);
		}
		
		foobar sample;
		fread(&sample, sizeof(sample), 1, fp);
		
		//Convert count to raw binary
		char cnt[33] = {0};
		unsigned int x = byteswap(sample.count);
		for(int j=0; j<33; j++)
		{
			if( (x >> j) & 1)
				cnt[31-j] = '1';
			else
				cnt[31-j] = '0';
		}
		
		printf( "#%d\n"
				"%da\n"
				"b%d%d%d%d b\n"
				"b%s c\n"
				"\n",
			i,
			sample.clk,
			sample.button0,
			sample.button1,
			sample.button2,
			sample.button3,
			cnt
			);
	}
	
	fclose(fp);
}
