
{ config, pkgs, ... }:

{
  imports =
    [ # Include the results of the hardware scan.
      ./hardware-configuration.nix
    ];

  # we've got a bluetooth adapater, mightaswell use it
  #
  hardware.bluetooth.enable = true;
  # Bootloader.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.hostName = "scorpion"; # Define your hostname.

  networking.networkmanager.enable = true;

  # Set your time zone.
  time.timeZone = "America/New_York";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Enable the X11 windowing system.
  # You can disable this if you're only using the Wayland session.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };

  services.openssh = {
      enable = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
        PermitRootLogin = "no";
        AllowUsers = [ "vcaaron" ];
      };
    };

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.vcaaron = {
    isNormalUser = true;
    description = "vcaaron";
    extraGroups = [ "networkmanager" "wheel" "podman" ];
    packages = with pkgs; [
      kdePackages.kate
    ];
  };

  # enable passwordless sudo, this is the only user account we need
  # security.sudo.extraRules = [
  #   {
  #     users = ["vcaaron"];
  #     commands = [ { command = "ALL"; options = "NOPASSWD"; } ];

  #   }
  # ];

  nix.settings = {
   trusted-users = ["root" "vcaaron"];
   experimental-features = ["nix-command" "flakes"];

  };

  # enable useage of containers, I prefer podman.
  virtualisation = {
    containers.enable = true;
    podman = {
      enable = true;
      dockerCompat = true;
      defaultNetwork.settings.dns_enabled = true; # Required for containers under podman-compose to be able to talk to each other.
    };
  };

  # # Install firefox.
  # programs.firefox.enable = true;

  # # start the ssh agent on login
  programs.ssh.startAgent = true;

  # List packages installed in system profile. To search, run:
  environment.systemPackages = with pkgs; [
       # -- Basic Required Files --
      gnugrep # GNU version of grep for searching text
      gnused # GNU version of sed for text processing
      gnutar # GNU version of tar for archiving
      gzip # Compression utility


      ghostty # a simply better terminal
      nushell # a simply better shell
      vim # THE editor of editors
      zed-editor # because we actually code
      starship
      atuin

      mask # a pretty good comamnd runner
      # -- OpenSSL --
      cacert
      dropbear
      openssh
      openssl
      openssl.dev

      # -- Development tools --
      zoxide # better than cd
      kubectl
      fluxcd
      bat
      curl
      xh
      delta
      direnv
      eza
      fd
      findutils
      fzf
      gawk
      getent
      git
      gnugrep
      iproute2
      jq
      lsof
      man
      man-db
      man-pages
      man-pages-posix
      ncurses
      procps
      ps
      ripgrep
      rsync
      rustlings
      strace
      tree
      tree-sitter
      which

      dhall
      dhall-yaml
      dhall-json

      # -- Compilers, Etc. --
      cmake
      gnumake
      glibc
      grc
      pkg-config
      util-linux
      sops
      envsubst
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;


  system.stateVersion = "25.05";

}
