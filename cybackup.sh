# ! bin/bash
# cyBackup by cytec
#	Version 2.0
#	
#	Complete rewrite of cyBackup, uses optargs for better usability and Cydia > 1 support for repo restorage
#	also added several folders that can be included in the local backup, with runtime triggers 
#
#
#   rsync is needed rsync -R for file copy...
#

# Dropbox uploading done by https://github.com/andreafabrizi/Dropbox-Uploader thx for that script
# python dropbox https://github.com/jncraton/PythonDropboxUploader/

# ============ DEFINE GLOBAL SETTINGS ============ #

cydiatemp="/var/cache/apt/archives/"
backupdir="/var/mobile/Media/Downloads/"
debbackup="/var/mobile/Media/Downloads/debs"
logfile="/var/mobile/Library/cybackup/cybackup.txt"
repolist="/etc/apt/sources.list.d/cydia.list"
updatetime="/var/mobile/Library/cybackup/update"
today=$(date +%D | sed 's/\///g')
version="2.0"

config_file="/var/mobile/Library/cybackup/cybackup.plist"
tmpdir="/var/tmp/cyBackup/cybackup_$today"
restoredir="/var/tmp/cyBackup/cybackup_latest"

if [ "$EUID" -ne "0" ]; then
	echo "Script must be run as root"
	exit 1
fi


if [ ! -e $tmpdir ]; then
	mkdir -p $tmpdir
else
	rm -rf $tmpdir
	mkdir -p $tmpdir
fi

TTY_SETTING=$(stty -g)
SCRIPT=$0
stty erase '^H'


# calculate free Disk space on iDevice
let FREE_SPACE=$(df | grep private | awk '{print $4}')

##### Help function

function helpme(){
clear
echo "cyBackup Version $version by cytec"
echo "Gives abylity to Backup Installed and Downladed Packages from Cydia"
echo "now more advanced backup to my Server"
echo ""
echo "usage $0 Options"
echo "  example -d /User/Mobile/DCIM -l this backups the named folders to your local machine"
echo ""
echo "    -b    backup to cytecs server"
echo "    -r    restore from server"
echo "    -f    remote save to ftp server"
echo "    -t    remote restore from ftp server"
echo "    -u     Update Script"
echo "    -l   IF LocalSharing is enabled, it makes a Backup of all installed deb Files to an remote Mac if not it just downloads and stores you debs..."
echo "    -a    Add directory to backup list"
echo "    -d    Only Backup Following dir"
echo "    -p    push dir to Dropbox account will promt u for user and pw"
echo "    -s    edit settings"
echo ""
exit 0
}


while getopts brftul:a:dps opt
do
  case "$opt" in
    b) BACKUP_CY=1;;
    r) RESTORE_CY=1;;
    f) BACKUP_FTP=1;;
    t) RESTORE_FTP=1;;
    u) update;;
    l) SYNC_TO_PC=1;;
    a) adbackupdir "$OPTARG";;
    d) ONLY_DIR="$OPTARG";;
    p) DROPBOX=1;;
    s) changesettings;;
    :) echo "Option \"$OPTARG\" needs an Argument.";;
    \?) helpme;;
  esac
done

## adds Dir follwed by -a to the custom backup list
function adbackupdir() {
    #touch $CUSTOM_BACKUP_DIRS
    if [ ! -d "$1" ]; then
        echo "$1 is not a valid directory"
    else
        echo "$1" >> $CUSTOM_BACKUP_DIRS
    fi
}

function backupcustomdirs() {
    while read line
    do
        echo "starting Backup for $line"
        rsync -R $line $cysave
    done < $CUSTOM_BACKUP_DIRS
    echo "Custom Dirs backuped successfully"
}

function uploadtodropbox() {
    echo "Please enter your Dropbox.com Username:"
    read dbuser
    echo "Please enter your Dropbox.com Password:"
    read dbpass
    echo "Starting upload to Dropbox..."
#    dropbox.sh -u "$dbuser" -p "$dbpass" -f "$latestbackup" -d "cyBackup/"
    if [ $0 == 0 ]; then
        echo "upload complete"
    else
        echo "something went wrong"
        exit 1
    fi
}

function backupdefaultdirs() {
DEFAULT_DIRS="/var/mobile/Library/SMS 
/var/mobile/Library/Notes
/var/mobile/Library/iFile
/var/mobile/Library/Safari
/var/mobile/Library/Preferences
/var/mobile/Library/Keyboard
/var/mobile/Library/Voicemail
/var/wireless/Library/CallHistory
/var/mobile/Media/DCIM
/var/mobile/Library/Maps
/var/mobile/Media/Recordings
"

for folder in $DEFAULT_DIRS
do
    #echo "$folder" | sed 's/%20/ /g'
    foldername=$(basename $folder)
    echo "creating backup of $foldername"
    rsync -R "$folder" "$tmpdir"
done

}

function simplerestore() {
    rsync -R "$restoredir/*" /
}