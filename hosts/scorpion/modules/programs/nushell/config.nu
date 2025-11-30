# ~/.config/nushell/config.nu
use std/util "path add"

#import custom modules
def --env source-env [file: path = ".env.nuon"] {
    let vars = open $file
    load-env $vars
}

# fuzzy find a directory and switch to it so we don't have to spend so much time tabbing and selecting
def --env ffcd [
  pattern?: string  # optional fuzzy pattern
] {
  let search = (if ($pattern | is-empty) { "" } else { $pattern })
  let dir = (fd --type d --hidden --exclude .git $search | sk --height 40% --prompt "jump> ")
  if ($dir | is-empty) {
    return
  }

  let target = (zoxide query $dir | complete)
  if ($target.exit_code == 0 and ($target.stdout | str length) > 0) {
    cd ($target.stdout | str trim)
  } else {
    cd $dir
  }
}

def zfcd [] {
  let query = (fd --type d . | fzf --no-sort --reverse --height 40% --prompt "jump> ")
  if $query != null and ($query | str length) > 0 {
    cd $query
  } else {
    let known = (zoxide query -i | complete)
    if ($known.exit_code == 0) and ($known.stdout | str length) > 0 {
      cd ($known.stdout | str trim)
    } else {
      print "no matching directory found"
    }
  }
}

# --- Nix Daemon Path ---
if ("/nix/var/nix/profiles/default/bin" | path exists ) {
  $env.PATH = ([
    "/nix/var/nix/profiles/default/bin"
  ] ++ ($env.PATH | split row (char esep))) | uniq | str join (char esep)
}

# Get the system path for our nix profile
let system_path = (
    ^bash -c 'source /etc/profile; printf $PATH'
)

path add system_path
$env.NO_PROXY = "localhost,127.0.0.1,10.96.0.0/12,192.168.59.0/24,192.168.49.0/24,192.168.39.0/24,kind-control-plane"
$env.config.show_banner = false
$env.EDITOR = "vim"

# --- Aliases you might port from fish ---
alias ls = eza --icons --group-directories-first
alias ll = eza -lh --git
alias cat = bat
alias gs = git status
alias gd = git diff
alias s = sudo
alias m = mask
alias p = podman
alias k = kubectl
# --- Handy utilities ---
# configure to use zoxide
source ~/.config/nushell/.zoxide.nu
