## Qué cambia y por qué

<!-- El porqué importa más que el qué. -->

## Tipo

- [ ] `fix` — corrige un fallo
- [ ] `feat` — funcionalidad nueva
- [ ] `docs` — solo documentación
- [ ] `refactor` — sin cambio de comportamiento

## ¿Afecta a la seguridad?

<!-- SSH, firewall, ptrace, exposición de puertos, permisos. Si es que sí,
     descríbelo aquí; si no, pon "No". -->

## Comprobaciones

- [ ] `bash -n` pasa en todos los scripts tocados
- [ ] Probado con una sesión desechable (`vibe start -s pruebas`), no con la de trabajo
- [ ] Si toca `install.sh`, probado contra una **copia** de `~/.bashrc` y es idempotente
- [ ] Documentación actualizada (`README.md`, `README-FAST.md`, `docs/`)
- [ ] Si añade un mensaje de error nuevo, la cadena literal está en `docs/troubleshooting.md`
