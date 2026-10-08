# Reporte: instalación de YADR 2027 en macOS Ventura (Intel x86_64)

**Fecha:** 7 de octubre de 2026
**Equipo:** macOS 13.7.8 Ventura, Intel x86_64
**Repo:** `https://github.com/marcoarata/dotfiles` (checkout local en `~/.yadr-2027`)
**Resultado final:** `yadr doctor → 0 errores, 0 avisos`. Ecosistema funcional.

---

## 1. Contexto

Con la llegada de **Homebrew 7.0.0 (13-sep-2026)**, el `installer package` de macOS pasó a ser **Apple Silicon only** y Homebrew dejó de construir *bottles* para Intel. En este equipo (Ventura + Intel) Homebrew quedó en **Tier 3**: corre, pero sin CI, sin binarios nuevos y con warnings fuertes; el propio `brew doctor` recomienda migrar a **MacPorts**. Por eso las dependencias se instalaron con `macports.org`, y ahí aparecieron los problemas descritos abajo.

Estado previo de Homebrew en el equipo:

- `brew --prefix` → `/usr/local`, pero `brew list` vacío y faltaban `/usr/local/Cellar`, `/Frameworks`, `/include`, `/lib`, `/opt`, `/sbin`, `/share`.
- `brew doctor` → warnings Tier 3 + CLT desactualizado + sugerencia de MacPorts.
- Vía MacPorts sí estaban: `tmux`, `neovim 0.12.4`, `ripgrep`, `fd`, `zoxide`, `lazygit`, `mise` (en `~/.local/bin`), `node 24`, `python 3.14`. Faltaban: `zsh-syntax-highlighting`, `zsh-autosuggestions`, `fzf`, `eza`, `bat`, `git-delta`, `gh`.

---

## 2. Problemas encontrados

### P1. `zsh-syntax-highlighting` y `zsh-autosuggestions` nunca cargaban
- No estaban instalados en MacPorts (`port installed` no los listaba).
- Aunque se instalaran, **`shell/plugins.zsh` nunca los habría encontrado**: el lookup cubría `$YADR_ZSH_*` explícito → `~/.local/share/yadr-plugins/` → `/usr/share/` (apt) → `$(brew --prefix)/share/`, pero **jamás `/opt/local/share/`** (MacPorts). El shell arrancaba degradado **en silencio** (`HL_MISSING`, `SG_MISSING`, sin `ZSH_HIGHLIGHT_HIGHLIGHTERS`, `Ctrl-E` sin bindear).
- `yadr doctor` no chequeaba estos plugins, así que reportaba todo en verde igual.

### P2. `~/.zprofile` frágil en Intel
- `eval "$(/usr/local/bin/brew shellenv)"` **incondicional**: falla/ruido si brew está roto o ausente, y no contemplaba el orden MacPorts-vs-brew ni `~/.local/bin` / `mise/shims` en login shells.

### P3. `fzf` de MacPorts sin integración
- `shell/zshrc` solo buscaba key-bindings en `/usr/share/fzf/`, `~/.fzf.zsh` y `$XDG_CONFIG_HOME/fzf/`. Las rutas de MacPorts (`/opt/local/share/fzf/...`) y el moderno `fzf --zsh` no estaban contemplados.

### P4. `platform/macos.sh` solo sabía de Homebrew
- `ensure_brew` + `brew install` directo, con fallback mínimo. En Intel Tier 3 `brew install` falla o compila desde fuente; no había ruta MacPorts, y el nombre del paquete `delta` (brew) vs **`git-delta`** (MacPorts) rompía la instalación 1:1.

### P5. `vim` abría Vim genuino, no Neovim
- `vim` → `/usr/bin/vim` (Vim 9.0 genuino), mientras `nvim` → `/opt/local/bin/nvim` 0.12.4 con toda la config/lazy. `nvim .zshrc` se veía completo; `vim .zshrc`, pelado.
- El `ensure_vim` existente solo vive en `platform/linux.sh` y está condicionado al marker `provides-nvim-upstream`, así que en macOS **nunca** crea el shim `~/.local/bin/vim`.

### P6. Bug en `yadr benchmark shell` (macOS/Bash 3.2)
- `now_ns()` usaba `date +%s%N`; en BSD `date` eso imprime `...N` literal (ej. `1791386783N`), el chequeo solo filtraba `%`, y la aritmética explotaba: `value too great for base`. El benchmark no corría.

### P7. Nerd Font instalada pero perfiles iTerm2 desalineados
- La fuente del manifest (`JetBrainsMono Nerd Font 3.5.1`, `terminal/fonts/manifest.env`) estaba bien instalada (`fc-list` la lista, doctor ✓). Pero el perfil `Default` usaba Monaco/Monaco con `Use Non-ASCII = 0` (glifos rotos) y `MasterDev` mezclaba `Monaco 15` + `JetBrainsMonoNFM-Regular 12` (tamaños distintos → powerline desalineado). Se quería **seguir usando Monaco** como fuente base.

---

## 3. Reparaciones aplicadas

> Todo verificado con ejecución, no solo lectura: `yadr doctor/diff/benchmark`, `zsh -i -c` con checks de funciones, `vim --version`, `bash -n`.

