Enterprise Vault plugin for Nagios. Uses Powershell, so must run in Windows and must have access to Enterprise Vault DLLs Checks: space, services, various DBs, Vault Store partitions, Windows events, indexes and indexes backup mode, tasks etc.

The file ev.pp contains the Nagios config parameters I use when setting up the checks in Puppet.

Anders Nordby <anders@fupp.net>
