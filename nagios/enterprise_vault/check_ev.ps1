##
## THIS FILE IS UNDER PUPPET CONTROL. DON'T EDIT IT HERE.
##

# Check Enterprise Vault
# Anders Nordby <anders.nordby@moller.no>

Param(
	[string]$mode,
	[string]$warning,
	[string]$critical,
	[string]$exclude
)

#$ErrorActionPreference="SilentlyContinue"
#Stop-Transcript | out-null
#$ErrorActionPreference = "Continue"
#Start-Transcript -path C:\check_ev_output.txt -append

# Norsk tegnsett: iconv -f utf-8 -t cp1252

Set-ExecutionPolicy Unrestricted

function load-dll {
	import-module "C:\Program Files (x86)\Enterprise Vault\Symantec.EnterpriseVault.PowerShell.Core.dll"
	import-module "C:\Program Files (x86)\Enterprise Vault\Symantec.EnterpriseVault.PowerShell.Monitoring.dll"
}

function checkspace ($type) {
	load-dll
	$floc = get-evfileLocation -type $type
	$free = $floc.TotalQuotaGBytesFree
	$total = $floc.TotalQuotaGBytesAvailable
	$pctdiskfree = [math]::Round(($free/$total)*100,2)
	write-host "Available $type space: $pctdiskfree% ($free out of $total GB disk space free)"
	if ($pctdiskfree -lt $critical) {
		exit 2
	} elseif ($pctdiskfree -lt $warning) {
		exit 1
	} else {
		exit 0
	}
}

function checkdb ($type) {
	load-dll
	$ret = 0
	$oktxt = ""
	$errtxt = ""
	get-evstoragedatabase | foreach-object {
		if ($_.Type -eq $type) {
			$entryid = $_.EntryId
			$ssentryid = $_.StorageServiceEntryId
			Get-EVDatabaseFileInfo -databasetype $type -entryid $entryid -storageserviceentryid $ssentryid | ForEach-Object {
				$dbinfo = $_
#				$dbinfo
				$lfn = $_.LogicalFileName
				$bkuphours = $_.Hourssincelastbackup
				$free = $_.TotalQuotaGBytesFree
				$total = $_.TotalQuotaGBytesAvailable
				$pctfree = [math]::Round(($free/$total)*100,2)
				$ftype = $_.FileType | out-string -stream
				$ftype = $ftype.ToLower()
				if ($ftype -eq "log") {
					$climithrs = 24
					$wlimithrs = 12
					$climitpfree = 5
					$wlimitpfree = 10
				} else {
					$climithrs = 72
					$wlimithrs = 48
					$climitpfree = 10
					$wlimitpfree = 25
				}
			
				$rettxt = " entry $lfn $ftype ($bkuphours hours since backup, $pctfree% free space)"
				if ($bkuphours -ge $climithrs -or $pctfree -le $climitpfree) {
					$errtxt += $rettxt
					$ret = 2
				} elseif ($bkuphours -ge $wlimithrs -or $pctfree -le $wlimitpfree) {
					$errtxt += $rettxt
					if ($ret -eq 0) {
						$ret = 1
					}
				} else {
					$oktxt += $rettxt
				}
			}
		}	
	}
	if ([string]::IsNullOrEmpty($errtxt)) {
		write-host "$type database OK:$oktxt"
	} else {
		write-host "$type database problems:$errtxt|$oktxt"
	}
	exit $ret
}

function check_connectivity ($counter, $text) {
	$ret = 0
	$rettxt = "$text connectivity:"
	$connectivity = get-counter -counter $counter
	foreach ($sample in $connectivity.countersamples) {
		$instance = $sample.InstanceName
		$value = $sample.CookedValue
		if ($value -ne 1) {
			$ret = 1
		}
		$rettxt += " $instance ($value)"
	}
	write-host $rettxt
	exit $ret
}

