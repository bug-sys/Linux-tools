#!/bin/bash

set -e

# Fungsi untuk menampilkan daftar disk yang tersedia
daftar_disk() {
    lsblk -d -o NAME,SIZE,TYPE | grep 'disk'
}

# Fungsi untuk memformat partisi
format_partisi() {
    local dev=$1
    local size_boot=$2
    local size_root=$3
    local label_boot=$4
    local label_root=$5

    echo "Memulai pembuatan MBR dan partisi pada $dev"
    parted -s "$dev" mklabel msdos
    parted -s "$dev" mkpart primary fat32 1M "$size_boot"
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
echo -e "\033[36m       Toolkit clone linux by SUIJUNG\033[0m"
echo -e "\033[32m*****************************************************\033[0m"
echo "Daftar disk yang tersedia:"
daftar_disk

echo -e "\033[33m"
read -p "Pilih disk yang akan digunakan (Contoh: /dev/sda): " chosen_disk
echo -e "\033[0m"
# Validasi pilihan disk dengan menggunakan ekspresi reguler
if ! [[ $chosen_disk =~ ^/dev/[a-z]{3}$ ]]; then
    echo -e "\033[31mPilihan disk tidak valid. Format yang diharapkan: /dev/sdX atau /dev/mmcblkX\033[0m"
    exit 1
fi

echo -e "\033[33m"
read -p "Masukkan ukuran partisi BOOT (Contoh: 50M): " size_boot
read -p "Masukkan ukuran partisi ROOT (Contoh: 1M sd 100%): " size_root

read -p "Masukkan label untuk partisi BOOT (Contoh: BOOT): " label_boot
read -p "Masukkan label untuk partisi ROOT (Contoh: ROOTFS / EMMC_ROOT): " label_root
echo -e "\033[0m"

format_partisi "$chosen_disk" "$size_boot" "$size_root" "$label_boot" "$label_root"
klon_sistem "$chosen_disk" "$label_boot" "$label_root"

echo "Mengupdate fstab..."
BOOT_UUID=$(blkid -s UUID -o value "${chosen_disk}1")
ROOT_UUID=$(blkid -s UUID -o value "${chosen_disk}2")
sed -i "s|^UUID=[^ ]* /boot|UUID=${BOOT_UUID} /boot|" /ddbr/clone/etc/fstab
sed -i "s|^UUID=[^ ]* /|UUID=${ROOT_UUID} /|" /ddbr/clone/etc/fstab
sync

umount $DIR_CLONE

echo "Menghapus direktori /ddbr..."
rm -rf /ddbr

echo -e "\033[32m*****************************************************"
echo -e "\033[36m        Cloning Linux Berhasil!\033[0m"
echo -e "\033[32m*****************************************************"
