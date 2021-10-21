# Check to see if passed fodler exists
function check_if_exists {
  if [[ ! -d $1 ]]
  then
    mkdir -p $1 2>/dev/null
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
  if [ -f ${working}/${1}_${lock_file} ]
  then
    echo 1
  else
    echo 0
  fi
}

# Create a lock file to stop multiple instances of the program running
function create_lock_file {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating lock file"
  if [ ! -f ${working}/${1}_$lock_file ]
  then
    touch ${working}/${1}_${lock_file}
  fi
}

# Remove the lock file
function remove_lock_file {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing lock file"
  rm -f ${working}/${1}_${lock_file}
}

function prepare_outbox {
  if [[ $1 == "Audience" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing old Audience files"
    rm -f ${outbox}/${1}*
    rm -f ${outbox}/AUDIENCE*
    rm -f ${outbox}/DLAR*
  fi
  if [[ $1 == "Advt" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing old optout files"
    rm -f ${outbox}/${1}*
  fi
} 

function tidy_up {
  cd $working
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Deleting old working $1 files"
  rm -f ${1}*.zip
  rm -f ${1}*.txt
  rm -f ${1}*.tmp
  rm -f ${1}*.csv
}

# This function moves the source files to the archive or sent directory
function archive_files {
  if [ -f ${1}/AUDIENCE_FILES.txt ]
  then
    if [[ $(wc -l ${1}/AUDIENCE_FILES.txt | awk '{print $1}') -gt 0 ]]
    then
      filedate=$(head -1 ${1}/AUDIENCE_FILES.txt | cut -d_ -f3)
      mv -f AUDIENCE_FILES.txt ${2}/AUDIENCE_FILES_${filedate}.txt
      mv -f Audience* $2
    fi
  elif [ -f ${1}/Advt_optout_devices.txt ]
  then
    filedate=$(head -1 ${1}/Advt_optout_devices.txt | cut -d_ -f4 | cut -c1-8)
    mv -n Advt_optout_devices.txt ${2}/Advt_optout_devices_${filedate}.txt
    mv -f Advt* $2
  else
    mv -f * $2
  fi
}

# This function checks to see whether the IT delivery is complete (we're checking whether IT think they've finished
# sending us stuff.) We archive everything they send us 'as is' and then perform the checks on the files we copy to 
# the outbox
function check_inbox {
  # Move the delivered files to the working directory if the .done file exists
  failure_status=0
  cd $1
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking inbox"
  if [[ $(ls | wc -l | awk '{print $1}') > 0 ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Files found, looking for 'done' file"
    donefile=$(ls ${2}*.done 2>/dev/null)
    if [[ $? == 0 ]]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - 'done' file found - file transfer appears complete"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Copy files to outbox for checking and sending"
      # We have to use cp rather than mv to cope with the different permissions
      if [[ $2 == "Audience" ]]
      then
        if [[ $(ls *${today}*csv 2>/dev/null | awk '{print $1}') > 0 ]]
        then
          cp -f *${today}* $outbox
          cp -f AUDIENCE_FILES.txt $outbox
          # archive the actual source files received
          archive_files $inbox $archive
          failure_status=0
        else
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Files are old. Failing"
          mv Audience_DLAR* $failed
          mv AUDIENCE* $failed
          failure_status=1
        fi
      elif [[ $2 == "Advt" ]]
      then
        if [[ $(ls *${today}*csv 2>/dev/null | awk '{print $1}') > 0 ]]
        then
          cp -f *${today}* $outbox
          cp -f Advt_optout_devices.txt $outbox 2>/dev/null
          # archive the actual source files received
          archive_files $inbox $archive
          failure_status=0
        else
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Files are old. Failing"
          mv Advt* $failed
          failure_status=1
        fi
      fi
    else
      echo "$(date "+%Y-%m-%d %H:%M:%S") - No 'done' file found - no transfer happened or not complete"
      failure_status=1
    fi
  else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - No files found"
    failure_status=1
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
  if [ ! -f $1 ]
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
  filecount=$(ls ${1}*.txt ${1}*.csv 2>/dev/null | wc -l | awk '{print $1}')
  datecount=$(ls ${1}*${today}* 2>/dev/null | wc -l | awk '{print $1}')
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
    if [[ $debug == 1 ]]
    then
      echo file = $file, records = $records, count = $count_without_headers >> $experian_error_file
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
  failure_status=0
  cd $1
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking outbox (${1})"
  if [[ $(ls | wc -l | awk '{print $1}') > 0 ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Files moved to outbox"
    donefile=$(ls ${2}*.done | tail -1 2>/dev/null)
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Donefile = $donefile"
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
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Supporting ${text_file} file has been found" >> ${working}/${files}_$experian_report_file
    else
      echo "$(date "+%Y-%m-%d %H:%M:%S") - ${text_file} is not found!"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Supporting ${text_file} file has not been found" >> ${working}/${files}_$experian_report_file
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Supporting ${text_file} file has not been found" >> $experian_error_file
      failure_status=1
    fi

    # The number of lines in the two supporting text files sent by IT should be consistent so let's check that
    count_lines_in_files_status=$(count_lines_in_files $(basename $donefile .done).txt $text_file)
    if [[ $count_lines_in_files_status == 1 ]]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - $(basename $donefile .done).txt and $text_file contain a different number of lines"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - $(basename $donefile .done).txt and $text_file contain a different number of lines - bad" >> ${working}/${files}_$experian_report_file
      echo "$(date "+%Y-%m-%d %H:%M:%S") - $(basename $donefile .done).txt and $text_file contain a different number of lines - bad" >> $experian_error_file
      failure_status=1
    else
      echo "$(date "+%Y-%m-%d %H:%M:%S") - $(basename $donefile .done).txt and $text_file contain the same number of lines"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - $(basename $donefile .done).txt and $text_file contain the same number of lines - good" >> ${working}/${files}_$experian_report_file
    fi

    # Check the date of the files to make sure we're using today's files
    check_textfile_date=$(check_textfile_date $2)
    if [[ $check_textfile_date == 1 ]]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - ${text_file} is old!"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - $text_file does not contain files for today - bad" >> ${working}/${files}_$experian_report_file
      echo "$(date "+%Y-%m-%d %H:%M:%S") - $text_file does not contain files for today - bad" >> $experian_error_file
      failure_status=1
    else
      echo "$(date "+%Y-%m-%d %H:%M:%S") - ${text_file} is present!"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - $text_file is present - good" >> ${working}/${files}_$experian_report_file
    fi

    # Check we have the files we're supposed to have
    check_files_exist_status=$(check_files_exist $2)
    if [[ $check_files_exist_status == 1 ]]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all files are present"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all stated $3 files are present - bad" >> ${working}/${files}_$experian_report_file
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all stated $3 files are present - bad" >> $experian_error_file
      failure_status=1
    else
      echo "$(date "+%Y-%m-%d %H:%M:%S") - All files appear to exist"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - All stated $3 files are present - good" >> ${working}/${files}_$experian_report_file
    fi

    # Now we check to see if the sizes supplied by match the actual filesizes for the siles
    file_size_check_status=$(check_file_sizes $(basename $donefile .done).txt $2)
    if [[ $file_size_check_status == 0 ]]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - All $3 files appear to have the correct size"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - All $3 files have the correct size - good" >> ${working}/${files}_$experian_report_file
    else
      echo "$(date "+%Y-%m-%d %H:%M:%S") - A file has the wrong size!"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all $3 files have the correct size - bad" >> ${working}/${files}_$experian_report_file
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all $3 files have the correct size - bad" >> $experian_error_file
      failure_status=1
    fi

    # Ensure the files delivered by IT are in the correct format
    check_file_type_status=$(check_file_type $text_file)
    if [[ $check_file_type_status == 0 ]]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - File types are good and convertable (if necessary)"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - All $3 files are in the correct format or can be converted - good" >> ${working}/${files}_$experian_report_file
    else
      echo "$(date "+%Y-%m-%d %H:%M:%S") - An $3 file has an unconvertable type!"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all $3 files are in the correct format or can be converted - bad" >> ${working}/${files}_$experian_report_file
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Not all $3 files are in the correct format or can be converted - bad" >> $experian_error_file
      failure_status=1
    fi
  fi
}

# Fail the files and tidy up
function fail_files {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - We have a failure. All files will be failed"
  archive_files $outbox $failed
  remove_lock_file $1
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Exiting"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - $1 done - exit" >> ${working}/${files}_$experian_report_file
  send_message $1 $2 $3
  break
}

function check_failure_status {
  if [ -f $experian_error_file ]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - We have a failure"
    fail_files $1 $2 $3
  fi
}

function cadent_delivery_failure_status {
  check_failure_status $1 $2 $3
}

function check_error_failure_status {
  # Setting a flag doesn't seem to work so we'll check to see if there's an 
  # error file.
  if [ -f ${working}/${files}_$experian_error_file ]
  then
    check_failure_status $1 $2 $3
  fi
}

function rename_reports {
  if [ -f ${working}/${files}_$experian_report_file ]
  then
    cp ${working}/${files}_$experian_report_file ${reports}/${1}_report_${today}.txt
    mv ${working}/${files}_$experian_report_file ${working}/${1}_report_${today}.txt
  fi
  if [ -f ${working}/error.tmp ]
  then
    cp $experian_error_file ${working}/${1}_error_report_${today}.txt
    mv $experian_error_file ${reports}/${1}_error_report_${today}.txt
  fi
  if [ -f ${working}/${files}_file_report.csv ]
  then
    cp ${working}/${files}_file_report.csv ${working}/${1}_file_report_${today}.csv
    mv ${working}/${files}_file_report.csv $reports/${1}_file_report_${today}.csv
  fi
  if [ -f ${working}/${files}_$experian_record_counts_csv ]
  then
    cp ${working}/${files}_$experian_record_counts_csv ${reports}/${files}_${experian_record_counts_csv}_${today}.csv
    mv ${working}/${files}_$experian_record_counts_csv ${files}_${experian_record_counts_csv}_${today}.csv
  fi
  if [ -f ${working}/${files}_$experian_file_report_csv ]
  then
    cp ${working}/${files}_$experian_file_report_csv ${reports}/${files}_${experian_file_report_csv}_${today}.csv
    mv ${working}/${files}_$experian_file_report_csv ${files}_${experian_file_report_csv}_${today}.csv
  fi
  if [ -f ${working}/${files}_$experian_attr_report_csv ]
  then
    cp ${working}/${files}_$experian_attr_report_csv ${reports}/${files}_${experian_attr_report_csv}_${today}.csv
    mv ${working}/${files}_$experian_attr_report_csv ${files}_${experian_attr_report_csv}_${today}.csv
  fi
  if [ -f ${working}/${files}_$experian_attr_data_report_csv ]
  then
    cp ${working}/${files}_$experian_attr_data_report_csv ${reports}/${files}_${experian_attr_data_report_csv}_${today}.csv
    mv ${working}/${files}_$experian_attr_data_report_csv ${files}_${experian_attr_data_report_csv}_${today}.csv
  fi
}

function zip_files {
  cd $working
  zip -q ${1}_${2}_reports_${today} ${1}* ${files}* -x \*.lock -x \*.raw -x \*.db -x \*.tmp 2>&1 > /dev/null
  if [[ $? == 0 ]]
  then
    echo ${1}_${2}_reports_${today}.zip
  fi
}

function send_mail {
  cd $working
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending mail to $send_to"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending $3"
  message="Hi All, 

Please find attached today's $1 report.

Richard"
  echo "$message" | mailx -a "$3" -s "$1 Delivery Report - $2" -r $reply_to $send_to
}

# Mail message routine
function send_message {
  rename_reports $1
  if [ -f ${working}/${files}_*error* ]
  then
    zipfile=$(zip_files $1 failure)
    if [[ $zipfile != "" ]]
    then
      send_mail $1 failure $zipfile
    else
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Zipfile creation failed"
    fi
  else
    zipfile=$(zip_files $1 success)
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
}

# Turn the date into a more readable format
function unfix_date {
  echo $(echo "$1" | sed 's/^\(.\{4\}\)/\1-/' | sed 's/^\(.\{7\}\)/\1-/')
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

# Here we create the Audience data delete file, this is different from the CACI delete file because of the delay in the flow
function create_delete {
  current_filedate=$(echo $1 | cut -d_ -f4)
  previous_filedate=$(ls -ltr ${sent}/Audience_DLAR*_1.csv 2> /dev/null | grep -v $today | tail -1 | awk '{print $9}' | cut -d_ -f3)

  echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating box list for $current_filedate"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating box list for $current_filedate" >> ${working}/${files}_$experian_report_file
  cat ${archive}/Audience_DLAR_${current_filedate}*.csv | grep -v DEVICE | cut -d, -f2 | sort >> $working/${current_filedate}.txt
  # We use sent rather than archive because sent is what was actually sent to Cadent so they're the ones we need to delete from
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating box list for $previous_filedate"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating box list for $previous_filedate" >> ${working}/${files}_$experian_report_file
  cat ${sent}/Audience_DLAR_${previous_filedate}*.csv | grep -v DEVICE | cut -d, -f2 | sort >> $working/${previous_filedate}.txt
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating diff file"
  diff -y ${working}/${current_filedate}.txt ${working}/${previous_filedate}.txt  | grep '>' | awk '{print $2}' >> $working/DLAR_${current_filedate}_delete.txt
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete list contains $(wc -l ${working}/DLAR_${current_filedate}_delete.txt | awk '{print $1}') records"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete list contains $(wc -l ${working}/DLAR_${current_filedate}_delete.txt | awk '{print $1}') records" >> ${working}/${files}_$experian_report_file

  rm ${working}/${current_filedate}.txt
  rm ${working}/${previous_filedate}.txt

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
ls DLAR_${current_filedate}_delete.csv
    rm ${working}/DLAR_${current_filedate}_delete.csv
    rm ${working}/delete.raw
  else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete file too small, not uploading to Cadent"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete file too small, not uploading to Cadent" >> ${working}/${files}_$experian_report_file
  fi
}

# Remove Trial Data
function remove_trial_data {
  file=$1
  if [[ $2 == "Audience" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Searching for trial boxes"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing trialist data from Experian file $file"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing trialist data from Experian file $file" >> ${working}/${files}_$experian_report_file
    grep -vf $support_files/MAC_list.txt $file > adjusted.tmp
    mv adjusted.tmp ${file}
  fi
}

# Remove Delete Data
function remove_delete_data {
  file=$1
  if [[ $2 == "Audience" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Searching for boxes to delete"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing delete data from Experian file $file"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing delete data from Experian file $file" >> ${working}/${files}_$experian_report_file
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
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is UTF-8" >> ${working}/${files}_$experian_report_file
    echo "$(date "+%Y-%m-%d %H:%M:%S") - No conversion necessary"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - No conversion necessary" >> ${working}/${files}_$experian_report_file
  # This is what IT usually deliver the files as
  elif [[ "$filetype" == "ISO-8859" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is an ISO-8859 variant - using ISO-8859-1"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is an ISO-8859 variant - using ISO-8859-1" >> ${working}/${files}_$experian_report_file
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting to UTF-8"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting to UTF-8" >> ${working}/${files}_$experian_report_file
    iconv -f ISO-8859-1 -t UTF-8 $1 > output.txt
    mv output.txt $1
  # This is just a paranoia value
  elif [[ "$filetype" == "ASCII" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is ASCII"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is ASCII" >> ${working}/${files}_$experian_report_file
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting to UTF-8"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting to UTF-8" >> ${working}/${files}_$experian_report_file
    iconv -f ASCII -t UTF-8 $1 > output.txt
    mv output.txt $1
  elif [[ "$filetype" == "US-ASCII" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is US-ASCII"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Filetype is US-ASCII" >> ${working}/${files}_$experian_report_file
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting to UTF-8"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting to UTF-8" >> ${working}/${files}_$experian_report_file
    iconv -f US-ASCII -t UTF-8 $1 > output.txt
    mv output.txt $1
  fi
}

# This is where we change the data in the files to remove boxes and the rest
function process_files {
  donefile=$(ls ${1}*.done 2>/dev/null)
  if [[ $debug == 1 ]]
  then
    echo in process_files
    echo dollar 1 = $1
    echo current directory = $(pwd)
    echo donefile = $donefile
  fi
  basefile=$(basename $donefile .done)
  if [[ $debug == 1 ]]
  then
    echo basefile = $basefile
  fi
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Processing ${basefile}.txt"
  if [[ $1 == "Audience" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating delete file"
    create_delete $donefile
    while read list
    do
      file=$(echo $list | awk '{print $2}')
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Editing $file to remove to trailist data"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Editing $file to remove to trailist data" >> ${working}/${files}_$experian_report_file
      remove_trial_data $file $1
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Editing $file to remove Experian key (if present)"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Editing $file to remove Experian key (if present)" >> ${working}/${files}_$experian_report_file
      remove_experian_keys $file $1
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting $file to proper enconding (if necessary)" >> ${working}/${files}_$experian_report_file
      utf_converter $file
    done < ${basefile}.txt
  elif [[ $1 == "Advt" ]]
  then
    while read list
    do
      file=$(echo $list | awk '{print $2}')
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting $file to proper enconding (if necessary)"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Converting $file to proper enconding (if necessary)" >> ${working}/${files}_$experian_report_file
      utf_converter $file
    done < ${basefile}.txt
  fi
}

function do_sftp {
  sftp $cadent_user@$cadent_server << EOF
  cd waiting
  put -p $1 ${base}.tmp
  rename ${base}.tmp ${base}.csv
EOF
}

function get_sftp_size {
  sftp $cadent_user@$cadent_server << EOF
  cd waiting
  ls -l $1
EOF
}

function sftp_check {
  local_size=$(ls -l $1 | awk '{print $5}')
  remote_size_and_name=$(get_sftp_size $1 | awk '{print $5 " " $9}')
  remote_size=$(echo $remote_size_and_name | awk '{print $1}')
  echo "$(date "+%Y-%m-%d %H:%M:%S") - local file size = ${local_size}, remote file size = ${remote_size}"
  if [[ $local_size != $remote_size ]]
  then
    echo "Local file sizes do not match the file sizes on Cadent - file delivery failed" >> ${working}/${files}_$experian_report_file
    echo "Local file sizes do not match the file sizes on Cadent - file delivery failed" >> $experian_error_file
  else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - File sizes match, delivery was successful"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - File sizes match, delivery was successful" >> ${working}/${files}_$experian_report_file
  fi
}

function upload_to_cadent {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Changing permissions on $1"
  chmod 666 $1
  echo "$(date "+%Y-%m-%d %H:%M:%S") - sftp $1 $cadent_user@${cadent_server}:${waiting}"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading $1"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading $1" >> ${working}/${files}_$experian_report_file
  base=$(basename $1 .csv)
  do_sftp $1
  sftp_check $1
}

function remove_uploaded_files {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing uploaded file $1"
    sftp $cadent_user@$cadent_server << EOF
    cd waiting
    rm ${1}*.csv
EOF
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
      upload_to_cadent $list
    done
  elif [[ "$1" == "DLAR_${today}_delete.csv" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading delete file to Cadent"
    upload_to_cadent DLAR_${today}_delete.csv
  fi
  if [ -f $experian_error_file ]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - An error has occurred, deleting $2 files" >> ${working}/${files}_$experian_report_file
    cat $1 | while read list
    do
      remove_uploaded_files $list
      if [[ $2 == "Audience" ]]
      then
        remove_uploaded_files DLAR_${today}_delete.csv
      fi
    done
  else
    if [[ $2 == "Audience" ]]
    then
      mv ${outbox}/Audience* $sent
      mv ${outbox}/AUDIENCE_FILES.txt ${sent}AUDIENCE_FILES_${today}.txt
    fi
    if [[ $2 == "Advt" ]]
    then
      mv ${outbox}/Advt_optout_devices.txt ${sent}/Advt_optout_devices_${today}.txt
      mv ${outbox}/Advt* $sent
    fi
    if [[ $1 == DLAR_${today}_delete.csv ]]
    then
      mv ${outbox}/DLAR_${today}_delete.csv $sent
    fi
  fi
}

# This is where we start to upload the files to Cadent.
# We deliberately limit what we sent so no spurious data gets sent by chance.
# Random stuff can be sent by hand.
function upload_files_to_cadent {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Time to send the files to Cadent"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Time to send the files to Cadent" >> ${working}/${files}_$experian_report_file
  cd $outbox
  if [[ $1 == "Audience" ]]
  then
    # If we're uploading Audience data then we have the audience files 
    # but now we have a delete file too
    file=AUDIENCE_FILES.txt
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading files from $file"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading files from $file" >> ${working}/${files}_$experian_report_file
    process_upload_file $file $1

    echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking for delete file, looking for - DLAR_${today}_delete.csv"
    if [ -f DLAR_${today}_delete.csv ]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete file found - uploading"
      process_upload_file DLAR_${today}_delete.csv
    else
      echo "$(date "+%Y-%m-%d %H:%M:%S") - No delete file found"
    fi
  elif [[ $1 == "Advt" ]]
  then
    # For the opt-out files we only have the opt-out files. Nothing else should go
    file=Advt_optout_devices.txt
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading files from $file"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading files from $file" >> ${working}/${files}_$experian_report_file
    process_upload_file $file $1
  fi
}
