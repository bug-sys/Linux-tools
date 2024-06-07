#!/bin/bash

# Fungsi untuk menampilkan daftar disk yang tersedia
daftar_disk() {
    lsblk -d -o NAME,SIZE,TYPE | awk '/disk/ {print}'
}

# Fungsi untuk memformat partisi
format_partisi() {
    local dev=$1
    local start_boot=$2
    local size_boot=$3
    local size_root=$4
    local label_boot=$5
    local label_root=$6

    echo "Memulai pembuatan MBR dan partisi pada $dev"
    parted -s "$dev" mklabel msdos
    parted -s "$dev" mkpart primary fat32 "$start_boot" "$size_boot"
    parted -s "$dev" mkpart primary ext4 "$size_boot" "$size_root"

    echo "Memformat partisi BOOT..."
    mkfs.vfat -n "$label_boot" "${dev}1"
    echo "Proses format partisi BOOT selesai."

    echo "Memformat partisi ROOT..."
    mke2fs -F -q -t ext4 -L "$label_root" -m 0 "${dev}2"
    e2fsck -n "${dev}2"
    echo "Proses format partisi ROOT selesai."
}

# Fungsi untuk mengkloning sistem ke partisi
klon_sistem() {
    local dev=$1
    local label_boot=$2
    local label_root=$3

    PART_BOOT="${dev}1"
    PART_ROOT="${dev}2"
    DIR_CLONE="/ddbr/clone"

    rm -rf "$DIR_CLONE" || true
    mkdir -p "$DIR_CLONE"

    if grep -q "$PART_BOOT" /proc/mounts ; then
        echo "Melepaskan partisi BOOT."
        umount "$PART_BOOT" || true
    fi

    echo "Menyalin BOOT..."
    mount "$PART_BOOT" "$DIR_CLONE"
    echo "Proses penyalinan BOOT dimulai."
    cp -a /boot/. "$DIR_CLONE"
    echo "Proses penyalinan BOOT selesai."
    umount "$DIR_CLONE"
    echo "Partisi BOOT dilepas."

    if grep -q "$PART_ROOT" /proc/mounts ; then
        echo "Melepaskan partisi ROOT."
        umount "$PART_ROOT" || true
    fi

    echo "Menyalin ROOT..."
    mount "$PART_ROOT" "$DIR_CLONE"
    echo "Proses penyalinan ROOT dimulai."
    cp -a /{bin,etc,home,lib,lib64,opt,root,sbin,selinux,srv,usr,var} "$DIR_CLONE"
    mkdir -p "$DIR_CLONE"/{dev,media,mnt,proc,run,sys,tmp}
    echo "Proses penyalinan ROOT selesai."
    umount "$DIR_CLONE"
    echo "Partisi ROOT dilepas."
}

# Skrip utama
echo -e "\033[32m*****************************************************"
echo -e "\033[36m       Toolkit clone linux by SUIJUNG\033[0m"
echo -e "\033[32m*****************************************************\033[0m"
echo "Daftar disk yang tersedia:"
daftar_disk

echo -e "\033[33m"
read -p "Pilih nomor disk yang akan digunakan: " disk_number
echo -e "\033[0m"

# Validasi nomor disk yang dipilih
if ! [[ $disk_number =~ ^[0-9]+$ ]]; then
    echo -e "\033[31mError: Pilihan disk tidak valid. Harap masukkan nomor disk yang valid.\033[0m"
    exit 1
fi

# Mendapatkan nama disk berdasarkan nomor yang dipilih
chosen_disk=$(lsblk -d -n -o NAME | sed -n "${disk_number}p")

if [ -z "$chosen_disk" ]; then
    echo -e "\033[31mError: Disk dengan nomor yang dipilih tidak ditemukan.\033[0m"
    exit 1
fi

echo -e "\033[33m"
read -p "Masukkan ukuran mulai partisi BOOT (Contoh: 200M): " start_boot
read -p "Masukkan ukuran akhir partisi BOOT (Contoh: 250M): " size_boot
read -p "Masukkan ukuran partisi ROOT (Contoh: 1000M sd 100%): " size_root
read -p "Masukkan label untuk partisi BOOT (Contoh: BOOT): " label_boot
read -p "Masukkan label untuk partisi ROOT (Contoh: ROOTFS): " label_root
echo -e "\033[0m"

# Validasi input ukuran partisi
if ! [[ $start_boot =~ ^[0-9]+[KMGT]$ ]]; then
    echo -e "\033[31mError: Ukuran awal partisi BOOT tidak valid.\033[0m"
    exit 1
fi

if ! [[ $size_boot =~ ^[0-9]+[KMGT]$ ]]; then
    echo -e "\033[31mError: Ukuran partisi BOOT tidak valid.\033[0m"
    exit 1
fi

if ! [[ $size_root =~ ^[0-9]+[KMGT]%?$ ]]; then
    echo -e "\033[31mError: Ukuran partisi ROOT tidak valid.\033[0m"
    exit 1
fi

format_partisi "$chosen_disk" "$start_boot" "$size_boot" "$size_root" "$label_boot" "$label_root"
klon_sistem "$chosen_disk" "$label_boot" "$label_root"

echo "Mengupdate fstab..."
PART_BOOT="/dev/${chosen_disk}1"
PART_ROOT="/dev/${chosen_disk}2"
BOOT_UUID=$(blkid -s UUID -o value "$PART_BOOT")
ROOT_UUID=$(blkid -s UUID -o value "$PART_ROOT")

# Tentukan urutan penggantian UUID yang benar
DIR_CLONE="/ddbr/clone"
if grep -q "/boot" "$DIR_CLONE/etc/fstab"; then
    # Entri /boot ada, jadi tukar urutannya
    sed_order="s|^UUID=[^ ]* /boot|UUID=${BOOT_UUID} /boot|;s|^UUID=[^ ]* /|UUID=${ROOT_UUID} /|"
else
    # Entri /boot tidak ada, maka pertahankan urutan aslinya
    sed_order="s|^UUID=[^ ]* /|UUID=${ROOT_UUID} /|;s|^UUID=[^ ]* /boot|UUID=${BOOT_UUID} /boot|"
fi

# Jalankan perintah sed dengan urutan yang ditentukan
sed -i -e "$sed_order" "$DIR_CLONE/etc/fstab"

umount "$DIR_CLONE"

echo "Menghapus direktori /ddbr..."
rm -rf /ddbr

echo -e "\033[32m*****************************************************"
echo -e "\033[36m        Cloning Linux Berhasil!\033[0m"
echo -e "\033[32m*****************************************************"
