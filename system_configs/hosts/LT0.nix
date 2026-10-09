# DRF-terminal-LT0 - laptop.
#
# Intel/Nvidia Optimus hybrid graphics (prime sync), onboard Bluetooth,
# a torrent daemon, and a couple of niri-specific extras that aren't on
# the desktop yet.
{ config, pkgs, unstable, ... }:
let
  # llama.cpp built for this machine's GPU and nothing else. The GTX 1050 is
  # Pascal (compute capability 6.1), and nixpkgs' default CUDA target list
  # starts at 7.5 - the stock llama-cpp-cuda compiles nine architectures over
  # several hours and emits no code this card can run. The arch list comes
  # from cudaPackages.flags (pkgs/by-name/ll/llama-cpp/package.nix), which
  # .override cannot reach, hence a scoped nixpkgs import instead.
  #
  # This attribute is .llama-cpp, not .llama-cpp-cuda: cudaSupport is already
  # on globally inside this import, so the base attribute is the CUDA build.
  llamaCppPascal = (import unstable.path {
    system = "x86_64-linux";
    config = {
      allowUnfree = true;
      cudaSupport = true;
      cudaCapabilities = [ "6.1" ];
    };
  }).llama-cpp;
in
{
  networking.hostName = "DRF-terminal-LT0";

  # ---- Bluetooth (laptop-only hardware) --------------------------------------
  hardware.bluetooth = {
    enable = true;
    powerOnBoot = true;
    settings.General.Enable = "Source,Sink,Media,Socket";
  };
  services.blueman.enable = true;

  # ---- GPU: Intel + Nvidia Optimus (hybrid) ------------------------------------
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      libva-vdpau-driver # for AMD/Nvidia
      libvdpau-va-gl
    ];
  };

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    # Off on the laptop: fine-grained/experimental power management can
    # cause sleep/suspend problems on hybrid setups, kept disabled here
    # deliberately (unlike the desktop, which has it on).
    powerManagement.enable = false;
    powerManagement.finegrained = false;
    open = false;
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
  };
  hardware.nvidia.prime = {
    sync.enable = true;
    # Bus IDs are hardware-specific - re-check these with `lspci` if you
    # ever move this config to different laptop hardware.
    intelBusId = "PCI:0:2:0";
    nvidiaBusId = "PCI:1:0:0";
  };

  hardware.opentabletdriver.enable = true;

  # ---- Machine exclusive packages --------------------------------------
  environment.systemPackages = with pkgs; [
  ];


  # FLAG: kept at the laptop's original value rather than bumping to
  # match the desktop's 25.05 - see the note in modules/misc.nix.
  system.stateVersion = "24.11";
}
