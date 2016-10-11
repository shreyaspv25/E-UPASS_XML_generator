#!/bin/bash
# Local Sales processor
mkdir $1/sales
# CSV Converter Module
bash $PWD/modules/csv_converter.sh sales
if [ $? -ne 0 ]
then
	exit 1
fi
main_input=$(zenity --title="Submit form" --forms --add-entry="TIN Number" --add-combo="Select Month" --combo-values="1|2|3|4|5|6|7|8|9|10|11|12" \
	--add-combo="Select Ret_Type" --combo-values="Monthly|Quaterly" \
	--text="Dealer Details" --add-entry="Enter header record count" --add-entry="Enter end record count" --ok-label="Continue")
if [ $? -eq 0 ]
then
	sales_our_tin=$(echo $main_input | cut -d"|" -f1)
	sales_ret_month=$(echo $main_input | cut -d"|" -f2)
	sales_ret_type=$(echo $main_input | cut -d"|" -f3)
	sales_top=$(echo $main_input | cut -d"|" -f4)
	sales_bottom=$(echo $main_input | cut -d"|" -f5) 
	if ( [ -z "$sales_our_tin" ] || [ -z "$sales_ret_month" ] || [ -z "$sales_ret_type" ] || [ -z "$sales_top" ] || [ -z "$sales_bottom" ] )
	then 
		zenity --error --text="No options entered" --ok-label="Quit";exit 1
	fi
else 
	zenity --error --text="No options entered" --ok-label="Quit";exit 1
fi
if [ "$sales_ret_type" == "Monthly" ]
then
	sales_ret_type="M"
else
	sales_ret_type="Q"
fi
# Dealer TIN Checker
bash $PWD/modules/connection_checker.sh
if [ $? -ne 0 ]
then
	exit 1
fi
elinks "https://www.tinxsys.com/TinxsysInternetWeb/dealerControllerServlet?tinNumber=$sales_our_tin&searchBy=TIN" > $1/sales/buffer
our_tin=$(cat $1/sales/buffer | sed -n 9p | tr -d " " | cut -c8-18)
our_name=$(cat $1/sales/buffer | sed -n 11p|tr -s " "|cut -c 18-100)
if [ "$sales_our_tin" == "$our_tin" ]
then
	echo -e "Please verify whether the following details are correct.\n\nSeller TIN --> $our_tin\n\
Seller Name --> $our_name\nSales Return Period --> $(date "+%b" -d $sales_ret_month/01/2016)" | zenity --text-info --ok-label="Proceed" \
	--height=250 --width=400
	if [ $? -ne 0 ]
	then
		zenity --error --text="Correct the details and restart" --ok-label="Quit";exit 1
	fi
else
	zenity --error --text="Invalid TIN entered";exit 1
