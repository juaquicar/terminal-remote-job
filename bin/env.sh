#!/usr/bin/env bash
# env.sh - Resuelve el PATH de los agentes CLI.
#
# Se piensa para ser SOURCEADO, no ejecutado:
#     source ~/terminal-remote-job/bin/env.sh
#
# Contexto: en shells INTERACTIVAS el PATH ya viene bien, porque ~/.bashrc
# carga ~/.local/share/<tu-gestor>/shellenv.sh, que inicializa fnm. Una
# sesion SSH normal, por tanto, ya encuentra los tres agentes.
#
# Este archivo es la red de seguridad para el resto de casos:
#   - shells de login NO interactivas (`bash -lc`, cron, systemd units),
#     donde ~/.bashrc no se lee y `opencode` desaparece del PATH
#   - el arranque del servidor tmux, para que herede un PATH deterministico
#     en vez de depender de que shell lo lanzara
#
# Rutas que fija, en este orden de prioridad:
#   ~/.local/bin                             -> claude, codex (instalador nativo)
#   ~/.local/share/fnm/aliases/default/bin   -> opencode (+ node/npm)
#
# La ruta de fnm pasa por el alias `default`, symlink a la version activa: al
# cambiar de version de node se actualiza solo y esto no hay que tocarlo.

# Mueve el directorio al frente del PATH. Si ya estaba, lo quita primero: asi
# el orden final es predecible aunque ~/.profile ya haya anadido ~/.local/bin.
_ar_prepend_path() {
    local dir="$1" clean
    [ -d "$dir" ] || return 0
    clean=":${PATH}:"
    clean="${clean//:${dir}:/:}"
    clean="${clean#:}"
    clean="${clean%:}"
    PATH="${dir}${clean:+:${clean}}"
}

_ar_prepend_path "$HOME/.local/share/fnm/aliases/default/bin"
_ar_prepend_path "$HOME/.local/bin"

export PATH

unset -f _ar_prepend_path
