#!/bin/sh

# Fungsi untuk menampilkan daftar disk yang tersedia
daftar_disk() {
    lsblk -d -o NAME,SIZE,TYPE | awk '/disk/ {print}'
}

# Fungsi untuk memformat disk, membuat partisi, dan memulihkan u-boot
setup_disk() {
    echo "Mulai memformat disk, membuat partisi, dan memulihkan u-boot..."

    chosen_disk=$(lsblk -d -n -o NAME | sed -n "${disk_number}p")

    # Validasi disk yang dipilih
    if [ -z "$chosen_disk" ]; then
        echo -e "\033[31mError: Disk tidak ditemukan.\033[0m"
        exit 1
    fi

    # Memformat disk dengan sistem file ext4
    mkfs.ext4 -F $chosen_disk

    # Membuat label MBR dan partisi-partisi pada disk
    parted -s "${chosen_disk}" mklabel msdos
    parted -s "${chosen_disk}" mkpart primary fat32 700M 828M
    parted -s "${chosen_disk}" mkpart primary ext4 829M 100%

    # Membackup u-boot default dari disk
    dd if="${chosen_disk}" of=/boot/u-boot-default.img bs=1M count=4

    # Memulihkan u-boot yang telah dibackup ke disk
    dd if=/boot/u-boot-default.img of="${chosen_disk}" conv=fsync bs=1 count=442
    dd if=/boot/u-boot-default.img of="${chosen_disk}" conv=fsync bs=512 skip=1 seek=1
    sync

    echo "Selesai memformat disk dan memulihkan u-boot."
}

# Fungsi untuk menyalin sistem operasi ke partisi yang telah dibuat
copy_system() {
    echo "Mulai menyalin sistem operasi ke eMMC..."

    PART_BOOT="${chosen_disk}p1"
    PART_ROOT="${chosen_disk}p2"
    DIR_INSTALL="/ddbr/install"

    # Validasi direktori instalasi
    if [ ! -d "$DIR_INSTALL" ]; then
        mkdir -p $DIR_INSTALL
    fi

    # Memastikan partisi boot tidak ter-mount
    if mount | grep -q $PART_BOOT ; then
        umount -f $PART_BOOT
    fi

    # Memformat partisi boot sebagai FAT32
    echo -n "Memformat partisi BOOT..."
    mkfs.vfat -n "BOOT_EMMC" $PART_BOOT
    echo "selesai."

    # Mount partisi boot untuk menyalin file
    mount -o rw $PART_BOOT $DIR_INSTALL

    # Menyalin isi direktori /boot ke partisi boot
    echo -n "Menyalin BOOT..."
    cp -r /boot/* $DIR_INSTALL && sync
    echo "selesai."

    # Mengedit konfigurasi uEnv.ini
    echo -n "Mengedit konfigurasi init..."
    sed -e "s/ROOTFS/ROOT_EMMC/g" -i "$DIR_INSTALL/uEnv.ini"
    echo "selesai."

    # Membersihkan file yang tidak diperlukan
    rm -f $DIR_INSTALL/s9*
    rm -f $DIR_INSTALL/s8*
    rm -f $DIR_INSTALL/aml*

    # Unmount partisi boot
    umount $DIR_INSTALL
    sync

    echo "Selesai menyalin sistem operasi ke eMMC."
}

# Fungsi untuk menyelesaikan instalasi dengan membersihkan dan menyiapkan reboot
finalize_installation() {
    echo "Menyelesaikan instalasi dan menyiapkan untuk reboot..."

    # Membersihkan file-file yang tidak diperlukan
    rm $DIR_INSTALL/etc/fstab
    cp -a /root/install/fstab $DIR_INSTALL/etc/fstab

    rm $DIR_INSTALL/root/linux-tools/fstab
    rm $DIR_INSTALL/usr/bin/ddbr

    sync

    # Unmount direktori instalasi
    umount $DIR_INSTALL

echo "*******************************************"
echo -e '\033[36mInstalasi selesai,\033[33m Rebooting\033[0m'
echo "*******************************************"
    sleep 5
    reboot
}

# Skrip utama
echo -e "\033[32m*****************************************************"
echo -e "\033[36m  Toolkit Install armbian ke Internal by bug-sys\033[0m"
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

# Panggil fungsi untuk memformat disk, membuat partisi, dan memulihkan u-boot
setup_disk
copy_system
finalize_installation
