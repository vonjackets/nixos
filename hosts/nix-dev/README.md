# Software Development Configuration for NixOS  

This repository contains some  **NixOS configurations** tailored for software development activities, designed to streamline development workflows and provide a robust, reproducible environment for developers. (But mostly myself). This is partly meant for daily usage as I work and prototype.


NOTE: There is an open bug in the vscode-server support library that tends to fail to start the systemd service properly. See issue https://github.com/nix-community/nixos-vscode-server/issues/70#issuecomment-2268488122. running this command to start the service manually seems to be a good workaround

---

## Features  
- TODO: I am planning to harden the nixos configuration more than it is, and convert to a flake based configuration.
### **Developer-Friendly Tools**
- I try to include essential development tools to my daily workflow in the base nixos config, so some may come and go as I continue working on projects.

- TODO: Configures IDE support with **language servers** for popular languages like Python, JavaScript, Rust, and Go.  

### **Containerization**
Flake defined images of development environments including:
- Python
- TODO: Rust
- TODO: Node.js?


### **Networking and Port Access**
- I only configure HTTP/S and SSH here, but as I continue working with new tools and things, I may use the nixos-firewall-tool to manipulate it further.

### **Custom Development Shortcuts**
TODO

---

## Usage  

1. Clone this repository into `/etc/nixos` or your desired location.  
2. Update the `configuration.nix` file to include this repository in your NixOS configuration:  
   ```nix
   imports = [
     ./path-to-clone/nix-config/configuration.nix
   ];
   ```  
3. Rebuild your NixOS configuration:  
   ```bash
   sudo nixos-rebuild switch
   ```  

---

Happy coding! 🚀  