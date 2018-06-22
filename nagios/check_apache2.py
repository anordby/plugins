#!/usr/bin/env python

##
## THIS FILE IS UNDER PUPPET CONTROL. DON'T EDIT IT HERE.
##

#   Author: Mike Adolphs, 2009
#   Blog: http://www.matejunkie.com/
#
#   This program is free software; you can redistribute it and/or modify
#   it under the terms of the GNU General Public License as published by
#   the Free Software Foundation; version 2 of the License only!
#
#   This program is distributed in the hope that it will be useful,
#   but WITHOUT ANY WARRANTY; without even the implied warranty of
#   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#   GNU General Public License for more details.
#
#   You should have received a copy of the GNU General Public License
#   along with this program; if not, write to the Free Software
#   Foundation, Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301  USA
#
# Updated 2016-12-16 by Anders Nordby <anders@fupp.net> to check minimum idle workers.

import sys
import urllib2

from optparse import OptionParser, OptionGroup

# Nagios return codes
OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3

usage = "Usage: %prog -H HOSTNAME -p PORT [-w] [-c]"
parser = OptionParser(usage, version="%prog 1.0")
parser.add_option( "-H",
                   "--hostname",
		   type="string",
		   dest="hostname",
		   default="localhost",
		   help="You may define a hostname with the -H option. \
		         Default is: localhost.")

parser.add_option( "-p",
                   "--port",
		   type="int",
		   dest="port",
		   default=80,
		   help="You may define a port with the -p option. \
		         Default is: 80.")

parser.add_option( "-s",
                   "--https",
		   action="store_true",
		   dest="protocol",
		   default=False,
		   help="You may connect over https with the -s option. \
		         Default is: http.")

parser.add_option( "-m",
                   "--mode",
		   type="string",
		   dest="mode",
		   default="accesses",
		   help="Mode for checks: <accesses|idle>, maximum accesses \
                    per second or minimum % idle workers. Default is: accesses")

group = OptionGroup(parser, "Warning/critical thresholds",
                    "Use these options to set warning/critical thresholds \
		     for requests per second served by your Apache.")
group.add_option( "-w",
                  "--warning",
		  type="int",
		  dest="warning",
		  default=-2,
		  help="Use this option if you want to use warning/critical \
		        thresholds. Make sure to set a critical value as \
                        well. Default is: -1.")
group.add_option( "-c",
                  "--critical",
		  type="int",
		  dest="critical",
		  default=-1,
		  help="Use this option if you want to use warning/critical \
		        thresholds. Make sure to set a warning value as \
                        well. Default is: -2.")
parser.add_option_group(group)

(options, args) = parser.parse_args()

hostname = options.hostname
port = options.port
warning = options.warning
critical = options.critical
mode = options.mode
if options.protocol:
    protocol = 'https'
else:
    protocol = 'http'

def end(status, message):
    """Exits the script with the first argument as the return code and the
       second as the message to generate output."""

    if status == OK:
        print "OK: %s" % message
        sys.exit(0)
    elif status == WARNING:
        print "WARNING: %s" % message
        sys.exit(1)
    elif status == CRITICAL:
        print "CRITICAL: %s" % message
        sys.exit(2)
    else:
        print "UNKNOWN: %s" % message
        sys.exit(3)

def validate_thresholds(warning, critical):
    """Validates warning and critical thresholds in several ways."""

# This is already done by OptionParser.
#    try:
#        warning = int(warning)
#    except ValueError:
#        end(stateUNK, "Warning threshold must be an integer value.")
#    try:
#        critical = int(critical)
#    except ValueError:
#        end(stateUNK, "Critical threshold must be an integer value.")
    if critical != -1 and warning == -2:
        end(UNKNOWN, "Please also set a warning value when using warning/" +
	             "critical thresholds!")
    if critical == -1 and warning != -2:
        end(UNKNOWN, "Please also set a critical value when using warning/" +
	             "critical thresholds!")
    if mode == "idle":
        if critical >= warning:
            end(UNKNOWN, "When using idle thresholds the warning value has " +
                      "to be higher than the critical value. Please adjust " +
                      "your thresholds.")
    else:
        if critical <= warning:
            end(UNKNOWN, "When using thresholds the critical value has to be " +
	              "higher than the warning value. Please adjust your " +
		      "thresholds.")

def retrieve_status_page():
    """Get's the server's status page and raises an exception if it's not
       accessible."""

    statusPage = "%s://%s:%s/server-status?auto" % (protocol, hostname, port)
    try:
        response = urllib2.urlopen(statusPage)
        content = response.read()
    except:
        end(CRITICAL, "Couldn't fetch the server's status page. Please " +
	              "check given hostname, port or Apache's " +
		      "configuration. We might not be allowed to access " +
		      "server-status due to your server's configuration.")
    return content

