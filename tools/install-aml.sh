#!/bin/sh

# Fungsi untuk menampilkan daftar disk yang tersedia
daftar_disk() {
    lsblk -d -n -o NAME,SIZE,TYPE | awk '/disk/ {print NR ". " $1 "\t" $2 "\t" $3}'
}

# Fungsi untuk memformat disk, membuat partisi, dan memulihkan u-boot
setup_disk() {
    echo "Mulai memformat disk, membuat partisi, dan memulihkan u-boot..."

    # Menampilkan daftar disk tersedia
    daftar_disk

    echo "\033[33m"
    read -p "Pilih nomor disk yang akan digunakan: " disk_number
    echo "\033[0m"

    chosen_disk=$(lsblk -d -n -o NAME | sed -n "${disk_number}p")

    # Validasi disk yang dipilih
    if [ -z "$chosen_disk" ]; then
        echo "\033[31mError: Disk tidak ditemukan.\033[0m"
        exit 1
    fi

    # Memformat disk dengan sistem file ext4
    mkfs.ext4 -F "/dev/${chosen_disk}"

    # Membuat label MBR dan partisi-partisi pada disk
    parted -s "/dev/${chosen_disk}" mklabel msdos
    parted -s "/dev/${chosen_disk}" mkpart primary fat32 700M 828M
    parted -s "/dev/${chosen_disk}" mkpart primary ext4 829M 100%

    # Membackup u-boot default dari disk
    dd if="/dev/${chosen_disk}" of=/boot/u-boot-default.img bs=1M count=4

    # Memulihkan u-boot yang telah dibackup ke disk
    dd if=/boot/u-boot-default.img of="/dev/${chosen_disk}" conv=fsync bs=1 count=442
    dd if=/boot/u-boot-default.img of="/dev/${chosen_disk}" conv=fsync bs=512 skip=1 seek=1
    sync

    echo "Selesai memformat disk dan memulihkan u-boot."
}

# Fungsi untuk menyalin sistem operasi ke partisi yang telah dibuat
copy_system() {
    echo "Mulai menyalin sistem operasi ke eMMC..."

    PART_BOOT="/dev/${chosen_disk}p1"
    PART_ROOT="/dev/${chosen_disk}p2"
    DIR_INSTALL="/ddbr/install"

    # Validasi direktori instalasi
    if [ ! -d "$DIR_INSTALL" ]; then
        mkdir -p "$DIR_INSTALL"
    fi

    # Memastikan partisi boot tidak ter-mount
    if mount | grep -q "$PART_BOOT" ; then
        umount -f "$PART_BOOT"
    fi

    # Memformat partisi boot sebagai FAT32
    echo -n "Memformat partisi BOOT..."
    mkfs.vfat -n "BOOT_EMMC" "$PART_BOOT"
    echo "selesai."

    # Mount partisi boot untuk menyalin file
    mount -o rw "$PART_BOOT" "$DIR_INSTALL"

    # Menyalin isi direktori /boot ke partisi boot
    echo -n "Menyalin BOOT..."
    cp -r /boot/* "$DIR_INSTALL" && sync
    echo "selesai."

    # Mengedit konfigurasi uEnv.ini
    echo -n "Mengedit konfigurasi init..."
    sed -i "s/ROOTFS/ROOT_EMMC/g" "$DIR_INSTALL/uEnv.ini"
    echo "selesai."

    # Membersihkan file yang tidak diperlukan
    rm -f "$DIR_INSTALL"/s9*
    rm -f "$DIR_INSTALL"/s8*
    rm -f "$DIR_INSTALL"/aml*

    # Unmount partisi boot
    umount "$DIR_INSTALL"
    sync

    echo "Selesai menyalin sistem operasi ke eMMC."
}

# Fungsi untuk menyelesaikan instalasi dengan membersihkan dan menyiapkan reboot
finalize_installation() {
    echo "Menyelesaikan instalasi dan menyiapkan untuk reboot..."

    # Membersihkan file-file yang tidak diperlukan
    rm -f "$DIR_INSTALL/etc/fstab"
    cp -a /root/Linux-tools/fstab "$DIR_INSTALL/etc/fstab"

    rm -f "$DIR_INSTALL/root/Linux-tools/fstab"
    rm -f "$DIR_INSTALL/usr/bin/ddbr"

    sync

    # Unmount direktori instalasi
    umount "$DIR_INSTALL"

    echo "*******************************************"
    echo "\033[36mInstalasi selesai,\033[33m Rebooting\033[0m"
    echo "*******************************************"
    sleep 5
    reboot
}

# Skrip utama
echo "\033[32m*****************************************************"
echo "\033[36m  Toolkit Install armbian ke Internal by bug-sys\033[0m"
echo "\033[32m*****************************************************\033[0m"

# Memanggil fungsi untuk menampilkan daftar disk yang tersedia
echo "Daftar disk yang tersedia: "
daftar_disk

# Meminta pengguna untuk memilih nomor disk yang akan digunakan
echo "\033[33m"
read -p "Pilih nomor disk yang akan digunakan: " disk_number
echo "\033[0m"

# Validasi nomor disk yang dipilih
if ! [[ $disk_number =~ ^[0-9]+$ ]]; then
    echo "\033[31mError: Pilihan disk tidak valid. Harap masukkan nomor disk yang valid.\033[0m"
    exit 1
fi

# Panggil fungsi untuk memformat disk, membuat partisi, dan memulihkan u-boot
setup_disk
copy_system
finalize_installation
