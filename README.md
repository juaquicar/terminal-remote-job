<div align="center">

# terminal-remote-job

**Sigue desde el iPhone el trabajo de los agentes CLI que corren en tu escritorio.**

No es un cliente nuevo ni una copia en la nube: son *las mismas terminales*,
vivas en `tmux`, a las que te atacas desde fuera.

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Shell: Bash](https://img.shields.io/badge/shell-bash-4EAA25.svg?logo=gnubash&logoColor=white)](https://www.gnu.org/software/bash/)
[![Platform: Linux](https://img.shields.io/badge/platform-Linux-333333.svg?logo=linux&logoColor=white)](#requisitos)
[![Probado en Ubuntu 26.04](https://img.shields.io/badge/probado-Ubuntu%2026.04-E95420.svg?logo=ubuntu&logoColor=white)](#requisitos)
[![PRs bienvenidos](https://img.shields.io/badge/PRs-bienvenidos-brightgreen.svg)](CONTRIBUTING.md)

[Instalación](#instalación) ·
[Uso diario](#uso-diario) ·
[Comandos](#comandos) ·
[Seguridad](#seguridad) ·
[Documentación](#documentación) ·
[Contribuir](CONTRIBUTING.md)

</div>

---

## El problema

Lanzas `claude` en una terminal, se pone a trabajar en una tarea de dos horas, y
te tienes que ir. La sesión vive atada al pty que le dio tu emulador de
terminal: si cierras el portátil, se acabó. Y si tienes tres agentes en tres
terminales distintas, no hay forma de ver cómo van desde el móvil.

Las soluciones habituales no encajan. El escritorio remoto es incómodo en una
pantalla de teléfono. Las versiones web de los agentes abren sesiones nuevas en
la nube: no se atacan a lo que ya tienes corriendo. Y abrir el puerto 22 a
internet para entrar por SSH es una idea regular.

## La solución

Los agentes viven en una sesión `tmux` persistente. Te atacas a ella desde el
iPhone por Tailscale, que atraviesa NAT sin abrir un solo puerto al exterior, y
con `mosh` encima para que la conexión sobreviva a los cambios de red. Cierras
la app y los agentes siguen trabajando.

Para lo que ya estaba corriendo fuera de `tmux` hay tres salidas, según lo que
necesites: verlo en vivo sin tocarlo, moverlo a `tmux` con el proceso vivo, o
clonar su directorio en una ventana nueva.

```
┌───────────────┐      Tailscale (WireGuard)      ┌──────────────────────┐
│   iPhone      │◄───────────────────────────────►│  Escritorio (Linux)  │
│   Blink Shell │           mosh / ssh            │                      │
└───────────────┘                                 │   tmux "vibe"        │
                                                  │    1 claude:proyecto │
┌───────────────┐      Cloudflare Tunnel          │    2 opencode        │
│   Safari      │◄───────────────────────────────►│    3 codex           │
│   (plan B)    │        HTTPS + Access           │    4 shell           │
└───────────────┘                                 └──────────────────────┘
```

Aunque nació para Claude Code, opencode y codex, **nada de esto es específico de
un agente**: sirve para cualquier proceso de terminal de larga duración.

> ¿Solo quieres los comandos del día a día? [`README-FAST.md`](README-FAST.md).

---

## Características

| | |
|---|---|
| **Sesiones que no mueren** | `tmux` con modo móvil de tamaño independiente: el iPhone no encoge la pantalla del escritorio |
| **Ver sin tocar** | Sigue en vivo la transcripción que el agente escribe en disco. Solo lectura, riesgo cero, funciona con la tarea a medias |
| **Adoptar procesos vivos** | Mueve a `tmux` un agente que ya estaba corriendo, vía `reptyr`, sin cerrarlo |
| **Que no vuelva a pasar** | Un hook opcional hace que los agentes nazcan siempre dentro de `tmux` |
| **Sin puertos abiertos** | Tailscale como vía principal; Cloudflare Tunnel como plan B para redes que bloquean UDP |
| **Pensado para el pulgar** | Ratón activo, prefijo alternativo `Ctrl+a`, nombres de ventana cortos, barra de estado compacta |
| **Instalación reversible** | Bloque delimitado en `~/.bashrc`, backups automáticos y desinstalación documentada |

---

## Requisitos

| | Para qué | Lo instala |
|---|---|---|
| `tmux` ≥ 3.0 | Sesiones persistentes | `install.sh` |
| `openssh-server` | Entrar desde el móvil | `install.sh` |
| `mosh` | Sobrevivir a cambios de red | `install.sh` |
| `tailscale` | Llegar desde fuera sin abrir puertos | [manual](https://tailscale.com/download) |
| `reptyr` | Solo para `vibe-adopt` | `apt install reptyr` |
| `ttyd`, `cloudflared` | Solo para `vibe-web` | `install.sh --web` |
| `python3` | `vibe-watch` y la gestión de `~/.bashrc` | viene de serie |

Probado en **Ubuntu 26.04**. Debería funcionar en cualquier Debian reciente; en
otras distribuciones habrá que sustituir `apt-get` en `install.sh`.

En el iPhone/iPad: la app de **Tailscale** y un cliente SSH — **Blink Shell**
(recomendado, tiene `mosh`) o **Termius**.

Ejecuta `bin/vibe-status` para ver qué falta en tu equipo.

---

## Instalación

```bash
git clone https://github.com/juaquicar/terminal-remote-job.git ~/terminal-remote-job
cd ~/terminal-remote-job
./install.sh --hook
sudo tailscale up
```

`install.sh` instala los paquetes, activa el servicio SSH, prepara `~/.ssh`,
añade reglas de firewall limitadas a la interfaz `tailscale0` y escribe en
`~/.bashrc` un bloque delimitado con el `PATH` de `bin/`.

| Opción | Qué añade |
|---|---|
| *(ninguna)* | Lo anterior, con el `PATH` de `bin/` |
| `--hook` | El envoltorio que lanza los agentes dentro de `tmux` |
| `--harden` | Endurece `sshd`: sin contraseñas, sin root (requiere clave ya funcionando) |
| `--web` | `ttyd` + `cloudflared` para la terminal en navegador |
| `--no-bashrc` | No tocar `~/.bashrc` |

El bloque de `~/.bashrc` se reescribe entero en cada ejecución, así que no se
acumulan copias, y deja backup en `~/.bashrc.bak-terminal-remote-job`.

### En el móvil

1. App **Tailscale**, la misma cuenta que en el escritorio.
2. App **Blink Shell** o **Termius**.
3. Genera una clave en la app y añádela a `~/.ssh/authorized_keys`.

Paso a paso, incluida la sintaxis de `ssh-copy-id` de Blink (que **no** es la de
siempre): [`docs/ios-setup.md`](docs/ios-setup.md).

### Cerrar la puerta

Cuando entres desde el móvil **sin que te pida contraseña**:

```bash
./install.sh --harden
```

Desactiva el login por contraseña y por root. El script se niega a hacerlo si
aún no tienes ninguna clave autorizada, para no dejarte fuera.

---

## Uso diario

```bash
vibe start        # levanta la sesión
vibe              # atacarte desde el escritorio
```

Desde el iPhone:

```
mosh usuario@100.x.y.z -- ~/terminal-remote-job/bin/vibe mobile
```

Ruta completa a propósito: `mosh` no lanza una shell interactiva, así que no lee
`~/.bashrc` y `vibe` no está en su `PATH`.

### Atajos de tmux imprescindibles

Prefijo: `Ctrl+b` **o** `Ctrl+a` (el segundo es más cómodo en iOS).

| Acción | Teclas |
|---|---|
| Ir a la ventana 1 / 2 / 3 | prefijo → `1` `2` `3` |
| Siguiente / anterior | prefijo → `Ctrl+n` / `Ctrl+p` |
| Lista de ventanas | prefijo → `w` |
| **Salir dejando todo corriendo** | prefijo → `d` |
| Nueva ventana | prefijo → `c` |
| Scroll (salir con `q`) | prefijo → `[` |

**Con el dedo:** toca la barra inferior para cambiar de ventana y arrastra para
hacer scroll. Desde el móvil casi no necesitas el prefijo.

Cerrar la app **no mata nada**.

---

## Comandos

| Comando | Qué hace |
|---|---|
| `vibe` | Crea la sesión si no existe y se ataca a ella |
| `vibe mobile` | Modo móvil: tamaño y ventana activa independientes del escritorio |
| `vibe start` | Levanta la sesión en segundo plano, sin atacarse |
| `vibe kill` | Mata la sesión y todo lo que corra dentro |
| `vibe -d ~/proyecto` | Ventanas arrancadas en ese directorio |
| `vibe-status` | Diagnóstico: qué falta, qué corre, IP del tailnet |
| `vibe-watch --list` | Sesiones de agentes, las vivas marcadas en verde |
| `vibe-watch N` | Ver en vivo lo que hace un agente. Solo lectura |
| `vibe-shells` | Shells abiertas fuera de tmux, con su directorio |
| `vibe-shells --clone` | Una ventana de tmux por shell, en su mismo directorio |
| `vibe-adopt --list` | Qué agentes corren y cuáles están fuera de tmux |
| `vibe-adopt PID` | Mete un agente ya en marcha en el panel tmux actual |
| `vibe-web` | Terminal en el navegador |

Todos aceptan `-h` / `--help`.

### Agentes que ya estaban corriendo fuera de tmux

`tmux` solo ve lo que nació dentro de él. **Lo que decide qué hacer es si el
agente está trabajando ahora mismo.**

Si está **a mitad de una tarea**, no puedes cerrarlo para relanzarlo: perderías
lo que tenga en vuelo.

```bash
vibe-watch --list     # sesiones activas, en verde las vivas
vibe-watch 2          # seguirla en vivo
```

`vibe-watch` sigue la transcripción que el agente escribe en disco. No adjunta
`ptrace`, no toca el proceso, no puede romper nada. Ves qué hace; no puedes
contestarle.

Si está **parado**, esperando órdenes, sí puedes migrarlo:

```bash
claude --continue      # dentro de tmux; recupera la conversación entera
vibe-adopt 78350       # o moverlo vivo, sin cerrarlo (puede matarlo)
```

Detalle de las cuatro vías, con sus pegas:
[`docs/adoptar-procesos.md`](docs/adoptar-procesos.md).

> [!TIP]
> **Las horas de contexto no viven en el proceso, viven en disco.**
> `claude --continue` reconstruye la conversación desde el mismo archivo que lee
> `vibe-watch`. Reiniciar un agente parado no cuesta el contexto; lo único que
> se pierde es el trabajo en vuelo.

### Que no vuelva a pasar

Con `install.sh --hook`, escribir `claude` en cualquier terminal crea una
ventana en la sesión `vibe` y te ataca a ella. El agente nace dentro de `tmux` y
es accesible desde el móvil desde el primer segundo.

```bash
VIBE_NO_WRAP=1 claude          # saltárselo esta vez
vibe-unwrap                    # desactivarlo en la shell actual
VIBE_WRAP_AGENTS="claude"      # envolver solo algunos
```

Dentro de `tmux` no se mete en medio: ejecuta el binario de siempre.

---

## Las dos vías de acceso

### Tailscale — la principal

Funciona **desde cualquier sitio**, no solo en la red local: atraviesa NAT y
CGNAT, va por 4G/5G y establece conexión directa entre el móvil y el escritorio
siempre que puede, así que la latencia al teclear es baja. No abre ningún puerto
a internet.

Con `mosh` encima, la sesión sobrevive a cambios de WiFi a datos y a bloquear la
pantalla del móvil.

### Cloudflare Tunnel — plan B

Útil cuando la red bloquea UDP o WireGuard, o cuando estás en un dispositivo
donde no puedes instalar Tailscale y solo tienes navegador.

```bash
./install.sh --web
vibe-web
```

Montaje completo, con dominio propio y política de Access:
[`docs/cloudflare-tunnel.md`](docs/cloudflare-tunnel.md).

---

## Seguridad

Este proyecto da acceso remoto a una shell con tus credenciales dentro. Los
criterios que sigue:

- **Nada se expone a internet por defecto.** Las reglas de firewall se limitan a
  la interfaz `tailscale0`, y `ufw` no se activa solo: hacerlo a ciegas en una
  máquina que administras en remoto es la forma clásica de quedarte fuera.
- **`--harden` se niega a ejecutarse** si no hay ninguna clave en
  `authorized_keys`. Desactivar las contraseñas sin clave puesta te deja fuera.
- **`vibe-web` ata `ttyd` a `127.0.0.1`**, nunca a `0.0.0.0`, y genera una
  contraseña aleatoria en cada arranque. Publicarlo hacia fuera exige poner
  Cloudflare Access delante; el modo `--quick` avisa de que la URL es pública.
- **`vibe-adopt` usa `sudo reptyr`** en vez de bajar `kernel.yama.ptrace_scope`
  globalmente. La alternativa `--sysctl` existe, avisa de lo que implica y
  restaura el valor a los 30 segundos pase lo que pase.
- **Las operaciones que pueden matar un proceso piden confirmación** escribiendo
  `SI`, y muestran antes qué se va a tocar.
- **`vibe-status` audita lo que tienes expuesto.** Avisa de todo lo que escuche
  en `0.0.0.0` y no solo en el tailnet, y marca los casos graves — escritorio
  remoto, VNC. No lo cierra: cuáles son legítimos solo lo sabes tú.

> [!WARNING]
> Una terminal web es una shell con tus tokens y claves SSH al alcance. No
> publiques `ttyd` sin autenticación, ni siquiera "un momento para probar": los
> rangos de `trycloudflare.com` se escanean.

Para reportar una vulnerabilidad, **no abras un issue público**: usa un
[security advisory](https://github.com/juaquicar/terminal-remote-job/security/advisories/new).
El alcance y el modelo de amenaza están en [`SECURITY.md`](SECURITY.md).

---

## Documentación

| Documento | Contenido |
|---|---|
| [`README-FAST.md`](README-FAST.md) | Chuleta: solo los comandos del día a día |
| [`docs/ios-setup.md`](docs/ios-setup.md) | Blink, Termius, claves, teclado de iOS |
| [`docs/adoptar-procesos.md`](docs/adoptar-procesos.md) | Agentes lanzados fuera de tmux: `reptyr`, VNC, `--continue` |
| [`docs/cloudflare-tunnel.md`](docs/cloudflare-tunnel.md) | Túnel, Access, avisos de seguridad |
| [`docs/troubleshooting.md`](docs/troubleshooting.md) | Suspensión, `PATH`, permisos SSH, tamaños, `mosh` |
| [`CONTRIBUTING.md`](CONTRIBUTING.md) | Cómo reportar, estilo del código, cómo probar |
| [`SECURITY.md`](SECURITY.md) | Alcance, modelo de amenaza, cómo reportar vulnerabilidades |

### Estructura

```
terminal-remote-job/
├── install.sh                    instala y configura. --hook, --harden, --web
├── bin/
│   ├── vibe                      crear / atacarse a la sesion
│   ├── vibe-status               diagnostico de un vistazo
│   ├── vibe-watch                ver en vivo un agente sin tocarlo
│   ├── vibe-shells               clonar en tmux las shells de fuera
│   ├── vibe-adopt                meter en tmux un proceso ya en marcha
│   ├── vibe-web                  terminal web via ttyd (+ tunel opcional)
│   ├── vibe-hook.sh              que los agentes nazcan siempre en tmux
│   └── env.sh                    red de seguridad para el PATH
├── config/
│   ├── agents.conf               que ventanas se crean          <-- EDITA ESTE
│   ├── tmux.conf                 tmux ajustado para uso movil
│   └── sshd-hardening.conf       drop-in de sshd que aplica --harden
└── docs/
```

### Configurar las ventanas

Edita [`config/agents.conf`](config/agents.conf). Una línea por ventana:

```
nombre | comando | directorio
```

Por defecto crea cuatro shells limpias, sin lanzar nada. Ejemplo con arranque
automático:

```
mi-proyecto | claude --continue | ~/repos/mi-proyecto
awake       | systemd-inhibit --what=sleep:idle --why="remoto" sleep infinity |
```

Los cambios se aplican en la siguiente sesión (`vibe kill && vibe start`).

---

## Lo que más veces falla

**El escritorio se suspende.** Es el fallo número uno y no tiene nada que ver
con la red: un equipo dormido no responde por SSH y los agentes se congelan.
Solución rápida, en una ventana de tmux:

```bash
systemd-inhibit --what=sleep:idle --why="terminal remoto" sleep infinity
```

Otras opciones, y el resto de problemas conocidos, en
[`docs/troubleshooting.md`](docs/troubleshooting.md).

---

## Limitaciones conocidas

- **`vibe-adopt` no es fiable al 100%.** `reptyr` falla con frecuencia sobre TUI
  de muchos hilos, que es justo lo que son los agentes. El modo `-T` no funciona
  con emuladores de modelo cliente-servidor (Ptyxis, GNOME Terminal, Konsole).
  Por eso el modo por defecto es `ptrace` directo y hay tres vías alternativas
  documentadas.
- **Las shells interactivas no se pueden adoptar.** Son el peor caso de
  `reptyr`. `vibe-shells --clone` las replica, que es lo único que hace falta.
- **`vibe-watch` no soporta opencode**, que guarda el estado en SQLite en vez de
  en JSONL. Claude Code y codex sí.
- **`vibe-watch` no da control**, solo lectura. Para responder al agente hace
  falta la terminal real.
- **`install.sh` asume `apt-get`.** En otras distribuciones hay que adaptarlo.

---

## Desinstalar

```bash
vibe kill
sed -i '/# >>> terminal-remote-job >>>/,/# <<< terminal-remote-job <<</d' ~/.bashrc
sudo rm -f /etc/ssh/sshd_config.d/50-terminal-remote-job.conf
sudo systemctl reload ssh
rm -rf ~/terminal-remote-job
```

Tailscale, mosh y openssh-server se quedan instalados; quítalos con `apt remove`
si no los quieres.

---

## Contribuir

Las aportaciones son bienvenidas, en español o en inglés. Lee
[`CONTRIBUTING.md`](CONTRIBUTING.md) antes de abrir un PR: hay criterios
concretos sobre seguridad y sobre cómo probar cambios sin cargarte tu propia
sesión de trabajo.

## Licencia

[MIT](LICENSE) © 2026 Juanma Quijada

## Agradecimientos

Construido sobre el trabajo de otros: [tmux](https://github.com/tmux/tmux),
[mosh](https://mosh.org/), [Tailscale](https://tailscale.com/),
[reptyr](https://github.com/nelhage/reptyr) y
[ttyd](https://github.com/tsl0922/ttyd).
