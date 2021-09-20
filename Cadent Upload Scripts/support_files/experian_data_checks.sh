#! /bin/bash

#
# Experian Data Checks
#
# Functions to support the checking of the Experian data go here

# We use $archive rather than $sent because we'll stop the upload if the variance is too great
# however, just because it changes a lot in one day doesn't meant that's a bad thing. It gives
# AdOps time to investigate though.

function import_todays_header_file {
	file=$(ls ${archive}/Audience_DLAR_${first_date}*_1.csv)
	import_file=${file}
	name=$(echo $import_file | rev | cut -d/ -f1 | rev)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Importing - $name"
	$sqlbin $sqldb << END_SQL
.mode csv
.import ${import_file} today
END_SQL
}

function import_yesterdays_header_file {
	# import first file from yesterday with headers
	file=$(ls ${archive}/Audience_DLAR_${second_date}*_1.csv)
	import_file=${file}
	name=$(echo $import_file | rev | cut -d/ -f1 | rev)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Importing - $name"
	$sqlbin $sqldb << END_SQL
.mode csv
.import ${import_file} yesterday
END_SQL
}

function import_todays_files {
	# import remaining files for today
	ls ${archive}/Audience_DLAR_${first_date}*.csv | grep -v _1.csv | while read list
	do
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Importing - $list"

		$sqlbin $sqldb << END_SQL
.mode csv
.header on
.import --skip 1 ${list} today
END_SQL
done
}

function import_yesterdays_files {
	# import remaining files for yesterday
	ls ${archive}/Audience_DLAR_${second_date}*.csv | grep -v _1.csv | while read list
	do
		name=$(echo $list | rev | cut -d/ -f1 | rev)
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Importing - $name"

		$sqlbin $sqldb << END_SQL
.mode csv
.header on
.import --skip 1 ${list} yesterday
END_SQL
done 
}

function import_sql_data {
	import_todays_header_file
	import_todays_files
	import_yesterdays_header_file
	import_yesterdays_files
}

function count_sql_records {
	records_today=$(sqlite3 $sqldb "SELECT count(*) from today")
	records_yesterday=$(sqlite3 $sqldb "SELECT count(*) from yesterday")
	echo records today = ${records_today}, records yesterday = $records_yesterday >> $experian_report_file
	percentage_change=$(check_percentage_change_in_files $records_today $records_yesterday)
	echo "Record counts","$records_today","$records_yesterday","$percentage_change" >> $experian_record_counts_csv
}

function count_hhids {
	householdid_records_today=$(sqlite3 $sqldb "SELECT count(distinct householdid) from today")
	householdid_records_yesterday=$(sqlite3 $sqldb "SELECT count(distinct householdid) from yesterday")
	echo Household IDs today = ${householdid_records_today}, Household IDs yesterday = $householdid_records_yesterday  >> $experian_report_file
	percentage_change=$(check_percentage_change_in_files $householdid_records_today $householdid_records_yesterday)
	echo "Household ID counts","$householdid_records_today","$householdid_records_yesterday","$percentage_change" >> $experian_record_counts_csv
}

function count_records {
	ls ${archive}/Audience_DLAR_*${first_date}*_1.csv ${archive}/Audience_DLAR_*${second_date}*_1.csv | while read list         
	do      
  		cat $list | head -1 | tr ',' '\n' | egrep -v "DEVICEID|HOUSEHOLDID" | tr -d '\r'
	done | sort -u | while read line
	do
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Counting records in $line"
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Counting records in $line" >> $experian_report_file
		count_today=$($sqlbin $sqldb "select count(\"$line\") from today")
		count_yesterday=$($sqlbin $sqldb "select count(\"$line\") from yesterday")
		percentage_change=$(check_percentage_change_in_files $count_today $count_yesterday)
		percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
		#
		# If we need to worry the experian_file_check_status flag wil be set here
		#
		worried=$(do_we_need_to_worry $percentage_change_whole_number)
#		echo "" >> $experian_report_file
#		printf "%-50s\n" $(echo "$line") >> $experian_report_file
#		printf "%50s\n" $(echo "--------------------------------------------------") >> $experian_report_file
#		printf "%-25s %-25s\n" $(echo "${first_date_formatted} ${second_date_formatted}") >> $experian_report_file
#		printf "%25s %25s\n" $(echo "=========================	=========================") >> $experian_report_file
#		printf "%25s %25s\n" $(echo "$count_today	$count_yesterday") >> $experian_report_file
#		echo "" >> $experian_report_file
#		echo "Percentage change = $percentage_change" >> $experian_report_file
#		echo "" >> $experian_report_file
#		echo "" >> $experian_report_file
		if [[ $worried == 1 ]]
		then
			printf "%-50s\n" $(echo "$line") >> $experian_error_file
			printf "%50s\n" $(echo "--------------------------------------------------") >> $experian_error_file
			printf "%-25s %-25s\n" $(echo "${first_date_formatted} $second_date_formatted") >> $experian_error_file
			printf "%25s %25s\n" $(echo "=========================	=========================") >> $experian_error_file
			printf "%25s %25s\n" $(echo "$count_today	$count_yesterday") >> $experian_error_file
			echo "" >> $experian_error_file
			echo "Percentage change = $percentage_change" >> $experian_error_file
			echo "" >> $experian_error_file
			echo "" >> $experian_error_file
		fi
		echo "$line","$count_today","$count_yesterday","$percentage_change" | sed -e "s/\r\n//g" >> $experian_attr_report_csv
	done
}

