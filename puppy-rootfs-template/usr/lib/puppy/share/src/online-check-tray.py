#!/usr/bin/python3
#monitor online internet connectivity

import requests
import gi
import subprocess
import time
import gc

gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')

from threading import Thread
from gi.repository import Gtk, GLib
from gi.repository import AppIndicator3 as AppIndicator

class OnlineIndicator:

    def __init__(self):
		
        self.check_url="http://www.msftncsi.com/ncsi.txt"
						
        self.last_status=""
        self.gc_tick=0
        self.status_tick=0

        self.indicator = AppIndicator.Indicator.new(
            "weather-overcast-symbolic",
            "weather-overcast-symbolic",
            AppIndicator.IndicatorCategory.APPLICATION_STATUS
        )
        
        self.indicator.set_title("Online Status")
        self.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE)
        self.indicator.set_menu(self.build_menu())
		
        #periodically check UFW status
        self.update_status()
        self.status_check_thread = Thread(target=self.start_periodic_check)
        self.status_check_thread.daemon = True
        self.status_check_thread.start()

    def build_menu(self):
		
        menu = Gtk.Menu()

        #Add quit option
        quit_item = Gtk.MenuItem(label="Quit")
        quit_item.connect('activate', self.quit)
        menu.append(quit_item)

        menu.show_all()
        
        return menu

    def quit(self, source):
		
        Gtk.main_quit()

    def get_online_status(self):
		
      try:
        response = requests.get(self.check_url, timeout=5)        
        return "online"       
      except requests.RequestException:
        return "offline"

    def update_status(self):
		
        status = self.get_online_status()
        
        if self.last_status != status:
          
          self.last_status=status
          
          if status == "online":
            self.indicator.set_icon_full("weather-overcast-symbolic","Connnected to the internet")
          else:
            self.indicator.set_icon_full("weather-severe-alert-symbolic", "No internet connection")

    def start_periodic_check(self):

        while True:
			
            self.status_tick+=1
			
            if self.status_tick==3:
               GLib.idle_add(self.update_status)
               self.status_tick=0
               
            self.gc_tick+=1
            
            if self.gc_tick==30:
               collected=gc.collect()
               self.gc_tick=0				
            
            time.sleep(10)

if __name__ == "__main__":
	
    indicator = OnlineIndicator()
    Gtk.main()
