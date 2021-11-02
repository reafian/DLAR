#! /bin/bash

# This script moves the Experian files to Cadent

# Change history
#	adding in csv reporting for AdOps
#	only mail if changes fall inside 40 - 99% changes
#	added delete function to delete old DLAR boxes

# Source files that provide the functionality we need (also keeps this file tidy)

if [[ $(uname -a | awk '{print $1}') == "Darwin" ]]
then
  source_path=/Users/richard/Desktop/dlar/scripts/support_files
else
  source_path=/ulshome/etluser-adm/scripts/support_files
fi

# Use these flags to enable or disable the components needed.

optout=0
experian=1
optout_checks=1
process_files=1
create_delete=1
experian_file_checks=0
experian_data_checks=0
upload_to_cadent=1
send_mail=0

source $source_path/variables.sh
source $source_path/functions.sh

if [[ $process_experian_files == 1 ]]
then
  source $source $source_path/experian_file_checks.sh
fi

if [[ $process_experian_data == 1 ]]
then
  source $source_path/experian_data_checks.sh
fi

if [[ $optout_checks == 1 ]]
then
  source $source_path/optout_file_checks.sh
fi

check_folder_structure

#
# Work on Optout files
#

if [[ $optout == 1 ]]
then
  files=Optout
  prefix=Advt
  inbox=$optout_inbox
    
  lock_status=$(check_for_lock $files)
  
  if [[ $lock_status != '1' ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - No lock file found, continuing"
    create_lock_file $files
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Working on the $files files"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Working on the $files files" > ${working}/${files}_$report_file

    if [[ $files == Optout ]]
    then
      prepare_outbox $prefix $files
      check_inbox $inbox $prefix $files

      if [[ $failure_status != 1 ]]
      then
        previous=$(ls -ltr ${sent}/Advt*.csv 2> /dev/null | grep -v $today | tail -1 | awk '{print $9}' | cut -d_ -f4 | cut -c1-8)
        if [[ $previous != "" ]] && [[ $optout_checks == 1 ]]
        then
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking delivered $files files"
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking delivered $files files" >> ${working}/${files}_$report_file

          echo "$(date "+%Y-%m-%d %H:%M:%S") - Today = $today"
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Previous = $previous"
          optout_file_checks $today $previous $files
        else
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Skipping $files checks"
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Skipping $files checks" >> ${working}/${files}_$report_file
        fi
        # If we have an error file there's no point sending the files to Cadent
        if [ -f ${working}/${files}_$error_file ]
        then
          archive_files $files $outbox $failed
        else
          # Upload the files to Cadent
          if [[ $upload_to_cadent == 1 ]]
          then
            upload_files_to_cadent $prefix $files
          fi
        fi
      fi
    fi
  else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Lock file found, exiting"
  fi

  echo "$(date "+%Y-%m-%d %H:%M:%S") - Processing of $files files complete"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Processing of $files files complete" >> ${working}/${files}_$report_file

  rename_reports $files

  # if reports are more than 2 lines long mail out because stuff happened.
  if [[ $send_mail == 1 ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending mail"
    if [[ $(wc -l ${working}/${files}_report_${today}.txt | awk '{print $1}') -gt 2 ]]
    then
      send_message $files $prefix
    fi
  else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending mail skipped"
  fi

  tidy_up $files $prefix
  remove_lock_file $files

fi

#
# Work on Experian files
#

if [[ $experian == 1 ]]
then
  files=Experian
  prefix=Audience
  inbox=$experian_inbox
    
  lock_status=$(check_for_lock $files)
  
  if [[ $lock_status != '1' ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - No lock file found, continuing"
    create_lock_file $files
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Working on the $files files"
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Working on the $files files" > ${working}/${files}_$report_file

    if [[ $files == Experian ]]
    then

      prepare_outbox $prefix $files
      check_inbox $inbox $prefix $files

      if [[ $failure_status != 1 ]]
      then

        # Processing the files should be the last thing we do because this takes time.
        # Here we remove the trialist data and change to the correct format (if that was necessary)
        if [[ $process_files == 1 ]]
        then
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Starting processing of $files files"
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Starting processing of $files files" >> ${working}/${files}_$report_file
          process_files $prefix
        fi

        previous=$(ls -ltr ${sent}/Audience_DLAR*_1.csv 2> /dev/null | grep -v $today | tail -1 | awk '{print $9}' | cut -d_ -f3)
        if [[ $previous != "" ]] && [[ $experian_checks == 1 ]]
        then
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking delivered $files files"
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking delivered $files files" >> ${working}/${files}_$report_file

          # AdOps don't need all these checks but there here for completeness. Check the experian_file_checks file to see what we're running.
          if [[ $experian_file_checks == 1 ]]
          then
            experian_file_checks $today $previous
          fi

          # These data checks take a long time to run but they're crucial for maintaining a good relationship with Sky
          if [[ $experian_data_checks == 1 ]]
          then
            experian_data_checks $today $previous
          fi

        else
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Skipping $files checks"
          echo "$(date "+%Y-%m-%d %H:%M:%S") - Skipping $files checks" >> ${working}/${files}_$report_file
        fi

        # If we have an error file there's no point sending the files to Cadent
        if [ -f ${working}/${files}_$error_file ]
        then
          archive_files $files $outbox $failed
        else
          # Upload the files to Cadent
          if [[ $upload_to_cadent == 1 ]]
          then
            upload_files_to_cadent $prefix $files
          fi
        fi
      fi
    fi
  else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Lock file found, exiting"
  fi

  echo "$(date "+%Y-%m-%d %H:%M:%S") - Processing of $files files complete"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Processing of $files files complete" >> ${working}/${files}_$report_file

  rename_reports $files

  # if reports are more than 2 lines long mail out because stuff happened.
  if [[ $send_mail == 1 ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending mail"
    if [[ $(wc -l ${working}/${files}_report_${today}.txt | awk '{print $1}') -gt 2 ]]
    then
      send_message $files $prefix
    fi
  else
    echo "$(date "+%Y-%m-%d %H:%M:%S") - Sending mail skipped"
  fi

  tidy_up $files $prefix
  remove_lock_file $files

fi
