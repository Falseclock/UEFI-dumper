# UEFI-dumper


## Toolkit preparation

1. You need download lates version of [PhoenixTool](https://www.bios-mods.com/tools/index.php?dir=Andy+P+(MDL)+Phoenix-Insyde-EFI+SLIC+Tool%2F) to decompose the bios file into its components.
2. You need Perl. If you under Linux, then everything is ok. If not then get [ActivePerl](http://www.activestate.com/activeperl) or [Cygwin](http://www.cygwin.com).
3. Your need latest bios for your laptop. Sometimes latest bios is no best idea, cause vendor can close access or issue patch or even change structure and headers. So let's say: get next version of your bios.
4. Any archivator.

## Obtaining an image of the BIOS

1. Open with any archivator **exe** file of your BIOS update package, find there file with **bin** or **fd** extension and unapack it to any desired place. Better to choose separate folder.
2. Rub PhoenixTool and try to open unpacked file from previous step.
3. If message will appear saying "Not phoenix/dell/insyde/EFI BIOS" then probably your firmware file is encrypted. As far as I know Decrypt still not available (2013 year). If it is your case, then proceed with next step, otherwise go to step **8**.
4. Take BIOS update package, unpack it and make an update as you usually do.
5. Once your notebook rebooted after successfull update find **platform.ini** file inside package folder.
6. Open with any text editor and do following changes: 
```
[BackupROM]
Flag=1
FilePath=C:
FileName=BACKUP.BIN
``` 
7. This change will allow you to update your BIOS once again, but backup of current firmware will be saved. After successfull reboot find BACKUP.BIN under C drive, move to folder created in step **1** and open it with PhoenixTool.
8. After couple awhile small alert window should apper pointing you addresses of Header, Pubkey and Marker.
9. Just close it and exit PhoenixTool.
10. Inside the folder, where you placed your firmware file, you will get DUMP filder with a lot of files. You need to locate file starting with **FE3542FE** and having biggest size.

