# Entorno de desarrollo

Cómo dejar la máquina en condiciones de correr `make test`. Si eso no corre, no
hay forma de verificar nada y no se puede dar ningún cambio por terminado (ver
la regla de oro en `CLAUDE.md`).

Hacen falta tres cosas:

| Qué | Para qué |
|---|---|
| **cc65** (`ca65` + `ld65`) | Ensamblar y linkear la ROM |
| **GNU make** | Correr el Makefile |
| **Python 3** + `requirements.txt` | El emulador headless de los tests y las capturas |

Para saber qué te falta:

```bash
make tools
```

Te dice qué encontró y con qué versión, o qué falta y cómo instalarlo.

---

## Linux (Debian/Ubuntu)

```bash
sudo apt install cc65 make python3-pip
pip install -r requirements.txt
```

## macOS

```bash
brew install cc65 make
pip3 install -r requirements.txt
```

## Windows

El proyecto asume herramientas Unix, así que **los comandos se corren desde Git
Bash**, no desde PowerShell ni `cmd`. Git Bash viene con
[Git para Windows](https://git-scm.com/download/win).

### 1. cc65

No hay instalador ni paquete de winget: es un ZIP con los binarios ya
compilados. Bajar el snapshot de Windows y descomprimirlo:

```bash
curl -sL -o /tmp/cc65.zip \
  https://sourceforge.net/projects/cc65/files/cc65-snapshot-win32.zip/download
unzip -q /tmp/cc65.zip -d "$LOCALAPPDATA/cc65"
```

Después hay que agregar `%LOCALAPPDATA%\cc65\bin` al PATH del usuario. Desde
PowerShell, una sola vez:

```powershell
$cc65 = "$env:LOCALAPPDATA\cc65\bin"
[Environment]::SetEnvironmentVariable(
    "Path", [Environment]::GetEnvironmentVariable("Path","User") + ";$cc65", "User")
```

Si preferís no tocar el PATH, el Makefile acepta la ruta directo:

```bash
make CC65_BIN="$LOCALAPPDATA/cc65/bin"
```

### 2. GNU make

```powershell
winget install ezwinports.make
```

Ojo con la alternativa `GnuWin32.Make`: es la 3.81, de 2006, y le faltan cosas.
La de ezwinports es la 4.4.1.

### 3. Python

Instalar Python 3 desde [python.org](https://www.python.org/downloads/) (no el
del Microsoft Store) y después:

```bash
make deps
```

**Los dos primeros pasos modifican el PATH, así que hay que cerrar y volver a
abrir la terminal** antes de que `make` los vea.

### La trampa del `python3` de Windows

Windows trae un alias `python3.exe` en `WindowsApps` que no es Python: es un
stub que abre el Microsoft Store. Está en el PATH y responde a `command -v`,
pero cualquier cosa que le pidas ejecutar falla con código 49.

Por eso el Makefile no busca el intérprete: lo **prueba**, corriendo
`python -c ''` sobre cada candidato (`python3`, `python`, `py`) y quedándose con
el primero que realmente arranca. Si alguna vez ves que `make` elige un Python
raro, `make tools` te muestra cuál agarró.

---

## Versiones verificadas

Esta combinación está probada de punta a punta (compila, `make test` da todo
verde y `make shots` saca las capturas):

- cc65 V2.19 (Git 547d923)
- GNU make 4.4.1
- Python 3.14.6
- nes-py 9.0.1, numpy 2.5.1, pillow 12.3.0

`nes-py` **solo soporta los mappers 0, 1, 2 y 3**. Es la razón por la que el
cartucho es MMC1 y no MMC3: con MMC3 la ROM no abre en el emulador y se pierden
`make test` y `make shots`.
