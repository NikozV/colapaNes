## Gran Premio NES - build
##
## Requiere cc65 (ca65 + ld65) y python3 con lo de requirements.txt. Si falta
## algo, cualquier target te lo dice y te explica como instalarlo en vez de
## reventar con "command not found". La receta por sistema esta en
## docs/entorno.md.
##
##   make          compila -> build/colapinto.nes
##   make test     corre la ROM en el emulador y verifica que el juego anda
##   make shots    capturas de cada pantalla -> build/shots/*.png
##   make tools    muestra que herramientas encontro y con que version
##   make deps     instala las dependencias de Python
##   make clean

ROM    := build/colapinto.nes
CHR    := build/game.chr
OBJ    := build/main.o
LABELS := build/labels.txt
CFG    := src/nes-mmc1.cfg

## --- Toolchain -------------------------------------------------------------
## Si cc65 esta instalado pero afuera del PATH:
##     make CC65_BIN=/ruta/a/cc65/bin
CC65_BIN ?=
ifeq ($(strip $(CC65_BIN)),)
  CA65 := ca65
  LD65 := ld65
else
  CA65 := $(CC65_BIN)/ca65
  LD65 := $(CC65_BIN)/ld65
endif

## En Windows 'python3' suele ser un stub del Microsoft Store: existe, esta en
## el PATH y no ejecuta nada (sale con codigo 49). Por eso no alcanza con
## buscarlo, hay que probar que corra de verdad.
PYTHON ?= $(shell for p in python3 python py; do \
              command -v $$p >/dev/null 2>&1 && $$p -c '' >/dev/null 2>&1 \
                  && { echo $$p; break; }; \
          done)

.PHONY: all run test shots clean tools deps check-tools check-emu

all: $(ROM)

$(ROM): $(OBJ) $(CFG) | check-tools
	$(LD65) -C $(CFG) $(OBJ) -o $(ROM) -Ln $(LABELS)
	@echo "--> $(ROM) ($$(wc -c < $(ROM)) bytes)"

$(OBJ): src/main.s $(CHR) | check-tools
	@mkdir -p build
	$(CA65) src/main.s -o $(OBJ)

$(CHR): src/makechr.py | check-tools
	@mkdir -p build
	$(PYTHON) src/makechr.py $(CHR)

## Corre el emulador headless y saca capturas a build/shots/
shots: $(ROM) | check-emu
	$(PYTHON) tools/shots.py

## Compila + verifica que el juego avanza (vueltas, meta, colisiones)
test: $(ROM) | check-emu
	$(PYTHON) tools/probe.py

## Abre la ROM en un emulador de escritorio si lo tenes instalado
run: $(ROM)
	@command -v mesen >/dev/null 2>&1 && exec mesen $(ROM) || true
	@command -v fceux >/dev/null 2>&1 && exec fceux $(ROM) || true
	@echo "No encontre mesen ni fceux. Abri $(ROM) a mano."

## Instala las dependencias de Python
deps:
	@[ -n "$(PYTHON)" ] || { echo "No encontre un python que funcione. Ver docs/entorno.md"; exit 1; }
	$(PYTHON) -m pip install -r requirements.txt

## Muestra que encontro y con que version
tools: check-tools
	@echo "  ca65     $$($(CA65) --version 2>&1)"
	@echo "  ld65     $$($(LD65) --version 2>&1)"
	@echo "  python   $(PYTHON) -> $$($(PYTHON) --version 2>&1)"
	@$(PYTHON) -c "import nes_py, numpy, PIL; \
	    print('  nes-py   ok (numpy ' + numpy.__version__ + ')')" 2>/dev/null \
	    || echo "  nes-py   FALTA -> make deps"

clean:
	rm -rf build

## --- Verificaciones --------------------------------------------------------

## Lo necesario para compilar. Va como prerequisito 'order-only' (|) para que
## corra siempre pero no invalide lo ya compilado.
check-tools:
	@missing=""; \
	command -v $(CA65) >/dev/null 2>&1 || missing="$$missing ca65"; \
	command -v $(LD65) >/dev/null 2>&1 || missing="$$missing ld65"; \
	[ -n "$(PYTHON)" ] || missing="$$missing python3"; \
	if [ -n "$$missing" ]; then \
	  echo ""; \
	  echo "  Faltan herramientas: $$missing"; \
	  echo ""; \
	  echo "    Debian/Ubuntu    sudo apt install cc65 make"; \
	  echo "    macOS            brew install cc65 make"; \
	  echo "    Windows          ver docs/entorno.md"; \
	  echo ""; \
	  echo "  Si cc65 ya esta instalado pero afuera del PATH:"; \
	  echo "    make CC65_BIN=/ruta/a/cc65/bin"; \
	  echo ""; \
	  exit 1; \
	fi

## Lo necesario para correr la ROM (test y shots)
check-emu:
	@$(PYTHON) -c "import nes_py, numpy, PIL" 2>/dev/null || { \
	  echo ""; \
	  echo "  Falta el emulador headless o sus dependencias."; \
	  echo ""; \
	  echo "    make deps"; \
	  echo ""; \
	  exit 1; \
	}
