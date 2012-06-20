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

#ifndef MainWindow_h
#define MainWindow_h
#include <gtkmm/actiongroup.h>
#include <gtkmm/box.h>
#include <gtkmm/combobox.h>
#include <gtkmm/comboboxtext.h>
#include <gtkmm/entry.h>
#include <gtkmm/frame.h>
#include <gtkmm/liststore.h>
#include <gtkmm/listviewtext.h>
#include <gtkmm/main.h>
#include <gtkmm/paned.h>
#include <gtkmm/scrolledwindow.h>
#include <gtkmm/widget.h>
#include <gtkmm/window.h>

#include <vector>
#include <map>

class Signal
{
public:
	int width;
	std::string name;
	
	Signal(int w, std::string n)
	: width(w)
	, name(n)
	{
	}
	
	//not used except by OnCapture
	int highbit;
	int lowbit;
};

class Trigger
{
public:
	enum TriggerTypes
	{
		TRIGGER_TYPE_LOW,
		TRIGGER_TYPE_HIGH,
		TRIGGER_TYPE_FALLING,
		TRIGGER_TYPE_RISING,
		TRIGGER_TYPE_CHANGE
	};
	
	std::string signalname;		//needed because IDs change when we delete a signal
	int nbit;
	int triggertype;
	
	Trigger(std::string s, int b, int t)
	: signalname(s)
	, nbit(b)
	, triggertype(t)
	{
	}
};

class MainWindow : public Gtk::Window
{
public:
	MainWindow();
	~MainWindow();
	
	////////////////////////////////////////////////////////////////////////////////////////////////
	//UI accessors
	
protected:

	//Initialization
	void CreateWidgets();
	
	Gtk::HPaned m_rootSplitter;
		Gtk::ScrolledWindow m_leftpanel;
			Gtk::VBox m_leftbox;
				Gtk::Frame m_editframe;
					Gtk::HBox m_editpanel;
						Gtk::ComboBoxText m_signalwidthbox;
						Gtk::Entry m_signalnameentry;
						Gtk::Button m_signalupdatebutton;
				Gtk::HBox m_leftbuttons;
					Gtk::Button m_editbutton;
					Gtk::Button m_deletebutton;
					Gtk::Button m_sigupbutton;
					Gtk::Button m_sigdownbutton;
				Gtk::ListViewText m_signallist;
		Gtk::ScrolledWindow m_rightpanel;
			Gtk::VBox m_rightbox;
				Gtk::Frame m_triggereditframe;
					Gtk::HBox m_triggereditpanel;
						Gtk::ComboBoxText m_triggersignalbox;
						Gtk::ComboBoxText m_triggerbitbox;
						Gtk::ComboBoxText m_triggeredgebox;
						Gtk::Button m_triggerupdatebutton;
				Gtk::Frame m_samplefreqframe;
					Gtk::HBox m_samplefreqpanel;
						Gtk::Entry m_samplefreqbox;
				Gtk::VBox m_triggerpanel;
					Gtk::ListViewText m_triggerlist;
					Gtk::HBox m_triggereditbuttons;
						Gtk::Button m_triggereditbutton;
						Gtk::Button m_triggerdeletebutton;
						Gtk::Button m_capturebutton;

	bool m_bEditingSignal;
	void OnSignalUpdate();
	void OnSignalDelete();
	void OnTriggerSignalChanged();
	void OnTriggerUpdate();
	void OnTriggerDelete();
	
	void OnCapture();
	
	std::vector<Signal> m_signals;	
	std::vector<Trigger> m_triggers;
	
	int write_looped(int fd, unsigned char* buf, int count);
	int read_looped(int fd, unsigned char* buf, int count);
	
	std::string signal_to_binary(unsigned char* data, int lowbit, int highbit);
};

#endif
