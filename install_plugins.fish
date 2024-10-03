# install fish plugins via fundle

#!/usr/bin/env fish

# Ensure fundle is installed
# Load fundle
fundle init

# Add desired plugins
fundle plugin 'edc/bass'
fundle plugin 'patrickF1/fzf.fish'

#restart shell
exec fish
# Install the plugins
fundle install
# Print success message
echo "Plugins have been installed successfully."

# Optionally, re-source the shell configuration to apply changes
source ~/.config/fish/config.fish
