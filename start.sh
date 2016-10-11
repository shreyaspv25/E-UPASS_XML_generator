#!/bin/bash
if [ -d $HOME/.temp_process ]
then 
	rm -R $HOME/.temp_process
fi
mkdir -p $HOME/.temp_process
temp_path="$HOME/.temp_process"
choice=$(zenity --title="e-UPaSS XML Generator" --list --text="Select Accounts type" --radiolist --column="Select" --column=" Account Type" \
FALSE "Local Sales" FALSE "Local Purchases" FALSE "Interstate Purchases" FALSE "Interstate Sales" \
--height=270 --width=350 --ok-label="Done")
case $choice in
		"Local Sales")bash $PWD/modules/process_sales.sh $temp_path;;
		"Local Purchases")bash $PWD/modules/process_purchases.sh $temp_path;;
		"Interstate Purchases")bash $PWD/modules/process_interstate_purchases.sh $temp_path;;
		#"Interstate Sales")process_interstate_sales;;
		*)zenity --title="XML" --error --text="Nothing selected ! Exiting..!" --ok-label="Quit";exit 1;;
esac
exit 0
