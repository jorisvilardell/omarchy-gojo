import QtQuick

// The whole lock screen, drawn on one canvas: background, the artwork, and the
// cursed energy sphere that stands in for the password field.
//
// Ported from an HTML/canvas prototype. Two effects from it are deliberately
// absent: the space-distortion lens, which needs to read back the canvas it is
// drawing on (a QML Canvas cannot sample itself), and the pre-rendered cloud
// canvases, which become the wisp textures in assets/ instead — QML's drawImage
// takes an image, not another canvas.
Canvas {
    id: scene

    // --- state driven from LockView -------------------------------------
    property int charge: 0            // password length
    property bool authenticating: false
    property bool errorState: false
    property url poseSource: ""
    property real poseAnchorX: 0.6    // where the hand is, fraction of the art
    property real poseAnchorY: 0.5
    property real poseFade: 0.72      // dissolve the cutout's bottom edge
    property real poseAspect: 1       // width / height of the artwork
    property color coreColor: "#ffffff"
    property color innerColor: "#e879ff"
    property color outerColor: "#7c3aed"
    property color haloColor: "#a855f7"

    renderStrategy: Canvas.Threaded
    renderTarget: Canvas.FramebufferObject

    // --- animation state -------------------------------------------------
    property real _t: 0
    property real _lastT: 0
    property real _entry: 0
    property real _chargeAmt: 0
    property real _chargeVel: 0
    property real _recoil: 0
    property real _recoilVel: 0
    property real _fail: 0
    property real _shake: 0
    property real _spin: 0
    property real _spin2: 0
    property real _breathe: 0
    property var _sparks: []
    property var _arcs: []
    property var _shocks: []
    property real _nextArc: 0

    property bool _wispReady: false

    Component.onCompleted: {
        var sparks = []
        for (var i = 0; i < 34; i++) {
            sparks.push({
                ang: Math.random() * 6.2832,
                sp: 0.5 + Math.random() * 1.5,
                orbit: 1.25 + Math.random() * 1.5,
                tilt: (Math.random() - 0.5) * 1.1,
                squash: 0.16 + Math.random() * 0.32,
                size: 0.7 + Math.random() * 1.9,
                wob: Math.random() * 6.2832
            })
        }
        _sparks = sparks
        loadImage("assets/wisp.png")
        loadImage("assets/wisp-dark.png")
    }

    onImageLoaded: {
        if (isImageLoaded("assets/wisp.png") && isImageLoaded("assets/wisp-dark.png")) _wispReady = true
        requestPaint()
    }

    onPoseSourceChanged: if (poseSource != "") loadImage(poseSource)

    // A keystroke feeds the sphere and knocks it back; the springs below settle
    // it again.
    function strike() {
        _chargeVel += 3.4
        _recoilVel -= 2.2
        spawnArcs(2 + Math.floor(Math.random() * 3))
    }

    function erase() { _chargeVel -= 1.4 }
    function clear() { _chargeVel -= 3 }

    function reject() {
        _fail = 1
        _shake = 1
        _recoilVel = 16
        _chargeVel = -6
        _shocks.push({ r: 0, life: 1, fail: true })
        spawnArcs(14)
    }

    function spawnArcs(n) {
        for (var i = 0; i < n; i++) {
            _arcs.push({
                ang: Math.random() * 6.2832,
                spread: (Math.random() - 0.5) * 1.5,
                len: 0.5 + Math.random() * 1.5,
                seed: Math.random() * 1000,
                life: 1,
                dur: 0.09 + Math.random() * 0.14,
                w: 0.8 + Math.random() * 1.8
            })
        }
    }

    onErrorStateChanged: if (errorState) reject()

    Timer {
        interval: 16
        running: scene.visible
        repeat: true
        onTriggered: {
            scene._t += 0.016
            scene.requestPaint()
        }
    }

    // --- helpers ---------------------------------------------------------
    function rgba(c, a) {
        return "rgba(" + Math.round(c.r * 255) + "," + Math.round(c.g * 255) + "," + Math.round(c.b * 255) + "," + a + ")"
    }

    function mixColor(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
    }

    function clamp(v, lo, hi) { return v < lo ? lo : (v > hi ? hi : v) }

    readonly property color failCore: "#fff0f0"
    readonly property color failInner: "#ff6060"
    readonly property color failOuter: "#be123c"
    readonly property color failHalo: "#f43f5e"

    onPaint: {
        var ctx = getContext("2d")
        var w = width, h = height
        if (!w || !h) return

        var t = _t
        var dt = Math.min(0.05, t - _lastT)
        _lastT = t

        _entry = clamp(_entry + dt / 1.6, 0, 1)
        var ease = 1 - Math.pow(1 - _entry, 3)

        // Charge is a spring, so the sphere overshoots and settles instead of
        // snapping to each keystroke.
        var target = clamp(charge / 10, 0, 1.15)
        _chargeVel += (target - _chargeAmt) * 42 * dt
        _chargeVel *= Math.pow(0.0025, dt)
        _chargeAmt = clamp(_chargeAmt + _chargeVel * dt, 0, 1.6)

        _recoilVel += -_recoil * 130 * dt
        _recoilVel *= Math.pow(0.012, dt)
        _recoil += _recoilVel * dt

        _fail = Math.max(0, _fail - dt / 1.15)
        _shake = Math.max(0, _shake - dt / 0.55)

        var chg = _chargeAmt * (authenticating ? 1.5 : 1)
        var boost = 1 + chg * 1.7 + _fail * 2.2
        _spin += dt * 0.42 * boost
        _spin2 -= dt * 0.63 * boost
        _breathe += dt * (1.15 + chg * 1.3)

        var pCore = coreColor, pInner = innerColor, pOuter = outerColor, pHalo = haloColor
        if (_fail > 0) {
            var f = Math.min(1, _fail * 1.5)
            pCore = mixColor(pCore, failCore, f)
            pInner = mixColor(pInner, failInner, f)
            pOuter = mixColor(pOuter, failOuter, f)
            pHalo = mixColor(pHalo, failHalo, f)
        }

        var base = Math.min(w, h) * 0.088
        var breathe = 1 + Math.sin(_breathe) * 0.035 + Math.sin(_breathe * 2.3) * 0.015
        var R = base * (1 + chg * 0.28) * breathe
        var cx = w * 0.79 + _recoil * base * 0.55 + (Math.random() - 0.5) * _shake * 8
        var cy = h * 0.545 + (Math.random() - 0.5) * _shake * 8

        ctx.reset()
        ctx.clearRect(0, 0, w, h)

        // --- background
        var bg = ctx.createRadialGradient(w * 0.62, h * 0.5, 0, w * 0.62, h * 0.5, Math.max(w, h) * 0.85)
        bg.addColorStop(0, "#131a2a")
        bg.addColorStop(0.45, "#0a0e18")
        bg.addColorStop(1, "#04050a")
        ctx.fillStyle = bg
        ctx.fillRect(0, 0, w, h)

        ctx.globalCompositeOperation = "lighter"
        var amb0 = ctx.createRadialGradient(cx, cy, 0, cx, cy, base * 12)
        amb0.addColorStop(0, rgba(pHalo, 0.13))
        amb0.addColorStop(0.5, rgba(pOuter, 0.05))
        amb0.addColorStop(1, "rgba(0,0,0,0)")
        ctx.fillStyle = amb0
        ctx.fillRect(0, 0, w, h)
        ctx.globalCompositeOperation = "source-over"

        // --- the artwork, hand centred on the orb
        if (poseSource != "" && isImageLoaded(poseSource)) {
            var drawH = h * ease
            var drawW = drawH * poseAspect
            var dy = (1 - ease) * 26
            ctx.globalAlpha = ease
            ctx.drawImage(poseSource, cx - poseAnchorX * drawW, cy - poseAnchorY * drawH + dy, drawW, drawH)
            ctx.globalAlpha = 1

            // Dissolve the artwork into the bottom of the frame so its cutout
            // edge never reads as a hard horizontal line.
            var y0 = h * poseFade
            if (y0 < h) {
                var fade = ctx.createLinearGradient(0, y0, 0, h)
                fade.addColorStop(0, "rgba(4,5,10,0)")
                fade.addColorStop(1, "rgba(4,5,10,1)")
                ctx.fillStyle = fade
                ctx.fillRect(0, y0, w, h - y0)
            }
        }

        // --- orb light spilling onto the scene
        ctx.globalCompositeOperation = "lighter"
        var amb = ctx.createRadialGradient(cx, cy, R * 0.4, cx, cy, base * 9)
        amb.addColorStop(0, rgba(pInner, 0.3 + chg * 0.18))
        amb.addColorStop(0.22, rgba(pHalo, 0.13 + chg * 0.1))
        amb.addColorStop(0.6, rgba(pOuter, 0.045))
        amb.addColorStop(1, "rgba(0,0,0,0)")
        ctx.fillStyle = amb
        ctx.fillRect(0, 0, w, h)

        // --- outer halo
        var halo = ctx.createRadialGradient(cx, cy, R * 0.5, cx, cy, R * 4.4)
        halo.addColorStop(0, rgba(pHalo, 0.42 + chg * 0.2))
        halo.addColorStop(0.28, rgba(pOuter, 0.16))
        halo.addColorStop(1, "rgba(0,0,0,0)")
        ctx.fillStyle = halo
        ctx.beginPath()
        ctx.arc(cx, cy, R * 4.4, 0, 6.2832)
        ctx.fill()

        // --- plasma body
        ctx.save()
        ctx.beginPath()
        ctx.arc(cx, cy, R, 0, 6.2832)
        ctx.clip()
        ctx.globalCompositeOperation = "source-over"

        var body = ctx.createRadialGradient(cx - R * 0.22, cy - R * 0.26, R * 0.04, cx, cy, R * 1.02)
        body.addColorStop(0, rgba(pInner, 0.95))
        body.addColorStop(0.34, rgba(mixColor(pInner, pOuter, 0.45), 0.92))
        body.addColorStop(0.78, rgba(pOuter, 0.8))
        body.addColorStop(1, rgba(pOuter, 0.22))
        ctx.fillStyle = body
        ctx.fillRect(cx - R, cy - R, R * 2, R * 2)

        if (_wispReady) {
            // Dark veins under bright wisps: two layers turning at different
            // rates is what stops the sphere reading as a flat gradient.
            // QML's Canvas implements only a subset of the compositing modes —
            // "multiply" silently falls back to source-over, which is why the
            // shading below is painted as translucent dark instead.
            ctx.globalCompositeOperation = "source-over"
            var dark = [[_spin2, 1.7, 0.55], [_spin * 1.35, 2.35, 0.4]]
            for (var i = 0; i < dark.length; i++) {
                ctx.save()
                ctx.globalAlpha = dark[i][2]
                ctx.translate(cx, cy)
                ctx.rotate(dark[i][0])
                ctx.scale(dark[i][1], dark[i][1] * 0.9)
                ctx.drawImage("assets/wisp-dark.png", -R, -R, R * 2, R * 2)
                ctx.restore()
            }

            ctx.globalCompositeOperation = "lighter"
            var bright = [[_spin, 1.45, 0.42], [-_spin2 * 1.2, 2.15, 0.3], [_spin * 2.1, 1.05, 0.24]]
            for (var j = 0; j < bright.length; j++) {
                ctx.save()
                ctx.globalAlpha = bright[j][2] * (0.8 + chg * 0.5)
                ctx.translate(cx, cy)
                ctx.rotate(bright[j][0])
                ctx.scale(bright[j][1], bright[j][1] * 0.92)
                ctx.drawImage("assets/wisp.png", -R, -R, R * 2, R * 2)
                ctx.restore()
            }
        }

        ctx.globalCompositeOperation = "lighter"
        var cr = R * (0.14 + 0.045 * Math.sin(_breathe * 1.6)) * (1 + chg * 0.4)
        var core = ctx.createRadialGradient(cx - R * 0.1, cy - R * 0.12, 0, cx - R * 0.1, cy - R * 0.12, cr * 3.1)
        core.addColorStop(0, "rgba(255,255,255,0.85)")
        core.addColorStop(0.16, rgba(pInner, 0.45))
        core.addColorStop(1, "rgba(0,0,0,0)")
        ctx.fillStyle = core
        ctx.fillRect(cx - R, cy - R, R * 2, R * 2)

        // Terminator: the shading that makes a disc read as a sphere. Drawn as
        // a translucent shadow from the far side rather than a multiply pass.
        ctx.globalCompositeOperation = "source-over"
        var term = ctx.createRadialGradient(cx - R * 0.3, cy - R * 0.34, R * 0.1, cx + R * 0.25, cy + R * 0.3, R * 1.5)
        term.addColorStop(0, "rgba(0,0,0,0)")
        term.addColorStop(0.55, "rgba(8,4,20,0.12)")
        term.addColorStop(1, "rgba(8,4,20,0.62)")
        ctx.fillStyle = term
        ctx.fillRect(cx - R, cy - R, R * 2, R * 2)
        ctx.restore()

        ctx.globalCompositeOperation = "lighter"

        // fresnel rim
        ctx.lineWidth = Math.max(1, R * 0.045)
        ctx.strokeStyle = rgba(pCore, 0.34 + chg * 0.2)
        ctx.beginPath()
        ctx.arc(cx, cy, R * 0.985, 0, 6.2832)
        ctx.stroke()

        // --- orbit rings, flattened into perspective
        for (var k = 0; k < 2; k++) {
            var rr = R * (1.55 + k * 0.72)
            var squash = 0.34 + k * 0.1
            ctx.save()
            ctx.translate(cx, cy)
            ctx.rotate(_spin * (k ? -0.6 : 0.45) + k * 0.9)
            ctx.scale(1, squash)
            if (k) ctx.setLineDash([R * 0.09, R * 0.14])
            ctx.lineWidth = Math.max(1, R * (k ? 0.035 : 0.02)) / squash
            ctx.strokeStyle = rgba(pHalo, (k ? 0.3 : 0.22) + chg * 0.25)
            ctx.beginPath()
            ctx.arc(0, 0, rr, 0, 6.2832)
            ctx.stroke()
            ctx.restore()
        }
        ctx.setLineDash([])

        // --- charge arc: how full the sphere is, one turn per ten characters
        if (charge > 0) {
            var frac = clamp(charge / 10, 0, 1)
            ctx.lineWidth = Math.max(1.5, R * 0.06)
            ctx.strokeStyle = rgba(pCore, 0.85)
            ctx.beginPath()
            ctx.arc(cx, cy, R * 1.28, -Math.PI / 2, -Math.PI / 2 + frac * 6.2832)
            ctx.stroke()
        }

        // --- sparks in orbit, sized by depth so some read as in front
        for (var s = 0; s < _sparks.length; s++) {
            var sp = _sparks[s]
            sp.ang += dt * sp.sp * (0.8 + chg * 1.6 + _fail * 2)
            var orbit = R * sp.orbit * (1 + Math.sin(t * 1.3 + sp.wob) * 0.06)
            var px = Math.cos(sp.ang) * orbit
            var py = Math.sin(sp.ang) * orbit * sp.squash
            var x = cx + px * Math.cos(sp.tilt) - py * Math.sin(sp.tilt)
            var y = cy + px * Math.sin(sp.tilt) + py * Math.cos(sp.tilt)
            var depth = 0.55 + 0.45 * Math.sin(sp.ang)
            var sz = sp.size * depth * (1 + chg * 0.5) * (R / base)
            ctx.globalAlpha = 0.35 + depth * 0.6
            var sg = ctx.createRadialGradient(x, y, 0, x, y, sz * 5)
            sg.addColorStop(0, rgba(pCore, 0.95))
            sg.addColorStop(0.3, rgba(pInner, 0.5))
            sg.addColorStop(1, "rgba(0,0,0,0)")
            ctx.fillStyle = sg
            ctx.beginPath()
            ctx.arc(x, y, sz * 5, 0, 6.2832)
            ctx.fill()
            ctx.globalAlpha = 1
        }

        // --- lightning, drawn twice: a wide soft pass under a thin bright one
        _nextArc -= dt
        var rate = 0.32 + chg * 1.9 + _fail * 2.4
        if (_nextArc <= 0 && rate > 0) {
            _nextArc = 0.1 / Math.max(0.2, rate)
            spawnArcs(1)
        }
        for (var ai = 0; ai < _arcs.length; ai++) {
            var arc = _arcs[ai]
            arc.life -= dt / arc.dur
            if (arc.life <= 0) continue
            var al = Math.sin(Math.max(0, arc.life) * Math.PI)
            var steps = 9
            ctx.lineCap = "round"
            ctx.beginPath()
            for (var st = 0; st <= steps; st++) {
                var fr = st / steps
                var ang = arc.ang + arc.spread * fr
                var rad = R * (0.9 + arc.len * fr * 0.9)
                var jit = (Math.sin(arc.seed + fr * 21) + Math.sin(arc.seed * 2.7 + fr * 47)) * R * 0.075 * (1 - Math.abs(0.5 - fr) * 0.6)
                var ax = cx + Math.cos(ang) * rad + Math.cos(ang + 1.57) * jit
                var ay = cy + Math.sin(ang) * rad + Math.sin(ang + 1.57) * jit
                if (st === 0) ctx.moveTo(ax, ay)
                else ctx.lineTo(ax, ay)
            }
            ctx.strokeStyle = rgba(pInner, 0.3 * al)
            ctx.lineWidth = arc.w * 4.5 * (R / base)
            ctx.stroke()
            ctx.strokeStyle = rgba(pCore, 0.9 * al)
            ctx.lineWidth = arc.w * 1.1 * (R / base)
            ctx.stroke()
        }
        _arcs = _arcs.filter(function (x) { return x.life > 0 }).slice(-90)

        // --- shockwaves
        for (var sh = 0; sh < _shocks.length; sh++) {
            var shock = _shocks[sh]
            shock.life -= dt / 0.6
            var prog = 1 - Math.max(0, shock.life)
            ctx.strokeStyle = shock.fail ? rgba(failInner, 0.55 * shock.life) : rgba(pCore, 0.6 * shock.life)
            ctx.lineWidth = Math.max(1, R * 0.16 * shock.life)
            ctx.beginPath()
            ctx.arc(cx, cy, R * (1 + prog * 7), 0, 6.2832)
            ctx.stroke()
        }
        _shocks = _shocks.filter(function (x) { return x.life > 0 })

        ctx.globalCompositeOperation = "source-over"

        // Entry veil, so the lock screen fades up rather than snapping in.
        if (ease < 1) {
            ctx.fillStyle = "rgba(4,5,10," + (1 - ease) + ")"
            ctx.fillRect(0, 0, w, h)
        }
    }
}
