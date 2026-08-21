# Problemas frecuentes

Antes de nada: `~/terminal-remote-job/bin/vibe-status` te dice qué falta.

---

## El portátil se suspende y pierdo el acceso

**El problema más gordo de todos**, y no es de red. Si cierras la tapa del
portátil o se duerme por inactividad, el equipo se apaga a efectos prácticos: las
sesiones tmux siguen ahí, pero nadie responde hasta que vuelva a despertar. Y
un portátil suspendido no despierta por SSH.

Los agentes tampoco avanzan mientras duerme: un `claude` a medio trabajo se
queda congelado.

### Opción A — impedir la suspensión solo mientras trabajas (recomendada)

```bash
systemd-inhibit --what=sleep:idle --why="agentes remotos" sleep infinity
```

Déjalo corriendo en una ventana de tmux. Al matarlo (`Ctrl+c`) el equipo vuelve
a poder suspenderse. Cero cambios permanentes.

Para que sea cómodo, añádelo como ventana en `config/agents.conf`:

```
awake | systemd-inhibit --what=sleep:idle --why="agentes remotos" sleep infinity |
```

### Opción B — no suspender al cerrar la tapa

```bash
sudo mkdir -p /etc/systemd/logind.conf.d
printf '[Login]\nHandleLidSwitch=ignore\nHandleLidSwitchExternalPower=ignore\n' \
  | sudo tee /etc/systemd/logind.conf.d/90-terminal-remote-job.conf
sudo systemctl restart systemd-logind
```

Ojo: con la tapa cerrada y sin suspender, el portátil se calienta. No lo metas
en una mochila así.

Revertir: `sudo rm /etc/systemd/logind.conf.d/90-terminal-remote-job.conf` y
reiniciar `systemd-logind`.

### Opción C — desactivar la suspensión del todo

```bash
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target
```

Bruto y global. Revertir con `unmask`. Solo si el portátil vive enchufado.

---

## `opencode: command not found`

`opencode` está instalado como paquete npm global bajo la versión de node que
gestiona **fnm**. En tus shells interactivas eso ya está resuelto: `~/.bashrc`
carga `~/.local/share/<tu-gestor>/shellenv.sh`, que inicializa fnm. Por
eso una sesión SSH normal y las ventanas de tmux lo encuentran sin más.

Donde **sí** desaparece es en shells de login no interactivas — `bash -lc`,
cron, unidades de systemd — porque ahí `~/.bashrc` no se lee:

```bash
$ env -i HOME=$HOME bash -lc 'command -v opencode'   # no imprime nada
```

`bin/env.sh` es la red de seguridad: añade
`~/.local/share/fnm/aliases/default/bin` (ruta estable, sobrevive a cambios de
versión de node) y `vibe` lo sourcea antes de arrancar el servidor tmux, para
que el `PATH` no dependa de qué shell lo lanzó.

Si te falta en una shell suelta:

```bash
source ~/terminal-remote-job/bin/env.sh
```

**Caso especial:** si el servidor tmux ya estaba corriendo *antes* de que
existiera este directorio, arrastra el `PATH` viejo. Mátalo y vuelve a empezar:

```bash
vibe kill && vibe start
```

---

## Al atacarme desde el móvil, el portátil se encoge

Comportamiento normal de tmux: una sesión compartida se ajusta al cliente más
pequeño. Soluciones, en orden:

1. Usa `vibe mobile` desde el móvil. Crea una sesión agrupada con tamaño
   propio: comparte las ventanas pero no el tamaño ni la ventana activa.
2. `aggressive-resize on` ya está en el `tmux.conf`, así que solo se ajusta la
   ventana que el cliente pequeño esté mirando.
3. Último recurso: `tmux attach -d` desde el móvil, que echa al otro cliente.

---

## Conexión que se cae al cambiar de WiFi a datos

Es SSH haciendo lo que hace SSH. Usa **mosh**:

```
mosh vibe -- ~/terminal-remote-job/bin/vibe mobile
```

