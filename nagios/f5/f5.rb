#! /usr/bin/ruby
# Monitor F5 load balancers with Nagios
# 2016-11-18, Anders Nordby <anders@fupp.net>
# Requirement: must run on the Nagios server itself to write to command file

# https://devcentral.f5.com/wiki/iControl.LocalLB.ashx
# https://devcentral.f5.com/wiki/iControl.System__Failover.ashx

# Uses f5-icontrol from rubygems. Easier to install with new Linux distros
# as it uses Savon for SOAP instead of legacy soap support.

require 'f5/icontrol'
require 'pp'
require 'erb'
require 'yaml'
require 'optparse'
require 'digest'
require 'fileutils'
require 'ipaddress'
require 'resolv'

def getfolders
  begin
    $api.System.Session.set_active_folder(:folder => "/Common")
    $folders = $api.Management.Folder.get_list[:item]
  rescue Exception => e
    eexit "Could not get folders list: #{e.to_s}", 3, "status"
  end
  $folders.unshift("/Common")
end

def service_config_template()
  %{
define service {
	use			<%= $config["service_template"] %>
	check_command		<%= $config["dummy_command"] %>
	contact_groups		<%= $config["contact_groups"] %>
	host_name		<%= $f5_hostname %>
	register		1
	service_description	<%= service %>
	
	initial_state		o
	max_check_attempts	<%= $config["max_checks"] %>

        flap_detection_enabled  0
        active_checks_enabled   0
        passive_checks_enabled  1
}
  }
end

def host_config_template()
  %{
define host {
	use			<%= $config["host_template"] %>
	contact_groups		<%= $config["contact_groups"] %>
	host_name		<%= $f5_hostname %>
	alias			<%= $f5_hostname %>
	address			<%= $f5_ip %>
	register		1
	
<% if not $hostgroups.nil? %>
	hostgroups		<%= $hostgroups %>
<% end %>
}
  }
end

def avail_ret (availability)
  case availability
  when "AVAILABILITY_STATUS_GREEN"
    ret=0
  when "AVAILABILITY_STATUS_BLUE"
    ret=0
  when "AVAILABILITY_STATUS_RED"
    ret=2
  else
    ret=3
  end
  return ret
end

def check_f5_status
  $folders.each do |folder|
    puts "Checking folder #{folder}" if $debug
    begin
      $api.System.Session.set_active_folder(:folder => folder)
    rescue Exception => e
      sendres "Could not set active folder to #{folder}: #{e.to_s}", 3, "status"
    end

    begin
      pools = $api.LocalLB.Pool.get_list
    rescue Exception => e
      sendres "Could not get pool list in folder #{folder}: #{e.to_s}", 3, "status"
    end
    pools_a = item_array(pools[:item])
    begin
      pstatus = $api.LocalLB.Pool.get_object_status(:pool_names => { item: pools_a })
    rescue Exception => e
      sendres "Could not get pool statuses in folder #{folder}: #{e.to_s}", 3, "status"
    end
    pstatus_a = item_array(pstatus[:item])
    if not pstatus[:item].nil?
      pstatus_n = pstatus[:item].length
      puts "Pools statuses: count=#{pstatus_a.length.to_s} of #{pools_a.length.to_s} total."
#      if pstatus_a.length != pools_a.length
#        puts "Ulik lengde på pools liste og pools status?"
#        puts "Pools_a:"
#        pp pools_a
#        puts "Pstatus:"
#        pp pstatus
#      end
#    pp pstatus
    else
      puts "No pools status found."
    end

    begin
      pmembersall = $api.LocalLB.Pool.get_member_v2(:pool_names => { item: pools_a })
    rescue Exception => e
      puts "Could not get pool member list for all pools in folder #{folder}: #{e.to_s}"
    end
    pmembersall_a = item_array(pmembersall[:item])
    puts "Pmembersall count: #{pmembersall_a.length.to_s}"

    pi = 0
    pools_a.each do |pool|
      puts "Checking pool #{pool}" if $debug

#      pi = 0
#      item_array(pools[:item]).each do |pool|
#        next if pool != "/Common/service_splunk_pool"
#        if pstatus.nil? or pstatus[:item].nil? or pstatus[:item][pi].nil?
#          puts "Unexpected pstatus data?"
#          puts "Pools lengde: " + item_array(pools[:item]).length.to_s
#          puts "Pstatus " + pstatus.length.to_s + ":"
#          pp pstatus
#          next
#        end
#      puts "Pool status:"
#      puts "PI class: " + pstatus[:item].class.to_s
#      pp pstatus
#      next
#      if pstatus[:item].nil?
#          puts "No pstatus at all" if $debug
#      elsif pstatus[:item][pi].nil?
#          puts "No pstatus for pool item?" if $debug
#      else
#      if not pstatus_a[pi].nil?
      status = pstatus_a[pi][:availability_status]
