#!/usr/bin/env bash

[[ "$PATH" != *"/usr/local/bin"* ]] && [[ -e "/usr/local/bin" ]] && export PATH=/usr/local/bin:"$PATH"
[[ "$PATH" != *"/usr/bin"* ]] && [[ -e "/usr/bin" ]] && export PATH=/usr/bin:"$PATH"
[[ "$PATH" != *"/bin:"* ]] && [[ -e "/bin" ]] && export PATH=/bin:"$PATH"

_compat_realpath() {
	[[ -e "$compat_realpath_bin" ]] && [[ "$compat_realpath_bin" != "" ]] && return 0
	
	#Workaround, Mac. See https://github.com/mirage335/ubiquitous_bash/issues/1 .
	export compat_realpath_bin=/opt/local/libexec/gnubin/realpath
	[[ -e "$compat_realpath_bin" ]] && [[ "$compat_realpath_bin" != "" ]] && return 0
	
	export compat_realpath_bin=$(type -p realpath)
	[[ -e "$compat_realpath_bin" ]] && [[ "$compat_realpath_bin" != "" ]] && return 0
	
	export compat_realpath_bin=/bin/realpath
	[[ -e "$compat_realpath_bin" ]] && [[ "$compat_realpath_bin" != "" ]] && return 0
	
	export compat_realpath_bin=/usr/bin/realpath
	[[ -e "$compat_realpath_bin" ]] && [[ "$compat_realpath_bin" != "" ]] && return 0
	
	# ATTENTION
	# Command "readlink -f" or text processing can be used as fallbacks to obtain absolute path
	# https://stackoverflow.com/questions/3572030/bash-script-absolute-path-with-osx
	
	export compat_realpath_bin=""
	return 1
}
_compat_realpath_run() {
	! _compat_realpath && return 1
	
	"$compat_realpath_bin" "$@"
}
_realpath_L() {
	if ! _compat_realpath_run -L . > /dev/null 2>&1
	then
		readlink -f "$@"
		return
	fi
	
	realpath -L "$@"
}
_realpath_L_s() {
	if ! _compat_realpath_run -L . > /dev/null 2>&1
	then
		readlink -f "$@"
		return
	fi
	
	realpath -L -s "$@"
}

#Critical prerequsites.
_getAbsolute_criticalDep() {
	#  ! type realpath > /dev/null 2>&1 && return 1
	! type readlink > /dev/null 2>&1 && return 1
	! type dirname > /dev/null 2>&1 && return 1
	! type basename > /dev/null 2>&1 && return 1
	
	#Known to succeed under BusyBox (OpenWRT), NetBSD, and common Linux variants. No known failure modes. Extra precaution.
	! readlink -f . > /dev/null 2>&1 && return 1
	
	! echo 'qwerty123.git' | grep '\.git$' > /dev/null 2>&1 && return 1
	echo 'qwerty1234git' | grep '\.git$' > /dev/null 2>&1 && return 1
	
	return 0
}
! _getAbsolute_criticalDep && exit 1

#Retrieves absolute path of current script, while maintaining symlinks, even when "./" would translate with "readlink -f" into something disregarding symlinked components in $PWD.
#However, will dereference symlinks IF the script location itself is a symlink. This is to allow symlinking to scripts to function normally.
#Suitable for allowing scripts to find other scripts they depend on. May look like an ugly hack, but it has proven reliable over the years.
_getScriptAbsoluteLocation() {
	if [[ "$0" == "-"* ]]
	then
		return 1
	fi
	
	local currentScriptLocation
	currentScriptLocation="$0"
	uname -a | grep -i cygwin > /dev/null 2>&1 && type _cygwin_translation_rootFileParameter > /dev/null 2>&1 && currentScriptLocation=$(_cygwin_translation_rootFileParameter)
	
	
	local absoluteLocation
	if [[ (-e $PWD\/$currentScriptLocation) && ($currentScriptLocation != "") ]] && [[ "$currentScriptLocation" != "/"* ]]
	then
		absoluteLocation="$PWD"\/"$currentScriptLocation"
		absoluteLocation=$(_realpath_L_s "$absoluteLocation")
	else
		absoluteLocation=$(_realpath_L "$currentScriptLocation")
	fi
	
	if [[ -h "$absoluteLocation" ]]
	then
		absoluteLocation=$(readlink -f "$absoluteLocation")
		absoluteLocation=$(_realpath_L "$absoluteLocation")
	fi
	echo $absoluteLocation
}
alias getScriptAbsoluteLocation=_getScriptAbsoluteLocation

#Retrieves absolute path of current script, while maintaining symlinks, even when "./" would translate with "readlink -f" into something disregarding symlinked components in $PWD.
#Suitable for allowing scripts to find other scripts they depend on.
_getScriptAbsoluteFolder() {
	if [[ "$0" == "-"* ]]
	then
		return 1
	fi
	
	dirname "$(_getScriptAbsoluteLocation)"
}
alias getScriptAbsoluteFolder=_getScriptAbsoluteFolder