def parse_status_page(content):
    """Main parsing function to put the server-status file's content into
       a dictionary."""

    dictStatus = {}
    counter = 1

    for line in content.splitlines():
        if "Total Accesses:" in line:
            key = "totalAcc"
        elif "Total kBytes:" in line:
            key = "totalKb"
        elif "Uptime:" in line:
            key = "uptime"
        elif "ReqPerSec:" in line:
            key = "reqPSec"
        elif "BytesPerSec:" in line:
            key = "bytesPSec"
        elif "BytesPerReq:" in line:
            key = "bytesPReq"
        elif "BusyWorkers:" in line:
            key = "busyWkrs"
        elif "IdleWorkers:" in line:
            key = "idleWkrs"
        else:
            key = str(counter)
   
        line = line.strip()
        dictStatus[key] = line
        counter = counter + 1

    return dictStatus

def transform_dict(resParse):
    """Transforms the dictionary to a list and converts variables to proper
       types."""

    totalAcc  = int(resParse['totalAcc'].strip(" Total Accesses:"))
    totalKb   = float(resParse['totalKb'].strip(" Total kBytes:"))
    uptime    = int(resParse['uptime'].strip(" Uptime:"))
    reqPSec   = float(resParse['reqPSec'].strip(" ReqPerSec:")) + 0
    bytesPSec = float(resParse['bytesPSec'].strip(" BytesPerSec:"))
    if resParse.has_key('bytesPReq'):
        bytesPReq = float(resParse['bytesPReq'].strip(" BytesPerReq:"))

    busyWkrs  = int(resParse['busyWkrs'].strip(" BusyWorkers:"))
    idleWkrs  = int(resParse['idleWkrs'].strip(" IdleWorkers:"))

    return [reqPSec, busyWkrs, idleWkrs]

# main
if __name__ == "__main__":
    if critical != -1 or warning != -2:
        validate_thresholds(warning, critical)
    
    status_html = retrieve_status_page()
    resParse = parse_status_page(status_html)
    result = transform_dict(resParse)

    if mode == "idle":
        idlepct = result[2]/((result[2]+result[1])*1.0)*100
        if critical != -1 and warning != -2:
            if idlepct < critical:
                end(CRITICAL, "%0.2f%% idle workers, below critical level %i. %i \
busy workers, %i idle. Apache serves %f requests per second. | requests=%f;;;; busyworkers=%i;;;; idleworkers=%i;;;;" % (idlepct, \
critical, result[1], result[2], result[0], result[0], result[1], result[2]))
            elif idlepct < warning:
                end(WARNING, "%0.2f%% idle workers, below warning level %i. %i \
busy workers, %i idle. Apache serves %f requests per second. | requests=%f;;;; busyworkers=%i;;;; idleworkers=%i;;;;" % (idlepct, \
warning, result[1], result[2], result[0], result[0], result[1], result[2]))
            else:
                end(OK, "Apache serves %f requests per second. %i busy workers, \
%i idle workers. %0.2f%% workers idle. | requests=%f;;;; busyworkers=%i;;;; idleworkers=%i;;;;" % (result[0], result[1], result[2], \
idlepct, result[0], result[1], result[2]))
        else:
            end(OK, "Apache serves %f requests per second. %i busy workers, %i \
idle workers. %0.2f%% workers idle. | requests=%f;;;; busyworkers=%i;;;; idleworkers=%i;;;;" % (result[0], result[1], result[2], \
idlepct, result[0], result[1], result[2]))
    elif mode == "accesses":
        if critical != -1 and warning != -2:
            if result[0] >= critical:
                end(CRITICAL, "Apache serves %f requests per second, exceeding \
critical threshold! %i busy workers, %i idle workers. | requests=%f;;;; busyworkers=%i;;;; idleworkers=%i;;;;" % (result[0], \
result[1], result[2], result[0], result[1], result[2]))
            elif result[0] >= warning and result[0] <= critical:
                end(WARNING, "Apache serves %f requests per second, exceeding \
warning threshold! %i busy workers, %i idle workers. | requests=%f;;;; busyworkers=%i;;;; idleworkers=%i;;;;" % (result[0], \
result[1], result[2], result[0], result[1], result[2]))
            else:
                end(OK, "Apache serves %f requests per second. %i busy workers, \
%i idle workers. | requests=%f;;;; busyworkers=%i;;;; idleworkers=%i;;;;" % (result[0], result[1], result[2], result[0], result[1], result[2]))
        else:
            end(OK, "Apache serves %f requests per second. %i busy workers, %i \
idle workers. | requests=%f;;;; busyworkers=%i;;;; idleworkers=%i;;;;" % (result[0], result[1], result[2], result[0], result[1], result[2]))
    else:
        print "Unknown mode %s" % mode
        sys.exit(0)
