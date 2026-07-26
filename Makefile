## Gran Premio NES - build
## Requiere: cc65 (ca65 + ld65) y python3

ROM    := build/colapinto.nes
CHR    := build/game.chr
OBJ    := build/main.o
LABELS := build/labels.txt

.PHONY: all run test shots clean

all: $(ROM)

$(ROM): $(OBJ) src/nes-mmc1.cfg
	ld65 -C src/nes-mmc1.cfg $(OBJ) -o $(ROM) -Ln $(LABELS)
	@echo "--> $(ROM) ($$(stat -c%s $(ROM)) bytes)"

$(OBJ): src/main.s $(CHR)
	@mkdir -p build
	ca65 src/main.s -o $(OBJ)

$(CHR): src/makechr.py
	@mkdir -p build
	python3 src/makechr.py $(CHR)

## Corre el emulador headless y saca capturas a build/shots/
shots: $(ROM)
	python3 tools/shots.py

## Compila + verifica que el juego avanza (vueltas, meta, colisiones)
test: $(ROM)
	python3 tools/probe.py

## Abre la ROM en un emulador de escritorio si lo tenes instalado
run: $(ROM)
	@which mesen  >/dev/null 2>&1 && exec mesen  $(ROM) || true
	@which fceux  >/dev/null 2>&1 && exec fceux  $(ROM) || true
	@echo "No encontre mesen ni fceux. Abri $(ROM) a mano."

clean:
	rm -rf build
