#! /bin/bash

#
# Variables file.
#
# Here we define all system variables we need for the script
#

# Change history
# v01 - Richard Newton - original version
#       variables file for v10 DLAR_uploader script

# System independent Variables
experian_file_check_status=0
experian_data_check_status=0
min_percent_to_worry_about=40
max_percent_to_worry_about=99
max_optout_change=10

# System Dependent Variables

if [[ $(uname -a | awk '{print $1}') == "Darwin" ]]
then
  #
  # Local variables for testing
  #
  today=$(date +%Y%m%d)
  yesterday=$(date -v-1d +%Y%m%d)
  day_before_yesterday=$(date -v-2d +%Y%m%d)

  home=~/Desktop/testing
  experian_inbox=${home}/dlar/inbox
  optout_inbox=${home}/dlar/optout/inbox
  outbox=${home}/outbox
  archive=${home}/archive
  reports=${home}/reports
  failed=${home}/failed
  sent=${home}/sent
  scripts=${home}/scripts
  working=$scripts/.working
  support_files=$scripts/support_files
  lock_file=dlar_uploader.lock
  last_upload_time="19:30"

  # Cadent
  cadent_user=$(grep ^cadent_user ${support_files}/user.ini | cut -d= -f2)
  cadent_server=$(grep ^cadent_server ${support_files}/user.ini | cut -d= -f2)
  remote_cadent_waiting=waiting


  # SQL
  sqlbin=$(which sqlite3)
  sqldb=$working/Experian.db

  # Reports
  experian_report_file=report.tmp
  experian_record_counts_csv=record_count_report
  experian_file_report_csv=file_report
  experian_attr_report_csv=attribute_count_report
  experian_attr_data_report_csv=attribute_data_count_report
  experian_error_file=error.tmp
  experian_zip=experian_reports_${today}.zip
else
  #
  # Actual proper ULS values
  #
  today=$(date +%Y%m%d)
  yesterday=$(date -d "1 day ago" +%Y%m%d)
  day_before_yesterday=$(date -d "2 day ago" +%Y%m%d)
  
  home=/ulshome/etluser-adm
  experian_inbox=/ulshome/etluser/dlar/inbox
  optout_inbox=/ulshome/etluser/dlar/optout/inbox
  outbox=$home/outbox
  archive=$home/archive
  reports=$home/reports
  failed=$home/failed
  sent=$home/sent
  scripts=$home/scripts
  working=$scripts/.working
  support_files=$scripts/support_files
  lock_file=dlar_uploader.lock
  last_upload_time="15:00"

  # Cadent
  cadent_user=$(grep ^cadent_user ${support_files}/user.ini | cut -d= -f2)
  cadent_server=$(grep ^cadent_server ${support_files}/user.ini | cut -d= -f2)
  remote_cadent_waiting=waiting

  
  # SQL
  sqlbin=~/bin/sqlite3
  sqldb=$working/Experian.db

  # Reports
  experian_report_file=report.tmp
  experian_record_counts_csv=record_count_report
  experian_file_report_csv=file_report
  experian_attr_report_csv=attribute_count_report
  experian_attr_data_report_csv=attribute_data_count_report
  experian_error_file=error.tmp
  experian_zip=experian_reports_${today}.zip

  # Mail
  reply_to=$(grep ^reply_to ${support_files}/user.ini | cut -d= -f2)
  send_to=$(grep ^send_to ${support_files}/user.ini | cut -d= -f2)
  failure_send_to=$(grep ^failure_send_to ${support_files}/user.ini | cut -d= -f2)
fi
