#!/bin/bash
ping -c 4 8.8.8.8
if [ $? -eq 2 ]
then 
	zenity --error --title="Network Error" --text="$(echo -e "No Internet connection.\nPlease connect to internet and try again!")" \
	--ok-label="Quit" --height=150 --width=275
	exit 1
else
	exit 0
fi
