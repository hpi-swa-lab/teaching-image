# teaching-image
A repository for scripts to build a teaching image

## How to build a Teaching Image for a Lecture

### 1. Set Build Configuration
- Open `.github/workflows/main.yml` and update the settings:
  - `env: LECTURE={SWA|SWT}`
  - `env: YEAR={YEAR OF LECTURE}`
  - `env: RELEASE={SQUEAK VERSION}`, `env: PATCH={PATCH VERSION}`
    - Find available SQUEAK VERSION and PATCH VERSION here: http://files.squeak.org/.
    - There, PATCH version can be found in parent folder name. For example: `/5.3/Squeak5.3-19431-32bit` gets Patch 19431 of Squeak 5.3
    - Don't use `trunk` as version (this is the nightly build, not stable).
- Commit to master with commit message "`Update configuration for {SWA|SWT} {YEAR OF LECTURE}`".

### 2. Check Image Configuration
- A build starts with a fresh empty image.
- It is possible to execute any command on that image, like one would do using the *Workspace*, thus pre-installing packages and setting other configurations.
- Open `SwaImageConfiguration.st` and edit it if necessary. This script is run to configure the image.
- Make sure all necessary packages are installed (e.g. AutoTDD, GameMecha, MorphicTutorial, StarTrack). You may merge the dev-branches of the packages into the respective masters to update to the version developed in the latest SWT lecture.
- Commit to master with commit message "`Update image configuration for {SWA|SWT} {YEAR OF LECTURE}`".

### 3. Build Image
- A new build is generated on each commit on any branch (using GitHub workflows).
- The build process takes around 20 minutes.
- Once the build process has finished, the image can be obtained here: https://www.hpi.uni-potsdam.de/hirschfeld/artefacts/lecture-image/?C=M;O=D.
  - The page only offers the image of the latest successful build. Older versions are overwritten.
  - An image is available as `.txz` and `.zip` and two versions: with and without `-` (like `SWT2020.*` and `SWT-2020.*`).
  - The builds with `-` in their name are the images with StarTrack enabled (StarTrack collects data for the user study).

## General Information

- The build process runs on MacOS, as MacOS software has to be built on MacOS. Nevertheless, this also builds versions for Windows and Linux.
- The MacOS image is certified with `.encrypted.zip.enc` to make the image trustworthy to MacOS. This certificate needs to be signed with a key which is in posession of [fniephaus](https://github.com/fniephaus) and [marceltaeumel](https://github.com/marceltaeumel).