### R1. Plugins zsh (fix inmediato + robustez)
- Clonados sin sudo (ruta ya soportada por el lookup #2):
  - `~/.local/share/yadr-plugins/zsh-syntax-highlighting`
  - `~/.local/share/yadr-plugins/zsh-autosuggestions`
  - Resultado: `HL_OK`, `SG_OK`, `bindkey '^E' = autosuggest-accept`.
- `shell/plugins.zsh`: agregado `/opt/local/share/${subdir}/${file}` al lookup (entre apt y brew) + comentario Intel/Tier 3 con la alternativa de clon XDG.

### R2. `~/.zprofile` blindado (archivo de usuario, no del repo)
- `brew shellenv` con guarda (`[[ -x /usr/local/bin/brew ]]`, fallback a `command -v brew`).
- Preservado el bloque del instalador de MacPorts; agregados `~/.local/bin` y `mise/shims` al PATH sin duplicados.

### R3. `shell/zshrc`: fzf vía MacPorts
- Agregadas rutas `/opt/local/share/fzf/shell/key-bindings.zsh`, `/opt/local/share/fzf/shell/completion.zsh`, `/opt/local/share/fzf/key-bindings.zsh`, `/opt/local/share/fzf/completion.zsh` y `eval "$(fzf --zsh)"`, todo con guardas.

### R4. `platform/macos.sh`: fallback MacPorts
- Nuevo `PORT_PACKAGES` (mapea `delta` → `git-delta`).
- Nueva `install_via_macports()` (con clones XDG sin sudo como respaldo).
- `main()`: en Intel (`uname -m != arm64`) intenta MacPorts primero; si brew no está, continúa solo con MacPorts/XDG en vez de abortar.
- Nueva `ensure_vim_macos()` (ver R5), llamada en ambas ramas de `main()`.

### R5. `vim` → Neovim
- Creado `~/.local/bin/vim → /opt/local/bin/nvim` + marker `~/.local/state/yadr/provides-vim` (así `yadr uninstall` lo limpia). No se toca `/usr/bin/vim`; el shim gana por PATH.
- Doctor pasó de `vim genuine` a `✓ vim → Neovim (NVIM v0.12.4)`.

### R6. `bin/yadr`
- `now_ns()`: match por `case` contra `''|*%*|*N*|*[^0-9]*` con fallback a `python3 time.time_ns()` — benchmark shell vuelve a correr.
- `doctor`: nuevos checks **advisory** (warn, no fail) para `zsh-syntax-highlighting` y `zsh-autosuggestions` en XDG, `/opt/local`, `/usr/share` y brew.

### R7. iTerm2 (config manual del usuario, verificada)
- `MasterDev` quedó en `Monaco 15` + `JetBrainsMonoNFM-Regular 15` con `Use Non-ASCII = 1` (variante Mono, no Propo). Línea de prueba `    ± ✓ →` renderiza completa y captura de nvim muestra statusline powerline continua. `Default` sigue en Monaco sin fallback (solo importa si se usa ese perfil).

### Paquetes instalados por el usuario (punto 1, con `sudo port install`)
`zsh-syntax-highlighting`, `zsh-autosuggestions`, `fzf 0.74.4`, `eza`, `bat 0.26.1`, `git-delta 0.20.1`, `gh 2.102.0` — todos activos y en PATH; `ls=eza`, `cat=bat` confirmados.

---

## 4. Estado final verificado

- `yadr doctor`: **0 errores, 0 avisos** (antes: 0 errores, 1 aviso por Nerd Font).
- `yadr diff`: 0 con cambios; symlinks intactos (`.zshrc`, `.gitconfig`, `.tmux.conf`, `nvim`, `mise.toml`, `yadr`).
- `zsh -i -c`: `HL_OK`, `SG_OK`, `^E` bindeado.
- `zsh -l -i -c`: `tmux/rg/fd/zoxide/mise/nvim` en PATH; `vim --version` → `NVIM v0.12.4`.
- `benchmark prompt`: 0 ms/render fuera y dentro de git. `benchmark shell`: ~700 ms (sobre el umbral 500 ms; desglose medido: base 0.03 s, `mise activate` 0.18 s, plugins 0.06 s, `compinit` frío 2.1 s — costo del hardware Intel + `mise`, no regresión de YADR; se deja como informativo).
- `nvim --headless +qa`: limpio, plugins en lockfile.

---

## 5. Pendientes / sugerencias upstream

1. **Soporte Intel documentado:** `INSTALL-YADR.md`/`README` asumen brew funcional en macOS. Sugerencia: detectar Intel/Tier 3 y guiar a MacPorts (o al clon XDG sin sudo) como hace ahora el `macos.sh` parcheado.
2. **Mapeo de nombres MacPorts:** `delta` → `git-delta` (y revisar `fd`, `mise`, etc. según disponibilidade de bottles Intel).
3. **Doctor:** los checks de plugins zsh agregados aquí podrían subir upstream tal cual (advisory, portables).
4. **`~/.gitconfig.user`:** en este equipo no se creó (dato personal, opcional); git usa el placeholder `YADR User / user@example.com` hasta que el usuario lo defina.
5. **iTerm2:** documentar el patrón Monaco + Nerd Mono como Non-ASCII activado, mismo puntaje, variante Mono (no Propo), para quien no quiera cambiar su fuente base.

---

*Reporte generado el 7-oct-2026 a partir de diagnóstico y verificación por ejecución en el equipo descrito.*
