#!/bin/bash

echo "Silakan pilih skrip yang ingin anda jalankan:"
echo "1. clone.sh"
echo "2. install-aml.sh"
echo -n "Masukkan pilihan Anda (1 atau 2): "
read choice

case "$choice" in
    1)
        echo "Menjalankan skrip clone.sh..."
        chmod +x "./tools/clone.sh"  # Memberikan izin eksekusi pada skrip
        "./tools/clone.sh"  # Memanggil skrip dari direktori /tools/
        ;;
    2)
        echo "Menjalankan skrip install-aml.sh..."
        chmod +x "./tools/install-aml.sh"  # Memberikan izin eksekusi pada skrip
        "./tools/install-aml.sh"  # Memanggil skrip dari direktori /tools/
        ;;
    *)
        echo "Pilihan tidak valid. Silakan masukkan 1 atau 2."
        exit 1
        ;;
esac

echo "Selesai."
