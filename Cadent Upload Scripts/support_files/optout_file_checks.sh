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
function get_eos_record_count {
	if [ -f ${archive}/Advt_optout_devices_${1}*.csv ]
	then
		if [[ $3 == "optedin" ]]
		then
			count=$(grep $2 ${archive}/Advt_optout_devices_${1}*.csv | grep -c ',"0"')
			echo $count
		elif [[ $3 == "optedout" ]]
		then
			count=$(grep $2 ${archive}/Advt_optout_devices_${1}*.csv | grep -c ',"1"')
			echo $count
		fi
	else
		echo 0
	fi
}

# TiVo is basically not EOS
function get_tivo_record_count {
	if [ -f ${archive}/Advt_optout_devices_${1}*.csv ]
	then
		if [[ $3 == "optedin" ]]
		then
			count=$(grep -v $2 ${archive}/Advt_optout_devices_${1}*.csv | grep -c ',"0"')
			echo $count
		elif [[ $3 == "optedout" ]]
		then
			count=$(grep -v $2 ${archive}/Advt_optout_devices_${1}*.csv | grep -c ',"1"')
			echo $count
		fi
	else
		echo 0
	fi
}

# Get a count of records for each supplied file and compare the numbers to see how different they are.
# If they're too different (but not a complete change we need to set a flag)
function get_optout_file_record_counts {
	echo "" >> $experian_report_file
	echo "EOS Opted In" >> $experian_report_file
	echo "$first_date_formatted	$second_date_formatted" >> $experian_report_file
	echo "===============================================" >> $experian_report_file

	eos_optedin_first_date=$(get_eos_record_count $first_date EOS optedin)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - $eos_optedin_first_date EOS boxes opted in on ${first_date_formatted}"

	eos_optedin_second_date=$(get_eos_record_count $second_date EOS optedin)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - $eos_optedin_second_date EOS boxes opted in on ${second_date_formatted}"

	percentage_change=$(check_percentage_change_in_files $eos_optedin_first_date $eos_optedin_second_date)
	percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
	echo "$eos_optedin_first_date			$eos_optedin_second_date" >> $experian_report_file
	echo "Percentage change = $percentage_change" >> $experian_report_file
	echo "" >> $experian_report_file
	echo "EOS Opted In","$eos_optedin_first_date","$eos_optedin_second_date","$percentage_change" >> $experian_file_report_csv
	worried=$(do_we_need_to_worry_optout $percentage_change_whole_number)

	if [[ $worried == 1 ]]
	then
		echo "Record Count $first_date_formatted	Record Count $second_date_formatted" >> $experian_error_file
		echo "===============================================" >> $experian_error_file
		echo "$eos_optedin_first_date			$eos_optedin_second_date" >> $experian_error_file
		echo "" >> $experian_error_file
		echo "Percentage change = $percentage_change" >> $experian_error_file
		echo "" >> $experian_error_file
	fi

	echo "EOS Opted Out" >> $experian_report_file
	echo "$first_date_formatted	$second_date_formatted" >> $experian_report_file
	echo "===============================================" >> $experian_report_file
	eos_optedout_first_date=$(get_eos_record_count $first_date EOS optedout)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - $eos_optedout_first_date EOS boxes opted out on ${first_date_formatted}"

	eos_optedout_second_date=$(get_eos_record_count $second_date EOS optedout)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - $eos_optedout_second_date EOS boxes opted out on ${second_date_formatted}"

	percentage_change=$(check_percentage_change_in_files $eos_optedout_first_date $eos_optedout_second_date)
	percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
	echo "$eos_optedout_first_date			$eos_optedout_second_date" >> $experian_report_file
	echo "Percentage change = $percentage_change" >> $experian_report_file
	echo "" >> $experian_report_file
	echo "EOS Opted Out","$eos_optedout_first_date","$eos_optedout_second_date","$percentage_change" >> $experian_file_report_csv
	worried=$(do_we_need_to_worry_optout $percentage_change_whole_number)

	if [[ $worried == 1 ]]
	then
		echo "Record Count $first_date_formatted	Record Count $second_date_formatted" >> $experian_error_file
		echo "===============================================" >> $experian_error_file
		echo "$eos_optedout_first_date			$eos_optedout_second_date" >> $experian_error_file
		echo "" >> $experian_error_file
		echo "Percentage change = $percentage_change" >> $experian_error_file
		echo "" >> $experian_error_file
	fi

	echo "TiVo Opted In" >> $experian_report_file
	echo "$first_date_formatted	$second_date_formatted" >> $experian_report_file
	echo "===============================================" >> $experian_report_file
	tivo_optedin_first_date=$(get_tivo_record_count $first_date EOS optedin)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - $eos_optedin_first_date TiVo boxes opted in on ${first_date_formatted}"

	tivo_optedin_second_date=$(get_tivo_record_count $second_date EOS optedin)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - $eos_optedin_second_date TiVo boxes opted in on ${second_date_formatted}"

	percentage_change=$(check_percentage_change_in_files $tivo_optedin_first_date $tivo_optedin_second_date)
	percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
	echo "$tivo_optedin_first_date			$tivo_optedin_second_date" >> $experian_report_file
	echo "Percentage change = $percentage_change" >> $experian_report_file
	echo "" >> $experian_report_file
	echo "TiVo Opted In","$tivo_optedin_first_date","$tivo_optedin_second_date","$percentage_change" >> $experian_file_report_csv
	worried=$(do_we_need_to_worry_optout $percentage_change_whole_number)

	if [[ $worried == 1 ]]
	then
		echo "Record Count $first_date_formatted	Record Count $second_date_formatted" >> $experian_error_file
		echo "===============================================" >> $experian_error_file
		echo "$tivo_optedin_first_date			$tivo_optedin_second_date" >> $experian_error_file
		echo "" >> $experian_error_file
		echo "Percentage change = $percentage_change" >> $experian_error_file
		echo "" >> $experian_error_file
	fi

	echo "TiVo Opted Out" >> $experian_report_file
	echo "$first_date_formatted	$second_date_formatted" >> $experian_report_file
	echo "===============================================" >> $experian_report_file
	tivo_optedout_first_date=$(get_tivo_record_count $first_date EOS optedout)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - $tivo_optedout_first_date TiVo boxes opted out on ${first_date_formatted}"

	tivo_optedout_second_date=$(get_tivo_record_count $second_date EOS optedout)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - $tivo_optedout_second_date TiVo boxes opted out on ${second_date_formatted}"

	percentage_change=$(check_percentage_change_in_files $tivo_optedout_first_date $tivo_optedout_second_date)
	percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
	echo "$tivo_optedout_first_date			$tivo_optedout_second_date" >> $experian_report_file
	echo "Percentage change = $percentage_change" >> $experian_report_file
	echo "" >> $experian_report_file
	echo "TiVo Opted Out","$tivo_optedout_first_date","$tivo_optedout_second_date","$percentage_change" >> $experian_file_report_csv
	worried=$(do_we_need_to_worry_optout $percentage_change_whole_number)

	if [[ $worried == 1 ]]
	then
		echo "Record Count $first_date_formatted	Record Count $second_date_formatted" >> $experian_error_file
		echo "===============================================" >> $experian_error_file
		echo "$tivo_optedout_first_date			$tivo_optedout_second_date" >> $experian_error_file
		echo "" >> $experian_error_file
		echo "Percentage change = $percentage_change" >> $experian_error_file
		echo "" >> $experian_error_file
	fi

}

# Run the checks on today's file and the previously delivered file.
function optout_file_checks {
	first_date=$1
	second_date=$2
	first_date_formatted=$(unfix_date $1)
	second_date_formatted=$(unfix_date $2)
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Check Optout files for consistency"
	# Experian will do pretty much all the data checks. We're just checking to see if we have
	# a sensible number of files delivered, or not.
	echo "Counted Value","$first_date_formatted","$second_date_formatted","Percentage Change" > $experian_file_report_csv
	get_optout_file_record_counts $first_date $second_date
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Audience file consistency check finished"
}