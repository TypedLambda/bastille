#!/bin/sh
# https://pastebin.com/T6eThbKu

DEVICE_SELF_SCAN_ALL=NO
DIALOG_BACKTITLE="BastilleBSD"
DIALOG_TITLE="bootstrap"
[ "$_SCRIPT_SUBR" ] || . /usr/share/bsdconfig/script.subr
usage(){ echo "Usage: ${0##*/} [-r releaseName] [dists ...]" >&2; exit 1; }
while getopts hr: flag; do
	case "$flag" in
	r) releaseName="$OPTARG" ;;
	*) usage
	esac
done
shift $(( $OPTIND - 1 ))
nonInteractive=1
MEDIA_TIMEOUT=3 # because ftp.f.o has no SRV records
_ftpPath=ftp://ftp.freebsd.org
mediaSetFTP
mediaOpen
set -e
#debug=1
REL_DIST=/usr/local/bastille/cache/$releaseName
download() # $src to $dest
{
	size=$( f_device_get device_media "$1" $PROBE_SIZE )
	f_device_get device_media "$1" | dpv -kb "$DIALOG_BACKTITLE" \
		-t "$DIALOG_TITLE" -p "Downloading $releaseName" \
		-o "$3" "$size:$1"
}
sign() # $file
{
	dpv -kb "$DIALOG_BACKTITLE" -t "$DIALOG_TITLE" \
		-p "Signing $releaseName" -mx "sha256 >&2" \
		"$size:${1##*/}" "$1" 2>&1 >&$TERMINAL_STDOUT_PASSTHRU
}
mkdir -p $REL_DIST
MANIFEST=$REL_DIST/MANIFEST
download MANIFEST to $MANIFEST
dists="$*"
for dist in ${dists:-$( awk '$0=$4' $MANIFEST )}; do
	eval "$( awk -v dist=$dist '$4 == dist {
		print "distfile=" $1
		print "sig=" $2
		exit found = 1
	} END { exit ! found }' $MANIFEST )"
	destfile=$REL_DIST/$distfile
	download $distfile to $destfile
	[ "$( sign $destfile )" = $sig ] ||
		f_die "$distfile signature mismatch!"
done
f_dialog_info "All dists successfully downloaded/verified."