#!/bin/bash
set -e

# Fungsi untuk menampilkan daftar disk yang tersedia
daftar_disk() {
    local disks=$(lsblk -d -o NAME,SIZE,TYPE | awk '/disk/ {print}')
    local i=1
    echo "$disks" | while read -r line; do
        echo "$i. $line"
        ((i++))
    done
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
    sync
    echo "Memformat partisi BOOT..."
    mkfs.vfat -n "$label_boot" "${dev}1"
    echo "selesai."
    echo "Memformat partisi ROOT..."
    mke2fs -F -q -t ext4 -L "$label_root" -m 0 "${dev}2"
    e2fsck -n "${dev}2"
    echo "selesai."
}

# Fungsi untuk mengkloning sistem ke partisi
klon_sistem() {
    local dev=$1
    local label_boot=$2
    local label_root=$3
    PART_BOOT="${dev}1"
    PART_ROOT="${dev}2"
    DIR_CLONE="/ddbr/clone"
    if [ -d $DIR_CLONE ] ; then
        rm -rf $DIR_CLONE
    fi
    mkdir -p $DIR_CLONE
    if grep -q $PART_BOOT /proc/mounts ; then
        echo "Melepaskan partisi BOOT."
        umount -f $PART_BOOT || true
    fi
    echo "Menyalin BOOT..."
    mount -o rw $PART_BOOT $DIR_CLONE
    cp -r /boot/* $DIR_CLONE && sync
    umount $DIR_CLONE
    if grep -q $PART_ROOT /proc/mounts ; then
        echo "Melepaskan partisi ROOT."
        umount -f $PART_ROOT || true
    fi
    echo "Menyalin ROOT..."
    mount -o rw $PART_ROOT $DIR_CLONE
    cp -r /{bin,etc,home,lib,lib64,opt,root,sbin,selinux,srv,usr,var} $DIR_CLONE
    mkdir -p $DIR_CLONE/{dev,media,mnt,proc,run,sys,tmp}
    sync
}

# Skrip utama
echo -e "\033[32m*****************************************************"
echo -e "\033[36m       Toolkit clone linux by bug-sys\033[0m"
echo -e "\033[32m*****************************************************\033[0m"
echo "Daftar disk yang tersedia: "
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

if ! [[ $size_root =~ ^[0-9]+[KMGT]%?$|^100%$ ]]; then
    echo -e "\033[31mError: Ukuran partisi ROOT tidak valid.\033[0m"
    exit 1
fi

format_partisi "/dev/$chosen_disk" "$start_boot" "$size_boot" "$size_root" "$label_boot" "$label_root"
klon_sistem "/dev/$chosen_disk" "$label_boot" "$label_root"

# Update fstab
echo "Mengupdate fstab..."
BOOT_UUID=$(blkid -s UUID -o value "${PART_BOOT}")
ROOT_UUID=$(blkid -s UUID -o value "${PART_ROOT}")
sed -i "s|^UUID=[^ ]* /|UUID=${ROOT_UUID} /|" $DIR_CLONE/etc/fstab
sed -i "s|^UUID=[^ ]* /boot|UUID=${BOOT_UUID} /boot|" $DIR_CLONE/etc/fstab
sync

umount $DIR_CLONE

echo "Menghapus direktori /ddbr..."
rm -rf /ddbr

echo -e "\033[32m*****************************************************"
echo -e "\033[36m        Cloning Linux Berhasil!\033[0m"
echo -e "\033[32m*****************************************************"
