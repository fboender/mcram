MCRam
=====

Description
-----------

A simple shell script for managing a Minecraft Server on a RAM disk, including
creating regular persistent copies of the world and making daily backups.

Features

*   Safe persistent copies of Minecraft world from RAM disk to real disk.
*   Check disk space used by world and report low RAM disk space.
*   Daily backups with max/min number of backups.
*   Start/stop the server from the commandline.

Setup
-----

Assumes following Directory layout:

    /home/minecraft/
    /home/minecraft/jre1.6.0_21/
    /home/minecraft/minecraft/
    /home/minecraft/minecraft/minecraft_server/
    /home/minecraft/minecraft/minecraft_server/world/
    /home/minecraft/minecraft/minecraft_server/minecraft_server.jar
    /home/minecraft/backups

if different, edit mc.ini.

Put mc and mc.ini in /home/minecraft

Usage
-----

Start the server

    ./mc start

Stop the server

    ./mc stop

Create a safe, persistent copy of the contents of the RAM disk (should be called from CRON, see later in this document)

    ./mc persistent
	
Create a backup of Minecraft and clear old backups (see mc.ini)

    ./mc backup

Check disk usage of world and mail if disk space is getting low (see mc.ini)

    ./mc checkspace

Cronjobs
--------

Install the following CRON jobs:

	# m h  dom mon dow   command
	0 17 * * * /home/minecraft/mc checkspace
	0 18 * * * /home/minecraft/mc backup
	0 * * * * /home/minecraft/mc persistant

License
-------

MCRAM is released into the Public Domain. Use it as you wish.