#       puts "Status for pool #{pool}: #{status}"
      sendres status, avail_ret(status), "pool:#{pool}"
#      end

#      begin
#        pmembers = $api.LocalLB.Pool.get_member_v2(:pool_names => { item: [ pool ] })
#      rescue Exception => e
#        sendres "Could not get pool member list for pool #{pool} in folder #{folder}: #{e.to_s}", 3, "status"
#      end
#      if pmembers[:item].nil? or pmembers[:item][:item].nil? or pmembers[:item][:item].class == Array
#        puts "Unexpected pool members data:"
#        pp pmembers
#      else
      if pmembersall_a[pi][:item].nil?
        puts "No pool members found."
      end
      begin
        pmstatuses = $api.LocalLB.Pool.get_member_object_status(
          :pool_names => { item: [ pool ] },
          :members => { item: [ item_array(pmembersall_a[pi][:item]) ] }
        )
      rescue Exception => e
         sendres "Could not get pool member status for pool #{pool} in folder #{folder}: #{e.to_s}", 3, "status"
      end
#      puts "Got pmstatuses:"
#      pp pmstatuses
#      if pmstatuses.nil?
#        puts "No pmstatuses."
#      else
#        puts "Got pmstatuses."
#        pp pmstatuses
#      end
      pmstatuses_a = item_array(pmstatuses[:item][:item])
#      puts "PMdata:"
#      pp pmembersall_a[pi]
#          :members => { item: [ pmembers[:item][:item] ] }

#        rescue Exception => e
#          sendres "Could not get pool member status for pool #{pool} in folder #{folder}: #{e.to_s}", 3, "status"
#        end
#        if not pmstatuses[:item].nil? and not pmstatuses[:item][:item].nil? and pmstatuses[:item][:item].class == Array
      pmi = 0
      item_array(pmembersall_a[pi][:item]).each do |pmember|
        pmstatus = pmstatuses_a[pmi][:availability_status]
        pmenstatus = pmstatuses_a[pmi][:enabled_status]
        pmaddr = pmember[:address]
        pmport = pmember[:port]
        pmtxt = pmstatus
        if pmenstatus == "ENABLED_STATUS_DISABLED"
          pmret = 0
          pmtxt << " (#{pmenstatus})"
        else
          pmret = avail_ret(pmstatus)
        end
        sendres pmtxt, pmret, "pm:#{pool}:#{pmaddr}:#{pmport}"
        pmi += 1
      end
      pi += 1
    end

    begin
      vses = $api.LocalLB.VirtualServer.get_list
    rescue Exception => e
      eexit "Could not get VS list in folder #{folder}: #{e.to_s}", 3, "status"
    end
    vses_a = item_array(vses[:item])
    begin
      vsstatuses = $api.LocalLB.VirtualServer.get_object_status( :virtual_servers => { item: vses_a } )
    rescue Exception => e
      eexit "Could not get VS statuses in folder #{folder}: #{e.to_s}", 3, "status"
    end
    vsstatuses_a = item_array(vsstatuses[:item])
    vn = 0
    vses_a.each do |vs|
      vsstatus = vsstatuses_a[vn][:availability_status]
      vsenstatus = vsstatuses_a[vn][:enabled_status]
      vstxt = vsstatus
      if vsenstatus == "ENABLED_STATUS_DISABLED"
        vsret = 0
        vstxt << " (#{vsenstatus})"
      else
        vsret = avail_ret(vsstatus)
      end
      sendres vstxt, vsret, "vs:#{vs}"
    end

    # Skip node checks if node_checks set to 0.
    next if (not $config["node_checks"].nil?) and $config["node_checks"].to_s == "0"

    begin
      nodes = $api.LocalLB.NodeAddressV2.get_list
    rescue Exception => e
      eexit "Could not get node list in folder #{folder}: #{e.to_s}", 3, "status"
    end
    nodes_a = item_array(nodes[:item])
    begin
      nodestatuses = $api.LocalLB.NodeAddressV2.get_object_status( :nodes => { item: nodes_a } )
    rescue Exception => e
      eexit "Could not get node statuses in folder #{folder}: #{e.to_s}", 3, "status"
    end
    nodestatuses_a = item_array(nodestatuses[:item])
    nn = 0
    nodes_a.each do |node|
      nodestatus = nodestatuses_a[nn][:availability_status]
      nodenstatus = nodestatuses_a[nn][:enabled_status]
      nodetxt = nodestatus
      if nodestatus == "ENABLED_STATUS_DISABLED"
        noderet = 0
        nodetxt << " (#{vsenstatus})"
      else
        noderet = avail_ret(nodestatus)
      end
      puts "Got node #{node} result ret=#{noderet.to_s} txt=#{nodetxt}"
      sendres nodetxt, noderet, "node:#{node}"
    end
  end
