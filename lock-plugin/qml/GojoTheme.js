.pragma library

// The three poses ship together and one is drawn at random each time the screen
// locks — the point is that you do not know which Gojo is waiting.
//
// Each pose carries its own energy palette. These deliberately do not come from
// the Omarchy theme: the sphere is the character's cursed technique, not a
// themed surface, and it has to read the same on a light theme as on a dark one.
//
// `anchorX`/`anchorY` are fractions of the artwork's box and say where his hand
// is, so the orb lands in it rather than floating beside it. `fade` is where the
// cutout starts dissolving into the dark, as a fraction of its height.
var poses = [
    {
        source: "assets/gojo-hollow-purple.png",
        name: "Hollow Purple",
        core: "#ffffff",
        inner: "#e879ff",
        outer: "#7c3aed",
        halo: "#a855f7",
        anchorX: 0.58,
        anchorY: 0.45,
        fade: 0.74,
        // Width / height of the artwork. Canvas cannot ask an image for its
        // size, so each pose states its own.
        aspect: 990 / 1200
    },
    {
        source: "assets/gojo-cursed-technique.png",
        name: "Cursed Technique",
        core: "#fff0ff",
        inner: "#ff41e0",
        outer: "#a21caf",
        halo: "#e879f9",
        anchorX: 0.46,
        anchorY: 0.52,
        fade: 0.80,
        aspect: 819 / 1200
    },
    {
        source: "assets/gojo-six-eyes.png",
        name: "Six Eyes",
        core: "#f0fcff",
        inner: "#6ee7ff",
        outer: "#2563eb",
        halo: "#38bdf8",
        anchorX: 0.67,
        anchorY: 0.85,
        fade: 0.66,
        aspect: 1307 / 1200
    }
];

function randomPose() {
    return poses[Math.floor(Math.random() * poses.length)];
}
