#!/usr/bin/env bash
set -exuo pipefail

# Temporary commands until we figure out a method for deploying Docker images
apt-get update
apt-get dist-upgrade -y

# Create user
useradd user

# Set perms
chmod 777 * -R

# Get variables
pkgver="$(cat 'src/PKGBUILD' | grep '^pkgver=' | awk -F '=' '{print $2}')"

# Copy PKGBUILD
rm 'src/PKGBUILD'
cp "PKGBUILDs/LOCAL/${release_type^^}.PKGBUILD" "src/PKGBUILD"

# Configure PKGBUILD
sed -i "s|pkgver={pkgver}|pkgver=${pkgver}|" 'src/PKGBUILD'

# Build makedeb
cd src
sudo -u user -- './makedeb.sh' --nodeps
