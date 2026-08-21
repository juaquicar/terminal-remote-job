# Ver agentes que ya estaban corriendo fuera de tmux

## El problema

`tmux` no puede atacarse a una terminal cualquiera. Solo ve lo que **nació
dentro de él**: un proceso lanzado en Ptyxis, en la terminal de PyCharm o en
VS Code está atado al pty que le dio ese emulador, y `tmux attach` no llega
ahí. Por eso `vibe` crea sesiones nuevas y no encuentra las que ya tenías.

Hay cuatro salidas. En orden de riesgo, de menos a más:

| | Qué hace | Riesgo | Da control | Cuándo |
|---|---|---|---|---|
| **A. `vibe-watch`** | Sigue en vivo la transcripción que el agente escribe en disco | Ninguno | No | **Tarea a medias**: solo quieres ver cómo va |
| **B. Ver el escritorio** | VNC: ves y manejas las ventanas reales desde el iPhone | Ninguno para el proceso | Sí | Tarea a medias y necesitas contestar |
| **C. Relanzar con `--continue`** | Cierras el agente y lo abres en tmux recuperando la conversación | Ninguno | Sí | Agente **parado**, esperando órdenes |
| **D. `vibe-adopt` (reptyr)** | Mueve el proceso vivo a un panel de tmux | Puede matarlo | Sí | Sesión larga que no quieres perder |

**El criterio que decide es si el agente está trabajando ahora mismo.** Si
está a mitad de una tarea, `--continue` no vale: al cerrarlo pierdes lo que
tenga en vuelo, y una herramienta a medio ejecutar puede dejar las cosas a
medias. Para ese caso, A o B.

---

## A. `vibe-watch` — ver en vivo sin tocar nada

Claude Code y codex van escribiendo la transcripción de la sesión en disco
según trabajan:

```
~/.claude/projects/<cwd-con-guiones>/<session-uuid>.jsonl
~/.codex/sessions/AAAA/MM/DD/rollout-*.jsonl
```

`vibe-watch` sigue ese archivo con `tail` y lo pinta legible. Es **solo
lectura**: no adjunta `ptrace`, no toca el proceso, no puede romper nada. Da
igual que el agente esté a mitad de la tarea más delicada del día.

```bash
vibe-watch --list      # sesiones, la más reciente arriba
```

```
#   AGENTE   ULT.     PROYECTO
1   claude   3s       /home/usuario                    <- en verde: activa ahora
2   claude   2min     /home/usuario/repos/mi-proyecto
3   claude   4h       /home/usuario
```

En verde las que han escrito hace menos de 90 segundos, que son las que están
vivas de verdad. Para seguir una:

```bash
vibe-watch 2           # por número
vibe-watch             # la más reciente
```

Se ve así:

```
  ⚙ Edit  /home/usuario/repos/mi-proyecto/CHANGELOG.md
  └ ok: The file ... has been updated successfully
  ⚙ Bash  cd mi-servicio && timeout 300 docker compose…
  └ ok: level=warning msg="The POSTGRES_PASSWORD variable is not set"
Listo. `diagnose.sh` creado y ejecutable.
```

Opciones:

| | |
|---|---|
| `--all` | Volcar todo el histórico antes de seguir (por defecto, últimas 15 entradas) |
| `--thinking` | Mostrar también los bloques de razonamiento |
| `--width N` | Ancho de recorte, si el automático no acierta |

**Lo que no da: control.** Ves lo que pasa, no puedes contestar. Si el agente
se para a preguntarte algo, lo verás y no podrás responder desde ahí.

**opencode no está soportado**: guarda el estado en SQLite
(`~/.local/share/opencode/opencode.db`), no en JSONL. Pero opencode ya lo
lanzas dentro de tmux con `vibe`, así que lo ves directamente.

### El flujo realista

Desde el móvil, con una tarea larga en marcha:

1. `vibe` para atacarte a tmux
2. En la ventana `shell`: `vibe-watch --list`, localiza la sesión en verde
3. `vibe-watch <n>` y lo dejas corriendo mientras haces otra cosa

Cuando el agente termine y se quede esperando, ya puedes cerrarlo y relanzarlo
dentro de tmux con `--continue` (opción C) para recuperar el control del todo.

---

## B. Ver el escritorio entero desde el iPhone (VNC)

Si lo único que quieres es **mirar** cómo va un agente, sin migrarlo ni tocarlo,
compartir la pantalla es lo más simple y no tiene ningún riesgo para el
proceso. Ves las ventanas reales de Ptyxis y PyCharm tal cual.

Ubuntu 26.04 ya trae `gnome-remote-desktop`:

**Configuración → Sistema → Escritorio remoto** → activa *Escritorio remoto* y
*Control remoto*, y apunta el usuario y contraseña que genera.

Desde el iPhone: **RealVNC Viewer**, **Jump Desktop** o cualquier cliente RDP,
apuntando a la IP del tailnet (`100.x.y.z`).

> **Seguridad:** que escuche **solo** en la interfaz de Tailscale, nunca
> expuesto a internet. El acceso remoto al escritorio es control total del
> equipo. Y si `ufw` está inactivo, el puerto queda abierto a toda tu red
> local.

Inconvenientes frente a tmux: gasta mucho más ancho de banda, la latencia se
nota, necesita que la sesión gráfica esté desbloqueada, y manejar un escritorio
de portátil en una pantalla de móvil es incómodo. Para trabajar de verdad, tmux
es mejor. Para echar un vistazo a media tarde, esto sobra.

---

## C. Relanzar dentro de tmux

Los agentes guardan la conversación en disco, así que cerrar y volver a abrir
no pierde el hilo:

