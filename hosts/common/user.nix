let

username = "vcoates";
home = "/home/vcoates";
# Create a default user for development
vcoates = {
  inherit home;
  isNormalUser = true;
  description = "";
  extraGroups = [ "networkmanager" "wheel" "docker" ];
  # openssh.authorizedKeys.keys = [];
};

in
{
  inherit vcoates;
}
