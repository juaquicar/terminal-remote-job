# terminal-remote-job

Suite para acceder por remoto a terminales de Ubuntu Desktop con el fin de
seguir labores de desarrollo agéntico desde un dispositivo iOS.

Acceso desde el iPhone/iPad a las terminales donde corren **Claude Code**,
**opencode** y **codex** en el escritorio, para seguir el trabajo desde el
móvil.

No es un cliente nuevo ni una copia en la nube: son **las mismas terminales**,
vivas en `tmux`, a las que te atacas desde fuera. Cierras la app y los agentes
siguen trabajando.

> ¿Solo quieres los comandos del día a día? [`README-FAST.md`](README-FAST.md).

```
┌──────────────┐        Tailscale (WireGuard)        ┌────────────────────┐
│  iPhone      │◄───────────────────────────────────►│  Portatil (Linux)  │
│  Blink Shell │            mosh / ssh               │                    │
└──────────────┘                                     │  tmux "vibe"       │
                                                     │   1 shell          │
┌──────────────┐        Cloudflare Tunnel            │   2 shell2         │
│  Safari      │◄───────────────────────────────────►│   3 shell3         │
│  (plan B)    │         HTTPS + Access              │   4 shell4         │
└──────────────┘                                     └────────────────────┘
```

---

## Requisitos

| | Para qué | Lo instala |
|---|---|---|
| `tmux` ≥ 3.0 | Sesiones persistentes | `install.sh` |
| `openssh-server` | Entrar desde el móvil | `install.sh` |
| `mosh` | Sobrevivir a cambios de red | `install.sh` |
| `tailscale` | Llegar desde fuera sin abrir puertos | manual, ver abajo |
| `reptyr` | Solo para `vibe-adopt` | `apt install reptyr` |
| `ttyd`, `cloudflared` | Solo para `vibe-web` | `install.sh --web` |

Probado en **Ubuntu 26.04**. Debería funcionar en cualquier Debian reciente;
en otras distribuciones habrá que sustituir `apt-get` en `install.sh`.

En el iPhone/iPad: la app de **Tailscale** y un cliente SSH — **Blink Shell**
(recomendado, tiene mosh) o **Termius**.

Nada de esto es específico de Claude Code: sirve para cualquier proceso de
terminal de larga duración. Los agentes son solo el caso de uso que lo motivó.

Ejecuta `bin/vibe-status` para ver qué falta en tu equipo.

---

## Puesta en marcha

### 1. En el portátil

```bash
~/terminal-remote-job/install.sh --hook
sudo tailscale up
```

`install.sh` instala `openssh-server` y `mosh`, activa el servicio SSH, prepara
`~/.ssh`, añade reglas de firewall limitadas a `tailscale0` y escribe en
`~/.bashrc` un bloque delimitado con el `PATH` de `bin/`.

| Opción | Qué añade |
|---|---|
| *(nada)* | Lo anterior, con el `PATH` de `bin/` |
| `--hook` | Además, el envoltorio que lanza los agentes dentro de tmux |
| `--harden` | Además, endurece `sshd` (requiere clave ya funcionando) |
| `--web` | Además, `ttyd` + `cloudflared` |
| `--no-bashrc` | No tocar `~/.bashrc` |

El bloque de `~/.bashrc` se reescribe entero en cada ejecución, así que no se
acumulan copias, y deja backup en `~/.bashrc.bak-terminal-remote-job`.
Necesita sudo, así que **lánzalo tú** — desde este chat, con `!` delante:

```
! ~/terminal-remote-job/install.sh
```

### 2. En el iPhone

1. App **Tailscale**, misma cuenta.
2. App **Blink Shell** (recomendada, tiene mosh) o **Termius**.
3. Genera una clave en la app y pégala en `~/.ssh/authorized_keys`.

Paso a paso, con capturas de dónde está cada opción:
[`docs/ios-setup.md`](docs/ios-setup.md).

### 3. Cerrar la puerta

Cuando la clave del móvil funcione:

```bash
~/terminal-remote-job/install.sh --harden
```

Desactiva el login por contraseña y por root. El script se niega a hacerlo si
aún no tienes ninguna clave, para no dejarte fuera.

### 4. Levantar la sesión

```bash
vibe start
```

Crea cuatro shells limpias. Los agentes los abres tú, en la ventana que
quieras: `claude`, `opencode`, `codex`, o `prefijo + c` para una ventana nueva.
Si algún día quieres que alguno arranque solo, ponlo en
[`config/agents.conf`](config/agents.conf).

### 5. Conectarte desde el móvil

```
mosh vibe -- ~/terminal-remote-job/bin/vibe mobile
```

---

## Uso diario

