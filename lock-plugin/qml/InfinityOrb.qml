import QtQuick
import QtQuick.Shapes

// The password field, drawn as the energy sphere Gojo holds.
//
// Everything here is geometry and colour — the field itself lives in LockView
// and is centred on this. The orb never handles input.
Item {
    id: orb

    property color glowColor: "#c04df0"
    property color ringColor: "#ff2fd0"
    property color sparkColor: "#ffd7ff"

    // 0 idle, 1 authenticating. Drives how hard the whole thing pulses.
    property real intensity: 0
    property bool errorState: false
    // Grows with the password: every keystroke feeds the sphere.
    property int charge: 0

    readonly property real coreRadius: Math.min(width, height) * 0.5
    readonly property real chargeFactor: Math.min(1, charge / 16)

    // Idle breathing, so the orb is alive before anyone touches the keyboard.
    property real breathe: 0
    SequentialAnimation on breathe {
        loops: Animation.Infinite
        running: true
        NumberAnimation { to: 1; duration: 2600; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 2600; easing.type: Easing.InOutSine }
    }

    // Authentication spins the rings up rather than replacing them with a
    // spinner: same object, more energy.
    property real spin: 0
    NumberAnimation on spin {
        from: 0
        to: 360
        duration: 9000
        loops: Animation.Infinite
        running: true
    }

    property real flash: 0
    SequentialAnimation {
        id: impact
        NumberAnimation { target: orb; property: "flash"; to: 1; duration: 70 }
        NumberAnimation { target: orb; property: "flash"; to: 0; duration: 420; easing.type: Easing.OutCubic }
    }
    function pulse() { impact.restart() }

    onErrorStateChanged: if (errorState) impact.restart()

    // Outer halo. A Shape with a RadialGradient, not a Rectangle: QML's plain
    // Gradient is linear, which paints a band instead of a glow.
    Shape {
        anchors.centerIn: parent
        width: orb.coreRadius * (3.6 + orb.breathe * 0.25 + orb.intensity * 0.5 + orb.flash * 0.6)
        height: width
        preferredRendererType: Shape.CurveRenderer
        Behavior on width { NumberAnimation { duration: 240; easing.type: Easing.OutCubic } }

        ShapePath {
            strokeWidth: 0
            strokeColor: "transparent"
            fillGradient: RadialGradient {
                centerX: parent.width / 2
                centerY: parent.height / 2
                centerRadius: parent.width / 2
                focalX: centerX
                focalY: centerY
                GradientStop { position: 0.0; color: Qt.rgba(orb.glowColor.r, orb.glowColor.g, orb.glowColor.b, 0.55 + orb.chargeFactor * 0.2 + orb.flash * 0.35) }
                GradientStop { position: 0.32; color: Qt.rgba(orb.glowColor.r, orb.glowColor.g, orb.glowColor.b, 0.28) }
                GradientStop { position: 0.62; color: Qt.rgba(orb.glowColor.r, orb.glowColor.g, orb.glowColor.b, 0.09) }
                GradientStop { position: 1.0; color: "transparent" }
            }

            PathAngleArc {
                centerX: parent.width / 2
                centerY: parent.height / 2
                radiusX: parent.width / 2
                radiusY: parent.height / 2
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // The sphere itself.
    Rectangle {
        id: core
        anchors.centerIn: parent
        width: orb.coreRadius * (1.5 + orb.chargeFactor * 0.28 + orb.flash * 0.22)
        height: width
        radius: width / 2
        color: Qt.rgba(orb.glowColor.r, orb.glowColor.g, orb.glowColor.b, 0.22)
        border.width: 2
        border.color: Qt.rgba(orb.ringColor.r, orb.ringColor.g, orb.ringColor.b, 0.85)
        Behavior on width { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.4 } }

        Rectangle {
            anchors.centerIn: parent
            width: parent.width * (0.42 + orb.breathe * 0.06 + orb.flash * 0.3)
            height: width
            radius: width / 2
            color: Qt.rgba(orb.sparkColor.r, orb.sparkColor.g, orb.sparkColor.b, 0.55 + orb.flash * 0.4)
        }
    }

    // Two counter-rotating rings. The dashed one reads as the technique
    // spinning up; the thin one keeps a steady horizon behind it.
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: 0.9

        ShapePath {
            strokeColor: Qt.rgba(orb.ringColor.r, orb.ringColor.g, orb.ringColor.b, 0.9)
            strokeWidth: 2 + orb.intensity
            fillColor: "transparent"
            strokeStyle: ShapePath.DashLine
            dashPattern: [1.6, 3.2]

            PathAngleArc {
                centerX: orb.width / 2
                centerY: orb.height / 2
                radiusX: orb.coreRadius * 1.16
                radiusY: orb.coreRadius * 1.16
                startAngle: orb.spin * (1 + orb.intensity * 3)
                sweepAngle: 360
            }
        }

        ShapePath {
            strokeColor: Qt.rgba(orb.sparkColor.r, orb.sparkColor.g, orb.sparkColor.b, 0.34)
            strokeWidth: 1
            fillColor: "transparent"

            PathAngleArc {
                centerX: orb.width / 2
                centerY: orb.height / 2
                radiusX: orb.coreRadius * (1.42 + orb.breathe * 0.05)
                radiusY: orb.coreRadius * (1.42 + orb.breathe * 0.05)
                startAngle: 0
                sweepAngle: 360
            }
        }
    }

    // Orbiting sparks, one per character typed, capped so a long passphrase
    // does not turn into a swarm.
    Repeater {
        model: Math.min(orb.charge, 12)

        delegate: Item {
            required property int index
            anchors.centerIn: parent
            width: orb.coreRadius * 2.6
            height: width
            rotation: orb.spin * -1.7 + index * (360 / 12)

            Rectangle {
                width: 4 + orb.flash * 3
                height: width
                radius: width / 2
                color: orb.sparkColor
                opacity: 0.85
                x: parent.width / 2 + parent.width * 0.42
                y: parent.height / 2 - width / 2
            }
        }
    }
}
