# Android Jenkins worker

The `Android build and test` stage requires an online macOS agent labeled
`android`, with **one executor** and usage restricted to matching labels.
The controller currently keeps the API/web stages on `built-in` for their
existing Docker network. Moving those stages to a separate Linux agent is
still needed before disabling controller executors.

## One-time worker setup

In Manage Jenkins > Nodes, create `android-mac` as a permanent agent:

- Remote root directory: `/Users/xavier/jenkins-agent`
- Executors: `1`
- Labels: `android`
- Usage: only build jobs with matching label expressions
- Launch method: connect agent to controller; enable WebSocket

Use the connection command shown on the node page on your Mac, with
`http://localhost:8080/` as the controller URL. Keep its secret private.
Run the agent under a supported Java runtime (the Android Studio JBR 21
is available on this Mac). Gradle 7.2 uses a separate JDK 11 for builds.
Keep the agent running while Jenkins jobs run.

Provision these tools under the agent's macOS user:

- Git and a modern Node runtime compatible with the project's Appium version.
  Current default bin directory: `/opt/homebrew/opt/node@22/bin`.
- JDK 11, discoverable through `/usr/libexec/java_home -v 11`.
- Android Studio JBR at
  `/Applications/Android Studio.app/Contents/jbr/Contents/Home`.
- Android SDK at `$HOME/Library/Android/sdk`, including platform-tools,
  emulator, command-line tools (latest), and the app's required build SDK/NDK.
- The system image selected by `ANDROID_SYSTEM_IMAGE`, installed with its
  SDK licenses accepted. The pipeline default matches the existing Pixel_8
  image on this Mac; it is not a long-term stable production baseline.
- UiAutomator2 driver configured for the agent user (as for the working
  local Appium run).

Optional node environment overrides: `ANDROID_HOME`, `ANDROID_NODE_BIN`,
`ANDROID_BUILD_JAVA_HOME`, and `ANDROID_TEST_JAVA_HOME`.

## Pipeline behavior

The build pins the app fork to `ANDROID_SOURCE_REV` (a full SHA), clones
into its own Jenkins workspace, and runs `clean assembleDebug` with JDK 11.
It copies the resulting APK to `ci-artifacts/android`, records its checksum
and source/test commits, and runs Appium against **that exact APK**.

The script creates a workspace-owned AVD using the selected system image,
cold-boots it headlessly with wiped data on port 5580, and waits up to four
minutes for Android and its package manager. It does not use or wipe Pixel_8.
Ports 5580, 5581, and 4723 must be free; stop manually started Appium first.
WebdriverIO starts/stops Appium. An exit trap collects logcat and stops only
the emulator started by this script, including on test failure.

Jenkins publishes Android JUnit results from the Mac workspace and archives
the APK, checksum, revisions, Gradle/emulator/test logs, and failure captures.
Fingerprinting links the archived files to the Jenkins build. This is
Jenkins artifact storage, not yet an external artifact repository or release
signing/distribution pipeline.

The app currently requires 16 KB page-size compatibility mode; functional
tests dismiss that exact warning. Passing tests do not establish native
16 KB compatibility. Fixing its native dependencies remains separate work.

## First run

1. Connect the Mac agent and confirm it is online in Jenkins.
2. Commit/push the QA Lab changes; the pinned Android commit must exist in
   `https://github.com/javierserret/my-demo-app-android.git`.
3. Run the pipeline. Later runs expose the source SHA/system image through
   Build with Parameters.
4. Confirm Android test results and `ci-artifacts/android/app-debug.apk`
   appear on the same build, and the CI emulator shuts down afterward.

This pipeline executes code from both repositories on the Mac agent. Use
trusted branches and restrict who can change build parameters or trigger
jobs on this worker. A dedicated OS account/machine is the next isolation
step beyond the personal-machine lab.
