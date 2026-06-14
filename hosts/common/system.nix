{ config, lib, pkgs, ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;


  #Steam, Proton, and most native Linux games still ship 32-bit binaries or depend on 32-bit Mesa/driver libs, and without this Steam will just silently fail to launch most games
  hardware.graphics.enable32Bit = true;

  networking.networkmanager.enable = true;

  time.timeZone = "America/New_York";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS        = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT    = "en_US.UTF-8";
    LC_MONETARY       = "en_US.UTF-8";
    LC_NAME           = "en_US.UTF-8";
    LC_NUMERIC        = "en_US.UTF-8";
    LC_PAPER          = "en_US.UTF-8";
    LC_TELEPHONE      = "en_US.UTF-8";
    LC_TIME           = "en_US.UTF-8";
  };

  services.xserver.enable = true;
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;
  services.xserver.xkb = {
    layout  = "us";
    variant = "";
  };

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication         = false;
      KbdInteractiveAuthentication   = false;
      PermitRootLogin                = "no";
      AllowUsers                     = [ "vcaaron" ];
    };
  };

  services.printing.enable = true;

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable           = true;
    alsa.enable      = true;
    alsa.support32Bit = true;
    pulse.enable     = true;
  };

  virtualisation = {
    containers.enable = true;
    oci-containers.backend = "podman";
    podman = {
      enable                       = true;
      autoPrune.enable             = true;
      dockerCompat                 = true;
      defaultNetwork.settings.dns_enabled = true;
    };
  };

  security.unprivilegedUsernsClone = true;

  programs.ssh.startAgent = true;
  programs.kdeconnect.enable = true;

  nix.settings = {
    trusted-users          = [ "root" "vcaaron" ];
    experimental-features  = [ "nix-command" "flakes" ];
  };

  system.stateVersion = "25.05";

  environment.variables = {
    PKG_CONFIG_PATH = "${pkgs.openssl.dev}/lib/pkgconfig";
  };
}
