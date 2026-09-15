import QtQuick

// The cursed-energy point of light that stands in for the password field.
// Pre-rendered offline (see the sheet generator in the repo history) as a
// 300-frame, 15 s loop -- bloom, two layers of radiating spokes, a few
// crackle arcs -- so this is one texture scrolled behind a clip, not
// per-frame Canvas math. Cost is the same whether one monitor is locked or
// five.
//
// The brightness itself is several sine waves at different integer
// harmonics of the loop summed together: each one alone closes cleanly,
// but the sum beats against itself into irregular power surges instead of
// one clean pulse -- a longer loop was the tradeoff for that not reading
// as a mechanical bounce.
Item {
    id: root

    readonly property int frameSize: 240
    readonly property int frameCount: 300
    readonly property int sheetColumns: 20
    readonly property int loopMs: 15000

    property url energySource: ""
    property url glowSource: ""
    property bool playing: true

    // 0..1, how much password has been typed. Reacts by scale/opacity only
    // -- the baked loop itself never changes -- exactly like the chibi
    // robot's charge pool.
    property real charge: 0

    implicitWidth: frameSize
    implicitHeight: frameSize

    property real _frameF: 0
    readonly property int frameIndex: Math.max(0, Math.min(frameCount - 1, Math.floor(_frameF)))

    NumberAnimation on _frameF {
        from: 0
        to: root.frameCount
        duration: root.loopMs
        loops: Animation.Infinite
        running: root.playing
    }

    scale: 1 + root.charge * 0.32
    opacity: 1
    Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
    Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }

    // A keystroke knocks the point back a little. A two-step animation, not
    // a per-frame spring -- costs nothing while idle.
    property real _recoilX: 0
    function strike() { recoilAnim.restart() }

    SequentialAnimation {
        id: recoilAnim
        NumberAnimation { target: root; property: "_recoilX"; to: -9; duration: 55 }
        NumberAnimation { target: root; property: "_recoilX"; to: 0; duration: 220; easing.type: Easing.OutCubic }
    }

    Item {
        anchors.fill: parent
        x: root._recoilX

        // Ambient spill onto the scene around the point, well outside the
        // tight sprite frame. A single static image, scaled/faded by charge
        // like the chibi robot's glow pool -- no gradients rebuilt per frame.
        Image {
            source: root.glowSource
            anchors.centerIn: parent
            width: root.width * (2.6 + root.charge * 1.1)
            height: width
            opacity: 0.75 + root.charge * 0.25
            smooth: true
            Behavior on opacity { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
            Behavior on width { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
        }

        Item {
            anchors.fill: parent
            clip: true

            Image {
                id: sheet
                source: root.energySource
                width: root.width * root.sheetColumns
                height: root.height * Math.ceil(root.frameCount / root.sheetColumns)
                x: -(root.frameIndex % root.sheetColumns) * root.width
                y: -Math.floor(root.frameIndex / root.sheetColumns) * root.height
                fillMode: Image.Stretch
                smooth: true
                asynchronous: false
                cache: true
            }
        }

        // A rejected password flashes red once, the same red for every pose
        // -- a plain opacity pulse on a pre-rendered burst, not a recolor of
        // the baked loop.
        Image {
            id: flash
            source: Qt.resolvedUrl("assets/flash.png")
            anchors.centerIn: parent
            width: root.width * 3.4
            height: width
            opacity: 0
            smooth: true
        }
    }

    function reject() { flashAnim.restart() }

    SequentialAnimation {
        id: flashAnim
        NumberAnimation { target: flash; property: "opacity"; to: 0.45; duration: 40 }
        NumberAnimation { target: flash; property: "opacity"; to: 0; duration: 480; easing.type: Easing.OutCubic }
    }
}
