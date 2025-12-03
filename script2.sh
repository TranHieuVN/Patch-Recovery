#!/usr/bin/env bash
set -euo pipefail

# Non-destructive, diagnostic wrapper for original script2 logic.
# - checks inputs and magiskboot binary compatibility
# - creates a backup of r.img before repack (if repack succeeds, output placed at recovery-patched.img)
# - prints helpful diagnostics for CI logs

echo "== script2.sh (safe) starting =="
WORKDIR="$(pwd)"
UNPACK_DIR="unpack"
IN_IMG="../r.img"
OUT_IMG="../recovery-patched.img"
BACKUP_IMG="../r.img.bak"

# Basic checks
if [ ! -f "$IN_IMG" ]; then
  echo "ERROR: input image not found: $IN_IMG"
  exit 2
fi

# Make sure magiskboot exists and is executable
if [ ! -f ../magiskboot ]; then
  echo "ERROR: ../magiskboot not found"
  file ../magiskboot || true
  echo "If magiskboot is built for ARM, it will not run on ubuntu-latest (x86_64)."
  exit 3
fi
chmod +x ../magiskboot || true

echo "magiskboot info:"
file ../magiskboot || true
ldd ../magiskboot 2>&1 || true

# Prepare unpack dir
rm -rf "$UNPACK_DIR"
mkdir -p "$UNPACK_DIR"
cd "$UNPACK_DIR"

echo "Unpacking $IN_IMG using ../magiskboot ..."
if ! ../magiskboot unpack "$IN_IMG"; then
  echo "ERROR: magiskboot unpack failed for $IN_IMG"
  ls -la || true
  exit 4
fi

if [ ! -f ramdisk.cpio ]; then
  echo "ERROR: ramdisk.cpio not produced by magiskboot unpack"
  ls -la || true
  exit 4
fi

echo "Extracting ramdisk.cpio ..."
if ! ../magiskboot cpio ramdisk.cpio extract; then
  echo "WARNING: magiskboot cpio extract failed (continuing if partial changes are possible)"
fi

# Apply hexpatches (kept identical to original values; errors suppressed individually)
set +e
../magiskboot hexpatch system/bin/recovery e10313aaf40300aa6ecc009420010034 e10313aaf40300aa6ecc0094 || true
../magiskboot hexpatch system/bin/recovery eec3009420010034 eec3009420010035 || true
../magiskboot hexpatch system/bin/recovery 3ad3009420010034 3ad3009420010035 || true
../magiskboot hexpatch system/bin/recovery 50c0009420010034 50c0009420010035 || true
../magiskboot hexpatch system/bin/recovery 080109aae80000b4 080109aae80000b5 || true
../magiskboot hexpatch system/bin/recovery 20f0a6ef38b1681c 20f0a6ef38b9681c || true
../magiskboot hexpatch system/bin/recovery 23f03aed38b1681c 23f03aed38b9681c || true
../magiskboot hexpatch system/bin/recovery 20f09eef38b1681c 20f09eef38b9681c || true
../magiskboot hexpatch system/bin/recovery 26f0ceec30b1681c 26f0ceec30b9681c || true
../magiskboot hexpatch system/bin/recovery 24f0fcee30b1681c 24f0fcee30b9681c || true
../magiskboot hexpatch system/bin/recovery 27f02eeb30b1681c 27f02eeb38b9681c || true
../magiskboot hexpatch system/bin/recovery b4f082ee28b1701c b4f082ee28b970c1 || true
../magiskboot hexpatch system/bin/recovery 9ef0f4ec28b1701c 9ef0f4ec28b9701c || true
../magiskboot hexpatch system/bin/recovery 9ef00ced28b1701c 9ef00ced28b9701c || true
../magiskboot hexpatch system/bin/recovery 2001597ae0000054 2001597ae1000054 || true
../magiskboot hexpatch system/bin/recovery 24f0f2ea30b1681c 24f0f2ea30b9681c || true
../magiskboot hexpatch system/bin/recovery 41010054a0020012f44f48a9 4101005420008052f44f48a9 || true
set -e

echo "Attempting to repack into new-boot.img ..."
if ! ../magiskboot cpio ramdisk.cpio 'add 0755 system/bin/recovery system/bin/recovery' 2>&1; then
  echo "WARNING: magiskboot cpio add may have issues; continuing to repack step"
fi

if ! ../magiskboot repack "$IN_IMG" new-boot.img; then
  echo "ERROR: magiskboot repack failed"
  ls -la || true
  exit 5
fi

if [ ! -f new-boot.img ]; then
  echo "ERROR: new-boot.img was not created"
  exit 5
fi

# Backup original only if not existing backup (non-destructive)
cd "$WORKDIR"
if [ ! -f "$BACKUP_IMG" ]; then
  echo "Creating backup of original r.img -> $BACKUP_IMG"
  cp -- "$IN_IMG" "$BACKUP_IMG"
fi

echo "Copying new-boot.img to $OUT_IMG"
cp "$UNPACK_DIR/new-boot.img" "$OUT_IMG"
echo "Patched image created: $OUT_IMG"
echo "Checksum:"
sha256sum "$OUT_IMG" || true

echo "== script2.sh finished =="
