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

using namespace std;

static const char* g_edgenames[] = 
{
	"= 0",
	"= 1",
	"falling edge",
	"rising edge",
	"changes"
};

MainWindow::MainWindow()
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
				
	//Set up signals
	m_signalupdatebutton.signal_clicked().connect(sigc::mem_fun(*this, &MainWindow::OnSignalUpdate));
	m_triggersignalbox.signal_changed().connect(sigc::mem_fun(*this, &MainWindow::OnTriggerSignalChanged));
	m_triggerupdatebutton.signal_clicked().connect(sigc::mem_fun(*this, &MainWindow::OnTriggerUpdate));
	m_capturebutton.signal_clicked().connect(sigc::mem_fun(*this, &MainWindow::OnCapture));
				
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
	
	unsigned char trigger_low[16] = {0};
	unsigned char trigger_high[16] = {0};
	unsigned char trigger_falling[16] = {0};
	unsigned char trigger_rising[16] = {0};
	unsigned char trigger_change[16] = {0};
	
	unsigned char* triggers[5]=
	{
		trigger_low,
		trigger_high,
		trigger_falling,
		trigger_rising,
		trigger_change
	};
	
	std::map<string, Signal*> signalmap;
	
	//Update the bit positions of each signal
	int bitpos = 127;
	for(size_t i=0; i<m_signals.size(); i++)
	{
		Signal& sig = m_signals[i];
		sig.highbit = bitpos;
		sig.lowbit = bitpos - sig.width + 1;
		if(sig.width == 1)
			printf("  Signal %s is data[%d]\n",  sig.name.c_str(), sig.highbit);
		else
			printf("  Signal %s[%d:0] is data[%d:%d]\n",  sig.name.c_str(), sig.width-1, sig.highbit, sig.lowbit);
		bitpos -= sig.width;
		
		if(bitpos < 0)
		{
			printf("Too many signals specified!\n");
			return;
		}
		
		signalmap[sig.name] = &sig;
	}
	
	//For each trigger, find the appropriate bits
	for(size_t i=0; i<m_triggers.size(); i++)
	{
		Trigger& trig = m_triggers[i];
		Signal& sig = *signalmap[trig.signalname];
		
		if(trig.triggertype > 5)
		{
			printf("Invalid trigger type\n");
			return;
		}
		
		printf("  Trigger of type %d on bit %d of signal %s\n", trig.triggertype, trig.nbit, trig.signalname.c_str());
		
		//Get the bit number for the signal
		int nbit = sig.lowbit + trig.nbit;
		printf("    = data[%d]\n", nbit);
		
		//Break the bit number down into a word number and a byte number
		int nword = 15 - (nbit >> 3);
		int col = nbit & 7;
		printf("    = mask[%d] bit %d\n", nword, col);
		
		//Update the trigger arrays
		triggers[trig.triggertype][nword] |= (0x01 << col);
	}
	
	//Print output masks
	for(int i=0; i<5; i++)
	{
		printf("Trigger mask %20s = ", g_edgenames[i]);
		for(int j=0; j<16; j++)
		{
			int val = triggers[i][j];
			for(int k=0; k<8; k++)
			{
				printf("%c", (val & 0x80) ? '1' : '0');
				val <<= 1;
			}
		}
		printf("\n");
	}
	
	//Connect to the UART
}