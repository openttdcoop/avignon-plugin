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

# We need the AvignonApplicationOpenTTD Plugin
package require AvignonApplicationOpenTTD

namespace eval ::ap::plugins::Openttdcoop {
	::msgcat::mcmset {} {
		critical_openttd_not_found      {Application OpenTTD was not found at '%s' forcing unload of [openttdcoop]}
		
		openttd_not_running             {Sorry. Can not issue command. OpenTTD Server is not running.}
		openttd_version_not_defined     {Sorry. There is no version of OpenTTD defined.}
		
		cmd_error                       {Sorry. Can't issue screenshot cmd}
		screenshot_error_path           {The directory '%s' does not exists.}
		screenshot_msg                  {*** %1$s made a screenshot at %2$s: %3$s/%2$s.png}
		cmd_date_msg                    {Current game date: %s}
		cmd_trains_msg                  {*** %s has set max_trains to %s}
		
		download_no_valid_build         {Sorry, there doesn't exist a build for %2$s. Please compile it yourself and share with others, if possible.}
		grfpack_version_file_not_found  {Error. The file containing the grfpack version was not found at '%s'.}
		grfpack_version_unknown         {Sorry. The version of GrfPack used is unknown.}
		
		cb_password_error               {The directory '%s' does not exists. Can not write passsword file.}
		cmd_uptime_error                {Error. Command '%s' not found on this system.}
	}
}
		
namespace eval ::ap::plugins::Openttdcoop {
	namespace path   ::ap::extends
	namespace import ::ap::extends::utils::*
	
	# set some default variables
	var ottd_ns     {::ap::apps::OpenTTD}
	var grf_version
	
	# set the default configuration
	var default_conf [dict create {*}{
		{identifier}            {SERVER}
		{short}                 {SERVER}
		{pw.key}                {PWKEY}
		{pw.path}               {./PATH/TO/DIR}
		{irc_bot}               {BOT}
		{openttd_server_ip}     {127.0.0.1}
		{grf_version_file_path} {./PATH/TO/FILE/VERSION}
		{openttd_dl_url}        {http://binaries.openttd.org/nightlies/trunk/%1$s/openttd-trunk-%1$s-%2$s.%3$s}
		{screenshot_path}       {./PATH/TO/DIR}
		{screenshot_uri}        {http://www.domain.com/webcam}
	}]
	
	################################
	# Initialisation of the plugin #
	################################
	proc init {} {
		variable ns [namespace current]
		variable default_conf
		variable ottd_ns
		
		# OpenTTD Plugin must be loaded, else this plugin doesn't make sense
		if {![namespace exists $ottd_ns]} {
			return -code error [::msgcat::mc critical_openttd_not_found $ottd_ns]
		}
		
		# set default configuration
		dict for {option value} $default_conf {
			if {![::ap::config::exists openttdcoop $option]} {
				::ap::config::set openttdcoop $option $value
			}
		}
		
		# irc + console commands
		cmd::register all date             ${ns}::cmd-date
		cmd::register all download         ${ns}::cmd-download
		cmd::register all dl               ${ns}::cmd-download
		cmd::register all grf              ${ns}::cmd-grf
		cmd::register all ip               ${ns}::cmd-ip
		cmd::register all info             ${ns}::cmd-info
		cmd::register all screenshot       ${ns}::cmd-screenshot
		cmd::register all server_status    ${ns}::cmd-server_status
		cmd::register all setdef           ${ns}::cmd-setdef
		cmd::register all time             ${ns}::cmd-time
		cmd::register all trains           ${ns}::cmd-trains
		cmd::register all transfer         ${ns}::cmd-transfer
		cmd::register all tunnels          ${ns}::cmd-tunnels
		cmd::register all uptime           ${ns}::cmd-uptime
		
		# register callbacks
		cb::register CB_OTTD_ON_PW_CHANGE  ${ns}::cb-password_change
		
		# determine the GrfPack version
		getGrfVersion
	}
	
	###############################################
	# Useful functions required often in commands #
	###############################################
	proc checkOpenTTD {} {
		if {![::ap::apps::OpenTTD::isRunning]} {
			say [who] [::msgcat::mc openttd_not_running]
			return -level 2
		}
	}
	
	proc getGrfVersion {} {
		if {![file exists [::ap::config::get openttdcoop grf_version_file_path]]} {
			::ap::log plugin error [::msgcat::mc grfpack_version_file_not_found [::ap::config::get openttdcoop grf_version_file_path]]
			var grf_version 0
			return
		}
		set grfVersionFile [open ./data/ottdc_grfpack/VERSION r]
		gets $grfVersionFile grfVersion
		close $grfVersionFile
		var grf_version $grfVersion
	}
	
	###################################################
	# All Commands of this plugin (with prefix 'cmd-' #
	###################################################
	proc cmd-date {} {
		# Usage: %plugin% %cmd%
		# Returns the date of the current game
		checkOpenTTD
		var ottd_ns
		
		set result [${ottd_ns}::utils::sendConsoleCmd "getdate"]
		if {[lindex $result 0]} {
			set date [join [lindex $result 1]]
			scan $date "Date: %d-%d-%d" day month year
			
			say [who] [::msgcat::mc cmd_date_msg [clock format [clock scan "$month/$day/2000"] -format "%e %b $year"]]
		}
	}
	
	proc cmd-download {} {
		# Usage: %plugin% %cmd% <os version> [<openttd revision>]
		# Provide direct download links to the currently hosted openttd version.
		# Omit all parameters to list all download options.
		
		array set options {}
		# define possible download arguments in an array
		set options(win64)     {windows-win64           zip}
		set options(win32)     {windows-win32           zip}
		set options(win9x)     {windows-win9x           zip}
		set options(lin)       {linux-generic-i686      tar.bz2}
		set options(lin64)     {linux-generic-amd64     tar.bz2}
		set options(source)    {source                  zip}
		
		set options(autoupdate) {http://www.openttdcoop.org/winupdater}
		set options(autostart)  {http://wiki.openttdcoop.org/Autostart}
		
		# older/outdated options
		# set options(deb.etch)  [format $url   $openttd_version linux-debian-etch-i386  deb]
		# set options(deb.lenny) [format $url   $openttd_version linux-debian-lenny-i386 deb]
		# set options(morphos)   [format $sorry $openttd_version morphos                 lha]
		# set options(sun)       [format $sorry $openttd_version sunos                   tar.bz2]
		# set options(osx)       {macosx-universal        zip}
		
		switch [numArgs] {
			0 {
				say [who] [::ap::func::listElements [array names options]]
				return
			}
			1 {
				if {![info exists ::ap::apps::OpenTTD::info(ottd_version)]} {
					say [who] [::msgcat::mc openttd_version_not_defined]
					return
				} elseif {$::ap::apps::OpenTTD::info(ottd_version) == {unknown}} {
					say [who] [::msgcat::mc openttd_version_not_defined]
					return
				}
				set openttd_version $::ap::apps::OpenTTD::info(ottd_version)
			}
			2 {
				if {[string match {r[0-9]*} [getArg 1]]} {
					set openttd_version [getArg 1]
				} else {
					say [who] [::msgcat::mc openttd_version_not_defined]
					return
				}
			}
		}
		
		# do the rest of the usage handling etc, based on the array
		if {[array names options -exact [getArg 0]] != {}} {
			if {[llength $options([getArg 0])] == 1} {
				say [who] $options([getArg 0])
			} else {
				say [who] [format [::ap::config::get openttdcoop openttd_dl_url] $openttd_version [lindex $options([getArg 0]) 0] [lindex $options([getArg 0]) 1]]
			}
		} else {
			say [who] "Sorry. Unknown option \"[getArg 0]\"."
		}
	}
	
	proc cmd-grf {} {
		# usage: %plugin% %cmd%
		# returns the version of #openttdcoop GrfPack used
		var grf_version
		if {$grf_version == 0} {
			say [who] [::msgcat::mc grfpack_version_unknown]
		} else {
			say [who] [format {http://www.openttdcoop.org/wiki/GRF (Version %1$s)} $grf_version]
		}
		
	}
	
	proc cmd-info {} {
		checkOpenTTD
		var ottd_ns
		
		set result [${ottd_ns}::utils::sendConsoleCmd "companies"]
		if {[lindex $result 0]} {
			set data [lindex $result 1]
			if {[llength $data] > 1} {
				foreach line  {
					append output $line \n
				}
			} else {
				set output [lindex $data 0]
			}
			say [who] $output
		} else {
			pluginErr
		}
	}
	
	proc cmd-ip {} {
		# usage: %plugin% %cmd%
		# returns the IP address of the OpenTTD Server
		checkOpenTTD
		say [who] "[::ap::config::get openttdcoop openttd_server_ip]:[::ap::apps::OpenTTD::settings::get network.server_port]"
	}
	
	proc cmd-screenshot {} {
		var ottd_ns
		checkOpenTTD
		
		if {![file isdirectory [::ap::config::get openttdcoop screenshot_path]]} {
			say [who] [::msgcat::mc cmd_error]
			pluginErr [::msgcat::mc screenshot_error_path [::ap::config::get openttdcoop screenshot_path]]
		}
		
		if {![info exists [expr $${ottd_ns}::info(last_action_location)]] || [expr $${ottd_ns}::info(last_action_location)] != [expr $${ottd_ns}::info(last_screen_location)]} {
			# scrollto location
			${ottd_ns}::send "scrollto 0x[expr $${ottd_ns}::info(last_action_location)]"
			# update the pointer
			set ${ottd_ns}::info(last_screen_location) [expr $${ottd_ns}::info(last_action_location)]
			# and create new screenshot
			${ottd_ns}::send "screenshot no_con screenshot"
			
			# the neccessary directories
			set latest_path [file normalize "[::ap::config::get openttdcoop screenshot_path]/[expr $${ottd_ns}::info(last_action_location)].png"]
			set link_path   [file normalize "[::ap::config::get openttdcoop screenshot_path]/screenshot.png"]
			
			# copy file to webdir and create symlink
			file rename -force "[file dirname [::ap::config::get openttd app.path]]/screenshot.png" $latest_path
			exec ln -fs $latest_path $link_path
			
			# return the screenshot url
			${ottd_ns}::msg::announce [::msgcat::mc screenshot_msg [who] [expr $${ottd_ns}::info(last_action_location)] [::ap::config::get openttdcoop screenshot_uri]]
		}
	}
	
	proc cmd-server_status {} {
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
	
	proc cmd-setdef {} {
		# usage: %plugin% %cmd%
		# sets default values for the server
		checkPermission operator
		checkOpenTTD
		
		var ottd_ns
		${ottd_ns}::settings::set pf.wait_for_pbs_path 255
		${ottd_ns}::settings::set pf.wait_twoway_signal 255
		${ottd_ns}::settings::set pf.wait_oneway_signal 255
		${ottd_ns}::settings::set pf.path_backoff_interval 1
		${ottd_ns}::settings::set train_acceleration_model 1
		${ottd_ns}::settings::set extra_dynamite 1
		${ottd_ns}::settings::set mod_road_rebuild 1
		${ottd_ns}::settings::set forbid_90_deg 1
		${ottd_ns}::settings::set ai_in_multiplayer 0
		${ottd_ns}::settings::set order.no_servicing_if_no_breakdowns 1
		if {[src] == console} {
			${ottd_ns}::msg::announce "*** Disabled wait_for_pbs_path, wait_twoway_signal, wait_oneway_signal, ai_in_multiplayer enabled no_servicing_if_no_breakdowns, extra_dynamite, mod_road_rebuild, forbid_90_deg and set path_backoff_interval to 1, train_acceleration_model to 1"
		} else {
			${ottd_ns}::msg::announce "*** [who] has disabled wait_for_pbs_path, wait_twoway_signal, wait_oneway_signal, ai_in_multiplayer enabled no_servicing_if_no_breakdowns, extra_dynamite, mod_road_rebuild, forbid_90_deg and set path_backoff_interval to 1, train_acceleration_model to 1"
		}
	}
	
	proc cmd-time {} {
		# usage: %plugin% %cmd%
		# returns the time of Europe and United States
		say [who] "EU: [clock format [clock seconds] -format {%R (%Z)}] / US: [clock format [clock seconds] -timezone :America/New_York -format {%R (%Z)}]"
	}
	
	proc cmd-trains {} {
		# usage: %plugin% %cmd% <integer>
		# Set the limit of maximum trains allowed in the game
		checkPermission operator
		checkOpenTTD
		var ottd_ns
		
		if {[numArgs] == 1 && [string is integer [getArg 1]]} {
			${ottd_ns}::settings::set max_trains [getArg 0]
			${ottd_ns}::msg::announce [::msgcat::mc cmd_trains_msg [who] [getArg 0]]
		} else {
			pluginHelp
		}
	}
	
	proc cmd-transfer {} {
		# usage: %plugin% %cmd% <game number> [-f] <savegame>
		# transfer the savegame to the webserver for archiving the game 
		checkPermission operator
		
		if {[numArgs] == 2} {
			catch { exec ./extensions/plugins/Openttdcoop/transfer.sh [::ap::config::get openttdcoop identifier] [getArg 0] /home/openttd/website/public/save/[getArg 1] } data
		} elseif {[numArgs] == 3} {
				catch { exec ./extensions/plugins/Openttdcoop/transfer.sh [::ap::config::get openttdcoop identifier] [getArg 0] [getArg 1] /home/openttd/website/public/save/[getArg 2] } data
		} else {
			say [who] [pluginHelp]
			return
		}
		
		say [who] $data
	}
	
	proc cmd-tunnels {} {
		# usage: %plugin% %cmd% <trainlength> <gap>
		# Returns the number of tunnels / bridges required for a longer signal gape /split
		# Formula: <number of tunnels/bridges> = (<gap>+<trainlength>-2)/(<trainlength>+2)
		if {[numArgs] == 2 && [string is integer [getArg 0]] && [string is integer [getArg 1]]} {
			set train [getArg 0]
			set gap [getArg 1]
			set a1 [expr ( int(ceil(( $gap + $train - 2 ) / ( $train. + 2 ))))]
			say [who] "You need [expr { $a1<2?2:$a1 } ] tunnels/bridges for trainlength $train and gap $gap."
		} else {
			pluginHelp
		}
	}
	
	proc cmd-uptime {} {
		# usage: %plugin% %cmd%
		# shows the uptime of the server and load averages
		set cmd "uptime"
		if {[auto_execok $cmd] == {}} {
			say [who] [::msgcat::mc cmd_uptime_error $cmd]
			return
		} 
		catch { exec $cmd } msg
		say [who] $msg
	}
	
	###################################################
	# All Callbacks of this plugin (with prefix 'cb-' #
	###################################################
	proc cb-password_change {} {
		if {[file isdirectory [::ap::config::get openttdcoop pw.path]]} {
			exec echo [::ap::apps::OpenTTD::settings::get "network.server_password"] > [::ap::config::get openttdcoop pw.path]/[::ap::config::get openttdcoop pw.key]
		} else {
			::ap::log plugin error [::msgcat::mc cb_password_error [::ap::config::get openttdcoop pw.path]]
		}
	}
	
}