| Comando | Qué hace |
|---|---|
| `vibe` | Crea la sesión si no existe y se ataca a ella. |
| `vibe mobile` | Se ataca en modo móvil: tamaño y ventana activa independientes del portátil. |
| `vibe start` | Levanta la sesión en segundo plano, sin atacarse. |
| `vibe kill` | Mata la sesión y todo lo que corra dentro. |
| `vibe -d ~/proyecto` | Arranca las ventanas en ese directorio. |
| `vibe --no-autostart` | Crea las ventanas sin lanzar los agentes. |
| `vibe-status` | Diagnóstico: qué falta, qué corre, IP del tailnet. |
| `vibe-shells` | Shells abiertas fuera de tmux, con su directorio. |
| `vibe-shells --clone` | Abre en tmux una ventana por shell, en su mismo directorio. |
| `vibe-watch --list` | Sesiones de agentes, las vivas marcadas en verde. |
| `vibe-watch N` | Ver en vivo lo que hace un agente. Solo lectura, riesgo cero. |
| `vibe-adopt --list` | Qué agentes corren y cuáles están fuera de tmux. |
| `vibe-adopt PID` | Mete un agente ya en marcha dentro del panel tmux actual. |
| `vibe-adopt PID --steal` | Segundo intento, si el modo normal falla. |
| `vibe-web` | Terminal en el navegador (ver Cloudflare, más abajo). |

Todos están en el `PATH` porque `install.sh` añadió el bloque correspondiente a
`~/.bashrc`.

### Atajos de tmux imprescindibles

Prefijo: `Ctrl+b` **o** `Ctrl+a` (el segundo es más cómodo en iOS).

| Acción | Teclas |
|---|---|
| Cambiar de agente | prefijo → `1` / `2` / `3` |
| Siguiente ventana | prefijo → `Ctrl+n` |
| Salir dejando todo corriendo | prefijo → `d` |
| Lista de ventanas | prefijo → `w` |

El ratón está activo: **toca la barra inferior** para cambiar de ventana y
arrastra para hacer scroll. Desde el móvil casi no necesitas el prefijo.

---

## Agentes que ya estaban corriendo fuera de tmux

`tmux` solo ve lo que nació dentro de él. Un `claude` lanzado en Ptyxis o en la
terminal de PyCharm queda fuera de su alcance, y `vibe` no lo encuentra.

```bash
vibe-adopt --list     # agentes: quién está dentro de tmux y quién no
vibe-shells           # shells: lo mismo, con su directorio
```

**Lo que decide es si el agente está trabajando ahora mismo.**

Si está **a mitad de una tarea**, no puedes cerrarlo para relanzarlo: perderías
lo que tenga en vuelo. Entonces:

```bash
vibe-watch --list     # sesiones activas (en verde las vivas)
vibe-watch 2          # seguir esa, en vivo
```

`vibe-watch` sigue la transcripción que el agente va escribiendo en disco. Es
**solo lectura**: no toca el proceso, no puede romper nada. Ves qué está
haciendo, pero no puedes contestarle. Si además necesitas responder, comparte
el escritorio por VNC.

Si el agente está **parado**, esperando órdenes, sí puedes migrarlo:

- **`claude --continue`** dentro de tmux. Recupera la conversación, riesgo
  cero. Coste de una sola vez.
- **`vibe-adopt PID`**, que usa `reptyr` para mover el proceso vivo a un panel
  de tmux sin cerrarlo. Útil si lleva horas trabajando, pero **puede matarlo**.

Detalle de las cuatro vías, con sus pegas:
[`docs/adoptar-procesos.md`](docs/adoptar-procesos.md).

### Que no vuelva a pasar: `vibe-hook.sh`

Lo activa `install.sh --hook`, escribiendo en `~/.bashrc`:

```bash
source ~/terminal-remote-job/bin/vibe-hook.sh
```

A partir de ahí, escribir `claude` en Ptyxis, PyCharm o VS Code **no** lanza el
agente ahí: crea una ventana en la sesión `vibe` con nombre `claude:carpeta`, en
el directorio donde estabas, y te ataca a ella. El agente nace dentro de tmux y
es accesible desde el móvil desde el primer segundo.

Dentro de tmux no se mete en medio: ejecuta el binario de siempre.

| Escape | Qué hace |
|---|---|
| `VIBE_NO_WRAP=1 claude` | Solo esta vez, sin envoltorio |
| `vibe-unwrap` | Desactiva las funciones en la shell actual |
| `VIBE_WRAP_AGENTS="claude"` | Envolver solo algunos (por defecto, los tres) |

Son funciones de shell, no scripts en el `PATH`, así que `command claude` sigue
llegando al binario real y no hay riesgo de recursión.

### Shells sueltas

