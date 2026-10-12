# yumi-eq — CFFI-модуль Waybar. CC=gcc обязательно: ~/.local/bin/cc — скрипт центра управления, не компилятор.
CC = gcc
CFLAGS = -O2 -fPIC -Wall -Wextra $(shell pkg-config --cflags gtk+-3.0)
LIBS = $(shell pkg-config --libs gtk+-3.0) -lm
OUT = $(HOME)/.config/waybar/cffi/yumi-eq.so

$(OUT): yumi-eq.c waybar_cffi_module.h
	$(CC) $(CFLAGS) -shared -o $@.tmp yumi-eq.c $(LIBS) && mv -f $@.tmp $@

.PHONY: clean
clean:
	rm -f $(OUT)
