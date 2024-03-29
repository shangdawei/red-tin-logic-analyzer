/******************************************************************************
*                                                                             *
* RED TIN logic analyzer v0.1                                                 *
*                                                                             *
* Copyright (c) 2012 Andrew D. Zonenberg                                      *
* All rights reserved.                                                        *
*                                                                             *
* Redistribution and use in source and binary forms, with or without modifi-  *
* cation, are permitted provided that the following conditions are met:       *
*                                                                             *
*    * Redistributions of source code must retain the above copyright notice  *
*      this list of conditions and the following disclaimer.                  *
*                                                                             *
*    * Redistributions in binary form must reproduce the above copyright      *
*      notice, this list of conditions and the following disclaimer in the    *
*      documentation and/or other materials provided with the distribution.   *
*                                                                             *
*    * Neither the name of the author nor the names of any contributors may be*
*      used to endorse or promote products derived from this software without *
*      specific prior written permission.                                     *
*                                                                             *
* THIS SOFTWARE IS PROVIDED BY THE AUTHORS "AS IS" AND ANY EXPRESS OR IMPLIED *
* WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF        *
* MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN     *
* NO EVENT SHALL THE AUTHORS BE HELD LIABLE FOR ANY DIRECT, INDIRECT,         *
* INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT    *
* NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,   *
* DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY       *
* THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT         *
* (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF    *
* THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.           *
*                                                                             *
******************************************************************************/

/**
	@file MainWindow.h
	@author Andrew D. Zonenberg
	@brief Main application window
 */

#include "MainWindow.h"
#include <gtkmm/messagedialog.h>
#include <gtkmm/stock.h>
#include <iostream>

#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
#include <fcntl.h>
#include <termios.h>
#include <memory.h>

using namespace std;

int bit_test_pair(int state_0, int state_1, int current_1, int old_1, int current_0, int old_0);
int bit_test(int state, int current, int old);
int MakeTruthTable(int state_0, int state_1);

static const char* g_edgenames[] = 
{
	"= 0",
	"= 1",
	"falling edge",
	"rising edge",
	"changes"
};

MainWindow::MainWindow(std::string fname)
: m_signallist(2)
, m_triggerlist(3)
{
	//Initial setup
	set_title("RED TIN Logic Analyzer");
	set_reallocate_redraws(true);
	set_default_size(1024, 768);

	m_bEditingSignal = false;

	try
	{
		//Add widgets
		CreateWidgets();
		
		//Load the config file, if any
		if(!fname.empty())
			LoadConfig(fname);
	}
	catch(std::string err)
	{
		cerr << err.c_str();
		exit(-1);
	}
	
	//Done adding widgets
	show_all();
	
}

MainWindow::~MainWindow()
{

}