Las shells normales **no se pueden adoptar**: una `bash` interactiva es el peor
caso de `reptyr` (líder de sesión y de grupo de procesos, el control de trabajos
no sobrevive al cambio de pty). Pero tampoco hace falta — una shell no guarda
nada salvo el directorio y el historial, y el historial es el mismo archivo.

Lo práctico es clonarlas:

```bash
vibe-shells --clone
```

Abre en tmux una ventana por cada shell que tengas fuera, arrancada en su mismo
directorio y con el nombre de la carpeta. Las originales quedan intactas. No
duplica ventanas sobre un directorio que ya tenga una.

Para que no vuelva a pasar: lanza los agentes desde `vibe`, o añádelos a
`config/agents.conf`.

---

## Las dos vías de acceso

### Tailscale — la principal

Funciona **desde cualquier sitio**, no solo en tu red local: atraviesa NAT y
CGNAT, va por 4G/5G y establece conexión directa entre iPhone y portátil
siempre que puede, así que la latencia al teclear es baja. No abre ningún
puerto a internet.

Con `mosh` encima, la sesión sobrevive a cambios de WiFi a datos y a bloquear
la pantalla del móvil.

### Cloudflare Tunnel — plan B

Útil cuando la red bloquea UDP o WireGuard, o cuando estás en un dispositivo
donde no puedes instalar Tailscale y solo tienes navegador.

```bash
~/terminal-remote-job/install.sh --web
~/terminal-remote-job/bin/vibe-web
```

> **Seguridad:** una terminal web es una shell con todas tus credenciales
> dentro. `vibe-web` ata `ttyd` a `127.0.0.1` y le pone una contraseña
> aleatoria en cada arranque, pero **antes de publicarlo hacia fuera tienes que
> poner Cloudflare Access delante**. No uses `--quick` (URL pública sin Access)
> más allá de una prueba corta.

Montaje completo, con dominio propio y política de Access:
[`docs/cloudflare-tunnel.md`](docs/cloudflare-tunnel.md).

---

## Qué hay en cada archivo

```
terminal-remote-job/
├── README.md                     este archivo
├── README-FAST.md                chuleta: comandos del dia a dia
├── install.sh                    instala y configura (sudo). --harden, --web
├── bin/
│   ├── vibe                      crear / atacarse a la sesion de agentes
│   ├── vibe-status               diagnostico de un vistazo
│   ├── vibe-watch                ver en vivo un agente sin tocarlo
│   ├── vibe-shells               clonar en tmux las shells de fuera
│   ├── vibe-hook.sh              que los agentes nazcan siempre en tmux
│   ├── vibe-adopt                meter en tmux un proceso ya en marcha
│   ├── vibe-web                  terminal web via ttyd (+ tunel opcional)
│   └── env.sh                    arregla el PATH de los agentes (fnm)
├── config/
│   ├── agents.conf               que ventanas se crean y que lanzan  <-- EDITA ESTE
│   ├── tmux.conf                 tmux ajustado para uso movil
│   └── sshd-hardening.conf       drop-in de sshd que aplica --harden
└── docs/
    ├── ios-setup.md              Blink, Termius, claves, teclado
    ├── adoptar-procesos.md       agentes lanzados fuera de tmux (reptyr, VNC)
    ├── cloudflare-tunnel.md      tunel, Access, avisos de seguridad
    └── troubleshooting.md        suspension, PATH, tamanos, mosh...
```

### Añadir o cambiar agentes

Edita [`config/agents.conf`](config/agents.conf). Una línea por ventana:

```
nombre | comando | directorio
```

Por ejemplo, para tener Claude Code trabajando en un repo concreto:

```
mi-proyecto | claude | ~/proyectos/mi-proyecto
```

Los cambios se aplican en la siguiente sesión (`vibe kill && vibe start`).

---

## Lo que más veces falla

**El portátil se suspende.** Es el fallo número uno y no tiene nada que ver con
la red: un equipo dormido no responde por SSH y los agentes se congelan.
Solución rápida, en una ventana de tmux:

```bash
systemd-inhibit --what=sleep:idle --why="agentes remotos" sleep infinity
```

Otras opciones (incluida la de ignorar el cierre de tapa) y el resto de
problemas: [`docs/troubleshooting.md`](docs/troubleshooting.md).

---

## Lo que esto no es

Claude Code también corre en la web (`claude.ai/code`) y en la app de Claude
para iOS. Pero eso son **sesiones nuevas en la nube** sobre repos de GitHub: no
se atacan a lo que ya tienes corriendo en el portátil, y no sirven para
`opencode` ni para `codex`. Este directorio resuelve el otro problema: llegar a
*tus* terminales, con *tu* estado, tal y como las dejaste.
