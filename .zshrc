# ==============================================================================
# Saludo — va antes del instant prompt a proposito: p10k avisa (y descoloca el
# prompt) si algo escribe en consola despues del preambulo de abajo.
# ==============================================================================
POKEMON_SPRITE_GENS="3,4"

(( $+commands[pokemon-colorscripts] )) && \
  pokemon-colorscripts --no-title -r $POKEMON_SPRITE_GENS

# ==============================================================================
# Powerlevel10k instant prompt — debe permanecer al inicio del archivo
# ==============================================================================
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# ==============================================================================
# Constantes
# ==============================================================================
ZSH_EVAL_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/eval"
ANDROID_SDK_DIR="$HOME/Android/Sdk"
CARGO_ENV_FILE="$HOME/.cargo/env"
PACMAN_BIN="/usr/bin/pacman"

[[ -d $ZSH_EVAL_CACHE_DIR ]] || mkdir -p $ZSH_EVAL_CACHE_DIR

# ==============================================================================
# PATH — `typeset -U` mantiene las entradas unicas y evita los duplicados que
# se acumulan al re-sourcear o al heredar el PATH de Hyprland.
# ==============================================================================
typeset -U path PATH

path=(
  "$HOME/.local/bin"
  "$ANDROID_SDK_DIR/platform-tools"
  $path
)

# ==============================================================================
# Oh My Zsh
# ==============================================================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

# zsh-syntax-highlighting va antes de zsh-autosuggestions (requisito del plugin)
plugins=(
  git
  zsh-syntax-highlighting
  zsh-autosuggestions
  zsh-256color
)

[[ -f "$ZSH/oh-my-zsh.sh" ]] && source "$ZSH/oh-my-zsh.sh"

# Para reconfigurar el prompt: `p10k configure` o editar ~/.p10k.zsh
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Va despues del source: ~/.p10k.zsh define INSTANT_PROMPT=verbose y ganaria.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=quiet

# ==============================================================================
# Integraciones de herramientas
# ==============================================================================

# Cachea en disco la salida de un `eval "$(cmd)"` costoso. Solo apto para
# comandos cuya salida no depende del shell concreto ni de la sesion.
# SHELL se fuerza a zsh al generar: `ng completion script` emite completions de
# bash si $SHELL no apunta a zsh, y el cache congelaria esa version incorrecta.
_zsh_source_cached() {
  local cache="$ZSH_EVAL_CACHE_DIR/$1.zsh"
  shift
  local bin="${commands[$1]}"
  if [[ ! -s $cache || -n $bin && $bin -nt $cache ]]; then
    SHELL="${commands[zsh]:-$SHELL}" "$@" >| "$cache" 2>/dev/null \
      || { rm -f "$cache"; return 1 }
  fi
  source "$cache"
}

(( $+commands[direnv] )) && eval "$(direnv hook zsh)"
(( $+commands[ng] ))     && _zsh_source_cached ng-completion ng completion script

[[ -f $CARGO_ENV_FILE ]] && source $CARGO_ENV_FILE

# ==============================================================================
# Gestion de paquetes (pacman / AUR)
# ==============================================================================
# Instala paquetes repartiendolos entre los repos oficiales y el AUR.
function in {
  local -a arch=() aur=()
  for pkg in "$@"; do
    if pacman -Si "$pkg" &>/dev/null; then
      arch+=("$pkg")
    else
      aur+=("$pkg")
    fi
  done

  (( ${#arch[@]} )) && sudo pacman -S "${arch[@]}"
  (( ${#aur[@]} ))  && yay -S "${aur[@]}"
}

# Sugiere el paquete que provee un comando inexistente.
function command_not_found_handler {
  local cmd="$1"
  echo "zsh: command not found: $cmd" >&2

  [[ -x $PACMAN_BIN ]] || return 127

  local entries=("${(@f)$($PACMAN_BIN -F --machinereadable -- "/usr/bin/$cmd")}")
  (( ${#entries[@]} )) || return 127

  echo "$cmd may be found in the following packages:"
  local pkg=""
  for entry in "${entries[@]}"; do
    local fields=("${(@s: :)entry}")
    if [[ "$pkg" != "${fields[2]}" ]]; then
      printf "  %s/%s %s\n" "${fields[1]}" "${fields[2]}" "${fields[3]}"
    fi
    echo "    /${fields[4]}"
    pkg="${fields[2]}"
  done
  return 127
}

alias un='yay -Rns'               # Desinstala, con sus configs y dependencias sueltas
alias up='yay -Syu'               # Actualiza todo el sistema
alias pl='yay -Qs'                # Busca entre los paquetes ya instalados
alias pa='yay -Ss'                # Busca en los repos remotos
alias pc='yay -Sc'                # Limpia de la cache los paquetes ya no instalados
alias po='yay -Qtdq | yay -Rns -' # Borra huerfanos (revisar antes con `yay -Qtdq`)

# ==============================================================================
# Aliases
# ==============================================================================
alias mkdir='/usr/bin/mkdir -p'

# Listados (eza)
alias ls='eza -1 --icons=auto'
alias l='eza -lh --icons=auto'
alias ll='eza -lha --icons=auto --sort=name --group-directories-first'
alias ld='eza -lhD --icons=auto'
alias lt='eza --icons=auto --tree'
alias lsd="$HOME/Scripts/docker-pretty-print"

alias claude='claude --dangerously-skip-permissions'