fi
rm $1/sales/buffer
sales_rec_cnt=$(wc -l < $1/sales/$(ls $1/sales | grep .*\.csv))
cat $1/sales/*.csv | sed -n "$(($sales_top+1))","$(($sales_rec_cnt-$sales_bottom))"p | \
sed 's/,/|/g' > $1/sales/sale_new.csv
# Duplicate Checker and Corrector Module
bash $PWD/modules/duplicate_processor.sh sales
if [ $? -ne 0 ]
then
	exit 1
fi
touch $1/sales/sale_errors.txt
cat $1/sales/sale_new.csv | awk -F "|" \
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
}' >> $1/sales/sale_errors.txt
if [ $(echo $(ls -l $1/sales/sale_errors.txt) | cut -d" " -f5) -ne 0 ]
then 
	zenity --error --title="Rule Validator" --text="$(echo -e "General Rule Validation Unsuccessful\nErrors Exists !")" \
	--ok-label="Click here to view errors" --height=170 --width=200
	if [ $? -eq 0 ]
	then
		cat $1/sales/sale_errors.txt | zenity --title="List of errors" \
		--text-info --height=350 --width=800 --checkbox="Write errors to file (Path : HOME Directory)" --ok-label="Quit"
		if [ $? -eq 0 ]
		then
			cp $1/sales/sale_errors.txt $HOME/rule_errors.txt
			exit 0
		else
			exit 1
		fi
	else
		exit 0
	fi
else
	zenity --info --title="Rule Validator" --text="Validation Successful !" --ok-label="Continue" --height=120 --width=150
	rm $1/sales/sale_errors.txt
	if [ $? -ne 0 ]
	then
		exit 1
	fi
fi
# Date Validator
bash $PWD/modules/date_validator.sh sales $sales_ret_month
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
	bash $PWD/modules/tin_validator.sh sales
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
touch $1/sales/LS_GEN_M"$sales_ret_month".xml
# XML headers
echo -e "\
<SaleDetails>\n\
<Version>13.11</Version>\n\
<TinNo>$sales_our_tin</TinNo>\n\
<RetPerdEnd>2016</RetPerdEnd>\n\
<FilingType>$sales_ret_type</FilingType>\n\
<Period>$sales_ret_month</Period>" >> $1/sales/LS_GEN_M"$sales_ret_month".xml
#XML body
cat $1/sales/sale_new.csv | sed 's/\//|/g' | awk -F "|" \
'{
printf("<SaleInvoiceDetails>\n\
<PurTin>%s</PurTin>\n\
<PurName>%s</PurName>\n\
<InvNo>%s</InvNo>\n\
<InvDate>%s-%s-%s</InvDate>\n\
<NetVal>%.2f</NetVal>\n\
<TaxCh>%.2f</TaxCh>\n\
<OthCh>%.2f</OthCh>\n\
<TotCh>%.2f</TotCh>\n\
</SaleInvoiceDetails>\n",$1,$2,$3,$6,$5,$4,$7,$8,$9,$10)
}' >> $1/sales/LS_GEN_M"$sales_ret_month".xml
# XML End
echo -e "</SaleDetails>" >> $1/sales/LS_GEN_M"$sales_ret_month".xml
if [ $(echo $(ls -l $1/sales/LS_GEN_M"$sales_ret_month".xml) | cut -d" " -f5) -ne 0 ]
then
	cp $1/sales/LS_GEN_M"$sales_ret_month".xml $HOME
	zenity --info --title="XML Creator" --text="$(echo -e "Xml created successfully.\nPlease find it in your HOME directory.\n\n \
XML File name : $(echo $(ls $HOME/LS_GEN_M"$sales_ret_month".xml | basename LS_GEN_M"$sales_ret_month".xml))")" \
	--ok-label="Finish" --height=170 --width=270
	rm $1/sales/LS_GEN_M"$sales_ret_month".xml
else
	zenity --error --title="XML Creator" --text="$(echo -e "XML not generated.\nPlease re-run the application.")" --ok-label="Exit" \
	--height=160 --width=200
	exit 1
fi
# Summary Generator
touch $1/sales/summary
echo -e "DEALER NAME --> $our_name" >> $1/sales/summary
echo -e "DEALER TIN --> $our_tin" >> $1/sales/summary
echo -e "RETURN PERIOD --> $(date "+%b" -d $sales_ret_month/01/2016)" >> $1/sales/summary
echo -e "RETURN TYPE --> $sales_ret_type" >> $1/sales/summary
echo -e "ACCOUNT TYPE --> LOCAL SALES" >> $1/sales/summary
echo -e "------------------------------------" >> $1/sales/summary
cat $1/sales/sale_new.csv | awk -F "|" \
'BEGIN{printf("----------GRAND TOTAL----------\n")}{ net=net+$5;tax=tax+$6;others=others+$7;total=total+$8 }\
END{ printf("NET VALUE = %.2f\nTAX VALUE = %.2f\nOTHERS VALUE = %.2f\nTOTAL VALUE = %.2f\n",net,tax,others,total)}'\
>> $1/sales/summary
echo -e "------------------------------------" >> $1/sales/summary
echo -e "TOTAL RECORD COUNT --> $(wc -l < $1/sales/sale_new.csv)" >> $1/sales/summary
echo -e "XML FILE NAME --> $(ls $HOME/LS_GEN_M"$sales_ret_month".xml | basename LS_GEN_M"$sales_ret_month".xml)" >> $1/sales/summary
cat $1/sales/summary | zenity --text-info --title="e-UPaSS Summary" --checkbox="$(echo -e "Save summary to File\n(File Location : HOME directory)")" \
--ok-label="FINISH" --height=450 --width=370
if [ $? -eq 0 ]
then
	cp $1/sales/summary $HOME/sales_summary.txt
fi
rm $1/sales/summary
exit 0
