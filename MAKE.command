#!/bin/bash

PROGRAM="$(echo $0 | sed 's%.*/%%')"
PROGDIR="$(cd "$(dirname "$0")"; echo $PWD)"

set -e

trap cat *.log; "/bin/echo -n \"Something went wrong\"" EXIT

# # Point-release
RELEASE="5.2alpha"
SRC_IMAGE="Squeak5.2alpha-18184-64bit"
SRC_URL="http://files.squeak.org/${RELEASE}/${SRC_IMAGE}/${SRC_IMAGE}.zip"
# OR Trunk:
# RELEASE="Trunk"
# SRC_IMAGE="TrunkImage"
# SRC_URL="http://build.squeak.org/job/SqueakTrunk/lastSuccessfulBuild/artifact/target/${SRC_IMAGE}.zip"


CONFIGURE_SCRIPT="SwaImageConfiguration"
BASE="SWA2018"
NAME="SWA 2018"
############################################################
DIST_DIR="./dist"
CACHE_DIR="./_cache"
TMP_DIR="./_tmp"
AIO_DIR="${TMP_DIR}/aio"
ICON="Smalltalk"
IMAGE="${BASE}.image"
CHANGES="${BASE}.changes"
APP="${BASE}.app"
DMG="${BASE}.dmg"
LOG="_${BASE}.log"
E=/bin/echo
cd "$PROGDIR"

ann() {
    tput civis || true
    tput sc && tput hpa 0 && $E -n "$1" && tput rc || true
    tput cnorm || true
    $E ""
}
check() {
    EX="$?"
    if [ "$?" -eq 0 ]; then
        ann "[$(tput setaf 2) OK $(tput op)]"
    else
        ann "[$(tput setaf 9)FAIL$(tput op)]"
        tail $LOG
        exit $EX
    fi
}

$E "Start at $(date)" > $LOG


if [ \! -d "${CACHE_DIR}" ]; then
    mkdir "${CACHE_DIR}"

    if [ \! -f "${CACHE_DIR}/${SRC_IMAGE}.zip" ]; then
        $E -n "[....] $(tput setaf 4)Fetching ${SRC_IMAGE} $(tput op)"
        curl -o "${CACHE_DIR}/${SRC_IMAGE}.zip" "$SRC_URL" 2>>$LOG >>$LOG
        check
    fi

    if [ \! -f "${CACHE_DIR}/SqueakV50.sources.gz" ]; then
        $E -n "[....] $(tput setaf 4)Fetching sources $(tput op)"
        curl -o "${CACHE_DIR}/SqueakV50.sources.gz" http://ftp.squeak.org/sources_files/SqueakV50.sources.gz 2>>$LOG >>$LOG
        check
    fi

fi
if [ \! -d "${TMP_DIR}" ]; then
    mkdir "${TMP_DIR}"

    $E -n "[....] $(tput setaf 4)Extracting ${SRC_IMAGE} $(tput op)"
    ditto -xk "${CACHE_DIR}/${SRC_IMAGE}.zip" "${TMP_DIR}/"  2>>$LOG >>$LOG
    check

    $E -n "[....] $(tput setaf 4)Decompressing sources $(tput op)"
    gunzip -c "${CACHE_DIR}/SqueakV50.sources.gz" > "${TMP_DIR}/SqueakV50.sources" 2>>$LOG
    check

    $E -n "[....] $(tput setaf 6)Building image $(tput op)"
    CONFIG="$(ls -1t ${CONFIGURE_SCRIPT}* | tail -n 1)"
    ./TEMPLATE.app/Contents/MacOS/Squeak "${TMP_DIR}/${SRC_IMAGE}.image" "../${CONFIG}" "${PROGDIR}" "${BASE}" 2>>$LOG >>$LOG
    check

    if [ \! -f "${TMP_DIR}/${IMAGE}" ]; then
        $E "BUILD FAILED"
        exit 1
    fi
fi

