#! /usr/bin/ruby
# Acknowledge services matching with given name in Nagios
# anders@fupp.net, 2016-09-05

require 'nagios_parser/status/parser'
require 'pp'
require 'optparse'
require 'httparty'
require 'nokogiri'

ARGV.push('--help') if ARGV.empty?
options = {}
optparse = OptionParser.new do |opts|
  opts.banner = "Usage: check_http_logintest [options]"

  opts.on("-s", "--service SERVICE", "Service name (regexp match)") do |a|
    options[:service] = a
  end
  opts.on("-c", "--comment COMMENT", "Actually execute acknowledge with given comment") do |a|
    options[:comment] = a
  end
  opts.on("-r", "--rescedule", "Rescedule check of service, dont ack") do |a|
    options[:reschedule] = a
  end
  opts.on_tail("--help", "Show this message") do
    puts opts
    exit 3
  end
end

begin
  optparse.parse!
  mandatory = [:service]
  missing = mandatory.select{ |param| options[param].nil? }
  raise OptionParser::MissingArgument, missing.join(', ') unless missing.empty?
rescue OptionParser::ParseError => e
    puts e
    puts optparse
  exit 3
end

nauth = {:username => "nagios", :password => "XXXXXXXX"}
status = File.open("/var/log/nagios/status.dat").read
data = NagiosParser::Status::Parser.parse(status)
smatch = options[:service]
comment = options[:comment]

smatches = 0
data["servicestatus"].each do |service|
	desc = service["service_description"]
	udesc = desc.gsub(/ /, "+")
	next if not desc.match(/#{smatch}/)
	next if service["problem_has_been_acknowledged"] != 0

	host = service["host_name"]
	state = service["current_state"]
	if state == 0
		next
	end
	puts "Fant service som matcher #{smatch} state=#{state} host=#{host} desc=#{desc}"
	smatches += 1
	url="http://nagios.foo.local/nagios/cgi-bin//cmd.cgi"
	if not comment.nil?
#		url="http://nagios.foo.local/nagios/cgi-bin//cmd.cgi?cmd_typ=34&host=#{host}&service=#{udesc}"
#		response = HTTParty.get(url, :basic_auth => nauth, debug_output: $stderr)
		body = {
				"cmd_typ" => 34,
				"cmd_mod" => 2,
				"host" => host,
				"service" => desc,
				"sticky_ack" => "on",
				"send_notification" => "on",
				"com_data" => comment,
				"btn_Submit" => "Commit",
		}

#		pp body
#		puts "Comment: #{comment}"
#		puts "Comment option: " + options[:comment].to_s
#.to_json
		response = HTTParty.post(url,
			:body => body,
			:basic_auth => nauth
#			debug_output: $stderr
		)
		puts "Acket denne og fikk #{response.code.to_s}"
		text = Nokogiri::HTML(response.body).text
		text.split(/\n/).each do |tstr|
			next if tstr.match(/^$/)
			next if tstr.match(/^External Command Interface/)
			next if tstr.match(/^Last Updated:/)
			next if tstr.match(/^Nagios.*Core/)
			next if tstr.match(/^Logged in as/)
			puts tstr
		end

#		puts text
#		puts "Request body:"
#		puts body
#		puts "Response body:"
#		puts response.body
		puts "-----"
		
#	end
#	exit if smatches > 5
	elsif options[:reschedule]
		body = {
			"cmd_typ" => 7,
			"cmd_mod" => 2,
			"host" => host,
			"service" => desc,
			"start_time" => (Time.now+10).strftime("%m-%d-%Y %H:%M:%S").to_s,
			"force_check" => "on",
			"btn_Submit" => "Commit",
		}
		response = HTTParty.post(url,
			:body => body,
			:basic_auth => nauth
#			debug_output: $stderr
		)
		puts "Reskedulerte sjekk av denne og fikk #{response.code.to_s}"
		text = Nokogiri::HTML(response.body).text
		text.split(/\n/).each do |tstr|
			next if tstr.match(/^$/)
			next if tstr.match(/^External Command Interface/)
			next if tstr.match(/^Last Updated:/)
			next if tstr.match(/^Nagios.*Core/)
			next if tstr.match(/^Logged in as/)
			puts tstr
		end
	end
end
puts "Antall matches: #{smatches.to_s}"