mosh sobrevive a cambios de IP y a la suspensión del móvil. No pierdes nada
aunque no lo uses, porque los agentes viven en tmux, pero la experiencia es
otra.

### mosh no conecta

- **`mosh-server` no encontrado**: no está instalado en el portátil →
  `sudo apt install mosh`.
- **Se queda en "Connecting…"**: mosh usa UDP 60000-61000. Sobre Tailscale no
  debería haber problema, pero comprueba el firewall:

  ```bash
  sudo ufw status | grep 60000
  ```
- **Locale**: mosh es quisquilloso. Si ves quejas de `LC_CTYPE`, en Blink
  fuerza `LANG=es_ES.UTF-8` o `en_US.UTF-8` en la config del host.

---

## Tailscale conectado pero no puedo entrar por SSH

Comprueba en este orden:

```bash
systemctl is-active ssh          # ¿está el servicio?
tailscale ip -4                  # ¿tengo IP de tailnet?
ss -tlnp | grep :22              # ¿escucha sshd?
sudo ufw status                  # ¿bloquea el firewall?
```

Desde el móvil, verifica que la app de Tailscale tiene el VPN **activo** (icono
en la barra de estado de iOS). Es lo que más veces falla.

Si has aplicado `--harden` y te pide contraseña, la clave pública no está bien
puesta. Mira los logs en el portátil mientras intentas entrar:

```bash
sudo journalctl -u ssh -f
```

---

## `Permission denied (publickey)` con la clave correcta puesta

Casi siempre son **permisos**, no la clave. `sshd` tiene `StrictModes` activo
por defecto: recorre la ruta de `authorized_keys` **directorio a directorio** y
rechaza la clave si alguno es escribible por grupo u otros. No avisa al
cliente; solo dice "Permission denied".

En este equipo `~/.ssh` es un **symlink**:

```
~/.ssh -> ~/repos/dotfiles/ssh
```

Así que `sshd` no comprueba `~/.ssh`, sino toda la cadena real: `repos`,
`repos`, `dotfiles`, `ssh`. Basta con que uno esté a 775 o 777 para que
falle.

Comprobar la cadena entera:

```bash
namei -l ~/.ssh/authorized_keys
```

Ninguno de los directorios puede tener el bit de escritura de grupo ni de
otros. Corregir:

```bash
chmod 755 ~/repos ~/repos/dotfiles ~/repos/dotfiles
chmod 700 ~/repos/dotfiles/ssh
chmod 600 ~/.ssh/authorized_keys
```

Cuidado con `ls -ld ~/.ssh`: al ser un symlink siempre muestra `lrwxrwxrwx`, y
eso no significa nada. Para ver los permisos reales hay que seguir el enlace:

```bash
stat -Lc '%a %n' ~/.ssh
```

Ver el motivo exacto del rechazo, en el portátil, mientras intentas entrar:

```bash
sudo journalctl -u ssh -f | grep -i "bad ownership\|Authentication refused"
```

---

## Los colores o las cajas se ven raros

Falta de acuerdo sobre el terminal. En el portátil:

```bash
tmux kill-server
vibe start
```

En Blink, `config` → **Appearance**, y asegúrate de que el terminal se anuncia
como `xterm-256color`. El `tmux.conf` ya declara `tmux-256color` con
`terminal-overrides` para color verdadero.

Si un agente pinta cajas rotas, casi siempre es una fuente sin glifos Nerd
Font. Blink permite instalar fuentes personalizadas.

---

## Servicios expuestos sin querer

`vibe-status` avisa de todo lo que escuche en `0.0.0.0`, `*` o `[::]`:

```
Servicios expuestos
  AVISO 7 puerto(s) en TODAS las interfaces, no solo en el tailnet:
        22     ?                SSH (esperado)
        3000   ?
        3389   gnome-remote-de  escritorio remoto: control total del equipo
```

