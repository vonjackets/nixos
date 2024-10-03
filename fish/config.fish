## Set any proxies we might need here

## Install plguins
fundle plugin 'edc/bass'
fundle plugin 'patrickF1/fzf.fish'

#init
fundle init

if status is-interactive
    # Commands to run in interactive sessions can go here
end

function show_fish
    fish_logo
end