void MainWindow::CreateWidgets()
{	
	/*
		Main window
		
		Splitter
			Scrolled panel (left)
				Vertical box
					List box for signals
					Horizontal box for buttons
						Edit button
						Delete button
			Scrolled panel (right)
				Vertical box
					Horizontal box for edit/modify area
						Dropdown for width
						Edit box for name
						Add button
					Horizontal box for triggers, text label of some sort (?)
						Some captions
						"bit" dropdown
						"edge" dropdown
						add button
	 */
	 
	add(m_rootSplitter);
		m_rootSplitter.add1(m_leftpanel);
			m_leftpanel.add(m_leftbox);
				m_leftbox.pack_start(m_editframe, Gtk::PACK_SHRINK);
					m_editframe.add(m_editpanel);
					m_editframe.set_label("Edit Signal");
						m_editpanel.pack_start(m_signalwidthbox, Gtk::PACK_SHRINK);
						m_editpanel.pack_start(m_signalnameentry);
						m_editpanel.pack_end(m_signalupdatebutton, Gtk::PACK_SHRINK);
						m_signalupdatebutton.set_label("Add Signal");
				m_leftbox.pack_start(m_signallist);
				m_leftbox.pack_end(m_leftbuttons, Gtk::PACK_SHRINK);
					m_leftbuttons.pack_start(m_editbutton, Gtk::PACK_SHRINK);
					m_leftbuttons.pack_start(m_deletebutton, Gtk::PACK_SHRINK);
					m_leftbuttons.pack_start(m_sigupbutton, Gtk::PACK_SHRINK);
					m_leftbuttons.pack_start(m_sigdownbutton, Gtk::PACK_SHRINK);
					m_editbutton.set_label("Edit Signal");
					m_deletebutton.set_label("Delete Signal");
					m_sigupbutton.set_label("Move Up");
					m_sigdownbutton.set_label("Move Down");
		m_rootSplitter.add2(m_rightpanel);
			m_rightpanel.add(m_rightbox);
			
				m_rightbox.pack_start(m_viewflagsframe, Gtk::PACK_SHRINK);
					m_viewflagsframe.add(m_viewflagspanel);
					m_viewflagsframe.set_label("Additional viewer command line arguments");
						m_viewflagspanel.pack_start(m_viewflagsbox);
			
				m_rightbox.pack_start(m_samplefreqframe, Gtk::PACK_SHRINK);
					m_samplefreqframe.add(m_samplefreqpanel);
					m_samplefreqframe.set_label("Sampling frequency (MHz, must match \"clk\" input to LA core)");
						m_samplefreqpanel.pack_start(m_samplefreqbox);
				m_rightbox.pack_start(m_triggereditframe, Gtk::PACK_SHRINK);
					m_triggereditframe.add(m_triggereditpanel);
					m_triggereditframe.set_label("Trigger when");
						m_triggereditpanel.pack_start(m_triggersignalbox);
						m_triggereditpanel.pack_start(m_triggerbitbox, Gtk::PACK_SHRINK);
						m_triggereditpanel.pack_start(m_triggeredgebox, Gtk::PACK_SHRINK);
						m_triggereditpanel.pack_start(m_triggerupdatebutton, Gtk::PACK_SHRINK);
						m_triggerupdatebutton.set_label("Add Trigger");
				m_rightbox.pack_start(m_triggerpanel);				
					m_triggerpanel.pack_start(m_triggerlist);
					m_triggerpanel.pack_start(m_triggereditbuttons, Gtk::PACK_SHRINK);
						m_triggereditbuttons.pack_start(m_triggereditbutton, Gtk::PACK_SHRINK);
						m_triggereditbuttons.pack_start(m_triggerdeletebutton, Gtk::PACK_SHRINK);
						m_triggereditbuttons.pack_end(m_capturebutton, Gtk::PACK_SHRINK);
						m_triggereditbutton.set_label("Edit");
						m_triggerdeletebutton.set_label("Delete");
						m_capturebutton.set_label("Start Capture");
	m_rootSplitter.set_position(375);
		
	//Turn off scrollbars if not necessary
	m_leftpanel.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC);
	m_rightpanel.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC);
	
	//Populate signal width combo box
	for(int i=0; i<128; i++)
	{
		if(i == 0)
			m_signalwidthbox.append_text("wire");
		else
		{
			char str[16];
			snprintf(str, 15, "wire[%d:0]", i);
			m_signalwidthbox.append_text(str);
		}
	}
	m_signalwidthbox.set_active(0);
	
	m_triggeredgebox.append_text("is low");
	m_triggeredgebox.append_text("is high");
	m_triggeredgebox.append_text("has a falling edge");
	m_triggeredgebox.append_text("has a rising edge");
	m_triggeredgebox.append_text("changes");
	
	//Set column titles
	m_signallist.set_column_title(0, "Width");
	m_signallist.set_column_title(1, "Name");
	m_triggerlist.set_column_title(0, "Signal");
	m_triggerlist.set_column_title(1, "Bit");
	m_triggerlist.set_column_title(2, "Edge");
	
	m_samplefreqbox.set_text("20.000");
				
	//Set up signals
	m_signalupdatebutton.signal_clicked().connect(sigc::mem_fun(*this, &MainWindow::OnSignalUpdate));
	m_deletebutton.signal_clicked().connect(sigc::mem_fun(*this, &MainWindow::OnSignalDelete));
	m_triggersignalbox.signal_changed().connect(sigc::mem_fun(*this, &MainWindow::OnTriggerSignalChanged));
	m_triggerupdatebutton.signal_clicked().connect(sigc::mem_fun(*this, &MainWindow::OnTriggerUpdate));
	m_capturebutton.signal_clicked().connect(sigc::mem_fun(*this, &MainWindow::OnCapture));
	m_triggerdeletebutton.signal_clicked().connect(sigc::mem_fun(*this, &MainWindow::OnTriggerDelete));
	
	signal_delete_event().connect(sigc::mem_fun(*this, &MainWindow::OnClose));
				
	//Disable unimplemented buttons
	m_editbutton.set_sensitive(false);
	m_sigupbutton.set_sensitive(false);
	m_sigdownbutton.set_sensitive(false);
	m_triggereditbutton.set_sensitive(false);
				
	//Set up viewport
	show_all();
}

