#!/usr/bin/env bash
set -euo pipefail

# Run on a dedicated macOS Jenkins agent with one executor.
ROOT=$(pwd)
REPORTS="$ROOT/ci-artifacts/android"
mkdir -p "$REPORTS"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export JAVA_HOME="${ANDROID_TEST_JAVA_HOME:-/Applications/Android Studio.app/Contents/jbr/Contents/Home}"
export PATH="${ANDROID_NODE_BIN:-/opt/homebrew/opt/node@22/bin}:$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
ADB="$ANDROID_HOME/platform-tools/adb"
EMULATOR="$ANDROID_HOME/emulator/emulator"
AVDMANAGER="$ANDROID_HOME/cmdline-tools/latest/bin/avdmanager"
export ANDROID_UDID=emulator-5580
export ANDROID_AVD_HOME="$ROOT/.ci-avd"
export ANDROID_APP_WAIT_ACTIVITY='com.saucelabs.mydemoapp.android.view.activities.*'
unset APPIUM_HOST
EMULATOR_PID=''

cleanup() {
    result=$?
    trap - EXIT
    if [ -n "$EMULATOR_PID" ]; then
        "$ADB" -s "$ANDROID_UDID" logcat -d > "$REPORTS/logcat.txt" 2>&1 || true
        if kill -0 "$EMULATOR_PID" 2>/dev/null; then
            "$ADB" -s "$ANDROID_UDID" emu kill > "$REPORTS/emulator-stop.txt" 2>&1 || true
            kill "$EMULATOR_PID" 2>/dev/null || true
            for attempt in 1 2 3 4 5; do
                kill -0 "$EMULATOR_PID" 2>/dev/null || break
                sleep 1
            done
            kill -KILL "$EMULATOR_PID" 2>/dev/null || true
        fi
        wait "$EMULATOR_PID" 2>/dev/null || true
    fi
    exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

: "${ANDROID_SOURCE_REV:?Supply the Android app commit SHA}"
: "${ANDROID_SYSTEM_IMAGE:?Supply an installed Android SDK system-image package}"
[[ "$ANDROID_SOURCE_REV" =~ ^[0-9a-fA-F]{40}$ ]] || { echo 'ANDROID_SOURCE_REV must be a full commit SHA'; exit 1; }
node --version
npm --version
command -v lsof >/dev/null
test -x "$AVDMANAGER"
"$JAVA_HOME/bin/java" -version
"$EMULATOR" -accel-check

git clone https://github.com/javierserret/my-demo-app-android.git android-source
git -C android-source checkout --detach "$ANDROID_SOURCE_REV"
git -C android-source rev-parse HEAD > "$REPORTS/source-revision.txt"
git rev-parse HEAD > "$REPORTS/test-revision.txt"
printf '%s\n' "$ANDROID_SYSTEM_IMAGE" > "$REPORTS/system-image.txt"

BUILD_JAVA_HOME="${ANDROID_BUILD_JAVA_HOME:-$(/usr/libexec/java_home -v 11)}"
"$BUILD_JAVA_HOME/bin/java" -version
(
    cd android-source
    JAVA_HOME="$BUILD_JAVA_HOME" PATH="$BUILD_JAVA_HOME/bin:$PATH" bash ./gradlew --no-daemon clean assembleDebug
) 2>&1 | tee "$REPORTS/gradle.log"
cp android-source/app/build/outputs/apk/debug/app-debug.apk "$REPORTS/app-debug.apk"
(cd "$REPORTS" && shasum -a 256 app-debug.apk > app-debug.apk.sha256)
export ANDROID_APP_PATH="$REPORTS/app-debug.apk"

(cd automation/appium && npm ci)
# Do not take over a developer's emulator or Appium server.
for port in 5580 5581 4723; do
    if lsof -nP -iTCP:"$port" -sTCP:LISTEN >/dev/null 2>&1; then
        echo "Port $port is occupied; stop the conflicting service or use a dedicated agent."
        exit 1
    fi
done
mkdir -p "$ANDROID_AVD_HOME"
echo no | "$AVDMANAGER" create avd --force --name qa_lab_ci --package "$ANDROID_SYSTEM_IMAGE" --device pixel_8
"$EMULATOR" -avd qa_lab_ci -port 5580 -no-window -no-audio -no-snapshot -wipe-data > "$REPORTS/emulator.log" 2>&1 &
EMULATOR_PID=$!

deadline=$((SECONDS + 240))
while :; do
    kill -0 "$EMULATOR_PID" 2>/dev/null || { echo 'Emulator exited; inspect emulator.log'; exit 1; }
    if [ "$("$ADB" -s "$ANDROID_UDID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = 1 ] &&
       "$ADB" -s "$ANDROID_UDID" shell pm path android >/dev/null 2>&1; then
        break
    fi
    [ "$SECONDS" -lt "$deadline" ] || { echo 'Android did not become ready within 240 seconds'; exit 1; }
    sleep 2
done
"$ADB" -s "$ANDROID_UDID" shell input keyevent 82
"$ADB" -s "$ANDROID_UDID" shell settings put global window_animation_scale 0
"$ADB" -s "$ANDROID_UDID" shell settings put global transition_animation_scale 0
"$ADB" -s "$ANDROID_UDID" shell settings put global animator_duration_scale 0
(cd automation/appium && npm test) 2>&1 | tee "$REPORTS/appium-tests.log"
