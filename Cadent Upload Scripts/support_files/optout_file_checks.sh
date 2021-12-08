#! /bin/bash
#
# Experian File Checks
#
# Functions to support the checking of the Experian files go here
#
# We use $archive rather than $sent because we'll stop the upload if the variance is too great
# however, just because it changes a lot in one day doesn't meant that's a bad thing. It gives
# people time to investigate though.

# Get a count of records in each file
function get_eos_record_count {
  file=$(ls ${archive}/Advt_optout_devices_${1}*.csv 2>/dev/null | tail -1)
  if [ -f $file ]
  then
    if [[ $3 == "optedin" ]]
    then
      count=$(grep $2 $file | grep -c ',"0"')
      echo $count
    elif [[ $3 == "optedout" ]]
    then
      count=$(grep $2 $file | grep -c ',"1"')
      echo $count
    fi
  else
    echo 0
  fi
}

# Get a count of records in each file
function get_apls_record_count {
  file=$(ls ${archive}/Advt_optout_devices_${1}*.csv 2>/dev/null | tail -1)
  if [ -f $file ]
  then
    if [[ $3 == "optedin" ]]
    then
      count=$(grep $2 $file | grep -c ',"0"')
      echo $count
    elif [[ $3 == "optedout" ]]
    then
      count=$(grep $2 $file | grep -c ',"1"')
      echo $count
    fi
  else
    echo 0
  fi
}

# TiVo is basically not EOS
function get_tivo_record_count {
  file=$(ls ${archive}/Advt_optout_devices_${1}*.csv 2>/dev/null | tail -1)
  if [ -f $file ]
  then
    if [[ $3 == "optedin" ]]
    then
      count=$(egrep -v $2 $file | grep -c ',"0"')
      echo $count
    elif [[ $3 == "optedout" ]]
    then
      count=$(egrep -v $2 $file | grep -c ',"1"')
      echo $count
    fi
  else
    echo 0
  fi
}

