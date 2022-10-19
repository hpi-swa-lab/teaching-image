#!/bin/bash

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
assert_env_variable "$BUNDLE_RELEASE" "BUNDLE_RELEASE"
assert_env_variable "$BUNDLE_PATCH" "BUNDLE_PATCH"

echo "This is a Squeak $RELEASE build (patch: $PATCH)."
if [ -n "$SUFFIX" ]
then
    echo "Build is marked as '$SUFFIX'"
fi
SRC_BUNDLE="Squeak${BUNDLE_RELEASE}-${BUNDLE_PATCH}-64bit"
SRC_BUNDLE_URL="http://files.squeak.org/${BUNDLE_RELEASE}/${SRC_BUNDLE}/${SRC_BUNDLE}-All-in-One.zip"
SRC_APP="${SRC_BUNDLE}-All-in-One.app"

if [ "$STARTRACK" == "true" ]
then
    # Set startrack option for smalltalk configuration file
    SQUEAK_ARGUMENTS="${SQUEAK_ARGUMENTS} '-startrack'"
    INFIX="-"
else
    INFIX=""
fi

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
AIO_IMAGE="${TMP_DIR}/aio/${APP}/Contents/Resources/${IMAGE}.image"
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
        tail "${LOG}"
        exit $EX
    fi
}

$E "Start at $(date)"

if [ \! -d "${CACHE_DIR}" ]; then
    mkdir "${CACHE_DIR}"

        
    # Ensure we download the bundle even if it is the same version as the release
    if [ \! -f "${CACHE_DIR}/${SRC_BUNDLE}.zip" ]; then
        $E "[....] $(tput setaf 4)Fetching ${SRC_BUNDLE} from ${SRC_BUNDLE_URL}"
        curl -o "${CACHE_DIR}/${SRC_BUNDLE}.zip" "${SRC_BUNDLE_URL}"
        check
    fi

    if [ \! -f "${CACHE_DIR}/SqueakV50.sources.gz" ]; then
        $E "[....] $(tput setaf 4)Fetching sources"
        curl -o "${CACHE_DIR}/SqueakV50.sources.gz" http://ftp.squeak.org/sources_files/SqueakV50.sources.gz
        check
    fi

    if [ \! -f "${CACHE_DIR}/${SRC_BUNDLE}.zip" ]; then
        $E "[....] $(tput setaf 4)Fetching ${SRC_BUNDLE} from ${SRC_BUNDLE_URL}"
        curl -o "${CACHE_DIR}/${SRC_BUNDLE}.zip" "${SRC_BUNDLE_URL}"
        check
    fi
fi

if [ \! -d "${TMP_DIR}" ]; then
    mkdir "${TMP_DIR}"
fi

if [ \! -d "${AIO_DIR}" ]; then
    mkdir "${AIO_DIR}"
    $E "[....] $(tput setaf 3)Building all-in-one "

    $E "[....] $(tput setaf 4)Extracting ${SRC_BUNDLE}"
    ditto -xk "${CACHE_DIR}/${SRC_BUNDLE}.zip" "${AIO_DIR}"
    check

    # Rename .app folder
    mv "${AIO_DIR}/${SRC_APP}" "${AIO_DIR}/${APP}"
fi

$E "[....] $(tput setaf 6)Building image "
CONFIG="$(ls -1t ${CONFIGURE_SCRIPT}* | tail -n 1)"
eval "${AIO_DIR}/${APP}/Contents/MacOS/Squeak" "-- '${PROGDIR}/${CONFIG}' ${SQUEAK_ARGUMENTS}"
check

$E "[....] $(tput setaf 6)Cleaning up old image and changes file"
rm "${AIO_DIR}/${APP}"/Contents/Resources/Squeak*.image
rm "${AIO_DIR}/${APP}"/Contents/Resources/Squeak*.changes
check

$E "[....] $(tput setaf 6)Preparing AIO files (icons, paths, etc.)"

# Ensure that image file is writeable
chmod -v a+rwx "${AIO_IMAGE}" && \
# Copy icon over and set it
ditto -v "icons/${ICON}.icns" "${AIO_DIR}/${APP}/Contents/Resources/${ICON}.icns" && \
chmod -v a+x set_icon.py
python set_icon.py "${AIO_DIR}/${APP}/Contents/Resources/${ICON}.icns" "${AIO_IMAGE}" && \
check

for aio_file in "${AIO_DIR}/squeak.sh" "${AIO_DIR}/squeak.bat";
do
  $E "Patching ${aio_file}"
  grep -q "${SRC_APP}" $aio_file && printf '%s\n' ",s/${SRC_APP}/${APP}/g" w q | ed -s $aio_file
  grep -q "${SRC_BUNDLE}" $aio_file && printf '%s\n' ",s/${SRC_BUNDLE}/${BASE}/g" w q | ed -s $aio_file
done

# Remove code signature of app
rm -r "${AIO_DIR}/${APP}/"**/_CodeSignature

# remove all extended attributes from app bundle
xattr -cr "${AIO_DIR}/${APP}" 

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

curl -s -u "${DEPLOY_CREDENTIALS}" -T "${DIST_DIR}/${BASE}.zip" "${DEPLOY_TARGET}" && $E ".zip uploaded."
curl -s -u "${DEPLOY_CREDENTIALS}" -T "${DIST_DIR}/${BASE}.txz" "${DEPLOY_TARGET}" && $E ".txz uploaded."

$E "Files are in the $(tput setaf 9)dist/ directory"

$E "$(tput setaf 2)Done."
