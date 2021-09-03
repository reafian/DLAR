#! /bin/bash

#
# Experian File Checks
#
# Functions to support the checking of the Experian files go here
#
# We use $archive rather than $sent because we'll stop the upload if the variance is too great
# however, just because it changes a lot in one day doesn't meant that's a bad thing. It gives
# AdOps time to investigate though.

# Get a count of records in each file
function get_record_count {
	if [ -f ${archive}/Audience_DLAR_${1}*_1.csv ]
	then
		echo $(awk 'END {print NR}' ${archive}/Audience_DLAR_${1}*)
	else
		echo 0
	fi
}

# Get a count of records for each supplied file and compare the numbers to see how different they are.
# If they're too different (but not a complete change we need to set a flag)
function get_file_record_counts {
	record_count_first_date=$(get_record_count $first_date)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - $record_count_first_date records in the files from ${first_date_formatted}"
	record_count_second_date=$(get_record_count $second_date)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - $record_count_second_date records in the files from ${second_date_formatted}"
	percentage_change=$(check_percentage_change_in_files $record_count_first_date $record_count_second_date)
	if [[ $debug == 1 ]]
	then
		echo experian file record counts percentage change = $percentage_change
	fi
	percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
	#
	# If we need to worry the experian_file_check_status flag wil be set here
	#
	worried=$(do_we_need_to_worry $percentage_change_whole_number)
	echo "Record Count $first_date_formatted	Record Count $second_date_formatted" >> $experian_report_file
	echo "===============================================" >> $experian_report_file
	echo "$record_count_first_date			$record_count_second_date" >> $experian_report_file
	echo "" >> $experian_report_file
	echo "Percentage change = $percentage_change" >> $experian_report_file
	if [[ $worried == 1 ]]
	then
		echo "Record Count $first_date_formatted	Record Count $second_date_formatted" >> $experian_error_file
		echo "===============================================" >> $experian_error_file
		echo "$record_count_first_date			$record_count_second_date" >> $experian_error_file
		echo "" >> $experian_error_file
		echo "Percentage change = $percentage_change" >> $experian_error_file
	fi
	echo "Record Count","$record_count_first_date","$record_count_second_date","$percentage_change" >> $experian_file_report_csv
}

# Count the number of files delivered
function count_files {
	if [ -f $archive/Audience_DLAR_${1}*_1.csv ]
	then
		count=$(ls $archive/Audience_DLAR_${1}*.csv | wc -l | awk '{print $1}')
		echo $count
	else
		echo 0
	fi
}

# Countthe total number of files delivered today compared to last time.
# Set a flag if the variance is too great.
function get_number_of_files_counts {
	file_count_first_date=$(count_files $first_date)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - $file_count_first_date files delivered on $first_date_formatted"
	file_count_second_date=$(count_files $second_date)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - $file_count_second_date files delivered on $second_date_formatted"
	percentage_change=$(check_percentage_change_in_files $file_count_first_date $file_count_second_date)
	percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
	
	#
	# If we need to worry the experian_file_check_status flag wil be set here
	#
	worried=$(do_we_need_to_worry $percentage_change_whole_number)
	echo "File Count $first_date_formatted	File Count $second_date_formatted" >> $experian_report_file
	echo "=============================================" >> $experian_report_file
	echo "$file_count_first_date			$file_count_second_date" >> $experian_report_file
	echo "" >> $experian_report_file
	echo "Percentage change = $percentage_change" >> $experian_report_file
	if [[ $worried == 1 ]]
	then
		echo "File Count $first_date_formatted	File Count $second_date_formatted" >> $experian_error_file
		echo "=============================================" >> $experian_error_file
		echo "$file_count_first_date			$file_count_second_date" >> $experian_error_file
		echo "" >> $experian_error_file
		echo "Percentage change = $percentage_change" >> $experian_error_file
	fi
	echo "File Count","$file_count_first_date","$file_count_second_date","$percentage_change" >> $experian_file_report_csv

}

# Run the checks on today's file and the previously delivered file.
function experian_file_checks {
	first_date=$1
	second_date=$2
	if [[ $debug == 1 ]]
	then
		echo experian file counts first date = $1
		echo experian file counts second date = $2
	fi
	first_date_formatted=$(unfix_date $1)
	second_date_formatted=$(unfix_date $2)
	if [[ $debug == 1 ]]
	then
		echo "experian file counts first date (formatted) = $first_date_formatted"
		echo "experian file counts second date (formatted) = $second_date_formatted"
	fi
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Check Audience files for consistency"
	# Experian will do pretty much all the data checks. We're just checking to see if we have
	# a sensible number of files delivered, or not.
	echo "Counted Value","$first_date_formatted","$second_date_formatted","Percentage Change" > $experian_file_report_csv
	get_file_record_counts $first_date $second_date
#	get_number_of_files_counts $first_date $second_date
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Audience file consistency check finished"
}