```bash
claude --continue      # retoma la última conversación de ese directorio
claude --resume        # deja elegir cuál de las anteriores
```

`codex` y `opencode` tienen equivalentes propios; consulta `--help` de cada uno,
que cambian entre versiones.

Flujo completo:

1. En el agente que tienes abierto, sal limpiamente.
2. `vibe` (o `vibe start` si aún no existe la sesión).
3. Ve a la ventana que toque y arranca ahí con `--continue`.

A partir de ahí ese agente ya vive en tmux y lo ves desde el móvil para
siempre. Es un coste de una sola vez.

Para que no vuelva a pasar, lanza los agentes desde `vibe` en vez de desde la
terminal gráfica. Los que uses siempre, ponlos en `config/agents.conf`.

---

## D. Adoptar el proceso vivo con `vibe-adopt`

Cuando el agente lleva horas trabajando y no quieres arriesgarte a perder el
contexto.

`reptyr` usa `ptrace` para reasignar los descriptores de terminal del proceso a
otro pty. En la práctica: lo saca de Ptyxis y lo mete en un panel de tmux, sin
matarlo.

### Uso

```bash
vibe-adopt --list          # ver qué hay y dónde
```

```
PID      TTY      DONDE      COMANDO
78350    pts/2    terminal   claude --dangerously-skip-permissions
209008   pts/1    terminal   claude --dangerously-skip-permissions
213615   pts/5    TMUX       opencode
```

Los marcados `TMUX` ya se ven desde el móvil. Para los otros:

1. Atacate a tmux: `vibe`
2. Ve a la ventana donde quieras que aterrice (prefijo → `1`)
3. Dentro de esa ventana:

```bash
vibe-adopt 78350
```

Pide confirmación escribiendo `SI` y muestra antes qué proceso va a mover y
desde qué terminal.

### Sin `sudo` delante

```bash
vibe-adopt 78350          # bien
sudo vibe-adopt 78350     # mal
```

Con `sudo` delante sale `sudo: vibe-adopt: command not found`. No es que falte
el script: `sudo` sustituye tu `PATH` por el `secure_path` de `/etc/sudoers`,
que solo trae `/usr/bin`, `/bin` y compañía — no `~/terminal-remote-job/bin`.

Y aunque lo llamaras por ruta absoluta seguiría sin funcionar, porque `sudo`
también limpia el entorno y se lleva `$TMUX`. Sin esa variable el script no
sabe en qué panel tiene que aterrizar el proceso, que es justo su trabajo.

El `sudo` lo pone el propio script, y solo sobre `reptyr`. Te pedirá la
contraseña en el momento justo. Desde la versión actual, si detecta que lo has
lanzado con `sudo` te lo dice en vez de fallar de forma críptica.

### `Unable to find the fd for the pty!`

Es el fallo más probable, y sale con `--steal` (modo `-T`).

`-T` no hace `ptrace` sobre el proceso: busca el emulador de terminal y le roba
el extremo maestro del pty. Eso choca con los emuladores de modelo
cliente-servidor — **Ptyxis, GNOME Terminal, Konsole** — donde el maestro lo
tiene un proceso agente compartido, con un pty por pestaña, y `reptyr` no
acierta cuál de todos es el tuyo:

```
[-] Unable to find the fd for the pty!
Unable to attach to pid 78350: No such process
```

El "No such process" despista: el proceso existe. El error es del emulador, no
del objetivo.

Por eso el modo por defecto de `vibe-adopt` es el normal (`ptrace` directo), y
`-T` queda detrás de `--steal` como segundo intento. Si falla uno, el script te
sugiere el otro.

### Lo que puede salir mal

- **reptyr falla.** Las TUI con muchos hilos son su caso difícil, y los agentes
  son aplicaciones Node/Bun con bastantes. Normalmente el proceso sobrevive en
  su terminal original, pero puede morir. No lo lances sobre trabajo sin
  guardar.
- **La ventana original queda inservible.** Ptyxis o PyCharm se quedan con un
  pty huérfano. Ciérrala.
- **La interfaz aparece descuadrada.** El agente no se ha enterado del cambio
  de tamaño. Redimensiona el panel de tmux, o `Ctrl+l` para forzar redibujado.
- **La shell original cree que el proceso sigue suyo.** Tras adoptarlo, ejecuta
  `bg; disown` en la terminal de origen para soltar la asociación.

### Shells normales no se pueden adoptar

Una `bash` interactiva es el peor caso de `reptyr`: es líder de sesión y de
grupo de procesos, y el control de trabajos no sobrevive al cambio de pty. El
modo `-T` existía justo para eso, pero es el que falla con Ptyxis.

Tampoco compensa: una shell no tiene estado que perder más allá del directorio
y el historial. Abre una nueva en tmux y `cd` donde estabas. El historial es
compartido, así que lo tienes igual.

### Sobre `ptrace_scope`

Ubuntu trae `kernel.yama.ptrace_scope=1`: un proceso solo puede inspeccionar a
sus propios descendientes. `reptyr`, lanzado desde tmux contra un proceso de
Ptyxis, no cumple esa condición.

`vibe-adopt` lo resuelve con `sudo reptyr`, que salta la restricción sin tocar
nada global. Es la opción por defecto y la preferible.

La alternativa, `vibe-adopt PID --sysctl`, baja `ptrace_scope` a 0. Mientras
está a 0, **cualquier proceso tuyo puede leer la memoria de cualquier otro
proceso tuyo** — incluidos los que tienen tus claves y tokens en RAM. El script
lo restaura solo a los 30 segundos, pase lo que pase, pero úsalo solo si no
quieres dar sudo.
