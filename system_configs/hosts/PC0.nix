# DRF-terminal-PC0 - desktop tower.
#
# Single dedicated Nvidia GPU (no hybrid/Optimus switching), no
# Bluetooth hardware, and a USB-C dock/controller quirk that needs a
# kernel workaround.
{ config, pkgs, ... }:
{
  networking.hostName = "DRF-terminal-PC0";

  # Desktop-only kernel workaround for a flaky USB-C controller.
  # Merges into modules/bootloader.nix's kernelParams list.
  boot.kernelParams = [ "ucsi_ccg.ignore=1" ];

  # Minecraft server port - only opened on the desktop.
  networking.firewall.allowedTCPPorts = [ 25565 ];

  # ---- GPU: single Nvidia card, no hybrid switching ------------------------
  hardware.graphics.enable = true;

  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    modesetting.enable = true;
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    open = true;
    nvidiaSettings = true;
    # No `package` pin - tracks whatever driver the current nixpkgs
    # channel ships by default. Pin it here if you need a specific
    # version again.
  };

  hardware.opentabletdriver.enable = true;
  
  # 3. Enable Ollama Systemd Service with CUDA GPU Acceleration
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda; # Forces CUDA build instead of CPU
    acceleration = "cuda";     # Explicit GPU offloading target
  };
  
  # ---- Machine exclusive packages --------------------------------------
  environment.systemPackages = with pkgs; [
    # Font editor
    fontforge-gtk
    # AI
    aider-chat
    
    claude-code
    

    # ---- Runtimes ----
    # Required by claude-code plugin hooks (claude-mem, security-guidance).
    # The claude-code derivation wraps its own node but doesn't expose it,
    # so hooks calling `node`/`python3` need these on PATH.
    nodejs
    python3
    # claude-mem's worker daemon uses the bun:sqlite API, which only Bun
    # provides - node cannot substitute for it.
    bun

    # ---- Claude Plugin tools ----
    # Not needed at session start like the runtimes above - these are shelled
    # out to on demand, so a missing one only breaks the skill that calls it.
    # PR review workflows: /code-review <PR#>, receiving-code-review,
    # babysit, standup, oh-my-issues.
    gh
    # JSON parsing in the babysit, oh-my-issues and wowerpoint skills.
    jq
    # `dot`, for rendering diagrams when authoring superpowers skills.
    graphviz
  ];
  
  # NixOS version at the time of install for legacy support purposes
  # after updates- only bump it if you've read the release notes for
  # the version jump and are sure.
  system.stateVersion = "25.05";
}
