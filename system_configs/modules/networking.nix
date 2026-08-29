# Core networking, shared between both machines.
#
# Per-host firewall ports and any host-only network services (e.g. the
# laptop's torrent daemon) belong in that host's file - they merge in
# automatically since networking.firewall.allowedTCPPorts is a list.
{ ... }:
{
  networking.networkmanager.enable = true;
}
