#!/bin/bash

PROGRAM="$(echo $0 | sed 's%.*/%%')"
PROGDIR="$(cd "$(dirname "$0")"; echo $PWD)"

# This string is later passed as arguments to the smalltalk configuration scripts
SQUEAK_ARGUMENTS=""

set -e

if [ "$RELEASE" == "Trunk" ]
then
    # # Trunk release - for now using same version as normal ones
    echo "This is a trunk build"
    RELEASE="5.3alpha"
    SRC_IMAGE="Squeak5.3alpha-19064-64bit"
    SRC_URL="http://files.squeak.org/${RELEASE}/${SRC_IMAGE}/${SRC_IMAGE}.zip"
    SUFFIX="Trunk"
else
    # # Point-release
    echo "Build on release: $RELEASE"
    RELEASE="5.3alpha"
    SRC_IMAGE="Squeak5.3alpha-19064-64bit"
    SRC_URL="http://files.squeak.org/${RELEASE}/${SRC_IMAGE}/${SRC_IMAGE}.zip"
    SUFFIX=""
fi

if [ "$STARTRACK" == "true" ]
then
    # Set startrack option for smalltalk configuration file
    SQUEAK_ARGUMENTS="${SQUEAK_ARGUMENTS} '-startrack'"
    INFIX="-"
else
    INFIX=""
fi

# OR Trunk:
# RELEASE="Trunk"
# SRC_IMAGE="TrunkImage"
# SRC_URL="http://build.squeak.org/job/SqueakTrunk/lastSuccessfulBuild/artifact/target/${SRC_IMAGE}.zip"


CONFIGURE_SCRIPT="SwaImageConfiguration"
BASE="SWA${INFIX}2019${SUFFIX}"
NAME="SWA ${INFIX}2019 ${SUFFIX}"
# These arguments are first because expected by configuration script 
SQUEAK_ARGUMENTS=" '${PROGDIR}' '${BASE}' ${SQUEAK_ARGUMENTS}"
DEPLOY_TARGET="https://www.hpi.uni-potsdam.de/hirschfeld/artefacts/lecture-image/"
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
    tput sc && tput hpa 0 && $E "$1" && tput rc || true
    tput cnorm || true
    $E ""
}
check() {
    EX="$?"
    if [ "$?" -eq 0 ]; then
        ann "[$(tput setaf 2) OK ]"
    else
        ann "[$(tput setaf 9)FAIL]"
        tail $LOG
        exit $EX
    fi
}

$E "Start at $(date)"

if [ \! -d "${CACHE_DIR}" ]; then
    mkdir "${CACHE_DIR}"

    if [ \! -f "${CACHE_DIR}/${SRC_IMAGE}.zip" ]; then
        $E "[....] $(tput setaf 4)Fetching ${SRC_IMAGE}"
        curl -o "${CACHE_DIR}/${SRC_IMAGE}.zip" "$SRC_URL"
        check
    fi

    if [ \! -f "${CACHE_DIR}/SqueakV50.sources.gz" ]; then
        $E "[....] $(tput setaf 4)Fetching sources"
        curl -o "${CACHE_DIR}/SqueakV50.sources.gz" http://ftp.squeak.org/sources_files/SqueakV50.sources.gz
        check
    fi

fi
if [ \! -d "${TMP_DIR}" ]; then
    mkdir "${TMP_DIR}"

    $E "[....] $(tput setaf 4)Extracting ${SRC_IMAGE}"
    ditto -xk "${CACHE_DIR}/${SRC_IMAGE}.zip" "${TMP_DIR}/"
    check

    $E "[....] $(tput setaf 4)Decompressing sources"
    gunzip -c "${CACHE_DIR}/SqueakV50.sources.gz" > "${TMP_DIR}/SqueakV50.sources"
    check

    $E "[....] $(tput setaf 6)Building image "
    CONFIG="$(ls -1t ${CONFIGURE_SCRIPT}* | tail -n 1)"
    chmod -R a+x ./TEMPLATE.app
    eval ./TEMPLATE.app/Contents/MacOS/Squeak "'${TMP_DIR}/${SRC_IMAGE}.image' '../${CONFIG}'${SQUEAK_ARGUMENTS}"
    check

    if [ \! -f "${TMP_DIR}/${IMAGE}" ]; then
        $E "BUILD FAILED"
        exit 1
    fi
fi

chmod -v a+x set_icon.py

