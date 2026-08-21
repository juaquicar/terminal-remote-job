#!/usr/bin/env bash
#
# install.sh - Deja el equipo listo para atacarse a los agentes desde iOS.
#
# Instala openssh-server y mosh, arranca el servicio SSH, prepara ~/.ssh y
# anade reglas de firewall restringidas a la interfaz de Tailscale.
#
# Uso:
#   ~/terminal-remote-job/install.sh              instalacion normal
#   ~/terminal-remote-job/install.sh --harden     ademas endurece sshd (ver abajo)
#   ~/terminal-remote-job/install.sh --web        ademas instala ttyd + cloudflared
#                                             (terminal en navegador, ver
#                                              docs/cloudflare-tunnel.md)
#   ~/terminal-remote-job/install.sh --hook       ademas activa vibe-hook.sh, que
#                                             hace que claude/opencode/codex
#                                             nazcan siempre dentro de tmux
#   ~/terminal-remote-job/install.sh --no-bashrc  no tocar ~/.bashrc
#
# Por defecto anade a ~/.bashrc, en un bloque delimitado y facil de quitar, el
# PATH de bin/. Con --hook anade tambien el envoltorio de los agentes.
#
# --harden aplica config/sshd-hardening.conf: desactiva login por contrasena y
# por root, y limita el acceso al usuario actual. SOLO se aplica si ya tienes
# al menos una clave publica en ~/.ssh/authorized_keys; en caso contrario el
# script se niega, porque te dejaria sin forma de entrar por red.
#
# Necesita sudo. Pide la contrasena al principio y no vuelve a molestar.
#
set -euo pipefail

AR_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HARDEN=0
WEB=0
HOOK=0
BASHRC=1
for arg in "$@"; do
    case "$arg" in
        --harden)     HARDEN=1 ;;
        --web)        WEB=1 ;;
        --hook)       HOOK=1 ;;
        --no-bashrc)  BASHRC=0 ;;
        -h|--help) sed -n '3,26p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) printf 'opcion desconocida: %s\n' "$arg" >&2; exit 1 ;;
    esac
done

step() { printf '\n\033[1;36m==>\033[0m \033[1m%s\033[0m\n' "$*"; }
ok()   { printf '    \033[32mok\033[0m %s\n' "$*"; }
warn() { printf '    \033[33m!!\033[0m %s\n' "$*"; }
die()  { printf '\n\033[31merror:\033[0m %s\n' "$*" >&2; exit 1; }

[ "$(id -u)" -ne 0 ] || die "no lo ejecutes como root; usa tu usuario, ya llama a sudo cuando toca"
command -v apt-get >/dev/null || die "esto asume Debian/Ubuntu (apt-get)"

step "Pidiendo sudo"
sudo -v || die "sin sudo no puedo instalar paquetes"

step "Instalando paquetes"
PKGS=()
command -v sshd >/dev/null 2>&1 || [ -x /usr/sbin/sshd ] || PKGS+=(openssh-server)
command -v mosh-server >/dev/null 2>&1 || PKGS+=(mosh)
command -v tmux >/dev/null 2>&1 || PKGS+=(tmux)