if [ \! -d "${AIO_DIR}" ]; then
    mkdir "${AIO_DIR}"
    $E -n "[....] $(tput setaf 3)Building all-in-one $(tput op)"
    ditto -v  "./squeak.bat.tmpl" "${AIO_DIR}/squeak.bat"  2>>$LOG >>$LOG && \
    ditto -v  "./squeak.sh.tmpl" "${AIO_DIR}/squeak.sh"  2>>$LOG >>$LOG && \
    ditto -v TEMPLATE.app "${AIO_DIR}/${APP}"  2>>$LOG >>$LOG && \
    ./set_icon.py "${AIO_DIR}/${APP}/Contents/Resources/${ICON}.icns" "${TMP_DIR}/${IMAGE}"  2>>$LOG >>$LOG && \
    ditto -v "${TMP_DIR}/${IMAGE}" "${TMP_DIR}/${CHANGES}" "${AIO_DIR}/${APP}/Contents/Resources"  2>>$LOG >>$LOG && \
    for template_file in "${AIO_DIR}/${APP}/Contents/Win32/Squeak.ini" "${AIO_DIR}/squeak.bat" "${AIO_DIR}/squeak.sh" "${AIO_DIR}/${APP}/Contents/Info.plist";
    do
        $E Patching $template_file >> $LOG
        grep -q '%BASE%' $template_file && printf '%s\n' ",s/%BASE%/${BASE}/g" w q | ed -s $template_file
        grep -q '%NAME%' $template_file && printf '%s\n' ",s/%NAME%/${NAME}/g" w q | ed -s $template_file
        grep -q '%RELEASE%' $template_file && printf '%s\n' ",s/%RELEASE%/${RELEASE}/g" w q | ed -s $template_file
    done
    check

    xattr -cr "${AIO_DIR}/${APP}" # remove all extended attributes from app bundle
    codesign --force --sign "Squeak Deutschland e.V." "${AIO_DIR}/${APP}"
    codesign -dv --verbose=4 "${AIO_DIR}/${APP}"
fi

mkdir -p dist || true

if [ \! -f "${DIST_DIR}/${BASE}.txz" ]; then
    if type xz 2>/dev/null >/dev/null; then
        $E -n "[....] $(tput setaf 3)Compressing txz $(tput op)"
        COPYFILE_DISABLE=1 tar -cf "${DIST_DIR}/${BASE}.txz" --use-compress-program xz "${AIO_DIR}"  2>>$LOG >>$LOG
        check
    fi
fi

if [ \! -f "${DIST_DIR}/${BASE}.zip" ]; then
    $E -n "[....] $(tput setaf 3)Compressing ${APP} $(tput op)"
    ditto -ck --noqtn --noacl --zlibCompressionLevel 9 "${AIO_DIR}" "${DIST_DIR}/${BASE}.zip"  2>>$LOG >>$LOG
    check
fi

if [ \! -f "${DIST_DIR}/${DMG}" ]; then
    $E -n "[....] $(tput setaf 3)Creating Disk Image ${DMG} $(tput op)"
    hdiutil create -size 256m -volname "${BASE}" -srcfolder "${AIO_DIR}" \
        -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -nospotlight "${TMP_DIR}/${DMG}"  2>>$LOG >>$LOG && \
    DEVICE="$(hdiutil attach -readwrite -noautoopen -nobrowse "${TMP_DIR}/${DMG}" | awk 'NR==1{print$1}')" && \
    VOLUME="$(mount | grep "$DEVICE" | sed 's/^[^ ]* on //;s/ ([^)]*)$//')" && \
    rm -f "${VOLUME}/squeak.bat" "${VOLUME}/squeak.sh" && \
    cp "./TEMPLATE.app/Contents/Resources/${ICON}.icns" "${VOLUME}/.VolumeIcon.icns" && \
    SetFile -c icnC "${VOLUME}/.VolumeIcon.icns" && \
    SetFile -a C "${VOLUME}" && \
    hdiutil detach "$DEVICE" 2>>$LOG >>$LOG  && \
    hdiutil convert "${TMP_DIR}/${DMG}" -format UDBZ -imagekey bzip2-level=9 -o "${DIST_DIR}/${DMG}" 2>>$LOG >>$LOG && \
    ./set_icon.py "./TEMPLATE.app/Contents/Resources/${ICON}.icns" "${DIST_DIR}/${DMG}"  2>>$LOG >>$LOG
    rm "${TMP_DIR}/${DMG}" && \
    check
fi

# mv "${BASE}/${APP}" . &&  rm -r "${BASE}"

if [ \! -f "${DIST_DIR}/${IMAGE}" ]; then
    ditto -v "${TMP_DIR}/${IMAGE}" "${TMP_DIR}/${CHANGES}" "${AIO_DIR}" "${DIST_DIR}"
fi

$E "Files are in the $(tput setaf 9)dist/$(tput op) directory"

$E "$(tput setaf 2)Done.$(tput op)"