end


def item_array (items)
  if items.class == Array
    return items
  elsif items.class == Hash
    return [items]
  elsif items.class == Nori::StringWithAttributes
    return [items.to_s]
  else
    if $debug and items.class != NilClass
      puts "Got unexpected class: " + items.class.to_s
    end
    return []
  end
end

def generate_config
  if $config["no_host"].nil? or $config["no_host"] != 1
    puts host_config_template
    $nagios_config << ERB.new(host_config_template).result(binding)
  end
  service = "status"
  $nagios_config << ERB.new(service_config_template).result(binding)
  service = "failover_state"
  $nagios_config << ERB.new(service_config_template).result(binding)

  $folders.each do |folder|
    puts "Checking folder #{folder}" if $debug
    begin
      $api.System.Session.set_active_folder(:folder => folder)
    rescue Exception => e
      eexit "Could not set active folder to #{folder}: #{e.to_s}", 3, "status"
    end

    begin
      pools = $api.LocalLB.Pool.get_list
    rescue Exception => e
      eexit "Could not get pool list in folder #{folder}: #{e.to_s}", 3, "status"
    end

    item_array(pools[:item]).each do |pool|
      puts "Checking pool #{pool}" if $debug
      service = "pool:#{pool}"
      $nagios_config << ERB.new(service_config_template).result(binding)

      begin
        pmembers = $api.LocalLB.Pool.get_member_v2(:pool_names => { item: [ pool ] })
      rescue Exception => e
        eexit "Could not get pool member list for pool #{pool} in folder #{folder}: #{e.to_s}", 3, "status"
      end

      item_array(pmembers[:item][:item]).each do |pmember|
#      if pmembers.class == Array
#        puts "Expected Pmembers class: " + pmembers.class.to_s
#        pmembers.each do |pmember|
        if pmember[:address].nil? or pmember[:port].nil?
          puts "Unknown address or port for pool member?"
          pp pmember
        else
          service = "pm:#{pool}:#{pmember[:address]}:#{pmember[:port]}"
          $nagios_config << ERB.new(service_config_template).result(binding)            end 
      end
    end

    begin
      vses = $api.LocalLB.VirtualServer.get_list
    rescue Exception => e
      eexit "Could not get VS list in folder #{folder}: #{e.to_s}", 3, "status"
    end


    item_array(vses[:item]).each do |vs|
      service = "vs:#{vs}"
      $nagios_config << ERB.new(service_config_template).result(binding)
    end

    # Skip node checks if node_checks set to 0.
    next if (not $config["node_checks"].nil?) and $config["node_checks"].to_s == "0"

    begin
      nodes = $api.LocalLB.NodeAddressV2.get_list
    rescue Exception => e
      eexit "Could not get node list in folder #{folder}: #{e.to_s}", 3, "status"
    end
    item_array(nodes[:item]).each do |node|
      service = "node:#{node}"
      $nagios_config << ERB.new(service_config_template).result(binding)
    end
  end
end

def updateconfig
  bfn = "#{$f5_hostname}.cfg"
  tfn = ENV["HOME"] + "/.nagios_check_f5_gen_#{bfn}.tmp"
  cfn = $config["configdir"] + "/#{bfn}"
  begin
    @tfile = File.open(tfn, "w")
  rescue Exception => e
    eexit "Could not write temp Nagios config file to #{tfn}: #{e.to_s}", 3, "status"
  end
  @tfile.write($nagios_config)
  @tfile.close

  md5 = Digest::MD5.new
  if File.file?(cfn)
    cursize = File.stat(cfn).size
    newsize = File.stat(tfn).size
    spct = (cursize-newsize)/cursize.to_f*100
    spctr = spct.round(2)
    maxshrink = $config["config_maxshrink"]
    if newsize < cursize and spct >= maxshrink
      eexit("New config shrinked by #{spctr.to_s}, more than max shrink #{maxshrink.to_s}%. Not using it.", 3, "status")
    end
    oldsum = md5.hexdigest(File.read(cfn)).to_s
  else
    oldsum = nil
  end
  newsum = md5.hexdigest(File.read(tfn)).to_s

  if oldsum != newsum
    puts "Config #{bfn} changed, updating."
    FileUtils.cp tfn, cfn
  else
    puts "Config #{bfn} did not change, not updating."
  end
