#!/bin/bash

#OpenXInstaller
#Installer script that installs the content from XCOM:UFO, XCOM:TFTD, and probably others.
#Created by Jane Fenech, Jan 15, 2016

GAMETITLE="XCom:TFTD"
XCOMDATADIRS_REQ="GEODATA GEOGRAPH MAPS ROUTES SOUND TERRAIN UFOGRAPH UNITS";
XCOMDATADIRS_OPT="ANIMS FLOP_INT";
DEFAULTINSTALLDIR="openxcom/TFTD";

#TODO:Fix the root branch to get the permissions from the correct place if the user specifies a specific directory. See permission setter below.

#Determine the Data Path
if [ "$(id -u)" == "0" ]; then
	DATAPATH="/usr/local/share/";	#Running as root
else
	DATAPATH="${HOME}/.local/share/";	#As Regular user
fi

function abspath() {
    # generate absolute path from relative path
    # pre    : path must exist
    # $1     : relative filename
    # return : absolute path
    if [ -d "$1" ]; then
        # dir
        echo "$(cd "$1"; pwd)"
    elif [ -f "$1" ]; then
        # file
        if [[ $1 == */* ]]; then
            echo "$(cd "${1%/*}"; pwd)/${1##*/}"
        else
            echo "$(pwd)/$1"
        fi
    fi
}

DIRLIST_TO_COPY="$XCOMDATADIRS_REQ";
INSTALLATIONDIR="${DATAPATH}${DEFAULTINSTALLDIR}";
failflag=0

#First, fetch the first command arg. It overrides the default target :)
if [ $# -gt 0 ]; then
	INSTALLATIONDIR="$1";
fi

#echo $INSTALLATIONDIR
#exit
echo "$GAMETITLE -> OpenXcom Original Data Install";

#Check to make sure the required directories exist.
for i in $XCOMDATADIRS_REQ;
do
	if [ ! -d "$i" ]; then
		echo "$i directory does not exist at this location.";
		failflag=true;
	fi  
done

if [ $failflag == true ]; then 
	echo "Missing required content directories. Aborting.";
	exit 1;		#One of them was missing. Exit with code 1.
fi

#Check to make sure the optional directories exist.
for i in $XCOMDATADIRS_OPT;
do
	if [ -d "$i" ]; then
		echo "Optional $i directory was found.";
		DIRLIST_TO_COPY="$DIRLIST_TO_COPY $i";
	fi
done

echo -e "\nAttempting to install to $INSTALLATIONDIR";

#Try to create the directory if it doesn't already exist.
mkdir -p "$INSTALLATIONDIR" 2> /dev/null;

#Check that the target directory exists, if it doesn't, kill out with an error. If it does, copy the source to it
if [ ! -d "$INSTALLATIONDIR" ]; then 
	echo -e "Could not create target directory: $INSTALLATIONDIR\nAborting. (Do you need root permissions to install here?)";
	exit 2;
fi

#One final check. It exists, so we better make sure we can write to the target directory
if [ ! -w "$INSTALLATIONDIR" ]; then
	echo -e "Target directory ($INSTALLATIONDIR) exists,\n  but we don't have permissions to write to it.\nAborting. (Do you need root permissions to install here?)";
	exit 3;
fi

echo "Copying game data."
cp -a $DIRLIST_TO_COPY "$INSTALLATIONDIR";

#Now that we've copied the files, let's jump to that directory.
pushd "$INSTALLATIONDIR" > /dev/null;



#Fix the permissions. First set the directory permissions,
# then fix the file permissions by removing the x permission.

#If running with sudo, we're probably doing a system install.
echo "Setting permissions and ownership"

#TODO:Fix the root branch to get the permissions from the correct place if the user specifies a specific directory.
if [ "$(id -u)" == "0" ]; then

	#Set the owner to root, if we invoked the script with sudo,
	# and fix the permissions to whatever the parent dir is. 
	# Presumably, we're installing for all users, so they should be 
	# allowed to read/access files & directories in accordance with the system policies.
	
	PERMS="`stat -c %a $DATAPATH`";
	
	chmod -R $PERMS $DIRLIST_TO_COPY;
	find $DIRLIST_TO_COPY -type f -exec chmod a-x {} +;
	chmod $PERMS "$INSTALLATIONDIR";
	chown -hR `stat -c %g $DATAPATH`:`stat -c %u $DATAPATH` $DIRLIST_TO_COPY;

else

	#This is the more common case. We're doing a user directory install. Set permissions based on umask.
	
	chmod -R $(umask -S) $DIRLIST_TO_COPY;					#Set permissions based on umask
	find $DIRLIST_TO_COPY -type f -exec chmod a-x {} +;		#Remove executable permissions from regular files.
	#find $DIRLIST_TO_COPY -type f -exec chmod 644 {} +		#rw-r--r--
	#find $DIRLIST_TO_COPY -type d -exec chmod 755 {} +		#rwxr-xr-x
fi



popd > /dev/null;

echo "Done. Game data installed to $(abspath "$INSTALLATIONDIR")".
