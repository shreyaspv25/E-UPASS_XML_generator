#!/bin/bash
cd $HOME/.temp_process/$1
selected_file=$(zenity --title="File Selector" --file-selection --file-filter=*.ods --file-filter=*.xlsx --file-filter=*.xls)
if [ $? -eq 0 ]
then 
	{
		libreoffice --headless --convert-to csv --outdir $PWD $selected_file > /dev/null 2>/dev/null
		if [ $? -ne 0 ]
		then 
			zenity --error --title="CSV Converter" --text="Conversion Failed! Please try again. " --ok-label="Quit"
			exit 1
		else
			echo "Conversion Successful" > /dev/null
			exit 0
		fi
		}
	else
		zenity --error --title="File Selector" --text="No file chosen.Exiting..!" --ok-label="Quit";exit 1
fi
