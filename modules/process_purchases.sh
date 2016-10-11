#!/bin/bash
# Local Purchases processor
mkdir $1/purchases
# CSV Converter Module
bash $PWD/modules/csv_converter.sh purchases
if [ $? -ne 0 ]
then
	exit 1
fi
main_input=$(zenity --title="Submit form" --forms --add-entry="TIN Number" --add-combo="Select Month" --combo-values="1|2|3|4|5|6|7|8|9|10|11|12" \
	--add-combo="Select Ret_Type" --combo-values="Monthly|Quaterly" \
	--text="Dealer Details" --add-entry="Enter header record count" --add-entry="Enter end record count" --ok-label="Continue")
if [ $? -eq 0 ]
then
	purchases_our_tin=$(echo $main_input | cut -d"|" -f1)
	purchases_ret_month=$(echo $main_input | cut -d"|" -f2)
	purchases_ret_type=$(echo $main_input | cut -d"|" -f3)
	purchases_top=$(echo $main_input | cut -d"|" -f4)
	purchases_bottom=$(echo $main_input | cut -d"|" -f5) 
	if ( [ -z "$purchases_our_tin" ] || [ -z "$purchases_ret_month" ] || [ -z "$purchases_ret_type" ] || [ -z "$purchases_top" ] || [ -z "$purchases_bottom" ] )
	then 
		zenity --error --text="No options entered" --ok-label="Quit";exit 1
	fi
else 
	zenity --error --text="No options entered" --ok-label="Quit";exit 1
fi
if [ "$purchases_ret_type" == "Monthly" ]
then
	purchases_ret_type="M"
else
	purchases_ret_type="Q"
fi
# Dealer TIN Checker
bash $PWD/modules/connection_checker.sh
if [ $? -ne 0 ]
then
	exit 1
fi
elinks "https://www.tinxsys.com/TinxsysInternetWeb/dealerControllerServlet?tinNumber=$purchases_our_tin&searchBy=TIN" > $1/purchases/buffer
our_tin=$(cat $1/purchases/buffer | sed -n 9p | tr -d " " | cut -c8-18)
our_name=$(cat $1/purchases/buffer | sed -n 11p|tr -s " "|cut -c 18-100)
if [ "$purchases_our_tin" == "$our_tin" ]
then
	echo -e "Please verify whether the following details are correct.\n\nPurchaser TIN --> $our_tin\n\
Purchaser Name --> $our_name\nPurchases Return Period --> $(date "+%b" -d $purchases_ret_month/01/2016)" | zenity --text-info --ok-label="Proceed" \
	--height=250 --width=400
	if [ $? -ne 0 ]
	then
		zenity --error --text="Correct the details and restart" --ok-label="Quit";exit 1
	fi
else
	zenity --error --text="Invalid TIN entered";exit 1
