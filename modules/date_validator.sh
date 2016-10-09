#!/bin/bash
cd $HOME/.temp_process/$1
touch $PWD/mod_date
touch $PWD/date_err
touch $PWD/date_errors
type=$(ls | grep .*_new.csv | cut -d"_" -f1)
cat $PWD/"$type"_new.csv | awk -F "|" '{ printf("%s\n",$4)}' | awk -F "/" '{printf("%s/%s/%s\n",$2,$1,$3)}' >> $PWD/mod_date
date_cnt=$(wc -l < $PWD/mod_date)
for i in `cat $PWD/mod_date`
do
	date "+%m/%d/%Y" -d $i
done > /dev/null 2>>$PWD/date_err
if [ $(echo $(ls -l $PWD/date_err) | cut -d" " -f5) -ne 0 ]
then
	date_cnt=$(wc -l < $PWD/date_err)
	for((i=1;$i<=date_cnt;i++))
	do
		error_date=$(cat $PWD/date_err | sed -n "$i"p | cut -c 23-32 | awk -F "/" '{printf("%s/%s/%s\n",$2,$1,$3)}')
		echo -e "Invalid DATE--> $(grep $error_date $PWD/"$type"_new.csv)" >> $PWD/date_errors
	done	
fi
cur_day=$(date '+%d')
cur_month=$(date '+%m')
for i in `cat $PWD/mod_date`
do
	inv_month=$(echo $i | cut -d"/" -f1)
	inv_day=$(echo $i | cut -d"/" -f2)
	if ( [ $inv_month -gt $2 ] || [ $inv_month -lt $2 ] )
		then
			grepdate=$(grep $i $PWD/mod_date | awk -F "/" '{ printf("%s/%s/%s\n",$2,$1,$3) }' )
			echo -e "DATE not of Ret_period--> $(grep $grepdate $PWD/"$type"_new.csv)" >> $PWD/date_errors
	elif ( [ $inv_month -eq $cur_month ] && [ $inv_day -gt $cur_day ] ) 
		then
			grepdate=$(grep $i $PWD/mod_date | awk -F "/" '{ printf("%s/%s/%s\n",$2,$1,$3) }' )
			echo -e "DATE exceeds today's_date--> $(grep $grepdate $PWD/"$type"_new.csv)" >> $PWD/date_errors
	else
		echo "Correct Date" > /dev/null
	fi
	if [ $inv_month -gt $cur_month ]
		then
			grepdate=$(grep $i $PWD/mod_date | awk -F "/" '{ printf("%s/%s/%s\n",$2,$1,$3) }' )
			echo -e "DATE exceeds today's_date--> $(grep $grepdate $PWD/"$type"_new.csv)" >> $PWD/date_errors
	fi
done
if [ $(echo $(ls -l $PWD/date_errors) | cut -d" " -f5) -ne 0 ]
then
	cat $PWD/date_errors | zenity --title="List of Date error records" --text-info --height=350 --width=800 \
	--checkbox="Write errors to file (Path : HOME Directory)" --ok-label="Quit"
	if [ $? -eq 0 ]
	then
		cp $PWD/date_errors $HOME/date_errors.txt
		rm $PWD/mod_date $PWD/date_err $PWD/date_errors
		exit 0
	else
		rm $PWD/mod_date $PWD/date_err $PWD/date_errors
		exit 1
	fi
else
	zenity --info --title="Date Validator" --text="$(echo -e "Date Validation Successful.\nNo errors found.")" \
	--height=150 --width=250 --ok-label="Continue"
	rm $PWD/mod_date $PWD/date_err $PWD/date_errors
	exit 0
fi
