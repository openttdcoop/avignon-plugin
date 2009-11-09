# Copyright 2009 codecubes.org - All rights reserved.
# Autopilot (Avignon) for use on OpenTTD dedicated server console.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

# Plugin to handle Debugging
package provide AvignonPluginOpenttdcoop 0.1

namespace eval ::ap::plugins::Openttdcoop {
	namespace path   ::ap::extends
	namespace import ::ap::extends::utils::*
	
	# init
	proc init {} {
		variable ns [namespace current]
		
		# irc commands
		cmd::register irc     download  ${ns}::download
		
		# console commands
		cmd::register console download  ${ns}::download
		
	}
	
	
	proc download {} {
		# provide direct download links to the currently hosted openttd version
		# + working test to detect nightly builds
		# file: autopilot/scripts/irc/download.tcl
		
		set nightly false
		# url style: http://binaries.openttd.org/nightlies/trunk/r14316/openttd-trunk-r14316-linux-generic-i686.tar.bz2
		set url   {http://binaries.openttd.org/nightlies/trunk/%1$s/openttd-trunk-%1$s-%2$s.%3$s}
		set sorry {Sorry, there exists no build for %2$s. Please compile it yoursel and if possible, share with others.}
		
		array set options {}
		
		# define possible download arguments in an array
		set options(win64)     [format $url   $::ap::apps::OpenTTD::info(ottd_version) windows-win64           zip]
		set options(win32)     [format $url   $::ap::apps::OpenTTD::info(ottd_version) windows-win32           zip]
		set options(win9x)     [format $url   $::ap::apps::OpenTTD::info(ottd_version) windows-win9x           zip]
		set options(lin)       [format $url   $::ap::apps::OpenTTD::info(ottd_version) linux-generic-i686      tar.bz2]
		set options(lin64)     [format $url   $::ap::apps::OpenTTD::info(ottd_version) linux-generic-amd64     tar.bz2]
		# set options(deb.etch)  [format $url   $::ap::apps::OpenTTD::info(ottd_version) linux-debian-etch-i386  deb]
		# set options(deb.lenny) [format $url   $::ap::apps::OpenTTD::info(ottd_version) linux-debian-lenny-i386 deb]
		set options(osx)       [format $url   $::ap::apps::OpenTTD::info(ottd_version) macosx-universal        zip]
		# set options(morphos)   [format $sorry $::ap::apps::OpenTTD::info(ottd_version) morphos                 lha]
		# set options(sun)       [format $sorry $::ap::apps::OpenTTD::info(ottd_version) sunos                   tar.bz2]
		# set options(source)    [format $url   $::ap::apps::OpenTTD::info(ottd_version) source                  zip]
		
		set options(autoupdate) {http://www.openttdcoop.org/winupdater}
		set options(autostart)  {http://www.openttdcoop.org/wiki/Autostart}
		
		# do the rest of the usage handling etc, based on the array
		if {[numArgs] == 1} {
			say [who] "[join [lsort [array names options]] {|}]"
		} else {
			if {[array names options -exact [getArg 1]] != {}} {
				say [who] $options([getArg 1])
			} else {
				say [who] "unknown option \"[getArg 1]\""
			}
		}
		
		
	}
	
	
	
		
}