if [ ${#PKGS[@]} -gt 0 ]; then
    printf '    instalando: %s\n' "${PKGS[*]}"
    sudo apt-get update -qq
    sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${PKGS[@]}"
else
    ok "nada que instalar, ya estaba todo"
fi

step "Activando el servicio SSH"
sudo systemctl enable --now ssh
systemctl is-active --quiet ssh && ok "ssh.service activo" || die "ssh.service no arranca"

step "Preparando ~/.ssh"
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
touch "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"
ok "permisos correctos"

step "Permisos de los scripts"
# env.sh y vibe-hook.sh NO llevan +x a proposito: se sourcean, no se ejecutan.
chmod +x "$AR_HOME"/install.sh
for f in vibe vibe-status vibe-watch vibe-adopt vibe-shells vibe-web; do
    [ -f "$AR_HOME/bin/$f" ] && chmod +x "$AR_HOME/bin/$f"
done
ok "bin/ ejecutable"

step "Terminal web (ttyd + cloudflared)"
if [ $WEB -eq 1 ]; then
    command -v ttyd >/dev/null 2>&1 \
        || sudo DEBIAN_FRONTEND=noninteractive apt-get install -y ttyd
    if ! command -v cloudflared >/dev/null 2>&1; then
        curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
            | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
        echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
            | sudo tee /etc/apt/sources.list.d/cloudflared.list >/dev/null
        sudo apt-get update -qq
        sudo DEBIAN_FRONTEND=noninteractive apt-get install -y cloudflared
    fi
    ok "ttyd + cloudflared listos  ->  bin/vibe-web"
    warn "No publiques ttyd sin Cloudflare Access delante."
    warn "Lee $AR_HOME/docs/cloudflare-tunnel.md antes de abrir nada."
else
    warn "omitido (--web para instalarlo). Solo hace falta si quieres la"
    warn "terminal en el navegador; con Tailscale + mosh no es necesario."
fi

step "Integracion con ~/.bashrc"
if [ $BASHRC -eq 1 ]; then
    BRC="$HOME/.bashrc"
    INI="# >>> terminal-remote-job >>>"
    FIN="# <<< terminal-remote-job <<<"

    cp "$BRC" "$BRC.bak-terminal-remote-job"

    # Quitar cualquier version anterior: el bloque delimitado, y tambien las
    # lineas sueltas que se pudieran haber anadido a mano antes de que el
    # instalador gestionara esto.
    python3 - "$BRC" "$INI" "$FIN" <<'PYEOF'
import re, sys

path, ini, fin = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path).read()

# 1. El bloque delimitado de una instalacion anterior.
s = re.sub(re.escape(ini) + r".*?" + re.escape(fin) + r"\n?", "", s, flags=re.S)

# 2. Lineas sueltas de cuando esto se anadia a mano. Se borran SOLO las que
#    coinciden con los patrones exactos que generaba el proceso manual, no
#    cualquier linea que mencione el directorio: el usuario puede tener alias
#    o cosas propias apuntando ahi y no son nuestras para borrarlas.
HUERFANAS = (
    re.compile(r'^\s*#\s*terminal-remote-job\s*$'),
    re.compile(r'^\s*export PATH="?\$\{?HOME\}?/terminal-remote-job/bin:\$PATH"?\s*$'),
    re.compile(r'^\s*source\s+"?\$\{?HOME\}?/terminal-remote-job/bin/vibe-hook\.sh"?\s*$'),
    re.compile(r'^\s*source\s+~/terminal-remote-job/bin/vibe-hook\.sh\s*$'),
)
lineas = [l for l in s.split("\n") if not any(p.match(l) for p in HUERFANAS)]

open(path, "w").write("\n".join(lineas).rstrip("\n") + "\n")
PYEOF

    {
        printf '\n%s\n' "$INI"
        printf 'export PATH="$HOME/terminal-remote-job/bin:$PATH"\n'
        if [ $HOOK -eq 1 ]; then
            printf '# Hace que claude/opencode/codex nazcan siempre dentro de tmux.\n'
            printf '# Escapes: VIBE_NO_WRAP=1 <agente>  |  vibe-unwrap\n'
            printf 'source "$HOME/terminal-remote-job/bin/vibe-hook.sh"\n'
        fi
        printf '%s\n' "$FIN"
    } >> "$BRC"

    ok "PATH de bin/ anadido (bloque delimitado, backup en $BRC.bak-terminal-remote-job)"
    if [ $HOOK -eq 1 ]; then
        ok "envoltorio activado: los agentes se lanzaran dentro de tmux"
        warn "Escapes:  VIBE_NO_WRAP=1 claude   |   vibe-unwrap"
    else
        warn "envoltorio NO activado. Con --hook, escribir 'claude' en cualquier"
        warn "terminal lo lanza dentro de tmux en vez de ahi mismo."
    fi
    warn "En las shells ya abiertas:  source ~/.bashrc"
else
    warn "omitido (--no-bashrc). Para tener los comandos a mano:"
    warn "    export PATH=\"\$HOME/terminal-remote-job/bin:\$PATH\""
fi

step "Reglas de firewall (solo interfaz tailscale0)"
if command -v ufw >/dev/null 2>&1; then
    # Se anaden las reglas pero NO se activa ufw: activarlo sin querer en una
    # maquina que administras en remoto es la forma clasica de quedarte fuera.
    sudo ufw allow in on tailscale0 to any port 22 proto tcp                >/dev/null
    sudo ufw allow in on tailscale0 to any port 60000:61000 proto udp       >/dev/null
    ok "SSH (22/tcp) y mosh (60000-61000/udp) permitidos en tailscale0"
    if sudo ufw status | head -1 | grep -qi inactive; then
        warn "ufw esta INACTIVO: las reglas quedan guardadas pero no filtran nada."
        warn "Si quieres activarlo: sudo ufw enable  (revisa antes tus otras reglas)"
    fi
else
    warn "ufw no instalado, me salto el firewall"
fi

step "Endurecimiento de sshd"
if [ $HARDEN -eq 1 ]; then
    if ! grep -qvE '^\s*(#|$)' "$HOME/.ssh/authorized_keys" 2>/dev/null; then
        die "me niego a endurecer sshd: ~/.ssh/authorized_keys esta vacio.
       Copia primero la clave publica del movil (ver docs/ios-setup.md),
       comprueba que puedes entrar, y vuelve a lanzar con --harden."
    fi
    sudo install -d -m 755 /etc/ssh/sshd_config.d
    sudo install -m 644 "$AR_HOME/config/sshd-hardening.conf" \
                        /etc/ssh/sshd_config.d/50-terminal-remote-job.conf
    sudo sed -i "s/^AllowUsers .*/AllowUsers $USER/" \
                        /etc/ssh/sshd_config.d/50-terminal-remote-job.conf
    if sudo sshd -t; then
        sudo systemctl reload ssh
        ok "sshd endurecido y recargado (sin contrasenas, sin root)"
    else
        sudo rm -f /etc/ssh/sshd_config.d/50-terminal-remote-job.conf
        die "la config de sshd no valida; revertido, sshd sigue como estaba"
    fi
else
    warn "omitido. Cuando tengas la clave del movil funcionando, ejecuta:"
    warn "    $AR_HOME/install.sh --harden"
fi

step "Tailscale"
if ! command -v tailscale >/dev/null 2>&1; then
    warn "tailscale no esta instalado:"
    warn "    curl -fsSL https://tailscale.com/install.sh | sh"
elif ! tailscale ip -4 >/dev/null 2>&1; then
    warn "tailscale instalado pero sin sesion. Ejecuta:"
    warn "    sudo tailscale up"
else
    ok "conectado como $(tailscale ip -4 | head -1)"
fi

cat <<EOF

$(printf '\033[1;32mListo.\033[0m') Siguientes pasos:

  1. sudo tailscale up                       (si aun no estas logueado)
  2. Instala Tailscale en el iPhone, misma cuenta
  3. Anade la clave publica del movil a ~/.ssh/authorized_keys
     -> ver $AR_HOME/docs/ios-setup.md
  4. $AR_HOME/install.sh --harden            (una vez la clave funcione)
  5. source ~/.bashrc                        (o abre una terminal nueva)
  6. vibe start                              (levanta la sesion de agentes)
  7. Desde Blink:  mosh usuario@<ip-tailnet> -- ~/terminal-remote-job/bin/vibe mobile

Diagnostico en cualquier momento:  $AR_HOME/bin/vibe-status
EOF
