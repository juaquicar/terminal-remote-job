# Configurar el iPhone / iPad

Objetivo: abrir la app, tocar un botón y aparecer dentro de la sesión tmux con
Claude Code, opencode y codex corriendo en el portátil.

---

## 1. Tailscale en iOS

1. App Store → **Tailscale** → instalar.
2. Iniciar sesión con **la misma cuenta** que en el portátil.
3. Activar el VPN cuando lo pida iOS.

Comprueba que el portátil aparece en la lista de dispositivos y apunta su IP
`100.x.y.z`. También funciona el nombre MagicDNS
(`portatil.<tu-tailnet>.ts.net`), más cómodo de recordar.

Tailscale en iOS gasta poca batería: es WireGuard y solo cifra el tráfico que
va al tailnet. Puedes dejarlo siempre activo.

---

## 2. Elegir cliente de terminal

| App | Precio | mosh | Por qué |
|---|---|---|---|
| **Blink Shell** | de pago | sí | La mejor. mosh nativo, teclado configurable, se reconecta sola. Recomendada. |
| Termius | gratis (con extras de pago) | no | Suficiente si solo quieres SSH y no te importa reconectar a mano. |
| a-Shell | gratis | no | Más limitada, sirve de apaño. |

Sin mosh la experiencia es peor: cada vez que el iPhone cambia de WiFi a datos
o se bloquea la pantalla, la sesión SSH se corta y hay que reconectar. Con mosh
la conexión sobrevive: reanudas donde estabas.

Aun con SSH pelado no pierdes trabajo — los agentes siguen corriendo dentro de
tmux en el portátil. Solo tienes que volver a atacarte.

---

## 3. Generar la clave en el móvil y copiarla al portátil

### Blink Shell

1. En Blink: `config` → **Keys** → `+` → **Create New** → tipo **Ed25519**,
   nombre `blink`.
2. Toca la clave → **Copy Public Key**.
3. Pégala en algún sitio desde el que puedas llevarla al portátil (Notas, un
   mail a ti mismo, Handoff…).
4. En el portátil, añádela:

   ```bash
   echo 'ssh-ed25519 AAAA...la-que-copiaste... blink' >> ~/.ssh/authorized_keys
   chmod 600 ~/.ssh/authorized_keys
   ```

### Termius

Settings → **Keychain** → `+` → **Generate key** → Ed25519 → compartir la clave
pública y pegarla igual que arriba.

### Atajo si ya tienes SSH funcionando por contraseña

**Ojo: el `ssh-copy-id` de Blink NO usa la sintaxis de siempre.** No acepta
`-i` y quiere el nombre de la clave *primero*:

```
ssh-copy-id identity_file [user@]host
```

Es decir, dentro de Blink:

```bash
ssh-copy-id id_ed25519 usuario@100.x.y.z
```

Donde `id_ed25519` es el **nombre que tiene la clave en el llavero de Blink**
(`config` → **Keys**), no una ruta. Si la creaste con otro nombre, usa ese.

Con el `ssh-copy-id` normal de Linux/macOS sí vale `ssh-copy-id usuario@host`.

---

## 4. Comprobar y endurecer

Desde el móvil, prueba a entrar. Cuando funcione **sin pedir contraseña**,
vuelve al portátil y cierra la puerta:

```bash
~/terminal-remote-job/install.sh --harden
```

Esto desactiva el login por contraseña. Si lo haces antes de que la clave
funcione, el script se niega y te lo dice.

---

## 5. Guardar el host

### Blink Shell

`config` → **Hosts** → `+`

| Campo | Valor |
|---|---|
| Host | `vibe` |
| HostName | `100.x.y.z` (o el nombre MagicDNS) |
| User | `usuario` |
| Key | `blink` |
| **Mosh Server** | `mosh-server` |

Con eso, desde la línea de comandos de Blink:

```
mosh vibe -- ~/terminal-remote-job/bin/vibe mobile
```

Aterrizas directamente en la sesión tmux, en modo móvil.

Puedes guardarlo como atajo: Blink permite crear un host cuyo comando por
defecto sea ese, y arrancar la app ya conectado.

### Termius

Hosts → `+` → rellena Address / Username / Key. En **Advanced → Startup
snippet** pon:

```
~/terminal-remote-job/bin/vibe mobile
```

---

## 6. Teclado: sobrevivir sin Ctrl ni Esc

El teclado de iOS no tiene teclas de control. Opciones:

- **Blink**: `config` → **Keyboard**. Lo más práctico es mapear
  `CapsLock → Ctrl` si usas teclado físico, y activar la barra de mods en
  pantalla (Ctrl, Alt, Esc, flechas) para el teclado táctil.
- **Ratón activado**: el `tmux.conf` de este directorio tiene `mouse on`, así
  que puedes **tocar la barra inferior** para cambiar de ventana sin usar el
  prefijo. Para el uso normal (leer lo que hace el agente, saltar entre
  claude / opencode / codex) casi no necesitas teclas.
- **Prefijo alternativo**: además de `Ctrl+b` está `Ctrl+a`, más cómodo de
  alcanzar.
- **Scroll**: arrastra con el dedo. Sales del modo copia con `q` o tocando.

### Chuleta mínima

| Acción | Teclas |
|---|---|
| Siguiente / anterior ventana | `Ctrl+a` luego `Ctrl+n` / `Ctrl+p` |
| Ir a la ventana N | `Ctrl+a` luego `1`…`4` |
| Ver lista de ventanas | `Ctrl+a` luego `w` |
| Salir dejando todo corriendo | `Ctrl+a` luego `d` |
| Nueva ventana | `Ctrl+a` luego `c` |
| Dividir en horizontal / vertical | `Ctrl+a` luego `"` / `%` |

**Nunca** cierres la app con la sesión sin detachar pensando que matas algo:
no lo hace. Los agentes siguen trabajando.

---

## 7. Ver un servidor de desarrollo desde el móvil

Como el iPhone está dentro del tailnet, no necesitas túneles SSH. Si un agente
levanta un dev server en el puerto 3000, en Safari del iPhone:

```
http://100.x.y.z:3000
```

Requisito: que el server escuche en `0.0.0.0` y no solo en `127.0.0.1`
(en Vite, `--host`; en Next.js, `-H 0.0.0.0`).
