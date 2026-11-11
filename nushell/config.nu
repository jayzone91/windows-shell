
$env.config.keybindings ++= [
    {
        name: fzf_files
        modifier: control
        keycode: char_t
        mode: emacs
        event: {
            send: executehostcommand
            cmd: "let selected = (fd --type f --hidden --exclude .git | fzf --height=40% --layout=reverse --query (commandline)); if ($selected | is-not-empty) { commandline edit --insert $selected }"
        }
    }
    {
        name: fzf_directories
        modifier: alt
        keycode: char_c
        mode: emacs
        event: {
            send: executehostcommand
            cmd: "cdi"
        }
    }
]
$env.config.show_banner = false
$env.PATH = ($env.PATH | prepend ($env.LOCALAPPDATA | path join "mise" "shims"))

alias l = eza --icons --git
alias ll = eza -lah --icons --git
alias la = eza -a --icons
alias lt = eza --tree --level=2 --icons
alias cat = bat --paging=never

$env.config.buffer_editor = "code"
$env.config.completions.algorithm = "fuzzy"
$env.config.completions.case_sensitive = false
$env.config.completions.quick = true
$env.config.completions.partial = true
$env.config.show_hints = true
$env.config.history.sync_on_enter = true
$env.config.edit_mode = "emacs"

$env.config.completions.external.completer = {|place|
    carapace $place.command.0 nushell ...$place.command | from json
}

$env.config.keybindings ++= [{
    name: fzf_history
    modifier: control
    keycode: char_r
    mode: emacs
    event: {
        send: executehostcommand
        cmd: "let selected = (history | get command | reverse | uniq | str join (char nl) | fzf --height=40% --layout=reverse --query (commandline) | str trim); if ($selected | is-not-empty) { commandline edit --replace $selected }"
    }
}]