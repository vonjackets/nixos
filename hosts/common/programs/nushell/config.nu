# ~/.config/nushell/config.nu
use std/util "path add"

# use community modules we'll have had pulled in by the time this config is used. See home.nix
use modules/docker/mod.nu *
use modules/kubernetes/mod.nu *

#import custom modules
def --env source-env [file: path = ".env.nuon"] {
    let vars = open $file
    load-env $vars
}

$env.config.show_banner = false
$env.EDITOR = "vim"
def create_left_prompt [] {
    starship prompt --cmd-duration $env.CMD_DURATION_MS $'--status=($env.LAST_EXIT_CODE)'
}
$env.STARSHIP_SHELL = "nu"
$env.STARSHIP_CONFIG = $"($env.HOME)/.config/starship/starship.toml"
# Use nushell functions to define the right and left prompt
$env.PROMPT_COMMAND = { || create_left_prompt }
$env.PROMPT_COMMAND_RIGHT = ""
# The prompt indicators are environmental variables that represent
# the state of the prompt
$env.PROMPT_INDICATOR = ""
$env.PROMPT_INDICATOR_VI_INSERT = ": "
$env.PROMPT_INDICATOR_VI_NORMAL = "〉"
$env.PROMPT_MULTILINE_INDICATOR = "::: "

alias ls = eza --icons --group-directories-first
alias ll = eza -lh --git
alias cat = bat
alias gs = git status
alias gd = git diff
alias s = sudo
alias m = mask
alias p = podman
alias k = kubectl
alias dyaml = dhall-to-yaml --file
alias djson = dhall-to-json --file
alias dfmt = dhall format
# --- Handy utilities ---
# configure to use zoxide
source ~/.config/nushell/.zoxide.nu
