#!/bin/bash
# Local Purchases processor
mkdir $1/interstate_purchases
# CSV Converter Module
bash $PWD/modules/csv_converter.sh interstate_purchases
if [ $? -ne 0 ]
then
	exit 1
fi
main_input=$(zenity --title="Submit form" --forms --add-entry="TIN Number" --add-combo="Select Month" --combo-values="1|2|3|4|5|6|7|8|9|10|11|12" \
	--add-combo="Select Ret_Type" --combo-values="Monthly|Quaterly" \
	--text="Dealer Details" --add-entry="Enter header record count" --add-entry="Enter end record count" --ok-label="Continue")
if [ $? -eq 0 ]
then
	interstate_purchases_our_tin=$(echo $main_input | cut -d"|" -f1)
	interstate_purchases_ret_month=$(echo $main_input | cut -d"|" -f2)
	interstate_purchases_ret_type=$(echo $main_input | cut -d"|" -f3)
	interstate_purchases_top=$(echo $main_input | cut -d"|" -f4)
	interstate_purchases_bottom=$(echo $main_input | cut -d"|" -f5) 
	if ( [ -z "$interstate_purchases_our_tin" ] || [ -z "$interstate_purchases_ret_month" ] || [ -z "$interstate_purchases_ret_type" ] || [ -z "$interstate_purchases_top" ] || [ -z "$interstate_purchases_bottom" ] )
	then 
		zenity --error --text="No options entered" --ok-label="Quit";exit 1
	fi
else 
	zenity --error --text="No options entered" --ok-label="Quit";exit 1
fi
if [ "$interstate_purchases_ret_type" == "Monthly" ]
then
	interstate_purchases_ret_type="M"
else
	interstate_purchases_ret_type="Q"
fi
# Dealer TIN Checker
bash $PWD/modules/connection_checker.sh
if [ $? -ne 0 ]
then
	exit 1
fi
elinks "https://www.tinxsys.com/TinxsysInternetWeb/dealerControllerServlet?tinNumber=$interstate_purchases_our_tin&searchBy=TIN" > $1/interstate_purchases/buffer
our_tin=$(cat $1/interstate_purchases/buffer | sed -n 9p | tr -d " " | cut -c8-18)
our_name=$(cat $1/interstate_purchases/buffer | sed -n 11p|tr -s " "|cut -c 18-100)
if [ "$interstate_purchases_our_tin" == "$our_tin" ]
then
	echo -e "Please verify whether the following details are correct.\n\nPurchaser TIN --> $our_tin\n\
Purchaser Name --> $our_name\nPurchases Return Period --> $(date "+%b" -d $interstate_purchases_ret_month/01/2016)" | zenity --text-info --ok-label="Proceed" \
	--height=250 --width=400
	if [ $? -ne 0 ]
	then
		zenity --error --text="Correct the details and restart" --ok-label="Quit";exit 1
	fi
else
	zenity --error --text="Invalid TIN entered";exit 1
