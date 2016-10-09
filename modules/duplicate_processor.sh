#!/bin/bash
cd $HOME/.temp_process/$1
type=$(ls | grep .*_new.csv | cut -d"_" -f1)
touch $PWD/dup_buf
touch $PWD/zenity_writer
sort $PWD/"$type"_new.csv | uniq -di >> $PWD/dup_buf
dup_cnt=$(wc -l < $PWD/dup_buf)
for ((i=1;i<=$dup_cnt;i++))
do
to_write="$(cat $PWD/dup_buf | sed -n "$i"p)"
echo -e "Duplicate record --> $to_write\n" >> $PWD/zenity_writer
done
if [ $(echo $(ls -l $PWD/zenity_writer) | cut -d" " -f5) -ne 0 ]
then
	cat $PWD/zenity_writer | zenity --text-info --title="List of Duplicate Records" --checkbox="Click here to remove Duplicate Records" \
	--height=400 --width=800 --ok-label="Remove Duplicates"
else
	zenity --info --title="Duplicate Finder" --text="No Duplicates found." --height=150 --width=250 --ok-label="Continue"
	rm $PWD/dup_buf $PWD/zenity_writer
	exit 0
fi
if [ $? -eq 0 ]
then
	{
		sort "$type"_new.csv | uniq -i > $PWD/"$type"_mod.csv
		rm "$type"_new.csv
		mv "$type"_mod.csv "$type"_new.csv
		flag=1
	}
else
	flag=0
fi
if [ $flag -eq 1 ]
then
	zenity --info --title="Duplicate Finder" --text="Duplicates were successfully removed." --height=150 --width=250 --ok-label="Continue"
	rm $PWD/dup_buf $PWD/zenity_writer
	exit 0
else
	zenity --error --title="Duplicate Finder" --text="$(echo -e "Duplicates were not removed.\nPlease delete them manually.")" \
	--height=150 --width=250  --ok-label="Exit"
	rm $PWD/dup_buf $PWD/zenity_writer
	exit 1
fi