void MainWindow::OnSignalUpdate()
{
	if(m_bEditingSignal)
	{
		printf("signal update\n");
	}
	else
	{
		int width = m_signalwidthbox.get_active_row_number() + 1;
		Glib::ustring name = m_signalnameentry.get_text();
		//printf("add new signal - width %d, name %s\n", width, name.c_str());
			
		//format name
		char str[16] = "wire";
		if(width > 1)
			snprintf(str, 15, "wire[%d:0]", width-1);
			
		//Add signal to list
		int rowid = m_signallist.append_text();
		m_signallist.set_text(rowid, 0, str);
		m_signallist.set_text(rowid, 1, name);
		
		m_signals.push_back(Signal(width, name));
		
		//Update triggersignalbox with new signal list
		m_triggersignalbox.clear_items();
		for(size_t i=0; i<m_signals.size(); i++)
			m_triggersignalbox.append_text(m_signals[i].name);
	}
}

void MainWindow::OnTriggerSignalChanged()
{
	int sel = m_triggersignalbox.get_active_row_number();
	
	m_triggerbitbox.clear_items();
	
	//no selection
	if(sel == -1)
	{
	}
	else
	{	
		//Look up this item
		Signal& sig = m_signals[sel];
		
		//Generate bits
		for(int i=0; i<sig.width; i++)
		{
			char str[16];
			snprintf(str, 15, "bit %d", i);
			m_triggerbitbox.append_text(str);
		}
	}
}

void MainWindow::OnTriggerUpdate()
{
	//Get trigger parameters
	int signal = m_triggersignalbox.get_active_row_number();
	int nbit = m_triggerbitbox.get_active_row_number();
	int edge = m_triggeredgebox.get_active_row_number();
	
	//If no selection for any of them, quit
	if( (edge == -1) || (signal == -1) || (nbit == -1) )
		return;
		
	Signal& sig = m_signals[signal];
	
	//Add to internal trigger list
	m_triggers.push_back(Trigger(sig.name, nbit, edge));
	
	//string formatting
	char sbit[16] = "";
	if(sig.width > 1)
		snprintf(sbit, 15, "[%d]", nbit);
	
	//Add to triggerlist
	int row = m_triggerlist.append_text();
	m_triggerlist.set_text(row, 0, sig.name.c_str());
	m_triggerlist.set_text(row, 1, sbit);
	m_triggerlist.set_text(row, 2, g_edgenames[edge]);
}