# Get a count of records for each supplied file and compare the numbers to see how different they are.
# If they're too different (but not a complete change we need to set a flag)
function get_optout_file_record_counts {
  eos_optedin_first_date=$(get_eos_record_count $first_date EOS optedin)
  eos_optedin_second_date=$(get_eos_record_count $second_date EOS optedin)

  percentage_change=$(check_percentage_change_in_files $eos_optedin_first_date $eos_optedin_second_date)
  percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
  echo "Horizon Opted In","$eos_optedin_first_date","$eos_optedin_second_date","$percentage_change" >> ${working}/${files}_$file_report_csv
  worried=$(do_we_need_to_worry_optout $percentage_change_whole_number)

  if [[ $worried == 1 ]]
  then
    echo "Record Count $first_date_formatted  Record Count $second_date_formatted" >> ${working}/${files}_$error_file
    echo "===============================================" >> ${working}/${files}_$error_file
    echo "$eos_optedin_first_date      $eos_optedin_second_date" >> ${working}/${files}_$error_file
    echo "" >> ${working}/${files}_$error_file
    echo "Percentage change = $percentage_change" >> ${working}/${files}_$error_file
    echo "" >> ${working}/${files}_$error_file
  fi

  eos_optedout_first_date=$(get_eos_record_count $first_date EOS optedout)
  eos_optedout_second_date=$(get_eos_record_count $second_date EOS optedout)

  percentage_change=$(check_percentage_change_in_files $eos_optedout_first_date $eos_optedout_second_date)
  percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
  echo "Horizon Opted Out","$eos_optedout_first_date","$eos_optedout_second_date","$percentage_change" >> ${working}/${files}_$file_report_csv
  worried=$(do_we_need_to_worry_optout $percentage_change_whole_number)

  if [[ $worried == 1 ]]
  then
    echo "Record Count $first_date_formatted  Record Count $second_date_formatted" >> ${working}/${files}_$error_file
    echo "===============================================" >> ${working}/${files}_$error_file
    echo "$eos_optedout_first_date      $eos_optedout_second_date" >> ${working}/${files}_$error_file
    echo "" >> ${working}/${files}_$error_file
    echo "Percentage change = $percentage_change" >> ${working}/${files}_$error_file
    echo "" >> ${working}/${files}_$error_file
  fi

  apls_optedin_first_date=$(get_apls_record_count $first_date APLS optedin)
  apls_optedin_second_date=$(get_apls_record_count $second_date APLS optedin)

  percentage_change=$(check_percentage_change_in_files $apls_optedin_first_date $apls_optedin_second_date)
  percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
  echo "TV2.0 Opted In","$apls_optedin_first_date","$apls_optedin_second_date","$percentage_change" >> ${working}/${files}_$file_report_csv
  worried=$(do_we_need_to_worry_optout $percentage_change_whole_number)

  if [[ $worried == 1 ]]
  then
    echo "Record Count $first_date_formatted  Record Count $second_date_formatted" >> ${working}/${files}_$error_file
    echo "===============================================" >> ${working}/${files}_$error_file
    echo "$apls_optedin_first_date      $apls_optedin_second_date" >> ${working}/${files}_$error_file
    echo "" >> ${working}/${files}_$error_file
    echo "Percentage change = $percentage_change" >> ${working}/${files}_$error_file
    echo "" >> ${working}/${files}_$error_file
  fi

  apls_optedout_first_date=$(get_apls_record_count $first_date APLS optedout)
  apls_optedout_second_date=$(get_apls_record_count $second_date APLS optedout)

  percentage_change=$(check_percentage_change_in_files $apls_optedout_first_date $apls_optedout_second_date)
  percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
  echo "TV2.0 Opted Out","$apls_optedout_first_date","$apls_optedout_second_date","$percentage_change" >> ${working}/${files}_$file_report_csv
  worried=$(do_we_need_to_worry_optout $percentage_change_whole_number)

  if [[ $worried == 1 ]]
  then
    echo "Record Count $first_date_formatted  Record Count $second_date_formatted" >> ${working}/${files}_$error_file
    echo "===============================================" >> ${working}/${files}_$error_file
    echo "$apls_optedout_first_date      $apls_optedout_second_date" >> ${working}/${files}_$error_file
    echo "" >> ${working}/${files}_$error_file
    echo "Percentage change = $percentage_change" >> ${working}/${files}_$error_file
    echo "" >> ${working}/${files}_$error_file
  fi

  tivo_optedin_first_date=$(get_tivo_record_count $first_date "EOS|APLS" optedin)
  tivo_optedin_second_date=$(get_tivo_record_count $second_date "EOS|APLS" optedin)

  percentage_change=$(check_percentage_change_in_files $tivo_optedin_first_date $tivo_optedin_second_date)
  percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
  echo "TiVo Opted In","$tivo_optedin_first_date","$tivo_optedin_second_date","$percentage_change" >> ${working}/${files}_$file_report_csv
  worried=$(do_we_need_to_worry_optout $percentage_change_whole_number)

  if [[ $worried == 1 ]]
  then
    echo "Record Count $first_date_formatted  Record Count $second_date_formatted" >> $${working}/${files}_error_file
    echo "===============================================" >> ${working}/${files}_$error_file
    echo "$tivo_optedin_first_date      $tivo_optedin_second_date" >> ${working}/${files}_$error_file
    echo "" >> ${working}/${files}_$error_file
    echo "Percentage change = $percentage_change" >> ${working}/${files}_$error_file
    echo "" >> ${working}/${files}_$error_file
  fi

  tivo_optedout_first_date=$(get_tivo_record_count $first_date "EOS|APLS" optedout)
  tivo_optedout_second_date=$(get_tivo_record_count $second_date "EOS|APLS" optedout)

  percentage_change=$(check_percentage_change_in_files $tivo_optedout_first_date $tivo_optedout_second_date)
  percentage_change_whole_number=$(echo $percentage_change | cut -d. -f1 | tr -d '-')
  echo "TiVo Opted Out","$tivo_optedout_first_date","$tivo_optedout_second_date","$percentage_change" >> ${working}/${files}_$file_report_csv
  worried=$(do_we_need_to_worry_optout $percentage_change_whole_number)

  if [[ $worried == 1 ]]
  then
    echo "Record Count $first_date_formatted  Record Count $second_date_formatted" >> ${working}/${files}_$error_file
    echo "===============================================" >> ${working}/${files}_$error_file
    echo "$tivo_optedout_first_date      $tivo_optedout_second_date" >> ${working}/${files}_$error_file
    echo "" >> ${working}/${files}_$error_file
    echo "Percentage change = $percentage_change" >> ${working}/${files}_$error_file
    echo "" >> ${working}/${files}_$error_file
  fi

}

# Run the checks on today's file and the previously delivered file.
function optout_file_checks {
  first_date=$1
  second_date=$2
  first_date_formatted=$(unfix_date $1)
  second_date_formatted=$(unfix_date $2)
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Check Optout files for consistency"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Check Optout files for consistency" >> ${working}/${files}_$report_file
  # Experian will do pretty much all the data checks. We're just checking to see if we have
  # a sensible number of files delivered, or not.
  echo "Counted Value","$first_date_formatted","$second_date_formatted","Percentage Change" > ${working}/${files}_$file_report_csv
  get_optout_file_record_counts $first_date $second_date
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Optout file consistency check finished"
  echo "$(date "+%Y-%m-%d %H:%M:%S") - Optout file consistency check finished" >> ${working}/${files}_$report_file
}
