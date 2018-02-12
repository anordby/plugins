Enterprise Vault plugin for Nagios. Uses Powershell, so must run in Windows and must have access to Enterprise Vault DLLs Checks: space, services, various DBs, Vault Store partitions, Windows events, indexes and indexes backup mode, tasks etc.

How to set it all up?

- You need a Nagios agent service on the Windows server associated with your
Enterprise Vault environment. I use <a href="https://itefix.net/winrpe">Nagios NRPE for Windows from itefix.net</a>.

- You need to import nrpe config settings from ev.cfg.erb here, and put it in
nrpe.cfg and/or NRPE config files on your Windows server.

- Add monitoring on your Nagios server, hints are in ev.pp here which I use to
set it up using Puppet.

- You may/probably need to adjust which user the NRPE/Nagios agent runs as in
Windows, in order to have it running with a user that has Enterprise Vault
privileges (we do this here) instead of the default local system account
SvcXinet that WiNRPE uses initially. Go to your services list, find XinetServer
service which runs NRPE, and change account in the Log On tab.

Anders Nordby <anders@fupp.net>