void MainWindow::OnCapture()
{
	printf("capture\n");	
	
	int state_vector[128];
	for(int i=0; i<128; i++)
		state_vector[i] = Trigger::TRIGGER_TYPE_DONTCARE;
	
	std::map<string, Signal*> signalmap;
	
	//Update the bit positions of each signal
	int bitpos = 127;
	for(size_t i=0; i<m_signals.size(); i++)
	{
		Signal& sig = m_signals[i];
		sig.highbit = bitpos;
		sig.lowbit = bitpos - sig.width + 1;
		bitpos -= sig.width;
		
		if((bitpos+1) < 0)
		{
			printf("Too many signals specified!\n");
			return;
		}
		
		signalmap[sig.name] = &sig;
	}
	
	//Set up the trigger array
	for(size_t i=0; i<m_triggers.size(); i++)
	{
		Trigger& trig = m_triggers[i];
		Signal& sig = *signalmap[trig.signalname];
		
		if(trig.triggertype > 5)
		{
			printf("Invalid trigger type\n");
			return;
		}
		
		//Get the bit number for the signal
		int nbit = sig.lowbit + trig.nbit;
		state_vector[nbit] = trig.triggertype;
	}
	
	//Build the full bitmask set
	int truth_tables[64] = {0};
	for(int i=0; i<64; i++)
		truth_tables[i] = MakeTruthTable(state_vector[2*i], state_vector[2*i + 1]);
	
	/*	
	printf("Bitmask: \n");
	for(int i=0; i<64; i++)
	{
		printf("%08x ", truth_tables[i]);
		if( (i & 0x7) == 0x7)
			printf("\n");
	}
	*/
	
	/*
		128 channels packed into 64 LUTs (two bits for each).
		Configuration is done in eight columns of 8 LUTs (16 channels) each.
		
		Channels [0,1]....[14,15] are loaded at once, with one bit of data per clock.
		[16,17]...[30,31] are in the next row, etc.
		
		Only the low 16 bits of each LUT are meaningful; 16 "don't care" bytes must be clocked
		into the high half.
		
		In total the configuration bitstream is 256 bytes (256 bits per column).
		
		The first configuration word is bit masks 56...63.
	*/
	
	//Generate the configuration bitstream for the proper column format
	unsigned char bitstream[256];
	for(int i=0; i<256; i++)
	{
		int flipped_bitnum = 255 - i;				//index from the start of the shift register
		int bitnum = flipped_bitnum & 0x1F;			//Index of the current bit in this LUT
		int lutnum = flipped_bitnum >> 5;			//Index of the current LUT
			
		//Find the appropriate truth tables and pull bits out	
		unsigned char cword = 0;
		for(int col=0; col<8; col++)
		{
			int masknum = 8*lutnum + col;
			int bitval = (truth_tables[masknum] >> bitnum) & 0x1;
			cword |= (bitval << col);
		}
		
		bitstream[i] = cword;
	}
	
	/*
	printf("Bitstream: \n");
	for(int i=0; i<256; i++)
	{
		printf("%02x ", bitstream[i] & 0xFF);
		if( (i & 0xF) == 0xF)
			printf("\n");
	}
	*/
	
	//Connect to the UART
	int hfile = open("/dev/ttyUSB0", O_RDWR);
	if(hfile < 0)
	{
		perror("couldn't open uart");
		return;
	}
	
	//Set flags
	termios flags;
	memset(&flags, 0, sizeof(flags));
	tcgetattr(hfile, &flags);
	flags.c_cflag = B115200 | CS8 | CLOCAL | CREAD;
	flags.c_iflag = 0;
	flags.c_cc[VMIN] = 1;
	if(0 != tcflush(hfile, TCIFLUSH))
	{
		perror("fail to flush tty");
		return;
	}
	if(0 != tcsetattr(hfile, TCSANOW, &flags))
	{
		perror("fail to set attr");
		return;
	}
	
	//Send trigger header to the board
	unsigned char header[5] = {0xfe, 0xed, 0xfa, 0xce, 0x00};
	if(5 != write_looped(hfile, header, 5))
	{
		perror("couldn't send header");
		return;
	}
	
	//Send bitstream to the board
	if(256 != write_looped(hfile, bitstream, 256))
	{
		perror("couldn't send bitstream");
		return;
	}
	
	//Wait for data to come back, then read it
	printf("Waiting for sync header...\n");
	char ch = 0;
	while(ch != 0x55)
	{
		if(1 != read(hfile, &ch, 1))
		{
			perror("couldn't read sync byte");
			return;
		}
		//printf("%c %02x\n", ch, ch & 0xFF);
	}
	unsigned char read_data[512][16];
	for(int i=0; i<512; i++)
	{
		if(16 != read_looped(hfile, read_data[i], 16))
			return;
		//printf("Got %d samples so far!\n", i);
	}
	printf("Got the data\n");
	
	//Done with the UART
	close(hfile);
	
	//Create the VCD file
	FILE* stemp = fopen("/tmp/redtin_temp.vcd", "w+");
	if(stemp == NULL)
	{
		perror("couldn't create temp file");
		return;
	}
		
	//Get the current time
	time_t now;
	time(&now);
	struct tm now_split;
	localtime_r(&now, &now_split);
	
	//Get sampling frequency
	string strRate = m_samplefreqbox.get_text();
	float frequency = atof(strRate.c_str());	//in MHz
	float period = 1000000 / frequency;			//in picoseconds
	
	//Format the VCD header
	fprintf(stemp, "$timescale %.0fps $end\n", period/2);	//period of 1/2 clock cycle
														//so we can show falling edges
	fprintf(stemp, "$date %4d-%02d-%02d %02d:%02d:%d $end\n",
		now_split.tm_year+1900, now_split.tm_mon, now_split.tm_mday,
		now_split.tm_hour, now_split.tm_min, now_split.tm_sec);
	fprintf(stemp, "$version RED TIN v0.1 $end\n");
	//The special signal "capture_clk" is the clock of our sampling module
	fprintf(stemp, "$var reg 1 * capture_clk $end\n");
	for(size_t i=0; i<m_signals.size(); i++)
		fprintf(stemp, "$var wire %d %c %s $end\n", m_signals[i].width, static_cast<char>('A' + i), m_signals[i].name.c_str());
	fprintf(stemp, "$enddefinition $end\n");
	
	//Write the data to the VCD
	for(int i=0; i<512; i++)
	{
		//Clock goes high
		fprintf(stemp,
				"#%d\n"
				"1*\n",
				i*2
			);
			
		//Everything changes on the rising edge		
		for(size_t j=0; j<m_signals.size(); j++)
		{
			Signal& sig = m_signals[j];
			
			std::string value = signal_to_binary(read_data[i], sig.lowbit, sig.highbit);
			
			//1-bit signal
			if(sig.lowbit == sig.highbit)
				fprintf(stemp, "%s%c\n", value.c_str(), static_cast<char>('A' + j));
			
			//Multi-bit signal
			else
				fprintf(stemp, "b%s %c\n", value.c_str(), static_cast<char>('A' + j) );
		}
		fprintf(stemp, "\n");
		
		//then clock goes low
		fprintf(stemp,
				"#%d\n"
				"0*\n"
				"\n",
				i*2 + 1);
	}
	
	fflush(stemp);
	fclose(stemp);
	
	//Get command line arguments
	string sargs = m_viewflagsbox.get_text();
	char* psargs = new char[sargs.length() + 1];
	strcpy(psargs, sargs.c_str());
	
	//Parse arguments
	std::vector<const char*> args;
	args.push_back("/usr/bin/gtkwave");
	args.push_back("/tmp/redtin_temp.vcd");
	char* s = strtok(psargs, " ");
	if(s != NULL)
	{
		args.push_back(s);
		while(NULL != (s = strtok(NULL, " ")))
			args.push_back(s);
	}
	args.push_back(NULL);
	
	//Spawn gtkwave
	pid_t gtkwave_pid = fork();
	if(gtkwave_pid == 0)
	{
		execv("/usr/bin/gtkwave", (char**)&args[0]);
		perror("child: failed to spawn gtkwave");
	}
	else if(gtkwave_pid == -1)
		perror("failed to spawn gtkwave");
		
	delete[] psargs;
}

