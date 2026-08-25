.pragma library

// The three poses ship together and one is drawn at random each time the
// screen locks — the point is that you do not know which Gojo is waiting.
//
// `glow` and `ring` are the orb colours that go with each pose, so the energy
// in his hand and the ring you type into always agree. They deliberately do not
// come from the Omarchy palette: the orb is the character's cursed technique,
// not a themed surface, and it has to read the same on a light theme as on a
// dark one.
var poses = [
    {
        source: "assets/gojo-hollow-purple.png",
        name: "Hollow Purple",
        glow: "#c04df0",
        ring: "#ff2fd0",
        spark: "#ffd7ff",
        // Where the orb sits relative to the artwork, as a fraction of the
        // image box: this pose already holds a sphere in its hand, so the ring
        // is placed over it rather than floating on its own.
        anchorX: 0.60,
        anchorY: 0.53,
        flip: false
    },
    {
        source: "assets/gojo-cursed-technique.png",
        name: "Cursed Technique",
        glow: "#e02fc0",
        ring: "#ff41e0",
        spark: "#ffe0fb",
        anchorX: 0.46,
        anchorY: 0.56,
        flip: false
    },
    {
        source: "assets/gojo-six-eyes.png",
        name: "Six Eyes",
        glow: "#3fa9ff",
        ring: "#5ee7ff",
        spark: "#e8f9ff",
        anchorX: 0.71,
        anchorY: 0.93,
        flip: false
    }
];

function randomPose() {
    return poses[Math.floor(Math.random() * poses.length)];
}

// Failure repaints the orb without changing its geometry: same ring, cursed
// red instead of the pose's colour.
var errorGlow = "#ff2d55";
var errorRing = "#ff5470";
var errorSpark = "#ffd0d8";
