#!/bin/bash

# Fungsi untuk menampilkan pesan dialog
show_dialog() {
    echo "Silakan pilih skrip yang ingin anda jalankan:"
    echo "1. clone.sh"
    echo "2. install-aml.sh"
    echo -n "Masukkan pilihan Anda (1 atau 2): "
}

# Fungsi untuk menjalankan skrip berdasarkan pilihan
run_script() {
    local script_name="$1"
    echo "Menjalankan skrip $script_name..."
    chmod +x "/tools/$script_name"  # Memberikan izin eksekusi pada skrip
    "/tools/$script_name"  # Memanggil skrip dari direktori /tools/
}

# Meminta pengguna untuk memilih skrip
while true; do
    show_dialog
    read choice

    case "$choice" in
        1)
            run_script "clone.sh"
            break
            ;;
        2)
            run_script "install-aml.sh"
            break
            ;;
        *)
            echo "Pilihan tidak valid. Silakan masukkan 1 atau 2."
            ;;
    esac
done

echo "Selesai."