end


def sendres (txt, excode, service)
  txt = txt.gsub(/\n/, "")
  if STDOUT.isatty and excode != 0
    puts "#{service}:#{txt}"
  end
  uxtime = Time.now.to_i
  $cmdfile.puts "[#{uxtime}] PROCESS_SERVICE_CHECK_RESULT;#{$f5_hostname};#{service};#{excode};#{txt}"
end

def eexit (txt, excode, service)
  txt = txt.gsub(/\n/, "")
  if STDOUT.isatty
    puts "#{txt}"
    exit excode
  else
    uxtime = Time.now.to_i
    $cmdfile.puts "[#{uxtime}] PROCESS_SERVICE_CHECK_RESULT;#{$f5_hostname};#{service};#{excode};#{txt}"
  end
end

$config = YAML.load_file(File.dirname(__FILE__) + '/check_f5.yaml')
#pp $config
#ARGV.push('--help') if ARGV.empty?
options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: check_f5 [options]"

  opts.on("-h", "--host HOSTNAME", "F5 Hostname") do |a|
    options[:host] = a
  end
  opts.on("-H", "--hostgroups HOSTGROUPS", "Associate hosts with listed Nagios hostgroups") do |a|
    options[:hostgroups] = a
  end
  opts.on("-c", "--config-gen", "Generate config (instead of checking") do |a|
    options[:configgen] = a
  end
  opts.on("-p", "--print", "Print config to standard output") do |a|
    options[:print] = a
  end
  opts.on("-d", "--debug", "Print debug output") do |a|
    options[:debug] = a
  end
  opts.on_tail("--help", "Show this message") do
    puts opts
    exit 3
  end
end

begin
  optparse.parse!
end

if not options[:host].nil?
  $f5_hostname = options[:host]
elsif not $config["hostname"].nil?
  $f5_hostname = $config["hostname"]
else
  puts "No F5 hostname found in config or command line arguments. Try --help."
  exit 3
end

if IPAddress.valid?($f5_hostname)
  $f5_ip = $f5_hostname
else
  begin
    $f5_ip = Resolv.getaddress($f5_hostname)
  rescue Exception => e
    $f5_ip = $f5_hostname
  end
end
$hostgroups = options[:hostgroups]
$debug = options[:debug]

F5::Icontrol.configure do |f|
  f.host = $f5_hostname
  f.username = $config["username"]
  f.password = $config["password"]
end

begin
  $cmdfile = File.open($config["nagios_cmdfile"], 'a')
rescue Exception => e
  puts "Could not append to Nagios cmdfile " + $config["nagios_cmdfile"] + " #{e.to_s}. Aborting operation."
  exit 2
end

$api = F5::Icontrol::API.new
begin
  $fstate = $api.System.Failover.get_failover_state.to_s
rescue Exception => e
  eexit "Could not get failover state: #{e.to_s}", 3, "failover_state"
end
if ['FAILOVER_STATE_STANDBY','FAILOVER_STATE_ACTIVE'].include? $fstate
  sendres "Failover state: #{$fstate}", 0, "failover_state"
else
  eexit "Unexpected failover state: #{$fstate}", 3, "failover_state"
end
#pp $fstate

if options[:configgen]
  $nagios_config = ""
  getfolders
  if $folders.nil?
    puts "Got no folders."
  else
    generate_config
  end
  if options[:print]
    puts "The config will be:"
    puts $nagios_config
  else
    updateconfig
    bfn = "#{@f5_hostname}.cfg"
    tfn = ENV["HOME"] + "/.nagios_check_f5_gen_#{bfn}.tmp"
    cfn = "#{@configdir}/#{bfn}"
    begin
      @tfile = File.open(tfn, "w")
    rescue Exception => e
      eexit "Could not write temp Nagios config file to #{tfn}: #{e.to_s}", 3, "status"
    end
  end
else
  if $fstate == "FAILOVER_STATE_STANDBY" and $config["check_standby"] == 0
    puts "Not running checks, we are in standby and are configured not to run checks against standby F5 hosts."
    exit 0
  elsif $fstate == "FAILOVER_STATE_ACTIVE" and $config["check_active"] == 0
    puts "Not running checks, we are in active and are configured not to run checks aginst active F5 hosts."
    exit 0
  end
  getfolders
  check_f5_status
end

$cmdfile.close