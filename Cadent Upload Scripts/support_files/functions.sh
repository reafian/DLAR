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
    ls ${outbox}/${1}* >/dev/null 2>&1 
    if [[ $? == 0 ]]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing old $2 files"
      rm -f ${outbox}/${1}*
      rm -f ${outbox}/AUDIENCE*
      rm -f ${outbox}/DLAR*
    fi
  fi
  if [[ $1 == "Advt" ]]
  then
    ls ${outbox}/${1}* >/dev/null 2>&1
    if [[ $? == 0 ]]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing old $2 files"
      rm -f ${outbox}/${1}*
    fi
  fi
}

# This function moves the source files to the archive or sent directory
function archive_files {
  if [[ $1 == "Audience" ]]
  then
    if [ -f ${2}/AUDIENCE_FILES.txt ]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Archiving $1 files"
      filedate=$(head -1 ${2}/AUDIENCE_FILES.txt | cut -d_ -f3)
      mv -f AUDIENCE_FILES.txt ${3}/AUDIENCE_FILES_${filedate}.txt
      mv -f Audience* $3
    fi
  elif [[ $1 == "Advt" ]]
  then
    if [ -f ${2}/Advt_optout_devices.txt ]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Archiving $1 files"
      filedate=$(head -1 ${2}/Advt_optout_devices.txt | cut -d_ -f4 | cut -c1-8)
      mv -n Advt_optout_devices.txt ${3}/Advt_optout_devices_${filedate}.txt
      mv -f Advt* $3
    fi
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
    echo "$(date "+%Y-%m-%d %H:%M:%S") - $3 files found, looking for 'done' file"
    donefile=$(ls ${2}*.done 2>/dev/null)
    if [[ $? == 0 ]]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - 'done' file found - file transfer appears complete"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Copying $3 files to outbox for checking and sending"
      # We have to use cp rather than mv to cope with the different permissions
      if [[ $2 == "Audience" ]]
      then
        if [[ $(ls *${today}*csv 2>/dev/null | awk '{print $1}') > 0 ]]
        then
          cp -f *${today}* $outbox
          cp -f AUDIENCE_FILES.txt $outbox
          # archive the actual source files received
          archive_files $2 $inbox $archive
          failure_status=0
        else
          echo "$(date "+%Y-%m-%d %H:%M:%S") - $3 files are old. Failing"
          echo "$(date "+%Y-%m-%d %H:%M:%S") - $3 files are old. Failing" >> ${working}/${files}_$report_file
          archive_files $2 $inbox $failed
          failure_status=1
        fi
      elif [[ $2 == "Advt" ]]
      then
        if [[ $(ls *${today}*csv 2>/dev/null | awk '{print $1}') > 0 ]]
        then
          cp -f *${today}* $outbox
          cp -f Advt_optout_devices.txt $outbox 2>/dev/null
          # archive the actual source files received
          archive_files $2 $inbox $archive
          failure_status=0
        else
          echo "$(date "+%Y-%m-%d %H:%M:%S") - $3 files are old. Failing"
          echo "$(date "+%Y-%m-%d %H:%M:%S") - $3 files are old. Failing" >> ${working}/${files}_$report_file
          archive_files $2 $inbox $failed
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

# Here we create the Audience data delete file, this is different from the CACI delete file because of the delay in the flow
function create_delete {
  current_filedate=$(echo $1 | cut -d_ -f4)
  previous_filedate=$(ls -ltr ${sent}/Audience_DLAR*_1.csv 2> /dev/null | grep -v $today | tail -1 | awk '{print $9}' | cut -d_ -f3)

  echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating box list for $current_filedate"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating box list for $current_filedate" >> ${working}/${files}_$report_file
  cat ${archive}/Audience_DLAR_${current_filedate}*.csv | grep -v DEVICE | cut -d, -f2 | sort >> $working/${current_filedate}.txt
  # We use sent rather than archive because sent is what was actually sent to Cadent so they're the ones we need to delete from
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating box list for $previous_filedate"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating box list for $previous_filedate" >> ${working}/${files}_$report_file
  cat ${sent}/Audience_DLAR_${previous_filedate}*.csv | grep -v DEVICE | cut -d, -f2 | sort >> $working/${previous_filedate}.txt
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating diff file"
  diff -y ${working}/${current_filedate}.txt ${working}/${previous_filedate}.txt  | grep '>' | awk '{print $2}' >> $working/DLAR_${current_filedate}_delete.txt
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete list contains $(wc -l ${working}/DLAR_${current_filedate}_delete.txt | awk '{print $1}') records"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete list contains $(wc -l ${working}/DLAR_${current_filedate}_delete.txt | awk '{print $1}') records" >> ${working}/${files}_$report_file

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
    rm ${working}/DLAR_${current_filedate}_delete.csv
    rm ${working}/delete.raw
  else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete file too small, not uploading to Cadent"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Delete file too small, not uploading to Cadent" >> ${working}/${files}_$report_file
  fi
}

# Remove Trial Data
function remove_trial_data {
  file=$1
  if [[ $2 == "Audience" ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Searching for trial boxes"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing trialist data from Experian file $file"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing trialist data from Experian file $file" >> ${working}/${files}_$report_file
    grep -vf $support_files/MAC_list.txt ${outbox}/$file > ${outbox}/adjusted.tmp
    mv ${outbox}/adjusted.tmp ${outbox}/${file}
  fi
}

# This is where we change the data in the files to remove boxes and the rest
function process_files {
  donefile=$(ls ${outbox}/${1}*.done | tail -1 2>/dev/null)
  basefile=$(basename $donefile .done)
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Processing ${basefile}.txt"
  if [[ $1 == "Audience" ]]
  then
    if [[ $create_delete == 1 ]]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Creating delete file"
      create_delete $donefile
    fi
    while read list
    do
      file=$(echo $list | awk '{print $2}')
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Editing $file to remove to trailist data"
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Editing $file to remove to trailist data" >> ${working}/${files}_$report_file
      remove_trial_data $file $1
    done < ${outbox}/${basefile}.txt
  fi
}

function get_sftp_size {
  sftp -q $cadent_user@$cadent_server << EOF
  cd waiting
  ls -l $1
EOF
}

function sftp_check {
  local_size=$(ls -l $1 | awk '{print $5}')
  remote_size_and_name=$(get_sftp_size $1 | awk '{print $5 " " $9}')
  remote_size=$(echo $remote_size_and_name | awk '{print $1}')
  echo "$(date "+%Y-%m-%d %H:%M:%S") - local file size = ${local_size}, remote file size = ${remote_size}"
  if [[ $local_size != $remote_size ]] || [[ $local_size == "" ]] || [[ $remote_size == "" ]]
  then
    echo "Local file sizes do not match the file sizes on Cadent - file delivery failed"
    echo "Local file sizes do not match the file sizes on Cadent - file delivery failed" >> ${working}/${files}_$report_file
    echo "Local file sizes do not match the file sizes on Cadent - file delivery failed" >> ${working}/${files}_$error_file
  else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - File sizes match, delivery was successful"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - File sizes match, delivery was successful" >> ${working}/${files}_$report_file
  fi
}

function do_sftp {
  sftp -q $cadent_user@$cadent_server << EOF
  cd waiting
  put -p $1 ${base}.tmp
  rename ${base}.tmp ${base}.csv
EOF
}

function upload_to_cadent {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Changing permissions on $1"
  chmod 666 $1
  echo "$(date "+%Y-%m-%d %H:%M:%S") - sftp -q $1 $cadent_user@${cadent_server}:${waiting}"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading $1"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading $1" >> ${working}/${files}_$report_file
  base=$(basename $1 .csv)
  do_sftp $1
  sftp_check $1
}

function remove_uploaded_files {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Removing uploaded file $1"
    sftp -q $cadent_user@$cadent_server << EOF
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

  if [ -f ${working}/${files}_$error_file ]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - An error has occurred, deleting $2 files"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - An error has occurred, deleting $2 files" >> ${working}/${files}_$report_file
    remove_uploaded_files $2
    archive_files $2 $outbox $failed
    if [ -f DLAR_${today}_delete.csv ]
    then
      remove_uploaded_files DLAR_${today}_delete.csv
    fi
  else
    if [[ $2 == "Audience" ]]
    then
      archive_files $2 $outbox $sent
    fi
    if [[ $2 == "Advt" ]]
    then
      archive_files $2 $outbox $sent
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
  # $1 = prefix (Audience or Advt)
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending $2 files to Cadent"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending $2 files to Cadent" >> ${working}/${files}_$report_file
  cd $outbox
  if [[ $1 == "Audience" ]]
  then
    # If we're uploading Audience data then we have the audience files 
    # but now we have a delete file too
    file=AUDIENCE_FILES.txt
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading files from $file"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading files from $file" >> ${working}/${files}_$report_file
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
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Uploading files from $file" >> ${working}/${files}_$report_file
    process_upload_file $file $1
  fi
}

function rename_reports {
  if [ -f ${working}/${files}_$report_file ]
  then
    cp ${working}/${files}_$report_file ${reports}/${files}_report_${today}.txt
    mv ${working}/${files}_$report_file ${working}/${files}_report_${today}.txt
  fi

  if [ -f ${working}/${files}_$error_file ]
  then
    cp ${working}/${files}_$error_file ${working}/${files}_error_report_${today}.txt
    mv ${working}/${files}_$error_file ${reports}/${files}_error_report_${today}.txt
  fi

  if [ -f ${working}/${files}_$file_report_csv ]
  then
    cp ${working}/${files}_$file_report_csv ${working}/${files}_file_report_${today}.csv
    mv ${working}/${files}_$file_report_csv ${reports}/${files}_file_report_${today}.csv
  fi
}

# Turn the date into a more readable format
function unfix_date {
  echo $(echo "$1" | sed 's/^\(.\{4\}\)/\1-/' | sed 's/^\(.\{7\}\)/\1-/')
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
  send_to=$(grep ^send_to $source_path/user.ini | cut -d= -f2)
  reply_to=$(grep ^reply_to $source_path/user.ini | cut -d= -f2)
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending mail to $send_to"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending $3"
  message="Hi All, 

Please find attached today's $1 report.

Richard"
  #echo "$message" | mailx -a "$3" -s "$1 Delivery Report - $2" -r $reply_to $send_to
}

# Mail message routine
function send_message {
  rename_reports $1
  if [ -f ${working}/${files}_*error* ]
  then
    zipfile=$(zip_files $1 failure)
    if [[ $zipfile != "" ]]
    then
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending failure mail"
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
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending success mail"
      send_mail $1 success $zipfile
    else
      echo "$(date "+%Y-%m-%d %H:%M:%S") - Zipfile creation failed"
    fi
  fi
}

# Check the percentage change in the delivered files
function check_percentage_change_in_files {
  # $1 = today
  # $2 = yesterday
  if [[ $1 == $2 ]]
  then
    echo "0"
  elif [[ $1 == 0 || $1 == "" ]]
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

function tidy_up {
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Deleting old working $1 files"
  rm -f $working/${1}*
  rm -f $outbox/${2}*
}