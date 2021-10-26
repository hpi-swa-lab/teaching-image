#!/bin/bash

LOCAL="true"
UPLOAD="false"
PROGRAM="$(echo $0 | sed 's%.*/%%')"
PROGDIR="$(cd "$(dirname "$0")"; echo $PWD)"

# This string is later passed as arguments to the smalltalk configuration scripts
SQUEAK_ARGUMENTS=""

set -e

# Environment variables expected by this script:
# RELEASE: The overall release version (e.g. 5.3 or 5.2, etc.)
# PATCH: The build number of the specific image to be downloaded (e.g. 19432)
# SUFFIX: Additional information about the image (e.g. "Trunk") (optional)
function assert_env_variable {
    if [ -z "$1" ]
    then
        echo "Error: Missing environment variable: $2"
        exit 1
    fi
}
assert_env_variable "$RELEASE" "RELEASE"
assert_env_variable "$PATCH" "PATCH"
assert_env_variable "$LECTURE" "LECTURE"

echo "This is a Squeak $RELEASE build (patch: $PATCH)."
if [ -n "$SUFFIX" ]
then
    echo "Build is marked as '$SUFFIX'"
fi
SRC_IMAGE="Squeak6.0alpha-${PATCH}-64bit"
SRC_URL="http://files.squeak.org/${RELEASE}/${SRC_IMAGE}/${SRC_IMAGE}.zip"

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
BASE="${LECTURE}${INFIX}${YEAR}${SUFFIX}"
NAME="${LECTURE} ${INFIX}${YEAR} ${SUFFIX}"
# These arguments are first because expected by configuration script 
SQUEAK_ARGUMENTS=" '${PROGDIR}' '${BASE}' ${SQUEAK_ARGUMENTS}"
DEPLOY_TARGET="https://www.hpi.uni-potsdam.de/hirschfeld/artefacts/lecture-image/"
############################################################
DIST_DIR="./dist"
CACHE_DIR="./_cache"
TMP_DIR="./_tmp"
AIO_DIR="${TMP_DIR}/aio"
ICON="Squeak"
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
        $E "[ OK ]"
    else
        $E "[FAIL]"
        tail $LOG
        exit $EX
    fi
}

$E "Start at $(date)"

if [ \! -d "${CACHE_DIR}" ]; then
    mkdir "${CACHE_DIR}"

    if [ \! -f "${CACHE_DIR}/${SRC_IMAGE}.zip" ]; then
        $E "[....] Fetching ${SRC_IMAGE}"
        curl -o "${CACHE_DIR}/${SRC_IMAGE}.zip" "$SRC_URL"
        check
    fi

    if [ \! -f "${CACHE_DIR}/SqueakV50.sources.gz" ]; then
        $E "[....] Fetching sources"
        curl -o "${CACHE_DIR}/SqueakV50.sources.gz" http://ftp.squeak.org/sources_files/SqueakV50.sources.gz
        check
    fi

fi
if [ \! -d "${TMP_DIR}" ]; then
    mkdir "${TMP_DIR}"

    $E "[....] Extracting ${SRC_IMAGE}"
    if [ "$LOCAL" == "true" ]; then
        unzip "${CACHE_DIR}/${SRC_IMAGE}.zip" -d "${TMP_DIR}/"
    else
        ditto -xk "${CACHE_DIR}/${SRC_IMAGE}.zip" "${TMP_DIR}/"
    fi
    check

    $E "[....] Decompressing sources"
    gunzip -c "${CACHE_DIR}/SqueakV50.sources.gz" > "${TMP_DIR}/SqueakV50.sources"
    check

    $E "[....] Building image "
    CONFIG="$(ls -1t ${CONFIGURE_SCRIPT}* | tail -n 1)"
    chmod -R a+x ./TEMPLATE.app
    if [ "$LOCAL" == "true" ]; then
        eval TEMPLATE.app/Contents/Linux-x86_64/squeak "'${TMP_DIR}/${SRC_IMAGE}.image' '../${CONFIG}'${SQUEAK_ARGUMENTS}"
    else
        eval TEMPLATE.app/Contents/MacOS/squeak "'${TMP_DIR}/${SRC_IMAGE}.image' '../${CONFIG}'${SQUEAK_ARGUMENTS}"
    fi
    check

    if [ \! -f "${TMP_DIR}/${IMAGE}" ]; then
        $E "BUILD FAILED"
        exit 1
    fi
