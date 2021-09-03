#! /bin/bash

# This script moves the Experian files to Cadent

################ DEBUG FLAG ################
debug=1
############################################

if [[ $(uname -a | awk '{print $1}') == "Darwin" ]]
then
  source_path=${HOME}/Desktop/testing/scripts/support_files
else
  source_path=${HOME}/testing/scripts/support_files
fi

source $source_path/variables.sh
source $source_path/functions.sh
source $source_path/experian_file_checks.sh
source $source_path/experian_data_checks.sh
source $source_path/optout_file_checks.sh

check_folder_structure
clear_working_folders

lock_status=$(check_for_lock)
if [[ $lock_status == '1' ]]
then
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Lock file found, exiting"
  exit 1
fi
echo "$(date "+%Y-%m-%d %H:%M:%S") - No lock file found, continuing"

create_lock_file

# Check in inboxes for files and copy the files to the outbox for checking
# Also copy the files to the archive so we know exactly what was received 
for files in Experian Optout
do
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Working on the $files files"

  if [[ $files == Experian ]]
  then
    inbox=$experian_inbox
    prefix="Audience"
  elif [[ $files == Optout ]]
  then
    inbox=$optout_inbox
    prefix="Advt"
  fi

  echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking inbox"
  inbox_status=$(check_inbox $inbox $prefix $files)
  if [[ $debug == 1 ]]
  then
    echo inbox status == $inbox_status
    ls $inbox
  fi

  if [[ $inbox_status != 1 ]]
  then
    echo "$(date "+%Y-%m-%d %H:%M:%S") - We appear to have valid inbox contents"
    check_outbox_consistency $outbox $prefix
    check_error_failure_status $files delivery error

    echo "$(date "+%Y-%m-%d %H:%M:%S") - All files appear to have been delivered correctly"

    # Now we check the files for deviation against the previous delivery
    if [[ $files == Experian ]]
    then
      # There's only value in running the Experian checks if we actually
      # have a file for yesterday. If we don't have a file for yesterday
      # then there's nothing to compare the data against and it'll all 
      # fail miserably
      previous=$(ls -ltr ${archive}/Audience_DLAR*_1.csv 2> /dev/null | grep -v $today | tail -1 | awk '{print $9}' | cut -d_ -f3)
      if [[ $previous != "" ]]
      then
        echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking delivered Experian files"
        # AdOps don't need all these checks but there here for completeness. Check the experian_file_checks file to see what we're running.
        experian_file_checks $today $previous
        # If the number or data of the files received is wrong then we need to fail this
        check_error_failure_status $files files error

        # These data checks take a long time to run but they're crucial for maintaining a good relationship with Sky
        experian_data_checks $today $previous
        # If the data in the file is wildly different then we need to fail the file
        check_error_failure_status $files data error
      else
        echo "$(date "+%Y-%m-%d %H:%M:%S") - We have no previous Experian files - skipping checks"
      fi
    fi

    if [[ $files == Optout ]]
    then
      echo inbox status = $inbox_status
      previous=$(ls -ltr ${archive}/Advt*.csv 2> /dev/null | grep -v $today | awk '{print $9}' | cut -d_ -f4 | cut -c1-8)
      if [[ $previous != "" ]]
      then
        echo "$(date "+%Y-%m-%d %H:%M:%S") - Checking delivered Optout files"
        optout_file_checks $today $previous
        check_error_failure_status $files data error
      else
        echo "$(date "+%Y-%m-%d %H:%M:%S") - We have no previous optout files - skipping checks"
      fi
    fi 

    # Processing the files should be the last thing we do because this takes time.
    # Here we remove the trialist data and change to the correct format (if that was necessary)
    process_files $prefix

    # Paranoia check the delivery window again just in case the processing took too long
    # This doesn't work with long running jobs but I don't want to delete it just yet
    #check_delivery_ability_window
    #check_error_failure_status $files time error

    # Upload the files to Cadent
    upload_files_to_cadent $prefix
    check_error_failure_status $files cadent error

    echo "$(date "+%Y-%m-%d %H:%M:%S") - Processing of $files files complete"
    send_message $files $prefix
  fi

done

tidy_up
remove_lock_file
