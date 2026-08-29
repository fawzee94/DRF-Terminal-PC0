# Bootloader, kernel parameters, and the Plymouth splash screen.
#
# Shared between both machines. Machine-specific kernel quirks (e.g. the
# desktop's USB-C controller workaround in hosts/desktop.nix) are added
# in the host files, not here - boot.kernelParams and
# boot.supportedFilesystems are list-type options, so NixOS concatenates
# every module's list rather than one overriding another. No merge logic
# needed on our end.
{ pkgs, ... }:
{
  boot = {
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # Hide the OS choice on the bootloader menu. Still reachable by
    # pressing any key during boot - it just won't show unprompted.
    loader.timeout = 0;

    supportedFilesystems = [ "ntfs" ];

    plymouth = {
      enable = true;
      theme = "lone";
      themePackages = with pkgs; [
        # Only build the "lone" theme instead of the full default set,
        # to keep the closure smaller.
        (adi1090x-plymouth-themes.override {
          selected_themes = [ "lone" ];
        })
      ];
    };

    # "Silent boot": suppress console log spam so the Plymouth splash is
    # what's actually shown during startup.
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "acpi_backlight=video"
    ];
  };
}
