# ~/.config/nushell/config.nu

#import custom modules
use /Users/vacoates/.config/nushell/bash-env.nu *
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

# --- Core PATH setup for Intel macOS ---
let home = $env.HOME

#proxies

$env.NO_PROXY = "localhost,127.0.0.1,*.cc.cert.org,10.96.0.0/12,192.168.59.0/24,192.168.49.0/24,192.168.39.0/24,kind-control-plane"
$env.http_proxy = "cloudproxy.sei.cmu.edu:80"
$env.https_proxy = "cloudproxy.sei.cmu.edu:80"
$env.HTTPS_PROXY = "cloudproxy.sei.cmu.edu:80"
$env.HTTP_PROXY =  "cloudproxy.sei.cmu.edu:80"
$env.SSL_CERT_FILE = "/etc/ssl/certs/ZscalerRootCertificate-2048-SHA256.crt"
# configure testcontainers to use our podman socker
# $env.TESTCONTAINERS_DOCKER_SOCKET_OVERRIDE = "/var/run/docker.sock"

# Starship prompt integration

$env.STARSHIP_SHELL = "nu"
$env.STARSHIP_CONFIG = $"($env.HOME)/.config/starship.toml"

def create_left_prompt [] {
  starship prompt --cmd-duration ($env.CMD_DURATION_MS | default 0)
}

#impure nixbuilds
#$env.NIXPKGS_ALLOW_UNSUPPORTED_SYSTEM = 1

# --- Prompt (optional, customizable) ---
$env.PROMPT_COMMAND = {|| $"(create_left_prompt) (whoami)@(hostname):(pwd) >" }
$env.PROMPT_INDICATOR = ""
$env.PROMPT_INDICATOR_VI_INSERT = ""
$env.PROMPT_INDICATOR_VI_NORMAL = ""

$env.PATH = [
  #make bash-env-json and other bash modules executable
  "/Users/vacoats/.config/nushell"
  "/usr/local/bin"
  "/usr/bin"
  "/bin"
  "/usr/sbin"
  "/sbin"
  "/nix/var/nix/profiles/default/bin"
  "/opt/podman/bin/"
  $"($home)/.nix-profile/bin"
  $"($home)/.cargo/bin"
  "/Applications/Zed.app/Contents/MacOS"
] | uniq | str join (char esep)

$env.config = {
  hooks: {
    pre_prompt: [{ ||
      if (which direnv | is-empty) {
        return
      }

      direnv export json | from json | default {} | load-env
      if 'ENV_CONVERSIONS' in $env and 'PATH' in $env.ENV_CONVERSIONS {
        $env.PATH = do $env.ENV_CONVERSIONS.PATH.from_string $env.PATH
      }
    }]
  }
  show_banner:  false
  buffer_editor:  "vim"
  edit_mode: vi
}

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
alias z = zoxide
# --- Handy utilities ---
# configure to use zoxide
source ~/.zoxide.nu

# Direnv integration
{ ||
    if (which direnv | is-empty) {
        return
    }

    direnv export json | from json | default {} | load-env
    # Direnv outputs $PATH as a string, but nushell silently breaks if isn't a list-like table.
    # The following behemoth of Nu code turns this into nu's format while following the standards of how to handle quotes, use it if you need quote handling instead of the line below it:
    $env.PATH = $env.PATH | parse --regex ('' + `((?:(?:"(?:(?:\\[\\"])|.)*?")|(?:'.*?')|[^` + (char env_sep) + `]*)*)`) | each {|x| $x.capture0 | parse --regex `(?:"((?:(?:\\"|.))*?)")|(?:'(.*?)')|([^'"]*)` | each {|y| if ($y.capture0 != "") { $y.capture0 | str replace -ar `\\([\\"])` `$1` } else if ($y.capture1 != "") { $y.capture1 } else $y.capture2 } | str join }
    #$env.PATH = $env.PATH | split row (char env_sep)
}