**Escuchar en `0.0.0.0` no significa "accesible desde el tailnet".** Significa
accesible desde **cualquier** red a la que esté conectado el equipo: el tailnet
sí, pero también el WiFi del hotel, el de la cafetería o el de la oficina del
cliente. Con `ufw` inactivo, no hay nada filtrando.

Se acumulan solos: un dev server que quedó con `--host`, un contenedor lanzado
con `-p 0.0.0.0:8080`, el escritorio remoto que activaste una vez para probar.

Ver quién es cada uno (con `sudo`, si no no salen los nombres):

```bash
sudo ss -tlnp
```

### Los tres casos y qué hacer

**1. Debería ser solo local.** Átalo a `127.0.0.1`. En Docker, `-p 127.0.0.1:8080:8080`
en vez de `-p 8080:8080`.

**2. Lo quieres desde el móvil, pero solo desde el tailnet.** Átalo a la IP del
tailnet en lugar de a todas las interfaces:

```bash
# En vez de escuchar en 0.0.0.0
vite --host 100.x.y.z
```

O deja `0.0.0.0` y activa el firewall, que es más cómodo si son varios
servicios. `install.sh` ya dejó las reglas de SSH y mosh sobre `tailscale0`;
añade las tuyas y luego activa `ufw`:

```bash
sudo ufw allow in on tailscale0 to any port 5173 proto tcp
sudo ufw default deny incoming
sudo ufw enable
```

> Antes de `ufw enable`, revisa `sudo ufw status numbered` y asegúrate de que
> la regla del 22 sobre `tailscale0` está. Activar el firewall sin ella te deja
> fuera de tu propia máquina si estás en remoto.

**3. Escritorio remoto (3389 RDP, 5900 VNC).** Es control total del equipo, no
un servicio más. Si lo usas, restríngelo al tailnet como en el caso 2. Si no lo
usas, apágalo: **Configuración → Sistema → Escritorio remoto**. Una superficie
de ataque menos, gratis.

---

## `claude` me mete en tmux y ahora no quiero eso

Es `vibe-hook.sh`, que `~/.bashrc` carga. Hace que los agentes nazcan siempre
dentro de tmux para que no haya que adoptarlos después.

Para saltárselo:

```bash
VIBE_NO_WRAP=1 claude     # solo esta vez
vibe-unwrap               # desactivarlo en la shell actual
```

Para envolver solo algunos, antes del `source` en `~/.bashrc`:

```bash
export VIBE_WRAP_AGENTS="claude"
```

Para quitarlo del todo, borra la línea del `source` dentro del bloque
`# >>> terminal-remote-job >>>` de `~/.bashrc`, o vuelve a lanzar el instalador sin
`--hook`:

```bash
~/terminal-remote-job/install.sh --no-bashrc     # no tocar nada
~/terminal-remote-job/install.sh                 # solo PATH, sin envoltorio
```

El instalador reescribe ese bloque entero cada vez, así que no se acumulan
copias. Deja backup en `~/.bashrc.bak-terminal-remote-job`.

Dentro de tmux el envoltorio no actúa: ejecuta el binario de siempre.

---

## Quiero matar todo y empezar de cero

```bash
vibe kill          # mata la sesión 'vibe'
tmux kill-server   # mata el servidor entero, todas las sesiones
```

Esto **sí** mata los agentes que estuvieran corriendo dentro.

---

## Deshacer la instalación

```bash
~/terminal-remote-job/bin/vibe kill
# quitar el bloque de ~/.bashrc
sed -i '/# >>> terminal-remote-job >>>/,/# <<< terminal-remote-job <<</d' ~/.bashrc
sudo rm -f /etc/ssh/sshd_config.d/50-terminal-remote-job.conf
sudo systemctl reload ssh
sudo systemctl disable --now ssh
sudo ufw delete allow in on tailscale0 to any port 22 proto tcp
sudo ufw delete allow in on tailscale0 to any port 60000:61000 proto udp
rm -rf ~/terminal-remote-job
```

Tailscale y mosh se quedan instalados; quítalos con `apt remove` si no los
quieres.