int MainWindow::write_looped(int fd, unsigned char* buf, int count)
{
	unsigned char* p = buf;
	int bytes_left = count;
	int x = 0;
	while( (x = write(fd, p, bytes_left)) > 0)
	{
		if(x < 0)
		{
			perror("fail to write");
			return -1;
		}
		bytes_left -= x;
		p += x;
	}
	
	return count;
}

int MainWindow::read_looped(int fd, unsigned char* buf, int count)
{
	unsigned char* p = buf;
	int bytes_left = count;
	int x = 0;
	while( (x = read(fd, p, bytes_left)) > 0)
	{
		if(x < 0)
		{
			perror("fail to read");
			return -1;
		}
		bytes_left -= x;
		p += x;
	}
	
	return count;
}

/**
	@brief Converts a signal to a binary string
 */
std::string MainWindow::signal_to_binary(unsigned char* data, int lowbit, int highbit)
{
	string ret;
	
	for(int i=highbit; i>=lowbit; i--)
	{
		int nword = 15 - (i >> 3);
		int col = i & 7;
		
		int j = (data[nword] >> col) & 1;
		char c = j + '0';
		ret += c;
	}
	
	return ret;
}

void MainWindow::OnSignalDelete()
{
	//Make sure something is selected
	Glib::RefPtr<Gtk::TreeSelection> sel = m_signallist.get_selection();
	if(sel->count_selected_rows() == 0)
		return;
	Glib::RefPtr<Gtk::ListStore> model = Glib::RefPtr<Gtk::ListStore>::cast_static(m_signallist.get_model());
	Gtk::TreeModel::iterator it = sel->get_selected();
	
	//Delete from our internal store
	m_signals.erase(m_signals.begin() + model->get_path(it)[0]);
	
	//Delete from tree model
	model->erase( it );
}

