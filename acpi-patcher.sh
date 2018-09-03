#!/bin/bash

wdir=./cpio
patch_url="https://delta-xi.net/download/X1C6_S3_DSDT.patch"
patch_fname="X1C6_S3_DSDT.patch"
iasl=`which iasl`
cpio=`which cpio`
grub_conf_file=/etc/grub.d/10_linux
grub_overrides_file="${wdir}/grub_changes"
prefix=$'\u2605 '

if [ ! -x "$iasl" ]; then
    echo "iasl: command not found. Tip: \`sudo apt install acpica-tools\`"
    exit 1
fi
if [ ! -x "$cpio" ]; then
    echo "cpio: command not found. Tip: \`sudo apt install cpio\`"
    exit 1
fi

if [ ! -d "$wdir" ]; then
	mkdir $wdir || (echo "Unable to create working directory"; exit 1)
fi

echo ""
echo -n "$prefix Locating patch file... "
if [ -f "$patch_fname" ]; then
    cp -f "$patch_fname" "$wdir" || (echo "Unable to copy patch file"; exit 1)
    echo "OK! Found on disk."
else
    echo -n "Downloading.. "
    wget -q -O - "$patch_url" > "$wdir/$patch_fname" || (echo "Unable to fetch patch"; exit 1)
    echo "OK!"
fi

echo ""
echo "$prefix Disassembling ACPI dsdt table..."
sudo cat /sys/firmware/acpi/tables/DSDT > "$wdir/dsdt.aml"
$iasl -d "$wdir/dsdt.aml" || (echo "Unable to disassemble dsdt file. Exit code: ${?}"; exit 1)

echo ""
echo "$prefix Applying patch to dsdt.aml..."
patch -d $wdir < "$wdir/$patch_fname" || (echo "Couldn't apply the patch. Please investigate manually"; exit 1)

echo ""
echo "$prefix Creating hex AML table file..."
$iasl -ve -tc "$wdir/dsdt.dsl" || (echo "Failed"; exit 1)

echo ""
echo "$prefix Creating acpi_override file using cpio"
mkdir -p "$wdir/kernel/firmware/acpi"
cp "$wdir/dsdt.aml" "$wdir/kernel/firmware/acpi/"
find "$wdir/kernel" | $cpio -H newc --create > "$wdir/acpi_override" || (echo "cpio failed"; exit 1)

echo ""
echo "$prefix Copying the acpi_override file to /boot"
sudo cp "$wdir/acpi_override" /boot/ || (echo "Couldn't copy acpi_override to /boot/"; exit 1)

echo ""
echo -n "$prefix Attempting to patch grub config initrd line(s). Trying preferred method (${grub_conf_file})... "
touch "$grub_overrides_file"

if [ -f "$grub_conf_file" ]; then
    echo "OK!"
    echo -n "$prefix Patching '${grub_conf_file}' initrd line... "
    pat="(^[\t ]+initrd[\t])(\\$\{rel_dirname\}\/\\$\{initrd\})"
    sudo sed -i -E "s/${pat@E}/\1\${rel_dirname}\/acpi_override \2/w ${grub_overrides_file}" $grub_conf_file
else
    echo "Failed"
    echo "Using alternate method (/boot/grub/grub.cfg)"
    echo "NOTE: This method is not permanent!"
    echo "      The patch must be re-applied after grub config generation (grub-mkconfig/update-grub etc)"
    echo -n "$prefix Patching 'grub.cfg' initrd line... "
    pat="(initrd[\t])(\\\/boot\/initrd.img-$(uname -r))"
    sudo sed -i -E "s/${pat@E}/\1\/boot\/acpi_override \2/w ${grub_overrides_file}" /boot/grub/grub.cfg
fi

if [ -s "$grub_overrides_file" ]; then
    echo "OK!"
    echo "Changed lines:"
    cat "$grub_overrides_file"
else
    echo "No changes made. Please inspect the grub config manually"
fi
rm "$grub_overrides_file"

echo ""
echo "Done."

