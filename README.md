# Blocky

A Roblox-like blocky third-person playground. Offline single-player. Built with Godot 4.

- **Character:** Kenney "Blocky Characters" pack (CC0, free forever) — animated idle / walk / sprint.
- **Controller:** standard Godot 4 `CharacterBody3D` third-person controller, hand-written.
- **Touch:** left virtual joystick to move, green button to jump, drag right half to look.
  Touch UI appears automatically on phones; on desktop use WASD + Space + mouse.

## Run on desktop

1. Install Godot 4.7 (or newer 4.x) from https://godotengine.org/download
2. Open Godot → Import → select `project.godot` in this folder
3. Press F5

## Build the Android APK

1. In Godot: Editor → Manage Export Templates → Download and Install (match your Godot version)
2. Project → Export → select the "Android" preset → Export Project → save `blocky.apk`
3. Copy the APK to your phone and install (allow "install unknown apps" once)

The game is fully offline — no internet permission is even requested.

## Controls

| Desktop | Touch |
|---|---|
| WASD / arrows — move | Left stick — move |
| Space — jump | JMP button — jump |
| Shift — sprint | Drag right half — camera |
| Click — capture mouse / Esc — release | ATK / CHI / DOM buttons — combat |
| J — melee attack | |
| K — Chidori (lightning dash) | |
| L — Domain Expansion (needs full meter) | |

## Combat

- **Melee (J / ATK):** quick swing, builds domain meter on hit.
- **Chidori (K / CHI):** lightning dash strike — crackling aura, screen shake, hit-stop.
- **Domain Expansion (L / DOM):** the cinematic ultimate. Letterbox bars, slow motion,
  a dark-red barrier dome expands over the arena, massive AoE damage.
  Requires a full meter — build it by landing hits.

## Credits

- Character models: "Blocky Characters" by Kenney (https://kenney.nl), CC0 — no attribution required, credited here anyway.
- Everything else: written for this project.
