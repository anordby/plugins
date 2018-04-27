#! /bin/sh

PATH="/bin:/usr/bin:/usr/sbin"
export PATH

f5_hosts="bigip1.yourcompany.local bigip2.yourcompany.local bigip3.yourcompany.local bigip4.yourcompany.local"
#f5_hosts="bigip4.yourcompany.local"
cmdfile="/var/spool/nagios/cmd/nagios.cmd"
cd `dirname $0`
for h in $f5_hosts
do
	echo "$h =>"
	timeout 300 ./f5.rb --host $h
	res=$?
	echo "Result: $?"
	if [ $res -gt 100 ]
	then
		uxtime="`date +%s`"
		# Timeout reached
		echo "[$uxtime] PROCESS_SERVICE_CHECK_RESULT;$h;status;3;Could not get updated data from $h due to timeout." >>$cmdfile
	fi
done
