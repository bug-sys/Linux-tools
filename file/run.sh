#!/bin/bash

# Kompilasi file .c menjadi file objek
gcc -c offsets.c -o offsets.o
gcc -c exploit.c -o exploit.o

# Menggunakan Python untuk menjalankan main.py
python main.py
