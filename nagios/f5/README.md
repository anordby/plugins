Complete Nagios solution for automated monitoring of F5 BigIP using API & SNMP
in Ruby. Generates Nagios config automatically.

Anders Nordby <anders@fupp.net>

Contents:

1) f5.rb

This is the main script. It will generate Nagios config to check all pools,
pool members, vses and if you wish nodes for availability. And will perform
those checks as passive checks. You will want to run it periodically in cron. I
do this through these shell scripts that iterate through the list of hosts:

13 * * * * cd /home/xuser/f5 && ./f5_gen.sh >f5_gen.out 2>&1
*/5 * * * * cd /home/xuser/f5 && ./f5_update.sh >f5_update.out 2>&1

Edit f5_gen.sh and f5_update.sh to use your IPs/hosts. Also you need to:

- check & edit the config in check_f5.yaml to fit your needs.

- make sure the user running the script has write access to Nagios' command
file to send in check results.

- install Ruby and rubygems:

gem install f5-icontrol

gem install ipaddress


13 * * * * cd /home/xuser/f5 && ./f5_gen.sh >f5_gen.out 2>&1
*/5 * * * * cd /home/xuser/f5 && ./f5_update.sh >f5_update.out 2>&1G

For command line options try f5.rb --help.

In nagois.cfg:

- accept_passive_service_checks must be set to 1.

- check_external_commands must be set to 1.

To be able to restart Nagios automatically you need to add sudo access for it
that matches what you have in f5_gen.sh:

xuser    ALL=(root) NOPASSWD: /usr/sbin/service nagios force-reload

2) check_f5_failover_state

This plugin is used to get Nagios to actively check a F5 cluster for a minimum
of 1 active and 1 standby device. To prevent putting the F5 username/password
in the Nagios config I run the check through sudo in a wrapper script
check_f5_failover_state_yourcompany.

For your sudoers file:

nagios     ALL=(xuser) NOPASSWD: /home/xuser/f5/check_f5_failover_state_yourcompany

define command{
        command_name    check_f5_failover_state
        command_line    /usr/bin/sudo -u xuser /home/xuser/f5/check_f5_failover_state_yourcompany "$ARG1$"
        }

define service {
        check_command           check_f5_failover_state!bigip1,bigip2
        contact_groups          f5-admins
        host_name               bigip-external.yourcompany.local
        service_description     f5_failover_state
        use                     generic-service
}
define service {
        check_command           check_f5_failover_state!bigip3,bigip4
        contact_groups          f5-admins
        host_name               bigip-internal.yourcompany.local
        service_description     f5_failover_state
        use                     generic-service
}

For command line options try check_f5_failover_state --help.

3) Monitor your F5 devices uptime to see if they have crashes or unexpectedly
rebooted. This can be done using the standard Nagios snmp plugin.

define service {
        check_command           check_snmp!-C public -o sysUpTime.0 -w 8640000:
        contact_groups          f5-admins
        hostgroup_name          f5-loadbalancers
        service_description     snmp_uptime
        use                     generic-service
}

Anders Nordby <anders@fupp.net>
2016-12-06
