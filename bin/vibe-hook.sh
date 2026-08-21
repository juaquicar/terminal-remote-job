#!/usr/bin/env bash
#
# vibe-hook.sh - Hace que los agentes nazcan SIEMPRE dentro de tmux.
#
# Se sourcea desde ~/.bashrc:
#
#     source ~/terminal-remote-job/bin/vibe-hook.sh
#
# A partir de ahi, escribir `claude` en cualquier terminal (Ptyxis, PyCharm,
# VS Code...) no lanza el agente ahi mismo: crea una ventana en la sesion tmux
# 'vibe' y te ataca a ella. El agente queda accesible desde el movil desde el
# primer segundo, sin tener que adoptarlo despues.
#
# Si ya estas dentro de tmux, ejecuta el binario de siempre y no se mete en
# medio.
#
# Escapes:
#   VIBE_NO_WRAP=1 claude      Una sola vez, sin envoltorio.
#   vibe-unwrap                Desactiva las funciones en esta shell.
#   VIBE_WRAP_AGENTS="..."     Que agentes envolver (por defecto los tres).
#
# Nota: son funciones de shell, no scripts en el PATH. Asi `command claude`
# sigue llegando al binario real y no hay riesgo de recursion infinita.

VIBE_WRAP_AGENTS="${VIBE_WRAP_AGENTS:-claude opencode codex}"

# Se resuelve al sourcear, no al invocar: dentro de la funcion BASH_SOURCE ya
# apuntaria a otra cosa.
VIBE_HOME="${AR_HOME:-$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)}"

_vibe_wrap() {
    local agent="$1"; shift

    # Dentro de tmux, o con la valvula de escape puesta: comportamiento normal.
    if [ -n "${TMUX:-}" ] || [ -n "${VIBE_NO_WRAP:-}" ]; then
        command "$agent" "$@"
        return $?
    fi

    local ar_home="${AR_HOME:-$VIBE_HOME}"
    local session="${VIBE_SESSION:-vibe}"
    local cwd="$PWD"

    if [ ! -x "$ar_home/bin/vibe" ]; then
        command "$agent" "$@"
        return $?
    fi

    # shellcheck source=/dev/null
    [ -f "$ar_home/bin/env.sh" ] && source "$ar_home/bin/env.sh"

    tmux has-session -t "=$session" 2>/dev/null \
        || "$ar_home/bin/vibe" start -s "$session" >/dev/null

    # Nombre de ventana: agente + carpeta, que en el movil se lee de un vistazo.
    local dir_tag
    if [ "$cwd" = "$HOME" ]; then dir_tag="home"; else dir_tag="$(basename "$cwd")"; fi
    local wname
    wname="$(printf '%s:%s' "$agent" "$dir_tag" | tr ':.' '--')"

    tmux new-window -t "$session:" -n "$wname" -c "$cwd"

    # El comando se envia al prompt en vez de reemplazar la shell: si el agente
    # termina te quedas en bash, con flecha arriba para relanzarlo.
    local cmdline="$agent"
    local a
    for a in "$@"; do cmdline="$cmdline $(printf '%q' "$a")"; done
    tmux send-keys -t "$session:$wname" "$cmdline" C-m

    printf '\033[36m::\033[0m %s lanzado en tmux (%s:%s). Accesible desde el movil.\n' \
           "$agent" "$session" "$wname"

    tmux attach-session -t "=$session" \; select-window -t "$session:$wname"
}

# Definir una funcion por agente. eval es la forma de generar N funciones con
# el nombre exacto de cada binario.
for _a in $VIBE_WRAP_AGENTS; do
    eval "${_a}() { _vibe_wrap ${_a} \"\$@\"; }"
done
unset _a

vibe-unwrap() {
    local a
    for a in $VIBE_WRAP_AGENTS; do unset -f "$a" 2>/dev/null; done
    echo "envoltorio desactivado en esta shell; los agentes vuelven a lanzarse aqui mismo"
}
