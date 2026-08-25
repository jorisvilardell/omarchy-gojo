import QtQuick
import QtQuick.Effects
import qs.Commons
import qs.Ui
import "GojoTheme.js" as Gojo

// Presentational layer for Omarchy's lock screen.
//
// The property and signal surface below is Service.qml's contract — PAM, the
// session-lock protocol and every retry rule live there, untouched. This file
// only decides what that state looks like.
Item {
    id: root

    property string backgroundPath: ""
    property int backgroundVersion: 0
    property bool fingerprintConfigured: false
    property bool authenticatingPassword: false
    property string failureMessage: ""
    property int failedAttempts: 0
    property bool inputEnabled: true
    property bool loadBackground: true
    property string passwordText: ""
    property bool syncingPasswordText: false

    signal submitPassword(string password)
    signal passwordTextEdited(string password)
    signal clearFailureRequested()
    signal wakeRequested()

    readonly property bool errorState: failureMessage.length > 0
    readonly property real orbSize: Math.min(width, height) * 0.34

    // Drawn once per lock, so which Gojo shows up is a small surprise rather
    // than a setting.
    property var pose: Gojo.randomPose()

    readonly property color glowColor: errorState ? Gojo.errorGlow : pose.glow
    readonly property color ringColor: errorState ? Gojo.errorRing : pose.ring
    readonly property color sparkColor: errorState ? Gojo.errorSpark : pose.spark

    function fileUrl(path) {
        if (!path) return ""
        var encoded = String(path).split("/").map(encodeURIComponent).join("/")
        return "file://" + encoded + "?v=" + backgroundVersion
    }

    function forcePasswordFocus() { passwordInput.forceActiveFocus() }
    function clearPassword() { passwordTextEdited("") }

    function syncPasswordText() {
        if (passwordInput.text === passwordText) return
        syncingPasswordText = true
        passwordInput.text = passwordText
        syncingPasswordText = false
    }

    onPasswordTextChanged: syncPasswordText()
    onInputEnabledChanged: if (inputEnabled) Qt.callLater(forcePasswordFocus)
    Component.onCompleted: {
        syncPasswordText()
        if (inputEnabled) Qt.callLater(forcePasswordFocus)
    }

    // A new failure is a new attempt: redraw the pose so a wrong password is
    // answered by a different Gojo.
    onFailedAttemptsChanged: if (failedAttempts > 0) pose = Gojo.randomPose()

    Rectangle {
        anchors.fill: parent
        color: Color.background

        Image {
            id: wallpaper
            anchors.fill: parent
            source: root.loadBackground ? root.fileUrl(root.backgroundPath) : ""
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: false
            sourceSize.width: width
            sourceSize.height: height
        }

        MultiEffect {
            anchors.fill: wallpaper
            source: wallpaper
            autoPaddingEnabled: false
            blurEnabled: root.loadBackground && wallpaper.status === Image.Ready
            blur: 1.0
            blurMax: 128
            blurMultiplier: 1.25
            contrast: -0.08
        }

        // The artwork needs a dark ground to read against, whatever the
        // wallpaper is doing underneath.
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.rgba(0.02, 0.01, 0.06, 0.72) }
                GradientStop { position: 1.0; color: Qt.rgba(0.02, 0.01, 0.06, 0.92) }
            }
        }

        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
            onPositionChanged: root.wakeRequested()
        }

        Image {
            id: gojo
            source: Qt.resolvedUrl(root.pose.source)
            height: parent.height * 0.82
            fillMode: Image.PreserveAspectFit
            anchors.right: parent.right
            anchors.rightMargin: parent.width * 0.04
            anchors.bottom: parent.bottom
            asynchronous: true
            smooth: true
            mipmap: true
            opacity: 0.96
            transform: Scale {
                origin.x: gojo.width / 2
                xScale: root.pose.flip ? -1 : 1
            }
        }

        // The orb sits over the artwork's own energy: the pose says where its
        // hand is, so the sphere lands in it instead of floating beside it.
        Item {
            id: orbAnchor
            width: root.orbSize
            height: root.orbSize
            x: gojo.x + gojo.width * root.pose.anchorX - width / 2
            y: gojo.y + gojo.height * root.pose.anchorY - height / 2

            InfinityOrb {
                id: energy
                anchors.fill: parent
                glowColor: root.glowColor
                ringColor: root.ringColor
                sparkColor: root.sparkColor
                errorState: root.errorState
                charge: passwordInput.text.length
                intensity: root.authenticatingPassword ? 1 : 0
            }

            // Failure shakes the orb, which is all the feedback a wrong
            // password needs before the message underneath is read.
            SequentialAnimation {
                id: shake
                NumberAnimation { target: orbAnchor; property: "anchors.horizontalCenterOffset"; to: 0; duration: 0 }
                NumberAnimation { target: energy; property: "x"; to: -14; duration: 55 }
                NumberAnimation { target: energy; property: "x"; to: 14; duration: 55 }
                NumberAnimation { target: energy; property: "x"; to: -8; duration: 55 }
                NumberAnimation { target: energy; property: "x"; to: 0; duration: 90 }
            }

            TextInput {
                id: passwordInput
                anchors.centerIn: parent
                width: parent.width * 1.1
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                activeFocusOnPress: true
                enabled: root.inputEnabled && !root.authenticatingPassword
                readOnly: root.authenticatingPassword
                echoMode: TextInput.Password
                passwordCharacter: "●"
                passwordMaskDelay: 0
                color: root.sparkColor
                selectionColor: Qt.rgba(root.ringColor.r, root.ringColor.g, root.ringColor.b, 0.45)
                selectedTextColor: root.sparkColor
                font.family: Style.font.family
                // Dots shrink once they outgrow the sphere, so a long
                // passphrase still shows every keystroke instead of clipping.
                font.pixelSize: {
                    var base = Math.round(root.orbSize * 0.16)
                    var fits = Math.max(6, Math.floor(base * Math.min(1, 9 / Math.max(1, text.length))))
                    return text.length > 0 ? fits : base
                }
                font.letterSpacing: 2
                clip: true
                cursorVisible: false

                onTextChanged: {
                    if (!root.syncingPasswordText) root.passwordTextEdited(text)
                    if (text.length > 0) {
                        root.wakeRequested()
                        energy.pulse()
                    }
                    if (text.length > 0 && root.failureMessage.length > 0) root.clearFailureRequested()
                }

                onAccepted: {
                    var submitted = root.passwordText
                    root.passwordTextEdited("")
                    if (submitted.length > 0) root.submitPassword(submitted)
                }

                Keys.onPressed: function (event) {
                    root.wakeRequested()
                    if (event.key === Qt.Key_Escape || (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_U)) {
                        root.passwordTextEdited("")
                        event.accepted = true
                    }
                }
            }
        }

        Connections {
            target: root
            function onErrorStateChanged() { if (root.errorState) shake.restart() }
        }

        // Status lives in the open half of the frame rather than under the orb:
        // the orb moves with the pose, this does not.
        Column {
            anchors.left: parent.left
            anchors.leftMargin: parent.width * 0.10
            anchors.verticalCenter: parent.verticalCenter
            spacing: 14

            Text {
                text: root.authenticatingPassword
                    ? "Domain Expansion…"
                    : (root.errorState ? root.failureMessage : "Enter Password")
                color: root.errorState ? root.ringColor : Color.lock.text
                font.family: Style.font.family
                font.pixelSize: Math.round(Style.font.heading * 1.9)
                font.italic: root.errorState
            }

            Text {
                text: root.fingerprintConfigured ? "󰈷  or touch the sensor" : root.pose.name
                color: Color.lock.placeholder
                opacity: 0.55
                font.family: Style.font.family
                font.pixelSize: Math.round(Style.font.heading * 0.9)
                font.letterSpacing: 3
                font.capitalization: Font.AllUppercase
            }
        }
    }
}