fi

chmod -v a+x set_icon.py

function _copy {
    if [ "$LOCAL" == "true" ]; then
        cp -R $@
    else
        ditto -v $@
    fi
}

if [ \! -d "${AIO_DIR}" ]; then
    mkdir "${AIO_DIR}"
    $E "[....] Building all-in-one "
    _copy  "./squeak.bat.tmpl" "${AIO_DIR}/squeak.bat"    && \
    _copy  "./squeak.sh.tmpl" "${AIO_DIR}/squeak.sh"    && \
    _copy TEMPLATE.app "${AIO_DIR}/${APP}" && \
    chmod -v a+rwx "${TMP_DIR}/${IMAGE}" && \
    python set_icon.py "${AIO_DIR}/${APP}/Contents/Resources/${ICON}.icns" "${TMP_DIR}/${IMAGE}" && \
    _copy "${TMP_DIR}/${IMAGE}" "${TMP_DIR}/${CHANGES}" "${TMP_DIR}/SqueakV50.sources" "${AIO_DIR}/${APP}/Contents/Resources"    && \
    for template_file in "${AIO_DIR}/${APP}/Contents/Win64/Squeak.ini" "${AIO_DIR}/squeak.bat" "${AIO_DIR}/squeak.sh" "${AIO_DIR}/${APP}/Contents/Info.plist";
    do
        $E "Patching ${template_file}"
        grep -q '%BASE%' $template_file && printf '%s\n' ",s/%BASE%/${BASE}/g" w q | ed -s $template_file
        grep -q '%NAME%' $template_file && printf '%s\n' ",s/%NAME%/${NAME}/g" w q | ed -s $template_file
        grep -q '%RELEASE%' $template_file && printf '%s\n' ",s/%RELEASE%/${RELEASE}/g" w q | ed -s $template_file
    done
    check

    if [ "$LOCAL" == "true" ]; then
        # probably not necessary?
        echo "FIXME: skip xattr"
    else
        xattr -cr "${AIO_DIR}/${APP}" # remove all extended attributes from app bundle
    fi

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
        $E "[....] Compressing txz "
        COPYFILE_DISABLE=1 tar -cf "${DIST_DIR}/${BASE}.txz" --use-compress-program xz "${AIO_DIR}"
        check
    fi
fi

if [ \! -f "${DIST_DIR}/${BASE}.zip" ]; then
    $E "[....] Compressing ${APP} "
    if [ "$LOCAL" == "true" ]; then
        zip -r "${AIO_DIR}" "${DIST_DIR}/${BASE}.zip"
    else
        ls "${AIO_DIR}"
        ditto -ck --noqtn --noacl --zlibCompressionLevel 9 "${AIO_DIR}" "${DIST_DIR}/${BASE}.zip"
    fi
    check
fi

if [ \! -f "${DIST_DIR}/${DMG}" ]; then
    $E "[....] Creating Disk Image ${DMG} "
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
    _copy "${TMP_DIR}/${IMAGE}" "${TMP_DIR}/${CHANGES}" "${AIO_DIR}" "${DIST_DIR}"
fi

if [ "$UPLOAD" == "true" ]; then
    curl -s -u "${DEPLOY_CREDENTIALS}" -T "${DIST_DIR}/${BASE}.zip" "${DEPLOY_TARGET}" && $E ".zip uploaded."
    curl -s -u "${DEPLOY_CREDENTIALS}" -T "${DIST_DIR}/${BASE}.txz" "${DEPLOY_TARGET}" && $E ".txz uploaded."
    curl -s -u "${DEPLOY_CREDENTIALS}" -T "${DIST_DIR}/${DMG}" "${DEPLOY_TARGET}" && $E ".txz uploaded."
else
    echo "Files are: ${DIST_DIR}/${BASE}.zip ${DIST_DIR}/${BASE}.txz ${DIST_DIR}/${DMG}"
fi

$E "Files are in the dist/ directory"
ls ${DIST_DIR}

$E "Done."
