#!/bin/sh

# TODO
# Check available diskspace.
##du minecraft/minecraft_server -s -m | cut -f1

ERR_RUN_NOSERVER="The minecraft server isn't running"
ERR_RUN_SERVER="The minecraft server is already running"
ERR_RUN_TMUX="tmux is already running"
ERR_RUN_RAMDISK="Ramdisk with world data not mounted"
ERR_NOTFOUND_JRE="Java JRE bin not found at $PATH_JAVA. (mc.ini:PATH_JAVA)"
ERR_NOTFOUND_MC="Minecraft server not found at $PATH_MC. (mc.ini:PATH_MC)"
ERR_NOTFOUND_WORLD="Minecraft world dir not found at $PATH_WORLD. (mc.ini:PATH_WORLD)\nPerhaps the ramdisk is not mounted?"
ERR_NOTFOUND_BACKUP="Minecraft backup dir not found at$PATH_BACKUP. (mc.ini:PATH_BACKUP)"

show_err () {
	echo $1 >&2
}

abrt_err () {
	echo $1 >&2
	exit 1
}

mc_check_conf () {
	if [ \! -f "$PATH_JAVA" ]; then
		abrt_err "$ERR_NOTFOUND_JRE"
	fi
	if [ \! -d "$PATH_MC" ]; then
		abrt_err "$ERR_NOTFOUND_MC"
	fi
	if [ \! -d "$PATH_WORLD" ]; then
		abrt_err "$ERR_NOTFOUND_WORLD"
	fi
	if [ \! -d "$PATH_BACKUP" ]; then
		abrt_err "$ERR_NOTFOUND_BACKUP"
	fi
}

mc_check_running_server () {
	RUNNING_JAR=`ps a | grep minecraft_server.jar | grep -v "grep"`
	[ -z "$RUNNING_JAR" ]
	return $?
}

mc_check_running_tmux () {
	RUNNING_TMUX=`$PATH_TMUX list-sessions 2>/dev/null | egrep "$$TMUX_MCNAME:"`
	[ -z "$RUNNING_TMUX" ]
	return $?
}

mc_check_running_ramdisk () {
	RUNNING_RAMDISK=`mount | grep "$PATH_MC"`
	[ -n "$RUNNING_RAMDISK" ]
	return $?
}

#
# Turn on saving of the world and flush changes to disk. This ensures that
# backups are not corrupt. This commands waits until the save is complete and
# then returns. Don't forget to call `mc_save_on` to re-enable saving.
#
mc_save_off () {
	$PATH_TMUX send -t "$TMUX_MCNAME" "save-off" C-m
	SAVE_COMPLETE=`grep "Saved the world" $PATH_MC/server.log | wc -l`
	$PATH_TMUX send -t "$TMUX_MCNAME" "save-all" C-m
	
	while true; do
		sleep 0.2
		TMP=`grep "Saved the world" $PATH_MC/server.log | wc -l`
		if [ $TMP -gt $SAVE_COMPLETE ]; then
			break
		fi
	done
}

#
# Turns saving of the world back on.
#
mc_save_on () {
	$PATH_TMUX send -t "$TMUX_MCNAME" "save-on" C-m
}

mc_start () {
	mc_check_running_server || abrt_err "$ERR_RUN_SERVER"
	mc_check_running_tmux || abrt_err "$ERR_RUN_TMUX"
	mc_check_running_ramdisk || abrt_err "$ERR_RUN_RAMDISK"

	cd $PATH_MC
	$PATH_TMUX new -d -n "$TMUX_MCNAME" -s "$TMUX_MCNAME" "$RUN"
}

#
# Stop the minecraft server
#
mc_stop () {
	mc_check_running_server && abrt_err "$ERR_RUN_NOSERVER"
	$PATH_TMUX send -t "$TMUX_MCNAME" "stop" C-m
}

#
# Create a backup of the Minecraft server and delete old backups.
#
mc_backup () {
	mc_check_running_server && abrt_err "$ERR_RUN_NOSERVER"

	# Create backup
	DATETIME=`date +"%Y%m%d%H%M"`
	mc_save_off
	cp -ar "$PATH_WORLD" "$PATH_BACKUP/world-$DATETIME"
	mc_save_on

	# Clean up old backups
	if [ `ls -1 "$PATH_BACKUP/" | wc -l` -gt $BACKUPS_MIN ]; then
		find $PATH_BACKUP -maxdepth 1 -mtime +$BACKUPS_DAYS -type d -print0  | xargs -0 rm -rf
	fi
}

#
# Make a persistent copy of the minecraft server's RAM disk
#
mc_persistent () {
	mc_check_running_server && abrt_err "$ERR_RUN_NOSERVER"
	mc_check_running_ramdisk || abrt_err "$ERR_RUN_RAMDISK"

	rm -rf "$PATH_MC.persistent"
	mc_save_off
	cp -ar "$PATH_MC" "$PATH_MC.persistent"
	mc_save_on
}

#
# Check disk space and alert admin if exceeded the limit.
#
mc_checkspace () {
	USEDSPACE=`df -m 2>/dev/null | grep "$PATH_MC" | awk '{ print $3 }'`
	if [ $USEDSPACE -gt $WORLD_MAXSIZE ]; then
		mail -s "Minecraft @ `hostname -f`: Max world size exceeded" $ADMIN_EMAIL <<EOT
The size of the world on disk of the Minecraft server (at `hostname -f`) has
exceeded the maximum allowed limit of $WORLD_MAXSIZE Mb.
EOT
	fi
}

# Read and validate the configuration
if [ ! -f mc.ini ]; then
	echo "mc.ini configuration not found. Aborting..."
	exit 1
fi
source mc.ini
mc_check_conf

RUN="$PATH_JAVA -server -Xincgc -Xmx$MEM -jar minecraft_server.jar nogui"

case "$1" in
	start)
		echo -n "Starting minecraft.."
		mc_start
		echo " done."
		;;
	stop)
		echo -n "Stopping minecraft.."
		mc_stop
		echo " done."
		;;
	backup)
		mc_backup
		;;
	persistent)
		mc_persistent
		;;
	checkspace)
		mc_checkspace
		;;
	*)
		echo "Usage: $0 {start|stop|backup|checkspace|persistent}"
		exit 1
		;;
	esac
exit 0