void MainWindow::OnTriggerDelete()
{
	//Make sure something is selected
	Glib::RefPtr<Gtk::TreeSelection> sel = m_triggerlist.get_selection();
	if(sel->count_selected_rows() == 0)
		return;
	Glib::RefPtr<Gtk::ListStore> model = Glib::RefPtr<Gtk::ListStore>::cast_static(m_triggerlist.get_model());
	Gtk::TreeModel::iterator it = sel->get_selected();
	
	//Delete from our internal store
	m_triggers.erase(m_triggers.begin() + model->get_path(it)[0]);
	
	//Delete from tree model
	model->erase( it );
}

bool MainWindow::OnClose(GdkEventAny* /*event*/)
{
	Gtk::MessageDialog msg("Save signal configuration?", false, Gtk::MESSAGE_QUESTION, Gtk::BUTTONS_YES_NO, true);
	int button = msg.run();
	
	if(button == Gtk::RESPONSE_YES)
	{
		Gtk::FileChooserDialog dlg("Save signal configuration", Gtk::FILE_CHOOSER_ACTION_SAVE);
		dlg.set_select_multiple(false);
		dlg.set_create_folders(true);
		dlg.add_button(Gtk::Stock::CANCEL, Gtk::RESPONSE_CANCEL);
		dlg.add_button("Save", Gtk::RESPONSE_OK);
		
		Gtk::FileFilter filter;
		filter.set_name("Signal configuration files (*.scfg)");
		filter.add_pattern("*.scfg");
		dlg.add_filter(filter);
		
		if(dlg.run() != Gtk::RESPONSE_OK)
			return true;
		
		//Create the file
		string fname = dlg.get_filename();
		if(fname == "")
			return true;
		FILE* fp = fopen(fname.c_str(), "w");
		
		//Save everything
		//Config file format is mostly a subset of Verilog to make it nice and readable.
		
		//Sample rate
		string sample_rate = m_samplefreqbox.get_text();
		fprintf(fp, "parameter SAMPLE_RATE_MHZ = %s;\n", sample_rate.c_str());
		
		//Arguments
		string sargs = m_viewflagsbox.get_text();
		fprintf(fp, "parameter VIEWER_ARGS = %s;\n", sargs.c_str());
		
		//Signals
		for(size_t i=0; i<m_signals.size(); i++)
		{
			Signal& sig = m_signals[i];
			fprintf(fp, "wire[%d:0] %s;\n", sig.width-1, sig.name.c_str());
		}
		
		//Triggers
		//add_trigger_condition(posedge foobar[3]);
		for(size_t i=0; i<m_triggers.size(); i++)
		{
			Trigger& trig = m_triggers[i];
			fprintf(fp, "add_trigger_condition(");
			switch(trig.triggertype)
			{
				case Trigger::TRIGGER_TYPE_LOW:
					fprintf(fp, "!%s[%d]", trig.signalname.c_str(), trig.nbit);
					break;
				case Trigger::TRIGGER_TYPE_HIGH:
					fprintf(fp, "%s[%d]", trig.signalname.c_str(), trig.nbit);
					break;
				case Trigger::TRIGGER_TYPE_RISING:
					fprintf(fp, "posedge %s[%d]", trig.signalname.c_str(), trig.nbit);
					break;
				case Trigger::TRIGGER_TYPE_FALLING:
					fprintf(fp, "negedge %s[%d]", trig.signalname.c_str(), trig.nbit);
					break;
				case Trigger::TRIGGER_TYPE_CHANGE:
					fprintf(fp, "posedge %s[%d] or negedge %s[%d]", trig.signalname.c_str(), trig.nbit, trig.signalname.c_str(), trig.nbit);
					break;
			}
			fprintf(fp, ");\n");
		}
		
		fclose(fp);
	}
	
	//keep going
	return false;
}

