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
	::msgcat::mcmset {} {
		download_no_valid_build         {Sorry, there doesn't exist a build for %2$s. Please compile it yourself and share with others, if possible.}
		openttd_not_running             {Sorry. Can not issue command. OpenTTD Server is not running.}
	}
}
		
namespace eval ::ap::plugins::Openttdcoop {
	namespace path   ::ap::extends
	namespace import ::ap::extends::utils::*
	
	var openttd_dl_url    {http://binaries.openttd.org/nightlies/trunk/%1$s/openttd-trunk-%1$s-%2$s.%3$s}
	var openttd_server_ip {ps.openttdcoop.org}
	
	# init
	proc init {} {
		variable ns [namespace current]
		
		# irc + console commands
		cmd::register all download         ${ns}::download
		cmd::register all dl               ${ns}::download
		cmd::register all ip               ${ns}::ip
		cmd::register all server_status    ${ns}::server_status
		cmd::register all time             ${ns}::time
		cmd::register all uptime           ${ns}::uptime
		
	}
	
	proc checkOpenTTD {} {
		if {![::ap::apps::OpenTTD::isRunning]} {
			say [who] [::msgcat::mc openttd_not_running]
			return -level 2
		}
	}
	
	proc download {} {
		# usage: %plugin% %cmd% <os version> [<openttd revision>]
		# provide direct download links to the currently hosted openttd version
		var openttd_dl_url
		
		if {[info exists ::ap::apps::OpenTTD::info(ottd_version)]} {
			if {$::ap::apps::OpenTTD::info(ottd_version) != {unknown}} {
				set openttd_version $::ap::apps::OpenTTD::info(ottd_version)
			} else {
				say [who] "Sorry. There is no version of OpenTTD defined."
				return
			}
		} elseif {[numArgs] <= 1} {
			say [who] "Sorry. There is no version of OpenTTD defined."
			return
		} else {
			set openttd_version [getArg 1]
		}
		
		array set options {}
		# define possible download arguments in an array
		set options(win64)     {windows-win64           zip}
		set options(win32)     {windows-win32           zip}
		set options(win9x)     {windows-win9x           zip}
		set options(lin)       {linux-generic-i686      tar.bz2}
		set options(lin64)     {linux-generic-amd64     tar.bz2}
		set options(osx)       {macosx-universal        zip}
		
		set options(autoupdate) {http://www.openttdcoop.org/winupdater}
		set options(autostart)  {http://wiki.openttdcoop.org/Autostart}
		
		# older/outdated options
		# set options(deb.etch)  [format $url   $openttd_version linux-debian-etch-i386  deb]
		# set options(deb.lenny) [format $url   $openttd_version linux-debian-lenny-i386 deb]
		# set options(morphos)   [format $sorry $openttd_version morphos                 lha]
		# set options(sun)       [format $sorry $openttd_version sunos                   tar.bz2]
		# set options(source)    [format $url   $openttd_version source                  zip]
		
		# do the rest of the usage handling etc, based on the array
		if {[numArgs] == 0} {
			say [who] [::ap::func::listElements [array names options]]
		} else {
			if {[array names options -exact [getArg 0]] != {}} {
				if {[llength $options([getArg 0])] == 1} {
					say [who] $options([getArg 0])
				} else {
					say [who] [format $openttd_dl_url $openttd_version [lindex $options([getArg 0]) 0] [lindex $options([getArg 0]) 1]]
				}
			} else {
				say [who] "Sorry. Unknown option \"[getArg 0]\"."
			}
		}
	}
	
	proc ip {} {
		# usage: %plugin% %cmd%
		# returns the IP address of the OpenTTD Server
		checkOpenTTD
		var openttd_server_ip
		say [who] "${openttd_server_ip}:[::ap::apps::OpenTTD::settings::get network.server_port]"
	}
	
	proc server_status {} {
		# usage: %plugin% %cmd%
		# shows the status of the server
		checkPermission operator
		
		catch { exec uptime } msg
		say [who] $msg
		
		catch { exec top -bcn1 -U openttd | grep Cpu } msg
		say [who] $msg
		
		catch { exec top -bcn1 -U openttd | grep ./openttd } msg
		say [who] $msg
	}
	
	proc time {} {
		# usage: %plugin% %cmd%
		# returns the time of Europe and United States
		say [who] "EU: [clock format [clock seconds] -format {%R (%Z)}] / US: [clock format [clock seconds] -timezone :America/New_York -format {%R (%Z)}]"
	}
	
	proc uptime {} {
		# usage: %plugin% %cmd%
		# shows the uptime of the server and load averages
		set cmd "uptime2"
		if {[auto_execok $cmd] == {}} {
			say [who] "Error.  '$cmd' not found on this system"
			pluginErr {"Error.  '$cmd' not found on this system"}
		} 
		catch { exec $cmd } msg
		say [who] $msg
	}
	
}