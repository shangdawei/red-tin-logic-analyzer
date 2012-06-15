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

MainWindow::MainWindow()
{
	//Initial setup
	set_title("RED TIN Logic Analyzer");
	set_reallocate_redraws(true);
	set_default_size(1024, 768);

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
		m_rootSplitter.add2(m_rightpanel);
			m_rightpanel.add(m_rightbox);
		m_rootSplitter.set_position(300);
		
	//Turn off scrollbars if not necessary
	m_leftpanel.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC);
	m_rightpanel.set_policy(Gtk::POLICY_AUTOMATIC, Gtk::POLICY_AUTOMATIC);
	
	//m_vbox.pack_start(*m_pMenu, Gtk::PACK_SHRINK);
	//m_vbox.pack_end(m_view);
				
	//Set up viewport
	show_all();
}
