# Chuleta

Lo del día a día. Para lo demás, [`README.md`](README.md).

Tu tailnet: **`100.x.y.z`**

---

## Conectarse desde el iPhone

```
mosh usuario@100.x.y.z -- ~/terminal-remote-job/bin/vibe mobile
```

Ruta completa a propósito: `mosh` no lanza shell interactiva, así que no lee
`.bashrc` y `vibe` no está en su `PATH`.

Si `mosh` falla, `ssh` sirve igual (se corta al cambiar de red, nada más):

```
ssh usuario@100.x.y.z -t ~/terminal-remote-job/bin/vibe mobile
```

Requisito: VPN de Tailscale **activo** en el iPhone. Es lo que más veces falla.

---

## Sesión

| Comando | Qué hace |
|---|---|
| `vibe start` | Levanta la sesión en segundo plano |
| `vibe` | Te atacas desde el portátil |
| `vibe mobile` | Te atacas desde el móvil (tamaño independiente) |
| `vibe kill` | Mata la sesión y todo lo que corra dentro |
| `vibe -d ~/proyecto` | Ventanas arrancadas en ese directorio |
| `vibe --no-autostart` | Crea las ventanas sin lanzar los agentes |

Ventanas por defecto: cuatro shells limpias, sin arrancar nada. Los agentes
los abres tú donde te interese — `claude`, `opencode`, `codex` — y con
`prefijo + c` sacas ventanas nuevas.

Si quieres arranque automático de algo, [`config/agents.conf`](config/agents.conf).

---

## tmux

Prefijo: **`Ctrl+a`** (o `Ctrl+b`). En el móvil, `Ctrl+a` es más fácil.

| Acción | Teclas |
|---|---|
| Ir al agente 1 / 2 / 3 | prefijo → `1` `2` `3` |
| Siguiente / anterior | prefijo → `Ctrl+n` / `Ctrl+p` |
| Lista de ventanas | prefijo → `w` |
| **Salir dejando todo corriendo** | prefijo → `d` |
| Nueva ventana | prefijo → `c` |
| Dividir abajo / derecha | prefijo → `"` / `%` |
| Saltar de panel | prefijo → `h` `j` `k` `l` |
| Scroll (salir con `q`) | prefijo → `[` |
| Recargar tmux.conf | prefijo → `r` |

**Con el dedo:** toca la barra inferior para cambiar de ventana, arrastra para
hacer scroll y para redimensionar paneles. Casi no necesitas el prefijo.

Cerrar la app **no mata nada**. Los agentes siguen trabajando.

---

## Los agentes ya nacen dentro de tmux

`~/.bashrc` carga `vibe-hook.sh`, así que escribir `claude` en cualquier
terminal crea una ventana en la sesión `vibe` y te ataca a ella. No hay que
adoptar nada después.

```bash
VIBE_NO_WRAP=1 claude   # saltarse el envoltorio esta vez
vibe-unwrap             # desactivarlo en esta shell
```

---

## Ver un agente que corre fuera de tmux

Lanzado en Ptyxis, PyCharm o VS Code, `vibe` no lo ve. Lo que decide qué hacer
es **si está trabajando ahora mismo**.

### Está a mitad de una tarea → mirar sin tocar

```bash
vibe-watch --list      # en verde, las sesiones vivas (< 90 s)
vibe-watch 2           # seguir esa
vibe-watch             # la más reciente
```

Solo lectura, riesgo cero. Ves lo que hace; no puedes contestarle.

`--all` histórico completo · `--thinking` razonamiento · `--width N` ancho.

### Está parado, esperando órdenes → migrarlo

```bash
claude --continue      # dentro de tmux; recupera la conversación
```

O moverlo vivo, sin cerrarlo:

```bash
vibe-adopt --list      # ver quién está fuera de tmux
vibe                   # atacarte, ir a la ventana destino
vibe-adopt 78350       # DENTRO de esa ventana. Sin sudo delante.
vibe-adopt 78350 --steal   # segundo intento si el primero falla
```

`vibe-adopt` **puede matar el proceso**. No lo uses sobre trabajo sin guardar.

### Shells sueltas → clonarlas

```bash
vibe-shells            # cuáles hay fuera de tmux y en qué directorio
vibe-shells --clone    # una ventana de tmux por shell, en su mismo sitio
vibe-shells --all      # incluir también las que ya están en tmux
```

Las shells no se adoptan (peor caso de `reptyr`) y tampoco compensa: una shell
solo guarda directorio e historial, y el historial es compartido. Las
originales quedan intactas.

---

## Diagnóstico

```bash
vibe-status                                    # qué falta, qué corre, IP
sudo journalctl -u ssh -f                      # ver por qué rechaza SSH
namei -l ~/.ssh/authorized_keys                # permisos de toda la cadena
tmux ls                                        # sesiones vivas
```

---

## Que el portátil no se duerma

Si se suspende, los agentes se congelan y no llegas por SSH. Es el fallo
número uno. En una ventana de tmux:

```bash
systemd-inhibit --what=sleep:idle --why="agentes remotos" sleep infinity
```

`Ctrl+c` para volver a la normalidad. Añádelo a `agents.conf` si lo quieres
siempre:

```
awake | systemd-inhibit --what=sleep:idle --why="agentes remotos" sleep infinity |
```

---

## Fallos habituales

| Síntoma | Causa | Arreglo |
|---|---|---|
| `vibe: command not found` | `.bashrc` no releído | `source ~/.bashrc` o ruta completa |
| `claude` me arrastra a tmux y no quiero | El envoltorio `vibe-hook.sh` | `VIBE_NO_WRAP=1 claude` o `vibe-unwrap` |
| `sudo: vibe-adopt: command not found` | Le pusiste `sudo` delante | Lánzalo sin `sudo`; ya lo pone él |
| `Unable to find the fd for the pty!` | Modo `-T` contra Ptyxis/GNOME Terminal | Usa el modo normal (sin `--steal`) |
| `Permission denied (publickey)` | Permisos de la cadena de `~/.ssh` | `namei -l ~/.ssh/authorized_keys`, ninguno con escritura de grupo/otros |
| `No identities found` (Blink) | Nombre de clave incorrecto | `ssh-copy-id NOMBRE user@host`, nombre exacto de `config` → Keys |
| El portátil se encoge al conectar el móvil | Sesión compartida | Usa `vibe mobile` |
| `opencode: command not found` | fnm fuera del `PATH` | `source ~/terminal-remote-job/bin/env.sh` |
| Se corta al cambiar WiFi/datos | SSH normal | Usa `mosh` |
| No responde nada | Portátil suspendido | Ver sección de arriba |

---

## Terminal en el navegador

Solo si la red bloquea Tailscale, o estás en un equipo sin la app.

```bash
vibe-web               # ttyd en 127.0.0.1:7681, clave aleatoria
vibe-web --quick       # + túnel público temporal de Cloudflare
```

> `--quick` publica una URL sin Cloudflare Access delante: la única barrera es
> esa contraseña, sobre una shell con todas tus credenciales dentro. Minutos,
> no días. Montaje serio en [`docs/cloudflare-tunnel.md`](docs/cloudflare-tunnel.md).

---

## Pendiente

```bash
~/terminal-remote-job/install.sh --harden
```

Desactiva el login por contraseña. Hazlo cuando confirmes que entras desde el
iPhone sin que te la pida.