fi
rm $1/purchases/buffer
purchases_rec_cnt=$(wc -l < $1/purchases/$(ls $1/purchases | grep .*\.csv))
cat $1/purchases/*.csv | sed -n "$(($purchases_top+1))","$(($purchases_rec_cnt-$purchases_bottom))"p | \
sed 's/,/|/g' > $1/purchases/purchase_new.csv
# Duplicate Checker and Corrector Module
bash $PWD/modules/duplicate_processor.sh purchases
if [ $? -ne 0 ]
then
	exit 1
fi
touch $1/purchases/purchase_errors.txt
cat $1/purchases/purchase_new.csv | awk -F "|" \
'{
	tin=match($1, /^29[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]$/)
	if(!tin)
		{ printf("TIN error : \"%s\" | %s | %s | %s | %s | %s | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8) }
	if(($2 ~ /[^a-zA-Z ]/) || length($2)<1 || length($2)>30)
		{ printf("NAME (Violates Constraints): %s | \"%s\" | %s | %s | %s | %s | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8) }	
	if(($3 ~ /[^0-9a-zA-Z]/) || length($3)<1 || length($3)>15)
		{ printf("INV NO (Violates Constraints): %s | %s | \"%s\" | %s | %s | %s | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8) }
	if(!($4 ~ /..\/..\/2016/))
		{ printf("DATE (Violates Constraints): %s | %s | %s | \"%s\" | %s | %s | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8) }
	if(!($5 ~ /^[0-9]+(\.[0-9]+)?$/) || ($5<=0))
		{ printf("NET VALUE (Violates constraints) : %s | %s | %s | %s | \"%s\" | %s | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8) }
	if(!($6 ~ /^[0-9]+(\.[0-9]+)?$/) || ($6<0))
		{ printf("TAX VALUE (Violates constraints) : %s | %s | %s | %s | %s | \"%s\" | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8) }
	if(!($7 ~ /^[0-9]+(\.[0-9]+)?$/) || ($7<0))
		{ printf("OTHER VALUE (Violates constraints) : %s | %s | %s | %s | %s| %s | \"%s\" | %s\n",$1,$2,$3,$4,$5,$6,$7,$8) }
	if(!($8 ~ /^[0-9]+(\.[0-9]+)?$/) || ($8<=0))
		{ printf("TOTAL VALUE (Violates constraints) : %s | %s | %s | %s | %s| %s | %s | \"%s\"\n",$1,$2,$3,$4,$5,$6,$7,$8) }
	if(($5+$6+$7)!=$8)
		{ printf("TOTAL VALUE (Sum Mismatch) : %s | %s | %s | %s | %s | %s | %s | %s\n",$1,$2,$3,$4,$5,$6,$7,$8) }
}' >> $1/purchases/purchase_errors.txt
if [ $(echo $(ls -l $1/purchases/purchase_errors.txt) | cut -d" " -f5) -ne 0 ]
then 
	zenity --error --title="Rule Validator" --text="$(echo -e "General Rule Validation Unsuccessful\nErrors Exists !")" \
	--ok-label="Click here to view errors" --height=170 --width=200
	if [ $? -eq 0 ]
	then
		cat $1/purchases/purchase_errors.txt | zenity --title="List of errors" \
		--text-info --height=350 --width=800 --checkbox="Write errors to file (Path : HOME Directory)" --ok-label="Quit"
		if [ $? -eq 0 ]
		then
			cp $1/purchases/purchase_errors.txt $HOME/rule_errors.txt
			exit 0
		else
			exit 1
		fi
	else
		exit 0
	fi
else
	zenity --info --title="Rule Validator" --text="Validation Successful !" --ok-label="Continue" --height=120 --width=150
	rm $1/purchases/purchase_errors.txt
	if [ $? -ne 0 ]
	then
		exit 1
	fi
fi
# Date Validator
bash $PWD/modules/date_validator.sh purchases $purchases_ret_month
if [ $? -ne 0 ]
then
	exit 1
fi
# TIN validator
zenity --question --title="TIN Validator" --text="$(echo -e "TIN numbers need to be verified.\nProceed with verification?")" \
--height=100 --width=300 --ok-label="Proceed"
if [ $? -eq 0 ]
then
	bash $PWD/modules/connection_checker.sh
	if [ $? -ne 0 ]
	then
		exit 1
	fi
	bash $PWD/modules/tin_validator.sh purchases
	if [ $? -ne 0 ]
	then
		exit 1
	fi
else
	zenity --error --title="TIN Validator" --text="$(echo -e "Exiting..! XML not generated since\nTIN not verified")" \
	--ok-label="Quit" --height=150 --width=250
	exit 1
fi
# XML Generation
touch $1/purchases/LP_GEN_M"$purchases_ret_month".xml
# XML headers
echo -e "\
<PurchaseDetails>\n\
<Version>13.11</Version>\n\
<TinNo>$purchases_our_tin</TinNo>\n\
<RetPerdEnd>2016</RetPerdEnd>\n\
<FilingType>$purchases_ret_type</FilingType>\n\
<Period>$purchases_ret_month</Period>" >> $1/purchases/LP_GEN_M"$purchases_ret_month".xml
#XML body
cat $1/purchases/purchase_new.csv | sed 's/\//|/g' | awk -F "|" \
'{
printf("<PurchaseInvoiceDetails>\n\
<SelTin>%s</SelTin>\n\
<SelName>%s</SelName>\n\
<InvNo>%s</InvNo>\n\
<InvDate>%s-%s-%s</InvDate>\n\
<NetVal>%.2f</NetVal>\n\
<TaxCh>%.2f</TaxCh>\n\
<OthCh>%.2f</OthCh>\n\
<TotCh>%.2f</TotCh>\n\
</PurchaseInvoiceDetails>\n",$1,$2,$3,$6,$5,$4,$7,$8,$9,$10)
}' >> $1/purchases/LP_GEN_M"$purchases_ret_month".xml
# XML End
echo -e "</PurchaseDetails>" >> $1/purchases/LP_GEN_M"$purchases_ret_month".xml
if [ $(echo $(ls -l $1/purchases/LP_GEN_M"$purchases_ret_month".xml) | cut -d" " -f5) -ne 0 ]
then
	cp $1/purchases/LP_GEN_M"$purchases_ret_month".xml $HOME
	zenity --info --title="XML Creator" --text="$(echo -e "Xml created successfully.\nPlease find it in your HOME directory.\n\n \
XML File name : $(echo $(ls $HOME/LP_GEN_M"$purchases_ret_month".xml | basename LP_GEN_M"$purchases_ret_month".xml))")" \
	--ok-label="Finish" --height=170 --width=270
	rm $1/purchases/LP_GEN_M"$purchases_ret_month".xml
else
	zenity --error --title="XML Creator" --text="$(echo -e "XML not generated.\nPlease re-run the application.")" --ok-label="Exit" \
	--height=160 --width=200
	exit 1
fi
# Summary Generator
touch $1/purchases/summary
echo -e "DEALER NAME --> $our_name" >> $1/purchases/summary
echo -e "DEALER TIN --> $our_tin" >> $1/purchases/summary
echo -e "RETURN PERIOD --> $(date "+%b" -d $purchases_ret_month/01/2016)" >> $1/purchases/summary
echo -e "RETURN TYPE --> $purchases_ret_type" >> $1/purchases/summary
echo -e "ACCOUNT TYPE --> LOCAL PURCHASES" >> $1/purchases/summary
echo -e "------------------------------------" >> $1/purchases/summary
cat $1/purchases/purchase_new.csv | awk -F "|" \
'BEGIN{printf("----------GRAND TOTAL----------\n")}{ net=net+$5;tax=tax+$6;others=others+$7;total=total+$8 }\
END{ printf("NET VALUE = %.2f\nTAX VALUE = %.2f\nOTHERS VALUE = %.2f\nTOTAL VALUE = %.2f\n",net,tax,others,total)}'\
>> $1/purchases/summary
echo -e "------------------------------------" >> $1/purchases/summary
echo -e "TOTAL RECORD COUNT --> $(wc -l < $1/purchases/purchase_new.csv)" >> $1/purchases/summary
echo -e "XML FILE NAME --> $(ls $HOME/LP_GEN_M"$purchases_ret_month".xml | basename LP_GEN_M"$purchases_ret_month".xml)" >> $1/purchases/summary
cat $1/purchases/summary | zenity --text-info --title="e-UPaSS Summary" --checkbox="$(echo -e "Save summary to File\n(File Location : HOME directory)")" \
--ok-label="FINISH" --height=450 --width=370
if [ $? -eq 0 ]
then
	cp $1/purchases/summary $HOME/purchases_summary.txt
fi
rm $1/purchases/summary
exit 0
