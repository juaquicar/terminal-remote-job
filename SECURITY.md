# Política de seguridad

## Reportar una vulnerabilidad

**No abras un issue público.** Usa
[GitHub Security Advisories](https://github.com/juaquicar/terminal-remote-job/security/advisories/new)
o escribe al mantenedor a través de su perfil de GitHub.

Incluye qué versión (commit) usas, la distribución, y los pasos para
reproducirlo. Si el fallo permite acceso no autorizado, dilo en la primera
línea.

Respuesta en unos días. Este es un proyecto personal mantenido en ratos libres,
no hay SLA.

## Alcance

Este proyecto configura acceso remoto a una shell. Entra dentro del alcance
cualquier cosa que amplíe ese acceso más allá de lo documentado:

- Exposición de servicios a interfaces distintas de las declaradas
- Escalada de privilegios a través de los scripts o del uso de `sudo`
- Fugas de credenciales, claves o tokens en logs, argumentos o archivos temporales
- Que `--harden` deje `sshd` en un estado menos seguro del que promete
- Inyección de comandos a través de `config/agents.conf` o de argumentos

**Fuera de alcance**, porque es comportamiento documentado y deliberado:

- `vibe-web --quick` publica una URL sin Cloudflare Access. Está avisado en el
  script, en el README y en `docs/cloudflare-tunnel.md`.
- `vibe-adopt --sysctl` baja `kernel.yama.ptrace_scope` durante 30 segundos.
  Avisado, y con restauración automática.
- `install.sh --harden` deja `sshd` sin login por contraseña: si pierdes la clave
  privada, solo entras físicamente. Avisado.
- Vulnerabilidades de las dependencias (`tmux`, `mosh`, `ttyd`, `reptyr`,
  `cloudflared`, Tailscale). Repórtalas a sus proyectos.

## Modelo de amenaza

El diseño asume que:

- La red del tailnet es de confianza y sus dispositivos son tuyos.
- Quien tiene acceso físico al escritorio ya ha ganado; no se defiende de eso.
- El usuario que ejecuta esto tiene `sudo`. Los scripts lo usan de forma
  acotada, nunca se ejecutan enteros como root, y `vibe-adopt` se niega
  explícitamente a correr bajo `sudo`.

Lo que **sí** se defiende:

- Que nada quede escuchando en `0.0.0.0` sin que lo hayas pedido.
- Que no se abran puertos a internet: las reglas de `ufw` se limitan a
  `tailscale0`, y `ufw` no se activa automáticamente.
- Que no puedas bloquearte a ti mismo: `--harden` se niega si no hay clave
  autorizada.
- Que ninguna operación destructiva ocurra sin confirmación explícita.

## Versiones soportadas

Solo la rama `main`. No hay releases con soporte extendido.
