# PATH
case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH

# EDITOR
export EDITOR=nano
export VISUAL=nano

# history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
setopt share_history
setopt hist_ignore_dups
setopt hist_reduce_blanks

# aliases
alias c='clear'
alias tm='tmux new-session -A -s main'

# completion
zstyle ':completion:*' menu select
zstyle ':completion::complete:*' gain-privileges 1

# prompt
if [[ -n ${TMUX-} ]]; then
  PROMPT='%n@%m:%~$ '
else
  PROMPT='$ '
fi

setopt PROMPT_SUBST

ps2_align() {
  local p=${(%)PROMPT}
  printf '%*s' "$(( ${#p} - 2 ))" ''
}

PS2='$(ps2_align)> '

# command separator (tmux only)
if [[ -n ${TMUX-} ]]; then
  autoload -Uz add-zsh-hook

  typeset -gi _command_executed=0

  _prompt_preexec() {
    case "$1" in
      clear|clear\ *|c|c\ *)
        _command_executed=0
        ;;
      *)
        _command_executed=1
        ;;
    esac
  }

  _prompt_separator() {
    if (( _command_executed )); then
      print
      _command_executed=0
    fi
  }

  add-zsh-hook preexec _prompt_preexec
  add-zsh-hook precmd _prompt_separator
fi

# terminfo
zmodload zsh/terminfo 2>/dev/null || true

# ZLE application mode
if (( ${+terminfo[smkx]} && ${+terminfo[rmkx]} )); then
  autoload -Uz add-zle-hook-widget

  zle_application_mode_start() { echoti smkx }
  zle_application_mode_stop()  { echoti rmkx }

  add-zle-hook-widget -Uz zle-line-init   zle_application_mode_start
  add-zle-hook-widget -Uz zle-line-finish zle_application_mode_stop
fi

# keymap
typeset -g -A key

key[Home]="${terminfo[khome]}"
key[End]="${terminfo[kend]}"
key[Insert]="${terminfo[kich1]}"
key[Backspace]="${terminfo[kbs]}"
key[Delete]="${terminfo[kdch1]}"
key[Left]="${terminfo[kcub1]}"
key[Right]="${terminfo[kcuf1]}"
key[PageUp]="${terminfo[kpp]}"
key[PageDown]="${terminfo[knp]}"
key[Shift-Tab]="${terminfo[kcbt]}"
key[Up]="${terminfo[kcuu1]}"
key[Down]="${terminfo[kcud1]}"
key[Control-Left]="${terminfo[kLFT5]}"
key[Control-Right]="${terminfo[kRIT5]}"

# key bindings
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search

for _binding_key _binding_widget in \
    Home beginning-of-line \
    End end-of-line \
    Insert overwrite-mode \
    Backspace backward-delete-char \
    Delete delete-char \
    Left backward-char \
    Right forward-char \
    PageUp beginning-of-buffer-or-history \
    PageDown end-of-buffer-or-history \
    Shift-Tab reverse-menu-complete \
    Up up-line-or-beginning-search \
    Down down-line-or-beginning-search \
    Control-Left backward-word \
    Control-Right forward-word
do
    [[ -n "${key[$_binding_key]}" ]] &&
        bindkey -- "${key[$_binding_key]}" "$_binding_widget"
done
unset _binding_key _binding_widget
