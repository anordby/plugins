class nagios::monitor::ev {
	# Need agent bits first
	include ::nagios::agent::windows
	include ::nagios::export

	include ::nagios::plugins::windows::ev

	$pluginslocaldir = $::nagios::agent::windows::pluginslocaldir
	file {
		"${::nagios::agent::windows::agentdir}/etc/nrpe.d/ev.cfg":
			ensure	=> file,
			owner	=> 'Administrators',
			mode	=> 0444,
			content	=> template("nagios/monitor/ev.cfg.erb"),
			notify	=> Service["nrpe"],
		;
	}
	Nagios_service {
		use		=> "generic-service",
		host_name	=> $fqdn,
		contact_groups	=> "$nagios::export::default_contactgroup,ev-admins",
		register	=> 1,
		target		=> "/etc/nagios/autoconf.d/service_${fqdn}.cfg",
		mode		=> "0644",
	}

	if hiera("nagios::disable",false) == false {
		@@nagios_service {
			"check_ev_space_${fqdn}":
				service_description	=> "ev_space",
				check_command		=> "check_nrpe!check_ev_space",
			;
			"check_ev_space_cache_${fqdn}":
				service_description	=> "ev_space_cache",
				check_command		=> "check_nrpe!check_ev_space_cache",
			;
			"check_ev_space_temp_${fqdn}":
				service_description	=> "ev_space_temp",
				check_command		=> "check_nrpe!check_ev_space_temp",
			;
			"check_ev_services_${fqdn}":
				service_description	=> "ev_services",
				check_command		=> "check_nrpe!check_ev_services",
			;
			"check_ev_dirdb_${fqdn}":
				service_description	=> "ev_dirdb",
				check_command		=> "check_nrpe!check_ev_dirdb",
				notification_interval	=> "240",
				normal_check_interval	=> "240",
				retry_check_interval	=> "60",
			;
			"check_ev_db_connectivity_${fqdn}":
				service_description	=> "ev_db_connectivty",
				check_command		=> "check_nrpe!check_ev_db_connectivity",
				notification_interval	=> "15",
				normal_check_interval	=> "15",
				retry_check_interval	=> "5",
			;
			"check_ev_vaultdb_${fqdn}":
				service_description	=> "ev_vaultdb",
				check_command		=> "check_nrpe!check_ev_vaultdb",
				notification_interval	=> "60",
				normal_check_interval	=> "60",
				retry_check_interval	=> "60",
			;
			"check_ev_fingerprintdb_${fqdn}":
				service_description	=> "ev_fingerprintdb",
				check_command		=> "check_nrpe!check_ev_fingerprintdb",
				notification_interval	=> "240",
				normal_check_interval	=> "240",
				retry_check_interval	=> "60",
			;
			"check_ev_vault_store_partitions_${fqdn}":
				service_description	=> "ev_vault_store_partitions",
				check_command		=> "check_nrpe!check_ev_vault_store_partitions",
				notification_interval	=> "15",
				normal_check_interval	=> "15",
				retry_check_interval	=> "5",
			;
			"check_ev_vault_store_partitions_connectivity_${fqdn}":
				service_description	=> "ev_vault_store_partitions_connectivity",
				check_command		=> "check_nrpe!check_ev_vault_store_partitions_connectivity",
				notification_interval	=> "240",
				normal_check_interval	=> "240",
				retry_check_interval	=> "120",
			;
			"check_ev_events_${fqdn}":
				service_description	=> "ev_events",
				check_command		=> "check_nrpe!check_ev_events",
				notification_interval	=> "15",
				normal_check_interval	=> "15",
				retry_check_interval	=> "5",
			;
			"check_ev_indexes_${fqdn}":
				service_description	=> "ev_indexes",
				check_command		=> "check_nrpe!check_ev_indexes",
				notification_interval	=> "15",
				normal_check_interval	=> "15",
				retry_check_interval	=> "5",
			;
			"check_ev_index_location_connectivity_${fqdn}":
				service_description	=> "ev_index_location_connectivity",
				check_command		=> "check_nrpe!check_ev_index_location_connectivity",
				notification_interval	=> "5",
				normal_check_interval	=> "5",
				retry_check_interval	=> "5",
			;
			"check_ev_websites_connectivity_${fqdn}":
				service_description	=> "ev_websites_connectivity",
				check_command		=> "check_nrpe!check_ev_websites_connectivity",
				notification_interval	=> "5",
				normal_check_interval	=> "5",
				retry_check_interval	=> "5",
			;
			"check_ev_tasks_${fqdn}":
				service_description	=> "ev_tasks",
				check_command		=> "check_nrpe!check_ev_tasks",
				notification_interval	=> "5",
				normal_check_interval	=> "5",
				retry_check_interval	=> "5",
			;
			"check_ev_indexes_backup_mode_${fqdn}":
				service_description	=> "ev_indexes_backup_mode",
				check_command		=> "check_nrpe!check_ev_indexes_backup_mode",
				notification_interval	=> "5",
				normal_check_interval	=> "5",
				retry_check_interval	=> "5",
				check_period		=> "enterprise-vault-worktime",
			;
			"check_ev_vault_store_partitions_backup_mode_${fqdn}":
				service_description	=> "ev_vault_store_partitions_backup_mode",
				check_command		=> "check_nrpe!check_ev_vault_store_partitions_backup_mode",
				notification_interval	=> "5",
				normal_check_interval	=> "5",
				retry_check_interval	=> "5",
				check_period		=> "enterprise-vault-worktime",
			;
		}
	}
}
