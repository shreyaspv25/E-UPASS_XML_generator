#!/bin/bash
cd $HOME/.temp_process/$1
type=$(ls | grep .*_new.csv | cut -d"_" -f1)
touch $PWD/tin_buf1
touch $PWD/tin_buf2
touch $PWD/zenity_writer
sort $PWD/"$type"_new.csv | awk -F "|" '{ printf("%s\n",$1) }' | uniq > $PWD/tin_buf1
tin_cnt=$(wc -l < $PWD/tin_buf1)
for ((i=1;i<=$tin_cnt;i++))
do
tin=$(cat $PWD/tin_buf1 | sed -n "$i"p )
elinks "https://www.tinxsys.com/TinxsysInternetWeb/dealerControllerServlet?tinNumber=$tin&searchBy=TIN" > $PWD/tin_buf2
if( [ $? -eq 0 ] && [ -e $PWD/tin_buf2 ] )
	then
		{ 
			extracted_tin=$(cat $PWD/tin_buf2 | sed -n 9p | tr -d " " | cut -c8-18)
			if [ "$extracted_tin" == "$tin" ]
				then 
					echo "Correct TIN" > /dev/null
				else
					{
						echo -e "Records with Invalid TIN\n" >> $PWD/zenity_writer
						grep "$tin" $PWD/"$type"_new.csv >> $PWD/zenity_writer
					}
			fi
		}
	else
		zenity --error --title="TIN Validator" --text="$(echo -e "Server Error.\nTIN not fetched.\nPlease try after some time.")" \
		--height=1700 --width=250  --ok-label="Exit"
		rm $PWD/tin_buf1 $PWD/tin_buf2 $PWD/zenity_writer
		exit 1
fi
echo $(bc -l <<< $i*100/$tin_cnt)
sleep 1s
done | zenity --progress --title="TIN Validator" --text="Checking TIN Numbers...." --time-remaining --height=100 --width=400 \
--no-cancel --ok-label="Continue"
if [ $(echo $(ls -l $PWD/zenity_writer) | cut -d" " -f5) -ne 0 ]
then
	cat $PWD/zenity_writer | zenity --text-info --title="List of TIN error records"	--height=400 --width=800 \
	--checkbox="Write errors to file (Path : HOME Directory)"--ok-label="Exit"
	cp $PWD/zenity_writer $HOME/tin_errors.txt
	rm $PWD/tin_buf1 $PWD/tin_buf2 $PWD/zenity_writer
	exit 1
else
	zenity --info --title="TIN Validator" --text="$(echo -e "Tin Validation Successful\nNo errors found.")" \
	--height=150 --width=250 --ok-label="Continue"
	rm $PWD/tin_buf1 $PWD/tin_buf2 $PWD/zenity_writer
	exit 0
fi