void MainWindow::LoadConfig(std::string fname)
{
	//Read the config file
	FILE* fp = fopen(fname.c_str(), "r");
	char line[1024];
	while(fgets(line, 1023, fp))
	{
		//Read the opcode
		char word[256];
		sscanf(line, "%255[a-z_]", word);
		std::string sw = word;
		
		//Parameters - global settings of some sort
		if(sw == "parameter")
		{
			char name[256];
			char value[1024];
			sscanf(line, "parameter %255[^ =] = %1023[^;];", name, value);
			string sname = name;
			
			if(sname == "SAMPLE_RATE_MHZ")
				m_samplefreqbox.set_text(value);
			else if(sname == "VIEWER_ARGS")
				m_viewflagsbox.set_text(value);
			else
				printf("unrecognized parameter \"%s\"\n", name);
		}
		
		//Wires - signals
		else if(sw == "wire")
		{
			char name[256];
			int maxbit;
			sscanf(line, "wire[%d:0] %255[^;];", &maxbit, name);
			
			m_signals.push_back(Signal(maxbit+1, name));
			
			char swidth[128] = "wire";
			if(maxbit != 0)
				snprintf(swidth, 127, "wire[%d:0]", maxbit);
			
			int rowid = m_signallist.append_text();
			m_signallist.set_text(rowid, 0, swidth);
			m_signallist.set_text(rowid, 1, name);
		}
		
		//Triggers
		else if(sw == "add_trigger_condition")
		{
			char body[256];
			sscanf(line, "add_trigger_condition( %255[^)] );", body);
			
			bool posedge = (strstr(body, "posedge") != NULL);
			bool negedge = (strstr(body, "negedge") != NULL);
			bool found_or = (strstr(body, "or") != NULL);
			
			// !foo
			int type = 0;
			char* namestart = body;
			if(body[0] == '!')
			{
				type = Trigger::TRIGGER_TYPE_LOW;
				namestart ++;
			}
			
			//posedge foo
			else if(posedge && !negedge)
			{
				type = Trigger::TRIGGER_TYPE_RISING;
				namestart += strlen("posedge");
			}
			
			//negedge foo
			else if(negedge && !posedge)
			{
				type = Trigger::TRIGGER_TYPE_FALLING;
				namestart += strlen("negedge");
			}
			
			//posedge foo or negedge foo
			else if(posedge && negedge && found_or)
			{
				type = Trigger::TRIGGER_TYPE_CHANGE;
				namestart += strlen("posedge");
			}
			
			//foo
			else
				type = Trigger::TRIGGER_TYPE_HIGH;
				
			//Read the name
			char name[128];
			int bit;
			sscanf(namestart, " %127[^ [][%d]", name, &bit);
			
			m_triggers.push_back(Trigger(name, bit, type));
			
			//Add to triggerlist
			char sbit[32];
			snprintf(sbit, 31, "%d", bit);
			int row = m_triggerlist.append_text();
			m_triggerlist.set_text(row, 0, name);
			m_triggerlist.set_text(row, 1, sbit);
			m_triggerlist.set_text(row, 2, g_edgenames[type]);
		}
		
		//Something's wrong, skip the line
		else
			printf("unrecognized keyword \"%s\" in config file\n", word);
	}

	fclose(fp);
	
	//Update triggersignalbox with new signal list
	m_triggersignalbox.clear_items();
	for(size_t i=0; i<m_signals.size(); i++)
		m_triggersignalbox.append_text(m_signals[i].name);
}

int bit_test_pair(int state_0, int state_1, int current_1, int old_1, int current_0, int old_0)
{
	return bit_test(state_0, current_0, old_0) && bit_test(state_1, current_1, old_1);
}

int bit_test(int state, int current, int old)
{
	switch(state)
	{
		case Trigger::TRIGGER_TYPE_LOW:
			return (!current);
		case Trigger::TRIGGER_TYPE_HIGH:
			return (current);
		case Trigger::TRIGGER_TYPE_RISING:
			return (current && !old);
		case Trigger::TRIGGER_TYPE_FALLING:
			return (!current && old);
		case Trigger::TRIGGER_TYPE_CHANGE:
			return (current != old);
		case Trigger::TRIGGER_TYPE_DONTCARE:
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