fi
rm $1/interstate_purchases/buffer
interstate_purchases_rec_cnt=$(wc -l < $1/interstate_purchases/$(ls $1/interstate_purchases | grep .*\.csv))
cat $1/interstate_purchases/*.csv | sed -n "$(($interstate_purchases_top+1))","$(($interstate_purchases_rec_cnt-$interstate_purchases_bottom))"p | \
sed 's/,/|/g' > $1/interstate_purchases/purchase_new.csv
# Duplicate Checker and Corrector Module
bash $PWD/modules/duplicate_processor.sh interstate_purchases
if [ $? -ne 0 ]
then
	exit 1
fi
touch $1/interstate_purchases/purchase_errors.txt
cat $1/interstate_purchases/purchase_new.csv | awk -F "|" \
'{
	tin=match($1, /^[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/)
	if(!tin)
		{ printf("TIN error : \"%s\" | %s | %s | %s | %s | %s | %s | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9) }
	if(($2 ~ /[^a-zA-Z ]/) || length($2)<1 || length($2)>30)
		{ printf("NAME (Violates Constraints): %s | \"%s\" | %s | %s | %s | %s | %s |%s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9) }	
	if(($4 ~ /[^0-9a-zA-Z]/) || length($3)<1 || length($3)>15)
		{ printf("INV NO (Violates Constraints): %s | %s | %s | \"%s\" | %s | %s | %s | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9) }
	if(!($5 ~ /..\/..\/2016/))
		{ printf("DATE (Violates Constraints): %s | %s | %s | %s | \"%s\" | %s | %s | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9) }
	if(!($6 ~ /^[0-9]+(\.[0-9]+)?$/) || ($6<=0))
		{ printf("NET VALUE (Violates constraints) : %s | %s | %s | %s | %s | \"%s\" | %s | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9) }
	if(!($7 ~ /^[0-9]+(\.[0-9]+)?$/) || ($7<0))
		{ printf("TAX VALUE (Violates constraints) : %s | %s | %s | %s | %s | %s | \"%s\" | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9) }
	if(!($8 ~ /^[0-9]+(\.[0-9]+)?$/) || ($8<0))
		{ printf("OTHER VALUE (Violates constraints) : %s | %s | %s | %s | %s | %s| %s | \"%s\" | %s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9) }
	if(!($9 ~ /^[0-9]+(\.[0-9]+)?$/) || ($9<=0))
		{ printf("TOTAL VALUE (Violates constraints) : %s | %s | %s | %s | %s | %s| %s | %s | \"%s\"\n",$1,$2,$3,$4,$5,$6,$7,$8,$9) }
	if(($6+$7+$8)!=$9)
		{ printf("TOTAL VALUE (Sum Mismatch) : %s | %s | %s | %s | %s | %s | %s | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8,$9) }
	if(!($10 ~ /(C|WC|CE|F|H|E1|E2|OT|IM)/))
		{ printf("INVALID FORM TYPE : %s | %s | %s | %s | %s | \"%s\"\n",$1,$2,$4,$5,$9,$10) }
	if(!($11>0 && $11<95))
		{ printf("INVALID MAIN COMMODITY CODE : %s | %s | %s | %s | %s | \"%s\"\n",$1,$2,$4,$5,$9,$11) }
	if(!($12 ~ /^[1-9]$/))
		{ printf("INVALID SUB COMMODITY CODE : %s | %s | %s | %s | %s | \"%s\"\n",$1,$2,$4,$5,$9,$12) }
	if($13 ~ /[^0-9a-zA-Z ]/ || length($13)<1 || length($13)>10)
		{ printf("INVALID QUANITY VALUE : %s | %s | %s | %s | %s | \"%s\"\n",$1,$2,$4,$5,$9,$13) }
	if(!($14 ~ /^[1-7]$/))
		{ printf("INVALID PURPOSE CODE : %s | %s | %s | %s | %s | \"%s\"\n",$1,$2,$4,$5,$9,$14) }
}' >> $1/interstate_purchases/purchase_errors.txt
if [ $(echo $(ls -l $1/interstate_purchases/purchase_errors.txt) | cut -d" " -f5) -ne 0 ]
then 
	zenity --error --title="Rule Validator" --text="$(echo -e "General Rule Validation Unsuccessful\nErrors Exists !")" \
	--ok-label="Click here to view errors" --height=170 --width=200
	if [ $? -eq 0 ]
	then
		cat $1/interstate_purchases/purchase_errors.txt | zenity --title="List of errors" \
		--text-info --height=350 --width=800 --checkbox="Write errors to file (Path : HOME Directory)" --ok-label="Quit"
		if [ $? -eq 0 ]
		then
			cp $1/interstate_purchases/purchase_errors.txt $HOME/rule_errors.txt
			exit 0
		else
			exit 1
		fi
	else
		exit 0
	fi
else
	zenity --info --title="Rule Validator" --text="Validation Successful !" --ok-label="Continue" --height=120 --width=150
	rm $1/interstate_purchases/purchase_errors.txt
	if [ $? -ne 0 ]
	then
		exit 1
	fi
fi
# Date Validator
bash $PWD/modules/date_validator.sh interstate_purchases $interstate_purchases_ret_month
if [ $? -ne 0 ]
then
	exit 1
fi
# XML Generation
touch $1/interstate_purchases/IP_GEN_M"$interstate_purchases_ret_month".xml
# XML headers
echo -e "\
<ISPur>\n\
<Version>13.11</Version>\n\
<TinNo>$interstate_purchases_our_tin</TinNo>\n\
<RetPerdEnd>2016</RetPerdEnd>\n\
<FilingType>$interstate_purchases_ret_type</FilingType>\n\
<Period>$interstate_purchases_ret_month</Period>" >> $1/interstate_purchases/IP_GEN_M"$interstate_purchases_ret_month".xml
#XML body
cat $1/interstate_purchases/purchase_new.csv | sed 's/\//|/g' | awk -F "|" \
'{
printf("<ISPurInv>\n\
<SelTin>%s</SelTin>\n\
<SelName>%s</SelName>\n\
<SelAddr>%s</SelAddr>\n\
<InvNo>%s</InvNo>\n\
<InvDate>%s-%s-%s</InvDate>\n\
<NetVal>%.2f</NetVal>\n\
<TaxCh>%.2f</TaxCh>\n\
<OthCh>%.2f</OthCh>\n\
<TotCh>%.2f</TotCh>\n\
<TranType>%s</TranType>\n\
<MainComm>%d</MainComm>\n\
<SubComm>%d</SubComm>\n\
<Qty>%s</Qty>\n\
<Purpose>%d</Purpose>\n\
</ISPurInv>\n",$1,$2,$3,$4,$7,$6,$5,$8,$9,$10,$11,$12,$13,$14,$15,$16)
}' >> $1/interstate_purchases/IP_GEN_M"$interstate_purchases_ret_month".xml
# XML End
echo -e "</ISPur>" >> $1/interstate_purchases/IP_GEN_M"$interstate_purchases_ret_month".xml
if [ $(echo $(ls -l $1/interstate_purchases/IP_GEN_M"$interstate_purchases_ret_month".xml) | cut -d" " -f5) -ne 0 ]
then
	cp $1/interstate_purchases/IP_GEN_M"$interstate_purchases_ret_month".xml $HOME
	zenity --info --title="XML Creator" --text="$(echo -e "Xml created successfully.\nPlease find it in your HOME directory.\n\n \
XML File name : $(echo $(ls $HOME/IP_GEN_M"$interstate_purchases_ret_month".xml | basename IP_GEN_M"$interstate_purchases_ret_month".xml))")" \
	--ok-label="Finish" --height=170 --width=270
	rm $1/interstate_purchases/IP_GEN_M"$interstate_purchases_ret_month".xml
else
	zenity --error --title="XML Creator" --text="$(echo -e "XML not generated.\nPlease re-run the application.")" --ok-label="Exit" \
	--height=160 --width=200
	exit 1
fi
# Summary Generator
touch $1/interstate_purchases/summary
echo -e "DEALER NAME --> $our_name" >> $1/interstate_purchases/summary
echo -e "DEALER TIN --> $our_tin" >> $1/interstate_purchases/summary
echo -e "RETURN PERIOD --> $(date "+%b" -d $interstate_purchases_ret_month/01/2016)" >> $1/interstate_purchases/summary
echo -e "RETURN TYPE --> $interstate_purchases_ret_type" >> $1/interstate_purchases/summary
echo -e "ACCOUNT TYPE --> INTERSTATE PURCHASES" >> $1/interstate_purchases/summary
echo -e "------------------------------------" >> $1/interstate_purchases/summary
cat $1/interstate_purchases/purchase_new.csv | awk -F "|" \
'BEGIN{printf("----------GRAND TOTAL----------\n")}{ net=net+$6;tax=tax+$7;others=others+$8;total=total+$9 }\
END{ printf("NET VALUE = %.2f\nTAX VALUE = %.2f\nOTHERS VALUE = %.2f\nTOTAL VALUE = %.2f\n",net,tax,others,total)}'\
>> $1/interstate_purchases/summary
echo -e "------------------------------------" >> $1/interstate_purchases/summary
echo -e "TOTAL RECORD COUNT --> $(wc -l < $1/interstate_purchases/purchase_new.csv)" >> $1/interstate_purchases/summary
echo -e "XML FILE NAME --> $(ls $HOME/IP_GEN_M"$interstate_purchases_ret_month".xml | basename IP_GEN_M"$interstate_purchases_ret_month".xml)" >> $1/interstate_purchases/summary
cat $1/interstate_purchases/summary | zenity --text-info --title="e-UPaSS Summary" --checkbox="$(echo -e "Save summary to File\n(File Location : HOME directory)")" \
--ok-label="FINISH" --height=450 --width=370
if [ $? -eq 0 ]
then
	cp $1/interstate_purchases/summary $HOME/interstate_purchases_summary.txt
fi
rm $1/interstate_purchases/summary
exit 0
