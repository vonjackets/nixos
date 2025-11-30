# get similar bash "source" like behavior from an nuon file containing some extra vars
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