#Retrieves absolute path of parameter, while maintaining symlinks, even when "./" would translate with "readlink -f" into something disregarding symlinked components in $PWD.
#Suitable for finding absolute paths, when it is desirable not to interfere with symlink specified folder structure.
_getAbsoluteLocation() {
	if [[ "$1" == "-"* ]]
	then
		return 1
	fi
	
	if [[ "$1" == "" ]]
	then
		echo
		return
	fi
	
	local absoluteLocation
	if [[ (-e $PWD\/$1) && ($1 != "") ]] && [[ "$1" != "/"* ]]
	then
		absoluteLocation="$PWD"\/"$1"
		absoluteLocation=$(_realpath_L_s "$absoluteLocation")
	else
		absoluteLocation=$(_realpath_L "$1")
	fi
	echo "$absoluteLocation"
}
alias getAbsoluteLocation=_getAbsoluteLocation

#Retrieves absolute path of parameter, while maintaining symlinks, even when "./" would translate with "readlink -f" into something disregarding symlinked components in $PWD.
#Suitable for finding absolute paths, when it is desirable not to interfere with symlink specified folder structure.
_getAbsoluteFolder() {
	if [[ "$1" == "-"* ]]
	then
		return 1
	fi
	
	local absoluteLocation=$(_getAbsoluteLocation "$1")
	dirname "$absoluteLocation"
}
alias getAbsoluteLocation=_getAbsoluteLocation

export scriptAbsoluteFolder=$(_getScriptAbsoluteFolder)

# ### END HEADER ^^^





KIAUH_SRCDIR="$scriptAbsoluteFolder"/kiauh

! [[ -e "$KIAUH_SRCDIR"/kiauh.sh ]] && return 1

for script in "${KIAUH_SRCDIR}/scripts/"*.sh; do . "${script}"; done
for script in "${KIAUH_SRCDIR}/scripts/ui/"*.sh; do . "${script}"; done

check_euid
init_logfile
set_globals


_install_mainsail_procedure() {
	### checking dependencies
	local dep=(wget nginx)
	dependency_check "${dep[@]}"
	### detect conflicting Haproxy and Apache2 installations
	detect_conflicting_packages

	status_msg "Initializing Mainsail installation ..."
	### first, we create a backup of the full klipper_config dir - safety first!
	#backup_klipper_config_dir

	### check for other enabled web interfaces
	unset SET_LISTEN_PORT
	detect_enabled_sites

	### check if another site already listens to port 80
	mainsail_port_check

	### download mainsail
	download_mainsail
	
	# ATTENTION: Non-interactive preferred instead.
	### ask user to install the recommended webinterface macros
	#install_mainsail_macros
	download_mainsail_macros

	### create /etc/nginx/conf.d/upstreams.conf
	set_upstream_nginx_cfg
	### create /etc/nginx/sites-available/<interface config>
	set_nginx_cfg "mainsail"
	### nginx on ubuntu 21 and above needs special permissions to access the files
	set_nginx_permissions

	### symlink nginx log
	symlink_webui_nginx_log "mainsail"

	### add mainsail to the update manager in moonraker.conf
	patch_mainsail_update_manager

	fetch_webui_ports #WIP

	### confirm message
	print_confirm "Mainsail has been set up!"
}

_install_crowsnest_procedure() {
	# Step 1: jump to home directory
	pushd "${HOME}" &> /dev/null || exit 1
	
	# Step 2: Clone crowsnest repo
	status_msg "Cloning 'crowsnest' repository ..."
	if [[ ! -d "${HOME}/crowsnest" && -z "$(ls -A "${HOME}/crowsnest" 2> /dev/null)" ]]; then
		clone_crowsnest
	else
		ok_msg "crowsnest repository already exists ..."
	fi
	
	# Step 3: Install dependencies
	dependency_check git make
	
	# Step 4: Check for Multi Instance
	check_multi_instance
	
	# Step 5: Launch crowsnest installer
	pushd "${HOME}/crowsnest" &> /dev/null || exit 1
	title_msg "Installer will prompt you for sudo password!"
	status_msg "Launching crowsnest installer ..."
	if ! sudo -n --preserve-env=CROWSNEST_UNATTENDED,CROWSNEST_ADD_CROWSNEST_MOONRAKER make install BASE_USER=$USER; then
		error_msg "Something went wrong! Please try again..."
		exit 1
	fi
	
	# Step 5: Leave directory (twice due two pushd)
	popd &> /dev/null || exit 1
	popd &> /dev/null || exit 1
}

echo '---------- klipper'
echo '------------------------------'
python_version=3
instance_count=1
instance_names+=("printer")
use_custom_names="false"
#start_klipper_setup
run_klipper_setup "${python_version}" "${instance_names[@]}"
# systemctl status klipper

echo '---------- moonraker'
echo '------------------------------'
moonraker_count=1
#moonraker_setup_dialog
moonraker_setup "$moonraker_count"


echo '---------- klipperscreen'
echo '------------------------------'
install_klipperscreen
# systemctl status KlipperScreen

echo '---------- mainsail'
echo '------------------------------'
#install_mainsail
_install_mainsail_procedure

echo '---------- crowsnest'
echo '------------------------------'
export CROWSNEST_UNATTENDED=1
export CROWSNEST_ADD_CROWSNEST_MOONRAKER=1
#install_crowsnest
_install_crowsnest_procedure


