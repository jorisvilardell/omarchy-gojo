import QtQuick
import qs.Commons
import qs.Ui
import "GojoTheme.js" as Gojo

// Presentational layer for Omarchy's lock screen.
//
// The property and signal surface below is Service.qml's contract — PAM, the
// session-lock protocol and every retry rule live there, untouched. This file
// only decides what that state looks like: background, artwork and the
// cursed-energy point are all pre-rendered media (see assets/), scaled and
// composited by the scene graph rather than redrawn by hand every frame.
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

    // Drawn once per lock, so which Gojo shows up is a small surprise rather
    // than a setting.
    property var pose: Gojo.randomPose()

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

    onErrorStateChanged: if (errorState) energy.reject()

    // Synthetic backdrop, not the desktop wallpaper — baked once offline,
    // stretched to cover whatever the monitor's aspect ratio is.
    Image {
        anchors.fill: parent
        source: Qt.resolvedUrl("assets/bg.png")
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: false
        cache: true
    }

    // The artwork is pinned to the bottom-right, so no cutout ever ends on a
    // visible horizontal edge; the energy point is then placed on the hand
    // within that frame, rather than the artwork being hung off the point.
    readonly property real imgH: root.height * root.pose.height
    readonly property real imgW: imgH * root.pose.aspect
    readonly property real imgX: root.width - imgW - root.width * 0.03
    readonly property real imgY: root.height - imgH

    Image {
        id: art
        x: root.imgX
        y: root.imgY + (1 - artReveal.value) * 26
        width: root.imgW
        height: root.imgH
        source: Qt.resolvedUrl(root.pose.source)
        fillMode: Image.Stretch
        smooth: true
        asynchronous: false
        opacity: artReveal.value
    }

    QtObject {
        id: artReveal
        property real value: 0
        NumberAnimation on value {
            from: 0; to: 1; duration: 1600; easing.type: Easing.OutCubic; running: true
        }
    }

    // Sinks the last of the artwork into the floor of the frame.
    Rectangle {
        x: 0
        y: root.imgY + root.imgH * root.pose.fade
        width: root.width
        height: root.imgH * (1 - root.pose.fade)
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#0004050a" }
            GradientStop { position: 1.0; color: "#eb04050a" }
        }
    }

    GojoEnergy {
        id: energy
        width: Math.min(root.width, root.height) * 0.325
        height: width
        x: root.imgX + root.imgW * root.pose.anchorX - width / 2
        y: root.imgY + root.imgH * root.pose.anchorY - height / 2
        energySource: Qt.resolvedUrl(root.pose.energySource)
        glowSource: Qt.resolvedUrl(root.pose.glowSource)
        charge: Math.min(1.15, passwordInput.text.length / 10)
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: { root.wakeRequested(); root.forcePasswordFocus() }
        onPositionChanged: root.wakeRequested()
    }

    // Status sits in the open half of the frame. The dots are drawn here rather
    // than by the TextInput so they can glow.
    Column {
        anchors.left: parent.left
        anchors.leftMargin: parent.width * 0.08
        anchors.verticalCenter: parent.verticalCenter
        spacing: 22

        Column {
            spacing: 10

            Text {
                text: root.authenticatingPassword ? "Domain Expansion" : "Enter Password"
                color: Qt.rgba(0.91, 0.886, 1, 0.62)
                font.family: Style.font.family
                font.pixelSize: Math.round(Style.font.heading * 1.7)
                font.weight: Font.Light
                font.letterSpacing: 3
            }

            Text {
                text: root.fingerprintConfigured ? "󰈷  OR TOUCH THE SENSOR" : root.pose.name
                color: Qt.rgba(0.745, 0.588, 1, 0.42)
                font.family: Style.font.family
                font.pixelSize: Math.round(Style.font.heading * 0.66)
                font.letterSpacing: 6
                font.capitalization: Font.AllUppercase
            }
        }

        Row {
            spacing: 14
            height: 26

            Repeater {
                model: Math.min(passwordInput.text.length, 24)

                delegate: Rectangle {
                    width: 11
                    height: 11
                    radius: 5.5
                    anchors.verticalCenter: parent.verticalCenter
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: "#ffffff" }
                        GradientStop { position: 0.45; color: root.pose.inner }
                        GradientStop { position: 1.0; color: root.pose.outer }
                    }
                }
            }

            Rectangle {
                width: 2
                height: 20
                anchors.verticalCenter: parent.verticalCenter
                color: Qt.rgba(0.886, 0.839, 1, 0.75)
                visible: root.inputEnabled && !root.authenticatingPassword

                SequentialAnimation on opacity {
                    loops: Animation.Infinite
                    running: true
                    NumberAnimation { to: 1; duration: 500 }
                    NumberAnimation { to: 0.05; duration: 600 }
                }
            }
        }

        Text {
            text: root.errorState ? root.failureMessage : ""
            color: Qt.rgba(1, 0.36, 0.47, 0.9)
            font.family: Style.font.family
            font.pixelSize: Math.round(Style.font.heading * 0.62)
            font.letterSpacing: 5
            font.capitalization: Font.AllUppercase
            height: 18
        }
    }

    // Invisible: the dots above are the visible field, and the energy point
    // is the rest of the feedback.
    TextInput {
        id: passwordInput
        width: 1
        height: 1
        opacity: 0
        activeFocusOnPress: true
        enabled: root.inputEnabled && !root.authenticatingPassword
        readOnly: root.authenticatingPassword
        echoMode: TextInput.Password
        passwordMaskDelay: 0
        cursorVisible: false

        onTextChanged: {
            if (!root.syncingPasswordText) root.passwordTextEdited(text)
            if (text.length > 0) {
                root.wakeRequested()
                energy.strike()
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
