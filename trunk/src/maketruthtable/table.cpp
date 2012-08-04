#include <stdio.h>

enum channel_states
{
	CHANNEL_STATE_LOW,
	CHANNEL_STATE_HIGH,
	CHANNEL_STATE_RISING,
	CHANNEL_STATE_FALLING,
	CHANNEL_STATE_CHANGING,
	CHANNEL_STATE_DONTCARE,
	
	CHANNEL_STATE_COUNT
};

int bit_test_pair(int state_0, int state_1, int current_1, int old_1, int current_0, int old_0);
int bit_test(int state, int current, int old);
int MakeTruthTable(int state_0, int state_1);

int main(int argc, char* argv[])
{	
	int truth_tables[CHANNEL_STATE_COUNT][CHANNEL_STATE_COUNT] = {0};
	
	//Six possible states for each of the 2 channels, 36 total
	//The other two possibilities (always zero, and "not changing") are not currently supported.
	for(int state_0 = 0; state_0 < CHANNEL_STATE_COUNT; state_0 ++)
		for(int state_1 = 0; state_1 < CHANNEL_STATE_COUNT; state_1 ++)
			truth_tables[state_1][state_0] = MakeTruthTable(state_0, state_1);
	
	const char* names[CHANNEL_STATE_COUNT]=
	{
		"low",
		"high",
		"rising",
		"falling", 
		"changing",
		"dontcare"
	};
	
	printf("%-8s   %-8s      %s\n", "CH1", "CH0", "Truth table");
	for(int state_0 = 0; state_0 < CHANNEL_STATE_COUNT; state_0 ++)
		for(int state_1 = 0; state_1 < CHANNEL_STATE_COUNT; state_1 ++)
			printf("%-8s   %-8s      %04x\n", names[state_1], names[state_0], truth_tables[state_1][state_0]);
}

int bit_test_pair(int state_0, int state_1, int current_1, int old_1, int current_0, int old_0)
{
	return bit_test(state_0, current_0, old_0) && bit_test(state_1, current_1, old_1);
}

int bit_test(int state, int current, int old)
{
	switch(state)
	{
		case CHANNEL_STATE_LOW:
			return (!current);
		case CHANNEL_STATE_HIGH:
			return (current);
		case CHANNEL_STATE_RISING:
			return (current && !old);
		case CHANNEL_STATE_FALLING:
			return (!current && old);
		case CHANNEL_STATE_CHANGING:
			return (current != old);
		case CHANNEL_STATE_DONTCARE:
			return 1;
	}
	
	return 0;
}

int MakeTruthTable(int state_0, int state_1)
{
	int table = 0;
	for(int current_0 = 0; current_0 <= 1; current_0 ++)
	{
		for(int current_1 = 0; current_1 <= 1; current_1 ++)
		{
			for(int old_0 = 0; old_0 <= 1; old_0 ++)
			{
				for(int old_1 = 0; old_1 <= 1; old_1 ++)
				{
					int bitnum = (old_1 << 3) | (current_1 << 2) | (old_0 << 1) | (current_0);
					int bitval = bit_test_pair(state_0, state_1, current_1, old_1, current_0, old_0);
					table |= (bitval << bitnum);
				}
			}					
		}
	}
	return table;
}