switch ($mode) {
	"space" {
		checkspace application
	}
	"cachespace" {
		checkspace cache
	}
	"tempspace" {
		checkspace temporary
	}
	"services" {
		load-dll
		$oktxt = ""
		$warntxt = ""
		get-evservice | foreach-object {
			$service = $_.Name
			$state = get-service $service
			$status = $state.Status
			if ($status -eq "Running") {
				$oktxt += " $service ($status)"
			} else {
				$warntxt += " $service ($status)"
			}
		}
		get-evdependencyservice | foreach-object {
			$service = $_.Name
			$state = get-service $service
			$status = $state.Status
			if ($status -eq "Running") {
				$oktxt += " $service ($status)"
			} else {
				$warntxt += " $service ($status)"
			}
		}

		IF([string]::IsNullOrEmpty($warntxt)) {
			write-host "All services OK:$oktxt"
			exit 0
		} else {
			write-host "Services with issues:$warntxt $oktxt"
			exit 1
		}
	}
	"dirdatabase" {
		load-dll
		$oktxt = ""
		$errtxt = ""
		$ret = 0
		Get-EVDatabaseFileInfo -databasetype directory | ForEach-Object {
			$ftype = $_.FileType | out-string -stream
			$ftype = $ftype.ToLower()

			if ($ftype -eq "log") {
				$climithrs = 24
				$wlimithrs = 12
				$climitpfree = 5
				$wlimitpfree = 10
			} else {
				$climithrs = 72
				$wlimithrs = 48
				$climitpfree = 10
				$wlimitpfree = 25
			}
			$bkuphours = $_.Hourssincelastbackup
			$free = $_.TotalQuotaGBytesFree
			$total = $_.TotalQuotaGBytesAvailable
			$pctfree = [math]::Round(($free/$total)*100,2)
			$rettxt = " $ftype ($bkuphours hours since backup, $pctfree% free space)"
			if ($bkuphours -ge $climithrs -or $pctfree -le $climitpfree) {
				$errtxt += $rettxt
				$ret = 2
			} elseif ($bkuphours -gt $wlimithrs -or $pctfree -le $wlimitpfree) {
				if ($ret -eq 0) {
					$ret = 1
				}
				$errtxt += $rettxt
			} else {
				$oktxt += $rettxt
			}
		}
		if ([string]::IsNullOrEmpty($errtxt)) {
			write-host "Directory database OK:$oktxt"
		} else {
			write-host "Directory database problems:$errtxt|$oktxt"
		}
		exit $ret
	}
	"database_connectivity" {
		check_connectivity "\Enterprise Vault Databases(*)\Connectivity" "Database"
	}
	"vault_store_partitions_connectivity" {
		check_connectivity "\Enterprise Vault Partitions(*)\Connectivity" "Enterprise Vault Partitions"
	}
	"index_location_connectivity" {
			check_connectivity "\Enterprise Vault Indexing(*)\Index location connectivity state" "Index location"
	}
	"websites_connectivity" {
			check_connectivity "\Enterprise Vault Websites(*)\Connectivity" "Websites"
	}
	"vaultdatabase" {
		checkdb VaultStore
	}
	"fingerprintdatabase" {
		checkdb Fingerprint
	}
	"vault_partitions_backup_mode" {
		# Nothing to monitor/alert?
		$partitions = get-counter -counter "\Enterprise Vault::Directory\Vault Stores in back-up mode"
		$value = $partitions.CounterSamples[0].CookedValue
		write-host "Number of Vault Store partitions in backup mode: $value"
		if ($value -ge $critical) {
			exit 2
		} elseif ($value -ge $warning) {
			exit 1
		} else {
			exit 0
		}		
	}
	"vault_store_partitions" {
		load-dll
		$ret = 0
		$oktxt = ""
		$errtxt = ""
		$exclude_array = $exclude -split ','
		Get-EVVaultStorePartition | ForEach-Object {
			$bkuphours = $_.Hourssincelastbackup
			$free = $_.TotalQuotaGBytesFree
			$total = $_.TotalQuotaGBytesAvailable
			$pctfree = [math]::Round(($free/$total)*100,2)
			$partition = $_.Name
		
			$climithrs = 24
			$wlimithrs = 12
			if ($exclude_array -contains $partition) {
				# Exclude space check for these partitions
				$climitpfree = -1
				$wlimitpfree = -1
			} else {
				$climitpfree = 5
				$wlimitpfree = 10
			}
			
			$rettxt = " partition $partition ($bkuphours hours since backup, $pctfree% free space)"
			if ($bkuphours -ge $climithrs -or $pctfree -le $climitpfree) {
				$errtxt += $rettxt
				$ret = 2
			} elseif ($bkuphours -ge $wlimithrs -or $pctfree -le $wlimitpfree) {
				$errtxt += $rettxt
				if ($ret -eq 0) {
					$ret = 1
				}
			} else {
				$oktxt += $rettxt
			}
		}
		if ([string]::IsNullOrEmpty($errtxt)) {
			write-host "Vault Store Partitions OK:$oktxt"
		} else {
			write-host "Vault Store Partition problems:$errtxt|$oktxt"
		}
		exit $ret
	}
	"indexes_backup_mode" {
		load-dll
		$ret = 0
		$oktxt = ""
		$errtxt = ""
		get-evindexlocation | foreach-object {
			$backupmode = $_.BackupMode
			$index = $_.IndexRootPath
			$rettxt = " index $index (backupmode $backupmode)"
			if ($backupmode -ne "Off") {
				$ret = 1
			} else {
				$oktxt += $rettxt
			}
		}
		if ([string]::IsNullOrEmpty($errtxt)) {
			write-host "Index Volumes backup state OK:$oktxt"
		} else {
			write-host "Index Volume backup problems:$errtxt|$oktxt"
		}
		exit $ret
	}
	"indexes" {
		load-dll
		$ret = 0
		$oktxt = ""
		$errtxt = ""
		get-evindexlocation | foreach-object {
			$free = $_.TotalQuotaGBytesFree
			$total = $_.TotalQuotaGBytesAvailable
			$pctfree = [math]::Round(($free/$total)*100,2)
			$index = $_.IndexRootPath
			$rettxt = " index $index ($pctfree% free space)"
			if ($pctfree -le 5) {
				$errtxt += $rettxt
				$ret = 2
			} elseif ($pctfree -le 20) {
				$errtxt += $rettxt
				if ($ret -eq 0) {
					$ret = 1
				}
			} else {
				$oktxt += $rettxt
			}
		}
		if ([string]::IsNullOrEmpty($errtxt)) {
			write-host "Index Volumes space OK:$oktxt"
		} else {
			write-host "Index Volume space problems:$errtxt|$oktxt"
		}
		exit $ret
	}
	"tasks" {
		load-dll
		$ret = 0
		$oktxt = ""
		$errtxt = ""
		get-evtask | foreach-object {
			$name = $_.Name
			$entryid = $_.EntryId
			$state = get-evtaskstate $entryid
			$rettxt = " $name (state $state)"
			if ($state -eq "Running") {
				$oktxt += $rettxt
			} else {
				$errtxt += $rettxt
				$ret = 1
			}
		}
		if ([string]::IsNullOrEmpty($errtxt)) {
			write-host "Tasks OK:$oktxt"
		} else {
			write-host "Task problems:$errtxt|$oktxt"
		}
		exit $ret
	}
	default {

		write-host "Usage: ev.ps1 -mode <space|services> [-warning <n>] [-critical <n>]"
		exit 3
	}
}

#$ErrorActionPreference="SilentlyContinue"
#Stop-Transcript | out-null
#$ErrorActionPreference = "Continue"
