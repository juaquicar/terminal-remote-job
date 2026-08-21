# Acceso por Cloudflare Tunnel (alternativa a Tailscale)

## Primero, una aclaración

**Tailscale ya funciona fuera de tu red local.** No es una VPN de LAN: monta
una red privada propia (tailnet) que atraviesa NAT y CGNAT, y conecta el
iPhone con el portátil estés donde estés — 4G, 5G, el WiFi de un hotel o el de
un aeropuerto. Si lo que quieres es "entrar desde fuera de casa", ya lo tienes
con la vía principal del README y **no necesitas Cloudflare**.

Cloudflare Tunnel resuelve otros casos:

| Situación | Vía |
|---|---|
| Entrar desde el iPhone estés donde estés | **Tailscale** |
| Red que bloquea UDP o WireGuard (algunas corporativas, WiFis captivos) | **Cloudflare** (va por HTTPS/443) |
| Dispositivo donde no puedes instalar la app de Tailscale (iPad prestado, PC ajeno) | **Cloudflare** (solo navegador) |
| Enseñarle la terminal a otra persona un rato | **Cloudflare** con Access |
| Terminal en Safari sin instalar nada | **Cloudflare** |

Se pueden tener las dos a la vez sin conflicto. Recomendación: Tailscale como
vía diaria, Cloudflare como plan B para redes hostiles.

---

## Aviso de seguridad — léelo

Lo que vas a publicar es **una shell con tus credenciales de GitHub, tus claves
de API y tus repos dentro**, y encima con agentes que ejecutan comandos. Quien
llegue a esa URL tiene control total del portátil. No es un blog.

Reglas que no se negocian:

1. **Nunca** expongas `ttyd` sin autenticación. Ni "un momento para probar".
   Los rangos de `trycloudflare.com` se escanean.
2. Pon **dos capas**: Cloudflare Access delante (autenticación por email/Google
   antes de que el tráfico llegue a tu equipo) **y** contraseña en `ttyd`.
3. `ttyd` debe escuchar en `127.0.0.1`, nunca en `0.0.0.0`. Solo `cloudflared`,
   que corre en la misma máquina, debe poder alcanzarlo.
4. Apaga el túnel cuando no lo uses. El script `vibe-web` lo hace al salir.

El montaje A cumple todo esto. El montaje B (túnel rápido) **no tiene Access** y
solo debería usarse minutos, con contraseña larga, y sabiendo lo que haces.

---

## Montaje A — túnel con nombre + Access (el bueno)

Requisito: un dominio gestionado por Cloudflare (los nameservers apuntando a
Cloudflare). El plan gratuito basta, y Zero Trust es gratis hasta 50 usuarios.

### 1. Instalar cloudflared y ttyd

```bash
~/terminal-remote-job/install.sh --web
```

O a mano:

```bash
sudo apt install ttyd
curl -fsSL https://pkg.cloudflare.com/cloudflare-main.gpg \
  | sudo tee /usr/share/keyrings/cloudflare-main.gpg >/dev/null
echo "deb [signed-by=/usr/share/keyrings/cloudflare-main.gpg] https://pkg.cloudflare.com/cloudflared any main" \
  | sudo tee /etc/apt/sources.list.d/cloudflared.list
sudo apt update && sudo apt install cloudflared
```

### 2. Crear el túnel

```bash
cloudflared tunnel login          # abre el navegador, elige tu dominio
cloudflared tunnel create agentes
```

Apunta el UUID que imprime.

### 3. Configurar

`~/.cloudflared/config.yml`:

```yaml
tunnel: PON-AQUI-EL-UUID
credentials-file: /home/usuario/.cloudflared/PON-AQUI-EL-UUID.json

ingress:
  # Terminal web
  - hostname: term.tudominio.com
    service: http://127.0.0.1:7681

  # SSH renderizado por Cloudflare en el navegador (opcional, ver mas abajo)
  - hostname: ssh.tudominio.com
    service: ssh://127.0.0.1:22

  - service: http_status:404
```

Ruta DNS:

```bash
cloudflared tunnel route dns agentes term.tudominio.com
cloudflared tunnel route dns agentes ssh.tudominio.com
```

### 4. Proteger con Cloudflare Access

En el panel: **Zero Trust → Access → Applications → Add an application →
Self-hosted**.

- Application domain: `term.tudominio.com`
- Policy: *Allow* → **Emails** → tu correo
- Método de login: One-time PIN por email, o Google/GitHub

Sin esto, cualquiera con la URL entra. **Este paso no es opcional.**

Añade también, en la política, `Session Duration: 24h` para no reautenticarte
cada rato desde el móvil.

### 5. Arrancar

```bash
sudo cloudflared service install    # el tunel arranca con el sistema
~/terminal-remote-job/bin/vibe-web      # levanta ttyd contra la sesion tmux
```

Desde Safari en el iPhone: `https://term.tudominio.com` → login de Access →
contraseña de ttyd → estás dentro de tmux.

Añádelo a la pantalla de inicio (**Compartir → Añadir a pantalla de inicio**) y
se abre a pantalla completa, como una app.

---

## SSH en el navegador, sin ttyd

Cloudflare puede renderizar una terminal SSH directamente, sin `ttyd`. En el
panel: **Zero Trust → Access → Applications**, aplicación self-hosted sobre
`ssh.tudominio.com`, y en **Settings → Browser rendering** elige **SSH**.

Ventaja: no expones ningún servicio HTTP propio y reutilizas `sshd`, que ya
está endurecido. Inconveniente: la terminal del navegador es más torpe que
`ttyd` con el teclado de iOS, y necesitas gestionar el acceso con certificados
de Access o claves.

---

## Montaje B — túnel rápido, sin dominio

Para una prueba de cinco minutos. **Sin Cloudflare Access**: la única barrera
es la contraseña de `ttyd`.

```bash
~/terminal-remote-job/bin/vibe-web --quick
```

Levanta `ttyd` en `127.0.0.1` con una contraseña aleatoria que imprime en
pantalla, abre `cloudflared tunnel --url` y te da una URL
`https://algo-aleatorio.trycloudflare.com`. Al pulsar `Ctrl+c`, mata las dos
cosas.

La URL es pública. Es larga y aleatoria, pero pública. Úsalo poco y no lo dejes
corriendo de un día para otro.

---

## Lo que Cloudflare no te da

- **Puertos que no son HTTP/SSH**: si un agente levanta un dev server, con
  Tailscale lo abres en `http://100.x.y.z:5173` sin más. Con Cloudflare hay que
  añadir otro hostname al `ingress` y otra aplicación de Access por cada
  puerto.
- **mosh**: mosh necesita UDP directo. No pasa por Cloudflare Tunnel. Sin mosh,
  cada corte de red te obliga a recargar la pestaña — aunque, otra vez, tmux te
  guarda el trabajo.
- **Latencia menor**: el tráfico da la vuelta por la red de Cloudflare.
  Tailscale suele establecer conexión directa entre iPhone y portátil, y se
  nota al teclear.

Por eso la vía principal sigue siendo Tailscale.
