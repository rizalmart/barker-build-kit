#!/usr/bin/python3
#monitor ufw status

import gi
import subprocess
import time
import gc

gi.require_version('Gtk', '3.0')
gi.require_version('AppIndicator3', '0.1')

from threading import Thread
from gi.repository import Gtk, GLib
from gi.repository import AppIndicator3 as AppIndicator

class UfwIndicator:

    def __init__(self):
		
        result = subprocess.run(['which', 'gufw'], capture_output=True, text=True)
        retcode=result.returncode
		
        if retcode==0:
          self.active_icon_name="gufw"
        else:
          self.active_icon_name="security-high-symbolic"			
		
        self.indicator = AppIndicator.Indicator.new(
            self.active_icon_name,
            "security-high-symbolic",
            AppIndicator.IndicatorCategory.APPLICATION_STATUS
        )
        
        self.indicator.set_title("Firewall Status")
        self.indicator.set_status(AppIndicator.IndicatorStatus.ACTIVE)
        self.indicator.set_menu(self.build_menu())
		
        self.last_status=""
        self.gc_tick=0
        self.status_tick=0
		
        #periodically check UFW status
        self.update_status()
        self.status_check_thread = Thread(target=self.start_periodic_check)
        self.status_check_thread.daemon = True
        self.status_check_thread.start()

    def build_menu(self):
		
        menu = Gtk.Menu()

        result = subprocess.run(['which', 'gufw'], capture_output=True, text=True)
        retcode=result.returncode
		
        if retcode==0:
           #Add "Open Gufw" option
           gufw_item = Gtk.MenuItem(label="Open Gufw")
           gufw_item.connect('activate', self.launch_gufw)
           menu.append(gufw_item)

        #Add quit option
        quit_item = Gtk.MenuItem(label="Quit")
        quit_item.connect('activate', self.quit)
        menu.append(quit_item)

        menu.show_all()
        
        return menu

    def launch_gufw(self, source):
		
        subprocess.Popen(["gufw"])

    def quit(self, source):
		
        Gtk.main_quit()

    def get_ufw_status(self):
		
        try:
            status = subprocess.check_output(["ufw", "status"]).decode("utf-8")
            if ": active" in status.lower():
                return "active"
            else:
                return "inactive"
        except subprocess.CalledProcessError:
            return "unknown"

    def update_status(self):
		
        status = self.get_ufw_status()
        
        if self.last_status != status:
          
          self.last_status=status
          
          if status == "active":
             self.indicator.set_icon_full(self.active_icon_name,"UFW: Active")
          elif status == "inactive":
             self.indicator.set_icon_full("security-low-symbolic", "UFW: Inactive")
          else:
            self.indicator.set_icon_full("network-no-route-symbolic", "UFW: Status Unknown")

    def start_periodic_check(self):

        while True:
			
            self.status_tick+=1
			
            if self.status_tick==3:
               GLib.idle_add(self.update_status)
               self.status_tick=0
               
            self.gc_tick+=1
            
            if self.gc_tick==60:
               collected=gc.collect()
               self.gc_tick=0				
            
            time.sleep(10)

if __name__ == "__main__":
	
    indicator = UfwIndicator()
    Gtk.main()
