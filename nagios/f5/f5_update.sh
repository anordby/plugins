#! /bin/sh

PATH="/bin:/usr/bin:/usr/sbin"
export PATH

f5_hosts="bigip1.yourcompany.local bigip2.yourcompany.local bigip3.yourcompany.local bigip4.yourcompany.local"
#f5_hosts="bigip4.yourcompany.local"
cd `dirname $0`
for h in $f5_hosts
do
	echo "$h =>"
	timeout 300 ./f5.rb --host $h
	res=$?
	echo "Result: $?"
done