function count_headers {
	ls ${archive}/Audience_DLAR_*${first_date}*_1.csv ${archive}/Audience_DLAR_*${second_date}*_1.csv | while read list         
	do      
		cat $list | head -1 | tr ',' '\n' | egrep -v "DEVICEID|HOUSEHOLDID"
	done | sort -u | while read line
	do     
    	echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking headers for $line"
    	echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking headers for $line" >> $experian_report_file
    	result=$($sqlbin $sqldb "select distinct \"$line\", count(\"$line\") from today group by \"$line\"")
    	echo "$result" | while read result
    	do
    		item=$(echo $result | cut -d\| -f1)
    		todays_value=$(echo $result | cut -d\| -f2)
    		yesterdays_result=$($sqlbin $sqldb "select distinct \"$line\", count(\"$line\") from yesterday group by \"$line\"")
    		yesterdays_value=$(echo "$yesterdays_result" | grep "^${item}|" | cut -d\| -f2)
    		percentage_change=$(check_percentage_change_in_files $todays_value $yesterdays_value)
    		percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
    		worried=$(do_we_need_to_worry $percentage_change_whole_number)
#    		echo "" >> $experian_report_file
#    		printf "%-50s\n" $(echo "$line") >> $experian_report_file
#    		printf "%-50s\n" $(echo "$item") >> $experian_report_file
#		printf "%50s\n" $(echo "--------------------------------------------------") >> $experian_report_file
#		printf "%-25s %-25s\n" $(echo "${first_date_formatted} ${second_date_formatted}") >> $experian_report_file
#		printf "%25s %25s\n" $(echo "=========================	=========================") >> $experian_report_file
#		printf "%25s %25s\n" $(echo "$todays_value	$yesterdays_value") >> $experian_report_file
#		echo "" >> $experian_report_file
#		echo "Percentage change = $percentage_change" >> $experian_report_file
#		echo "" >> $experian_report_file
#		echo "" >> $experian_report_file
    		if [[ $worried == 1 ]]
    		then
    			echo "" >> $experian_report_file
    			printf "%-50s\n" $(echo "$line") >> $experian_error_file
    			printf "%-50s\n" $(echo "$item") >> $experian_error_file
				printf "%50s\n" $(echo "--------------------------------------------------") >> $experian_error_file
				printf "%-25s %-25s\n" $(echo "${first_date_formatted} ${second_date_formatted}") >> $experian_error_file
				printf "%25s %25s\n" $(echo "=========================	=========================") >> $experian_error_file
				printf "%25s %25s\n" $(echo "$todays_value	$yesterdays_value") >> $experian_error_file
				echo "" >> $experian_error_file
				echo "Percentage change = $percentage_change" >> $experian_error_file
				echo "" >> $experian_error_file
				echo "" >> $experian_error_file
    		fi
		echo \"$line\",\"$item\","$todays_value","$yesterdays_value","$percentage_change" >> $experian_attr_data_report_csv
    	done
	done
}

function check_sql_data {
	echo "Counts","$1","$2",\"Percentage Change\" > $experian_record_counts_csv
	count_sql_records
	count_hhids
	echo "Counts","$1","$2",\"Percentage Change\" > $experian_attr_report_csv
	count_records
	echo "Field","Value","$1","$2",\"Percentage Change\" > $experian_attr_data_report_csv
	count_headers
}

function experian_data_checks {
	first_date=$1
	second_date=$2
	first_date_formatted=$(unfix_date $1)
	second_date_formatted=$(unfix_date $2)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Running checks on the Experian data"
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Running checks on the Experian data" >> $experian_report_file
	import_sql_data
	check_sql_data $first_date_formatted $second_date_formatted
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Finished checking the Experian data"
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Finished checking the Experian data" >> $experian_report_file
	rm -f $sqldb
}