if [ \! -d "${AIO_DIR}" ]; then
    mkdir "${AIO_DIR}"
    $E "[....] $(tput setaf 3)Building all-in-one "
    ditto -v  "./squeak.bat.tmpl" "${AIO_DIR}/squeak.bat"    && \
    ditto -v  "./squeak.sh.tmpl" "${AIO_DIR}/squeak.sh"    && \
    ditto -v TEMPLATE.app "${AIO_DIR}/${APP}" && \
    chmod -v a+rwx "${TMP_DIR}/${IMAGE}" && \
    python set_icon.py "${AIO_DIR}/${APP}/Contents/Resources/${ICON}.icns" "${TMP_DIR}/${IMAGE}" && \
    ditto -v "${TMP_DIR}/${IMAGE}" "${TMP_DIR}/${CHANGES}" "${TMP_DIR}/SqueakV50.sources" "${AIO_DIR}/${APP}/Contents/Resources"    && \
    for template_file in "${AIO_DIR}/${APP}/Contents/Win64/Squeak.ini" "${AIO_DIR}/squeak.bat" "${AIO_DIR}/squeak.sh" "${AIO_DIR}/${APP}/Contents/Info.plist";
    do
        $E "Patching ${template_file}"
        grep -q '%BASE%' $template_file && printf '%s\n' ",s/%BASE%/${BASE}/g" w q | ed -s $template_file
        grep -q '%NAME%' $template_file && printf '%s\n' ",s/%NAME%/${NAME}/g" w q | ed -s $template_file
        grep -q '%RELEASE%' $template_file && printf '%s\n' ",s/%RELEASE%/${RELEASE}/g" w q | ed -s $template_file
    done
    check

    xattr -cr "${AIO_DIR}/${APP}" # remove all extended attributes from app bundle

    if [[ -f ".encrypted.zip" ]]; then
        $E "Signing macOS bundles..."
        unzip -q ".encrypted.zip"
        KEY_CHAIN=macos-build.keychain
        security create-keychain -p travis "${KEY_CHAIN}"
        security default-keychain -s "${KEY_CHAIN}"
        security unlock-keychain -p travis "${KEY_CHAIN}"
        security set-keychain-settings -t 3600 -u "${KEY_CHAIN}"
        security import "encrypted/sign.cer" -k ~/Library/Keychains/"${KEY_CHAIN}" -T /usr/bin/codesign
        security import "encrypted/sign.p12" -k ~/Library/Keychains/"${KEY_CHAIN}" -P "${CERT_P12_PASS}" -T /usr/bin/codesign
        security set-key-partition-list -S apple-tool:,apple: -s -k travis "${KEY_CHAIN}"

        codesign -s "Squeak Deutschland e.V." --force --deep "${AIO_DIR}/${APP}"
        # codesign -dv --verbose=4 "${AIO_DIR}/${APP}"
        # Remove sensitive files again
        rm -rf ./.encrypted.zip ./encrypted*
        security delete-keychain "${KEY_CHAIN}"
    else
        $E "Skipping codesign on macOS..."
    fi
fi

mkdir -p dist || true

if [ \! -f "${DIST_DIR}/${BASE}.txz" ]; then
    if type xz 2>/dev/null >/dev/null; then
        $E "[....] $(tput setaf 3)Compressing txz "
        COPYFILE_DISABLE=1 tar -cf "${DIST_DIR}/${BASE}.txz" --use-compress-program xz "${AIO_DIR}"
        check
    fi
fi

if [ \! -f "${DIST_DIR}/${BASE}.zip" ]; then
    $E "[....] $(tput setaf 3)Compressing ${APP} "
    ditto -ck --noqtn --noacl --zlibCompressionLevel 9 "${AIO_DIR}" "${DIST_DIR}/${BASE}.zip"
    check
fi

if [ \! -f "${DIST_DIR}/${DMG}" ]; then
    $E "[....] $(tput setaf 3)Creating Disk Image ${DMG} "
    hdiutil create -size 256m -volname "${BASE}" -srcfolder "${AIO_DIR}" \
        -fs HFS+ -fsargs "-c c=64,a=16,e=16" -format UDRW -nospotlight "${TMP_DIR}/${DMG}" && \
    DEVICE="$(hdiutil attach -readwrite -noautoopen -nobrowse "${TMP_DIR}/${DMG}" | awk 'NR==1{print$1}')" && \
    VOLUME="$(mount | grep "$DEVICE" | sed 's/^[^ ]* on //;s/ ([^)]*)$//')" && \
    rm -f "${VOLUME}/squeak.bat" "${VOLUME}/squeak.sh" && \
    cp "./TEMPLATE.app/Contents/Resources/${ICON}.icns" "${VOLUME}/.VolumeIcon.icns" && \
    SetFile -c icnC "${VOLUME}/.VolumeIcon.icns" && \
    SetFile -a C "${VOLUME}" && \
    hdiutil detach "$DEVICE" && \
    hdiutil convert "${TMP_DIR}/${DMG}" -format UDBZ -imagekey bzip2-level=9 -o "${DIST_DIR}/${DMG}" && \
    chmod -v a+rwx "${DIST_DIR}/${DMG}" && \
    python set_icon.py "./TEMPLATE.app/Contents/Resources/${ICON}.icns" "${DIST_DIR}/${DMG}"
    rm "${TMP_DIR}/${DMG}" && \
    check
fi

# mv "${BASE}/${APP}" . &&  rm -r "${BASE}"

if [ \! -f "${DIST_DIR}/${IMAGE}" ]; then
    ditto -v "${TMP_DIR}/${IMAGE}" "${TMP_DIR}/${CHANGES}" "${AIO_DIR}" "${DIST_DIR}"
fi

curl -s -u "${DEPLOY_CREDENTIALS}" -T "${DIST_DIR}/${BASE}.zip" "${DEPLOY_TARGET}" && $E ".zip uploaded."
curl -s -u "${DEPLOY_CREDENTIALS}" -T "${DIST_DIR}/${BASE}.txz" "${DEPLOY_TARGET}" && $E ".txz uploaded."
curl -s -u "${DEPLOY_CREDENTIALS}" -T "${DIST_DIR}/${DMG}" "${DEPLOY_TARGET}" && $E ".txz uploaded."

$E "Files are in the $(tput setaf 9)dist/ directory"

$E "$(tput setaf 2)Done."
