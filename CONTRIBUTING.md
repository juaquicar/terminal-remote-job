# Contribuir

Gracias por pasarte. Esto nació como un apaño personal para seguir el trabajo
de agentes CLI desde el móvil, así que hay mucho margen de mejora y las
aportaciones son bienvenidas.

Se acepta español e inglés, tanto en issues como en pull requests.

---

## Antes de abrir un issue

Ejecuta esto y pega la salida:

```bash
bin/vibe-status
```

Y di al menos:

- Distribución y versión (`. /etc/os-release && echo $PRETTY_NAME`)
- Versión de tmux (`tmux -V`)
- Emulador de terminal desde el que lanzas las cosas
- Qué esperabas y qué pasó

Si el problema es de `vibe-adopt`, incluye también:

```bash
cat /proc/sys/kernel/yama/ptrace_scope
reptyr --help 2>&1 | head -1
pstree -sp <PID-del-proceso>
```

`reptyr` falla de formas muy distintas según el emulador, y el árbol de
procesos suele ser la pista que resuelve el caso.

---

## Estilo del código

Bash, sin dependencias más allá de lo que trae una Ubuntu de serie. Un script
que necesite instalar algo tiene que degradarse con elegancia si no está.

- `set -euo pipefail` en todo script nuevo.
- Cabecera de comentario con el propósito, el uso y **las limitaciones**. Que
  alguien pueda leer los primeros 20 renglones y saber si le sirve.
- `-h/--help` que imprima esa cabecera.
- Nombres y mensajes en español, como el resto. Comentarios sin tildes, para no
  depender del locale del terminal.
- Comentarios que expliquen **por qué**, no qué. El qué ya se lee en el código.
- Los mensajes al usuario van por `info()`, `warn()`, `die()`, con el mismo
  formato que los scripts existentes.

### Lo que no se acepta

- Nada que baje la seguridad por comodidad. En concreto: reglas `NOPASSWD`,
  exponer `ttyd` sin autenticación, o dejar `ptrace_scope` a 0 de forma
  permanente. Si una función lo necesita, va detrás de un flag explícito, con
  el aviso delante y restauración automática.
- Operaciones destructivas sin confirmación.
- Silenciar errores con `2>/dev/null` sin explicar por qué en un comentario.

---

## Probar los cambios

No hay suite de tests; el proyecto manipula terminales de verdad y eso es
incómodo de automatizar. Lo mínimo antes de un PR:

```bash
# Sintaxis de todo
for f in install.sh bin/vibe bin/vibe-status bin/vibe-shells bin/vibe-adopt bin/vibe-web bin/env.sh bin/vibe-hook.sh; do
    bash -n "$f" || echo "FALLA: $f"
done
python3 -c "import ast; ast.parse(open('bin/vibe-watch').read())"

# shellcheck, si lo tienes
shellcheck -S warning install.sh bin/vibe bin/vibe-*

# Sesión desechable, para no tocar la tuya
bin/vibe start -s pruebas
tmux list-windows -t pruebas
bin/vibe kill -s pruebas
```

Usa **siempre** `-s <nombre>` al probar. Un `vibe kill` sin sesión indicada se
lleva por delante la sesión de trabajo de quien lo ejecute.

Si tocas `install.sh`, prueba la parte de `~/.bashrc` contra una **copia**:

```bash
cp ~/.bashrc /tmp/bashrc-prueba
# ...ejecuta tu lógica contra /tmp/bashrc-prueba...
diff <(grep -v terminal-remote-job ~/.bashrc) <(grep -v terminal-remote-job /tmp/bashrc-prueba)
```

Tiene que ser idempotente: ejecutarlo tres veces seguidas debe dejar el archivo
igual que ejecutarlo una.

---

## Documentación

Cada cambio de comportamiento toca al menos dos sitios:

| Dónde | Qué va |
|---|---|
| Cabecera del script | Uso y limitaciones |
| `README.md` | Explicación y contexto |
| `README-FAST.md` | Una línea en la tabla de comandos |
| `docs/troubleshooting.md` | Si puede fallar de forma confusa |

Si añades un mensaje de error nuevo que alguien pueda buscar en Google, mete la
cadena literal en `docs/troubleshooting.md`. Es lo que más agradece quien llega
desde un buscador.

---

## Pull requests

- Una cosa por PR.
- Explica el **por qué** en la descripción, no solo el qué.
- Si el cambio afecta a la seguridad (SSH, firewall, ptrace, exposición de
  puertos), dilo en la primera línea.
- Los commits en imperativo, con prefijo: `fix:`, `feat:`, `docs:`, `refactor:`.

## Reportar un problema de seguridad

No abras un issue público. Escribe directamente al mantenedor a través del
perfil de GitHub.
