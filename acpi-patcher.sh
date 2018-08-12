#!/bin/bash

wdir=./cpio
patch_url="https://delta-xi.net/download/X1C6_S3_DSDT.patch"
patch_fname="X1C6_S3_DSDT.patch"
iasl=`which iasl`
cpio=`which cpio`

if [ ! -x "$iasl" ]; then
    echo "iasl: command not found. Tip: \`sudo apt install acpica-tools\`"
    exit 1
fi
if [ ! -x "$cpio" ]; then
    echo "cpio: command not found. Tip: \`sudo apt install cpio\`"
    exit 1
fi


if [ ! -d "$wdir" ]; then
    mkdir $wdir || echo "Unable to create working directory"; exit 1
fi

if [ -f "$patch_fname" ]; then
    cp -f "$patch_fname" "$wdir" || (echo "Unable to copy patch file"; exit 1)
else
    wget -O - "$patch_url" > "$wdir/$patch_fname" || (echo "Unable to fetch patch"; exit 1)
fi

sudo cat /sys/firmware/acpi/tables/DSDT > "$wdir/dsdt.aml"
$iasl -d "$wdir/dsdt.aml"
patch -d $wdir < "$wdir/$patch_fname"
$iasl -ve -tc "$wdir/dsdt.dsl"
mkdir -p "$wdir/kernel/firmware/acpi"
cp "$wdir/dsdt.aml" "$wdir/kernel/firmware/acpi/"
find "$wdir/kernel" | $cpio -H newc --create > "$wdir/acpi_override"
sudo cp "$wdir/acpi_override" /boot/

pat="(initrd[\t])(\\\/boot\/initrd.img-$(uname -r))"
sudo sed -i -E "s/${pat@E}/\1\/boot\/acpi_override \2/" /boot/grub/grub.cfg

echo "Success"

