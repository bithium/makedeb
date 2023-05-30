#!/usr/bin/env bash
set -euo pipefail

depends=(
	'apt'
	'binutils'
	'build-essential'
	'curl'
	'fakeroot'
	'file'
	'gettext'
	'gawk'
	'libarchive-tools'
	'lsb-release'
	'python3'
	'python3-apt'
	'zstd'
)
error() {
	echo "ERROR: ${*}"
}

# BEGIN PROGRAM
cd "$(git rev-parse --show-toplevel)"

# Make sure needed variables are set.
failed_checks=0

for var in TARGET RELEASE; do
	if [[ "${!var:+x}" == '' ]]; then
		error "Variable '${var}' isn't set."
		failed_checks=1
	fi
done

# Make sure needed software is installed.
for prgm in jq; do
	if ! type -t "${prgm}" 1> /dev/null; then
		error "Program '${prgm}' isn't installed."
		failed_checks=1
	fi
done

if (( "${failed_checks}" )); then
	exit 1
fi

# Get needed variables.
new_pkgver="$(jq -r '.current_pkgver' .data.json)"
repo_short=$(git config --get remote.origin.url | sed -e 's|^.\+github\.com[/:]||' -e 's|\.git$||' )
repo_user=${repo_short%%/makedeb}
repo="https://github.com/${repo_short}.git"
releases="$(curl -s -S "https://api.github.com/repos/${repo_short}/releases?per_page=100" | jq -r '.[].name')"
if [[ -z "${releases}" ]]; then
	releases="$(curl -s -S "https://api.github.com/repos/${repo_short}/tags?per_page=100" | jq -r '.[].name')"
fi

case "${RELEASE}" in
	stable)
		pkgname='makedeb'
		release="$(echo "${releases}" | grep 'v[0-9.-]*$')"
		;;
	beta|alpha|"${repo_user}")
		pkgname="makedeb-${RELEASE}"
		release="$(echo "${releases}" | grep "v[0-9.]*-${RELEASE}[0-9]*\$")"
		;;
	*)
		error "Invalid release '${RELEASE}'.";
		exit 1
		;;
esac

# Get the pkgver by checking the current latest pkgver for this release, and bumping it as necesary.
set +eo pipefail
current_pkgver="$(apt list "${pkgname}" 2> /dev/null | grep "^${pkgname}/" | awk '{print $2}' | grep -o '^[^-]*')"
current_pkgrel="$(apt list "${pkgname}" 2> /dev/null | grep "^${pkgname}/" | awk '{print $2}' | grep -o '[^-]*$')"
set -eo pipefail

if [[ "${new_pkgver}" != "${current_pkgver}" ]]; then
	new_pkgrel="${RELEASE}"
else
	declare -i pkgrel_norelease="$(echo "${current_pkgrel}" | grep -o '[0-9]*$')"
	pkgrel_norelease+=1
	new_pkgrel="${RELEASE}${pkgrel_norelease}"
fi

# Print out the generated PKGBUILD.
sed -e "s|{{ release }}|${RELEASE}|g" \
	-e "s|{{ target }}|${TARGET}|g" \
	-e "s|{{ pkgname }}|${pkgname}|g" \
	-e "s|{{ pkgver }}|${new_pkgver}|g" \
	-e "s|{{ pkgrel }}|${new_pkgrel}|g" \
	-e "s|^url=.\+|url=\'${repo}\'|" \
	PKGBUILD/TEMPLATE.PKGBUILD | {
		if [[ "${RELEASE}" == 'stable' ]]; then
			grep -Ev '^conflicts=|^provides='
		else
			cat
		fi
	} | {
		if [[ "${LOCAL:+x}" == '' ]]; then
			sed 's|{{ source }}|makedeb::git+${url}/#tag=v${pkgver}-${pkgrel}|g'
		else
			sed 's|{{ source }}|makedeb::git+file://$(git rev-parse --show-toplevel)|'
		fi
	}
