#!/bin/bash

# Path untuk file log
log_file="/var/log/script.log"

# Fungsi untuk logging
log() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $1" >> "$log_file"
}

# Fungsi untuk menampilkan menu utama menggunakan dialog
show_main_menu() {
    local scripts_dir="scripts"
    local scripts=($(find "$scripts_dir" -maxdepth 1 -type f -executable -printf "%f\n" | sort))

    dialog --backtitle "Main Menu" --cancel-label "Keluar" \
        --menu "Pilih operasi yang ingin dilakukan:" 15 60 $((${#scripts[@]} + 1)) \
        "${menu[@]}" \
        2>/tmp/menuchoice
}

# Fungsi untuk memberikan izin eksekusi jika belum ada
ensure_execution_permission() {
    local script_path="$1"
    if [[ ! -x "$script_path" ]]; then
        echo "Memberikan izin eksekusi pada $script_path..."
        chmod +x "$script_path"
    fi
}

# Fungsi untuk mengeksekusi skrip berdasarkan pilihan
execute_script() {
    local script_path="$1"
    
    # Memeriksa apakah skrip ada dan dapat dieksekusi
    if [[ ! -f "$script_path" ]]; then
        echo "Skrip $script_path tidak ditemukan."
        exit 1
    fi
    
    if [[ ! -x "$script_path" ]]; then
        echo "Memberikan izin eksekusi pada $script_path..."
        chmod +x "$script_path"
    fi
    
    # Menjalankan skrip
    if [[ -x "$script_path" ]]; then
        log "Menjalankan script: $script_path"
        ./"$script_path" 2>&1 | tee -a "$log_file"
    else
        echo "Gagal menjalankan operasi. Skrip tidak dapat dieksekusi."
        log "Gagal menjalankan script: $script_path"
    fi
}

# Fungsi untuk membersihkan file sementara setelah selesai
cleanup() {
    rm -f /tmp/menuchoice
}

# Pemanggilan fungsi cleanup di akhir skrip
trap cleanup EXIT

# Array untuk menyimpan daftar skrip yang dapat dijalankan (dihilangkan)
# Membuat menu dari daftar skrip (dihilangkan)

# Memanggil fungsi untuk menampilkan menu utama
show_main_menu

# Membaca pilihan dari file sementara (/tmp/menuchoice)
choice=$(cat /tmp/menuchoice)

# Menangani pilihan yang dipilih
if [[ ! $choice =~ ^[0-9]+$ ]]; then
    echo "Pilihan tidak valid. Keluar dari skrip."
    exit 1
fi

local scripts_dir="scripts"
local scripts=($(find "$scripts_dir" -maxdepth 1 -type f -executable -printf "%f\n" | sort))

if [[ $choice -ge 1 && $choice -le ${#scripts[@]} ]]; then
    execute_script "$scripts_dir/${scripts[$(($choice - 1))]}"
elif [[ $choice -eq ${#scripts[@]} + 1 ]]; then
    echo "Keluar dari skrip."
    exit 0
else
    echo "Pilihan tidak valid. Keluar dari skrip."
    exit 1
fi
