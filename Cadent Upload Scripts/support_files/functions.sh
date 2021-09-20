#! /bin/bash

#
# Check and create the folders for the scripts
#

# Clear down the contents of the working folders before we start doing stuff
function clear_working_folders {
	if [[ $debug == 1 ]]
	then
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Clearing $working"
		rm -f ${working}/*
	fi
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Clearing $outbox"
	rm -f ${outbox}/*
}

# Check to see if passed fodler exists
function check_if_exists {
	if [[ ! -d $1 ]]
	then
		mkdir -p $1
	fi
}

# Check local folder structure and create if necessary
function check_folder_structure {
	for i in $working $outbox $archive $failed $sent $reports
	do
		check_if_exists $i
	done
}

# Check to see if we have a lock file
function check_for_lock {
	if [[ -f ${1}_${lock_file} ]]
	then
		echo 1
	else
		echo 0
	fi
}

# Create a lock file to stop multiple instances of the program running
function create_lock_file {
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating lock file"
	if [[ ! -f $lock_file ]]
	then
		touch ${1}_${lock_file}
	fi
}

# Remove the lock file
function remove_lock_file {
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing lock file"
	rm -f ${1}_${lock_file}
}

function check_inbox {
	cd $1
	if [[ $(ls | wc -l | awk '{print $1}') > 0 ]]
	then
		donefile=$(ls ${2}*.done 2>/dev/null)
		if [[ $? == 0 ]]
		then
			echo 0
			# We have to use cp rather than mv to cope with the different permissions
			cp -f * $outbox
			archive_files $1 $archive
		else
			echo 1
		fi
	else
		echo 1
	fi
}

# This function moves the source files to the archive or sent directory
function archive_files {
	if [[ -f ${1}/AUDIENCE_FILES.txt ]]
	then
		if [[ $(wc -l ${1}/AUDIENCE_FILES.txt | awk '{print $1}') -gt 0 ]]
		then
			filedate=$(head -1 ${1}/AUDIENCE_FILES.txt | cut -d_ -f3)
			mv -n AUDIENCE_FILES.txt ${2}/AUDIENCE_FILES_${filedate}.txt
			mv -f * $2
		fi
	elif [[ -f ${1}/Advt_optout_devices.txt ]]
	then
		filedate=$(head -1 ${1}/Advt_optout_devices.txt | cut -d_ -f4 | cut -c1-8)
		mv -n Advt_optout_devices.txt ${2}/Advt_optout_devices_${filedate}.txt
		mv -f * $2
	else
		mv -f * $2
	fi

}

# Mail message routine
function send_message {
	if [[ $debug == 1 ]]
	then
		echo "*** send_message dollar 1 (files) = $1"
		echo "*** send_message dollar 2 (prefix)= $2"
		echo "*** send_message dollar 3 (failure status) = $3"
	fi
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending mail"
	if [[ $debug == 1 ]]
	then
		echo send_mail $1 $2 $3
	fi
	rename_reports
	if [[ $3 == "error" ]]
	then
		zipfile=$(zip_files failure)
		if [[ $zipfile != "" ]]
		then
			send_mail $1 $3 $zipfile
		else
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Zipfile creation failed"
		fi
		
	else
		zipfile=$(zip_files success)
		if [[ $debug = 1 ]]
		then
			echo "zipfile = $zipfile"
		fi
		if [[ $zipfile != "" ]]
		then
			send_mail $1 success $zipfile
		else
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Zipfile creation failed"
		fi
		
	fi

	tidy_up
}

function send_mail {
	cd $working
	if [[ $debug == 1 ]]
	then
		echo send_mail dollar 1 = $1
		echo send_mail dollar 2 = $2
		echo send_mail dollar 3 = $3
		ls $3
	fi
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending mail to $send_to"
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending $3"
	message="Hi All, 

Please find attached today's $1 report.

Richard"
	echo "$message" | mailx -a "$3" -s "$1 Delivery Report - $2" -r $reply_to $send_to
}

function rename_reports {
	mv ${working}/report.tmp ${working}/experian_report_${today}.txt
	if [ -f ${working}/error.tmp ]
	then
		mv ${working}/error.tmp ${working}/experian_error_report_${today}.txt
	fi
}

function zip_files {
	cd $working
	zip -q experian_${1}_reports_${today} * -x \*.lock -x \*.raw 2>&1 > /dev/null
	if [[ $? == 0 ]]
	then
		echo experian_${1}_reports_${today}.zip
	fi
}

# Check the text files  This one contains just the names
function check_textfile {
	if [[ $1 == "Audience" ]]
	then
		textfile="AUDIENCE_FILES.txt"
		ls $textfile &> /dev/null
		echo $? $textfile
	elif [[ $1 == "Advt" ]]
	then
		textfile="Advt_optout_devices.txt"
		ls $textfile &> /dev/null
		echo $? $textfile
	fi
}

# Check the number of files in two files is the same
function count_lines_in_files {
	if [[ ! -f $1 ]]
	then
		echo 1
		return
	fi
	length_1=$(wc -l $1 | awk '{print $1}') 
	length_2=$(wc -l $2 | awk '{print $1}') 
	if [[ $length_1 == $length_2 ]]
	then
		echo 0
	else
		echo 1
	fi
}

# Check the text files  We're makking sure the dates are for today
function check_textfile_date {
	if [[ $1 == "Audience" ]]
	then
		textfile="AUDIENCE_FILES.txt"
		cat $textfile | while read list
		do
			given_date=$(echo $list | cut -d_ -f3)
			if [[ $given_date != $today ]]
			then
				# Pass
				echo 1
			fi
		done
	elif [[ $1 == "Advt" ]]
	then
		textfile="Advt_optout_devices.txt"
		cat $textfile | while read list
		do
			given_date=$(echo $list | cut -d_ -f3 | cut -c1-8)
			echo $given_date
		done
	fi
}

# Here we check that all the files have the correct date in
# their filenames
function check_file_dates {
	# Turn off case sensitivity because the Audience files are both Audience
	# and AUDIENCE and that's not good
	shopt -s nocaseglob
	filecount=$(ls ${1}*.txt ${1}*.csv | wc -l | awk '{print $1}')
	datecount=$(ls ${1}*${today}* | wc -l | awk '{print $1}')
	shopt -u nocaseglob
	if [[ $filecount == $datecount ]]
	then
		echo 0
	else
		echo 1
	fi
}

# Here we check that all the files that IT list in their text file
# are actually supplied.
function check_files_exist {
	if [[ $1 == Audience ]]
	then
		listing_file=AUDIENCE_FILES.txt
	elif [[ $1 == Advt ]]
	then
		listing_file=Advt_optout_devices.txt
	fi
	#  local error=0
	while read list
	do
		ls $list &> /dev/null
		if [[ $? != 0 ]]
		then
			echo 1
		fi
	done < $listing_file
}

# Check the sizes of the files delivered match what IT claim for the sizes
function check_file_sizes {
	local error=0
	while read list
	do
		records=$(echo $list | awk '{print $1}')
		file=$(echo $list | awk '{print $2}')
		linecount=$(wc -l $file | awk '{print $1}')
		count_without_headers=$(echo $(($linecount - 1)))
		if [[ $count_without_headers != $records ]]
		then
			error=1
		fi
	done < ${1}
	if [[ $error == 1 ]]
	then
		local count=1
		echo $count
	else
		local count=0
		echo $count
	fi
}

# Check for the filetypes that Cadent supports
function check_file_type {
	local error=0
	while read list
	do
		filetype=$(file --mime-encoding $list | cut -d: -f2 | tr '[:lower:]' '[:upper:]' | awk '{print $1}')
		if [[ "$filetype" =~ "UTF-8" ]]
		then
			error=0
		elif [[ "$filetype" == "ISO-8859" ]]
		then
			error=0
		elif [[ "$filetype" == "ASCII" ]]
		then
			error=0
		elif [[ "$filetype" == "US-ASCII" ]]
		then
			error=0
		else
			error=1
		fi
	done < ${1}
	echo $error
}

# Here we check the files that IT have sent us before we send them over to Cadent
function check_outbox_consistency {
	# Do all the work to check the files and then process the accordingly
	cd $outbox
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking outbox"
	if [[ $(ls | wc -l | awk '{print $1}') > 0 ]]
	then
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Files moved to outbox"
		donefile=$(ls ${2}*.done 2>/dev/null)
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Time to start checking the files"

		# If we have a textfile we're good, otherwise we need to fail the files
		# The text files defines all the files we should receive in the delivery
		# so it's kind of important that it's accurate. 
		check_textfile_value=$(check_textfile $2)
		check_textfile_status=$(echo $check_textfile_value | awk '{print $1}')
		text_file=$(echo $check_textfile_value | awk '{print $2}')
		if [[ $check_textfile_status == 0 ]]
		then
			echo "$(date "+%Y-%m-%d %H:%M:%S") - ${text_file} is found!"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Supporting ${text_file} file has been found" >> $experian_report_file
		else
			echo "$(date "+%Y-%m-%d %H:%M:%S") - ${text_file} is not found!"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Supporting ${text_file} file has not been found" >> $experian_report_file
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Supporting ${text_file} file has not been found" >> $experian_error_file
			return
		fi

		# The number of lines in the two supporting text files sent by IT should be consistent so let's check that
		count_lines_in_files_status=$(count_lines_in_files $(basename $donefile .done).txt $text_file)
		if [[ $count_lines_in_files_status == 1 ]]
		then
			echo "$(date "+%Y-%m-%d %H:%M:%S") - $(basename $donefile .done).txt and $text_file contain a different number of lines"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - $(basename $donefile .done).txt and $text_file contain a different number of lines - bad" >> $experian_report_file
			echo "$(date "+%Y-%m-%d %H:%M:%S") - $(basename $donefile .done).txt and $text_file contain a different number of lines - bad" >> $experian_error_file
		else
			echo "$(date "+%Y-%m-%d %H:%M:%S") - $(basename $donefile .done).txt and $text_file contain the same number of lines"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - $(basename $donefile .done).txt and $text_file contain the same number of lines - good" >> $experian_report_file
		fi

		# Check the date of the files to make sure we're using today's files
		check_textfile_date=$(check_textfile_date $2)
		if [[ $check_textfile_date == 1 ]]
		then
			echo "$(date "+%Y-%m-%d %H:%M:%S") - ${text_file} is old!"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - $text_file does not contain files for today - bad" >> $experian_report_file
			echo "$(date "+%Y-%m-%d %H:%M:%S") - $text_file does not contain files for today - bad" >> $experian_error_file
			return
		else
			echo "$(date "+%Y-%m-%d %H:%M:%S") - ${text_file} is current!"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - $text_file contains files for today - good" >> $experian_report_file
		fi

		# Check the dates on the files in the inbox
		check_file_dates_status=$(check_file_dates $2)
		if [[ $check_file_dates_status == 1 ]]
		then
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Files have bad dates"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Supplied $3 files are not dated today - bad" >> $experian_report_file
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Supplied $3 files are not dated today - bad" >> $experian_error_file
			return
		else
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Files have good dates"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Supplied $3 files are dated today - good" >> $experian_report_file
		fi

		# Check we have the files we're supposed to have
		check_files_exist_status=$(check_files_exist $2)
		if [[ $check_files_exist_status == 1 ]]
		then
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all files are present"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all stated $3 files are present - bad" >> $experian_report_file
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all stated $3 files are present - bad" >> $experian_error_file
			returnn
		else
			echo "$(date "+%Y-%m-%d %H:%M:%S") - All files appear to exist"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - All stated $3 files are present - good" >> $experian_report_file
		fi

		# Now we check to see if the sizes supplied by match the actual filesizes for the siles
		file_size_check_status=$(check_file_sizes $(basename $donefile .done).txt $2)
		if [[ $file_size_check_status == 0 ]]
		then
			echo "$(date "+%Y-%m-%d %H:%M:%S") - All $3 files appear to have the correct size"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - All $3 files have the correct size - good" >> $experian_report_file
		else
			echo "$(date "+%Y-%m-%d %H:%M:%S") - A file has the wrong size!"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all $3 files have the correct size - bad" >> $experian_report_file
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all $3 files have the correct size - bad" >> $experian_error_file
			return
		fi

		# Ensure the files delivered by IT are in the correct format
		check_file_type_status=$(check_file_type $text_file)
		if [[ $check_file_type_status == 0 ]]
		then
			echo "$(date "+%Y-%m-%d %H:%M:%S") - File types are good and convertable (if necessary)"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - All $3 files are in the correct format or can be converted - good" >> $experian_report_file
		else
			echo "$(date "+%Y-%m-%d %H:%M:%S") - An $3 file has an unconvertable type!"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all $3 files are in the correct format or can be converted - bad" >> $experian_report_file
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all $3 files are in the correct format or can be converted - bad" >> $experian_error_file
			return
		fi

	fi
}

function check_failure_status {
	if [[ -f $experian_error_file ]]
	then
		echo "$(date "+%Y-%m-%d %H:%M:%S") - We have a failure"
		fail_files $1 $2 $3
	fi
}

# Fail the files and tidy up
function fail_files {
	echo "$(date "+%Y-%m-%d %H:%M:%S") - We have a failure. All files will be failed"
	archive_files $outbox $failed
	clean_inbox
	remove_lock_file
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Exiting"
	echo "$(date "+%Y-%m-%d %H:%M:%S") - All done - exit" >> $experian_report_file
	send_message $1 $2 $3
	break
}

function clean_inbox {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing files from inbox" 
  rm -f ${inbox}/*
}

# Check the percentage change in the delivered files
function check_percentage_change_in_files {
	# $1 = today
	# $2 = yesterday
	if [[ $1 == 0 || $1 == "" ]]
	then
		echo "-100"
	elif [[ $2 == 0 || $2 == "" ]]
	then
		echo "+100"
	elif [[ $1 == $2 ]]
	then
		echo "0"
	else
		change=$(bc <<< "scale=10; ((($1-$2)/$1)*100)")
		percent=$(printf "%0.10f\n" $change)
		echo $percent
	fi
}

# If the percentage change is greater than the amount we need to worry about
# we need to fail the files and, probably, send a notification email.
function do_we_need_to_worry {
	if [[ $percentage_change_whole_number -ge $min_percent_to_worry_about ]] && [[ $percentage_change_whole_number -le $max_percent_to_worry_about ]]
	then
		echo 1
	else
		echo 0
	fi
}

# If the percentage change is greater than the amount we need to worry about
# we need to fail the files and, probably, send a notification email.
function do_we_need_to_worry_optout {
	if [[ $percentage_change_whole_number -ge $max_optout_change ]]
	then
		echo 1
	else
		echo 0
	fi
}

# Turn the date into a more readable format
function unfix_date {
	echo $(echo "$1" | sed 's/^\(.\{4\}\)/\1-/' | sed 's/^\(.\{7\}\)/\1-/')
}

function check_error_failure_status {
  # Setting a flag doesn't seem to work so we'll check to see if there's an 
  # error file.
  if [[ -f $experian_error_file ]]
  then
    check_failure_status $1 $2 $3
  fi
}

function process_files {
  donefile=$(ls ${1}*.done 2>/dev/null)
  basefile=$(basename $donefile .done)
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Processing ${basefile}.txt"
  if [[ $1 == "Audience" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating delete file"
    create_delete $donefile
    while read list
    do
      file=$(echo $list | awk '{print $2}')
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Editing $file to remove to trailist data"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Editing $file to remove to trailist data" >> $experian_report_file
      remove_trial_data $file $1
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Editing $file to remove to old boxes"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Editing $file to remove to old boxes" >> $experian_report_file
      remove_delete_data $file $1
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Editing $file to remove Experian key (if present)"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Editing $file to remove Experian key (if present)" >> $experian_report_file
      remove_experian_keys $file $1
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting $file to proper enconding (if necessary)" >> $experian_report_file
      utf_converter $file
    done < ${basefile}.txt
  elif [[ $1 == "Advt" ]]
  then
    while read list
    do
      file=$(echo $list | awk '{print $2}')
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting $file to proper enconding (if necessary)"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting $file to proper enconding (if necessary)" >> $experian_report_file
      utf_converter $file
    done < ${basefile}.txt
  fi
  # remove raw delete file now we've processed all the files
  if [ -f ${working}/delete.raw} ]
  then
    rm -f ${working}/delete.raw
  fi
}

function create_delete {
  current_filedate=$(echo $1 | cut -d_ -f4)
  previous_filedate=$(ls -ltr ${sent}/Audience_DLAR*_1.csv 2> /dev/null | grep -v $today | awk '{print $9}' | cut -d_ -f3 | tail -1)

  cat Audience_DLAR_${current_filedate}*.csv | grep -v DEVICE | cut -d, -f2 | sort >> $working/${current_filedate}.txt
  # We use sent rather than archive because sent is what was actually sent to Cadent so they're the ones we need to delete from
  cat ${sent}/Audience_DLAR_${previous_filedate}*.csv | grep -v DEVICE | cut -d, -f2 | sort >> $working/${previous_filedate}.txt
  diff -y ${working}/${current_filedate}.txt ${working}/${previous_filedate}.txt  | grep '<' | awk '{print $1}' >> $working/DLAR_${current_filedate}_delete.txt
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete list contains $(wc -l ${working}/DLAR_${current_filedate}_delete.txt | awk '{print $1}') records"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete list contains $(wc -l ${working}/DLAR_${current_filedate}_delete.txt | awk '{print $1}') records" >> $experian_report_file

#  rm ${working}/${current_filedate}.txt
#  rm ${working}/${previous_filedate}.txt

  if [[ $(wc -l ${working}/DLAR_${current_filedate}_delete.txt | awk '{print $1}') -ge 1 ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Copying delete file to archive"
    cp ${working}/DLAR_${current_filedate}_delete.txt $working/delete.raw
    echo "DEVICEID,Action" > ${working}/DLAR_${current_filedate}_delete.csv
    cat $working/delete.raw | while read line
    do
      echo ${line},delete >> ${working}/DLAR_${current_filedate}_delete.csv
    done
    rm ${working}/DLAR_${current_filedate}_delete.txt
    cp ${working}/DLAR_${current_filedate}_delete.csv $archive
    cp ${working}/DLAR_${current_filedate}_delete.csv $outbox
    rm ${working}/DLAR_${current_filedate}_delete.csv
  else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete file too small, not uploading to Cadent"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete file too small, not uploading to Cadent" >> $experian_report_file
  fi
}

# Remove Trial Data
remove_trial_data() {
  file=$1
  if [[ $2 == "Audience" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Searching for trial boxes"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing trialist data from Experian file $file"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing trialist data from Experian file $file" >> $experian_report_file
    grep -vf $support_files/MAC_list.txt $file > adjusted.tmp
    mv adjusted.tmp ${file}
  fi
}

# Remove DELETE Data
remove_delete_data() {
  file=$1
  if [[ $2 == "Audience" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Searching for boxes to delete"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing delete data from Experian file $file"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing delete data from Experian file $file" >> $experian_report_file
    grep -vf ${working}/delete.raw $file > adjusted.tmp
    mv adjusted.tmp ${file}
  fi
}

# This shouldn't be necessary anymore but if for some reason IT stuff up and put the keys back in
# then we can remove them, otherwise it just sits there costing nothing
function remove_experian_keys {
  if [[ $2 == "Audience" ]]
  then
    if head -1 $1 | grep -q EXPERIANHOUSEHOLDKEY
    then
      experianhhid=$(awk '$1 == "EXPERIANHOUSEHOLDKEY" {print NR;exit} ' RS="," $1)
      cat $1 | cut -d, -f-$(($experianhhid-1)),$(($experianhhid+1))- > adjusted.tmp
      mv adjusted.tmp ${file}
    fi
  fi
}

# We have to convert the files to UTF-8 (if they're not already)
function utf_converter {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting $1"
  filetype=$(file --mime-encoding ${1} | cut -d: -f2 | awk '{print $1}' | tr '[:lower:]' '[:upper:]')
  # On the off-chance that we ever receive a UTF-8 file we dont' need to do anything
  if [[ "$filetype" =~ "UTF-8" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is UTF-8"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is UTF-8" >> $experian_report_file
    echo "$(date "+%Y-%m-%d %H:%M:%S") - No conversion necessary"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - No conversion necessary" >> $experian_report_file
  # This is what IT usually deliver the files as
  elif [[ "$filetype" == "ISO-8859" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is an ISO-8859 variant - using ISO-8859-1"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is an ISO-8859 variant - using ISO-8859-1" >> $experian_report_file
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting to UTF-8"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting to UTF-8" >> $experian_report_file
    iconv -f ISO-8859-1 -t UTF-8 $1 > output.txt
    mv output.txt $1
  # This is just a paranoia value
  elif [[ "$filetype" == "ASCII" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is ASCII"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is ASCII" >> $experian_report_file
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting to UTF-8"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting to UTF-8" >> $experian_report_file
    iconv -f ASCII -t UTF-8 $1 > output.txt
    mv output.txt $1
  elif [[ "$filetype" == "US-ASCII" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is US-ASCII"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is US-ASCII" >> $experian_report_file
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting to UTF-8"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting to UTF-8" >> $experian_report_file
    iconv -f US-ASCII -t UTF-8 $1 > output.txt
    mv output.txt $1
  fi
}

# Are we inside the delivery window
function check_delivery_ability_window {
	time_check_status=$(time_check)
	if [[ $time_check_status == 0 ]]
 	then
        echo "$(date "+%Y-%m-%d %H:%M:%S") - Cadent can process these files today, continuing"
        echo "$(date "+%Y-%m-%d %H:%M:%S") - Cadent can process these files today - sending to Cadent" >> $experian_report_file
    else
        echo "$(date "+%Y-%m-%d %H:%M:%S") - It's too late to send the files to Cadent as they will not be processed today"
        echo "$(date "+%Y-%m-%d %H:%M:%S") - Cadent cannot process these files today - not sending" >> $experian_report_file
        echo "$(date "+%Y-%m-%d %H:%M:%S") - Cadent cannot process these files today - not sending" >> $experian_error_file
    fi
}

# Quick check on the time to see if we can upload to Cadent before
# Cadent start their ingest
function time_check {
 	date_now=$(date +%H:%M)
 	if [[ $date_now > $last_upload_time ]]
 	then
    	echo 1   
 	else
		echo 0
 	fi
}

# This is where we start to upload the files to Cadent.
# We deliberately limit what we sent so no spurious data gets sent by chance.
# Random stuff can be sent by hand.
function upload_files_to_cadent {
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Time to send the files to Cadent"
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Time to send the files to Cadent" >> $experian_report_file
	cd $outbox
	if [[ $1 == "Audience" ]]
	then
		# If we're uploading Audience data then we have the audience files 
		# but now we have a delete file too
		file=AUDIENCE_FILES.txt
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading files from $file"
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading files from $file" >> $experian_report_file
		process_upload_file $file $1

		if [[ -f DLAR_${today}_delete.csv ]]
		then
			process_upload_file DLAR_${today}_delete.csv
			archive_files $outbox $sent
		else
			archive_files $outbox $sent
		fi
	elif [[ $1 == "Advt" ]]
	then
		# For the opt-out files we only have the opt-out files. Nothing else should go
		file=Advt_optout_devices.txt
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading files from $file"
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading files from $file" >> $experian_report_file
		process_upload_file $file $1
		archive_files $outbox $sent
	else
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Something appears to have gone wrong"
		echo "Failed to send Experian files to Cadent" >> $experian_report_file
		echo "Failed to send Experian files to Cadent" >> $experian_error_file
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Exiting"
#		check_upload_failure_status
	fi
}

# Here we iterate through the file that contains the list of files
# For opt-out this will only ever be one line but for the audience data it
# will increase over time.
function process_upload_file {
	# $1 = index file
	# $2 = Audience or Advt
	if [[ $2 ]]
	then
		cat $1 | while read list
		do
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading $list"
			echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading $list" >> $experian_report_file
			upload_to_cadent $list $2
			if [[ $upload_fail_status == 1 ]]
			then
				echo "$(date "+%Y-%m-%d %H:%M:%S") - We have upload errors with the Cadent data."
				cadent_delivery_failure_status $upload_status cadent_delivery
				break
			fi
		done
		echo "Local file sizes match the file sizes on Cadent - files delivered successfully" >> $experian_report_file
  	echo "" >> $experian_report_file
	elif [[ "$1" == "DLAR_${today}_delete.csv" ]]
	then
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading delete file"
		echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading delete file" >> $experian_report_file
		upload_to_cadent DLAR_${today}_delete.csv
	fi

}

function upload_to_cadent {
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Changing permissions on $1"
	chmod 666 $1
	echo "$(date "+%Y-%m-%d %H:%M:%S") - sftp $1 $cadent_user@${cadent_server}:${waiting}"
	sftp_file $1 $2
  if [[ $upload_fail_status == 1 ]]
  then
  	echo "$(date "+%Y-%m-%d %H:%M:%S") - delete all uploaded $2 files"
  	echo "Local file sizes do not match the file sizes on Cadent - file delivery failed" >> $experian_report_file
  	echo "Local file sizes do not match the file sizes on Cadent - file delivery failed" >> $experian_error_file
  	remove_uploaded_files $2
  	return $upload_fail_status
  fi
}

function cadent_delivery_failure_status {
  check_failure_status 1 $1
}

function do_sftp {
	echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading $1"
	sftp $cadent_user@$cadent_server << EOF
	cd waiting
	put -p $1 ${base}.tmp
  rename ${base}.tmp ${base}.csv
EOF
}

function sftp_file {
	if [[ $2 ]]
	then
		base=$(basename $1 .csv)
		today=$(date +%Y%m%d)
		if [[ $2 == "Audience" ]]
  	then
    	date_name=$(echo $base | cut -d_ -f3)
  	fi
  	if [[ $2 == "Advt" ]]
  	then
    	date_name=$(echo $base | cut -d_ -f4 | cut -c1-8)
  	fi
		if [[ $date_name == $today ]]
		then
			do_sftp $1
  	fi
  	sftp_check ${base}.csv
  else
  	base=$(basename $1 .csv)
  	do_sftp $1
  	sftp_check $1
  fi
}

function sftp_check {
	local_size=$(ls -l $1 | awk '{print $5}')
	remote_size_and_name=$(get_sftp_size $1 | awk '{print $5 " " $9}')
	remote_size=$(echo $remote_size_and_name | awk '{print $1}')
	echo "$(date "+%Y-%m-%d %H:%M:%S") - local file size = ${local_size}, remote file size = ${remote_size}"
	if [[ $local_size != $remote_size ]]
	then
		upload_fail_status=1
	else
		upload_fail_status=0
		echo "$(date "+%Y-%m-%d %H:%M:%S") - File sizes match, delivery was successful"
		echo "$(date "+%Y-%m-%d %H:%M:%S") - File sizes match, delivery was successful" >> $experian_report_file
	fi
}

function remove_uploaded_files {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing uploaded files"
      sftp $cadent_user@$cadent_server << EOF
      cd waiting
      rm ${1}*.csv
EOF
}

function get_sftp_size {
	sftp $cadent_user@$cadent_server << EOF
	cd waiting
	ls -l $1
EOF
}

function tidy_up {
	cd $working
	rm -f *.zip
	rm -f *
}
