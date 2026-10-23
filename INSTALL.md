# Installation and switching

R1Delta candidate for Titanfall 1, developed against launcher 2.14.14 scripts.
Every participating host/client needs the same Tactical version. Avoid stock
servers while a custom tactical is selected.

1. Exit the game and back up the pilot profile/settings. Preserve the working
   Powder/Cooldown folder outside `r1/addons`; do not delete it.
2. Keep one movement controller for a fresh VM. The installer refuses
   `R1Delta.Cooldown`, `R1Delta.Powder`, `R1Delta.Sliding` and
   `R1Delta.PilotMovement`, even if disabled.
3. From the package run `./Install.ps1 -GamePath '<Titanfall folder>'`.
   `-WhatIf` validates without copying. Existing addons, settings, bindings,
   addonlist and cfg are never edited. Shared loose-file conflicts are refused.
4. Enable Tactical in Addons and restart. Edit a pilot loadout and select Grapple
   in Tactical Ability beside the original three options. Use the tactical key.

Manual install: copy only `R1Delta.Tactical` to `r1/addons`, following the same
backup/conflict rules. Do not copy research/tools. The authorized test uses a separate game copy; the original Powder/Cooldown
installation is preserved. The shared profile has a verified pretest backup.

Optional slide aliases are defined after sign-on without assigning keys:
`+tactical_slide` / `-tactical_slide`, and `+tactical_slide_toggle` /
`-tactical_slide_toggle`. The explicit relay captures intent before crouch can
reduce running speed. Use `exec tactical_commands` if aliases are missing.
Do not keep Powder/Cooldown slide aliases when testing Tactical; preserve their
old controls for reverting. Native crouch/controller behavior needs testing.

Before removing Tactical, **select stock Cloak, Stim or Active Radar Pulse in
every saved pilot loadout while Tactical is still loaded**, then exit. Back up
the profile first. Tactical appends enum value 45 to `loadoutItems`; stock cannot
interpret Grapple. Loading a profile still referencing it without Tactical has
not been validated. No automatic profile repair or migration is included.

Move Tactical outside addons, restore the preserved controller and its controls,
enable that addon and restart. Do not hot-swap movement VMs. The addon's
`_items.nut`, `_pdef.nut`, `_menu_callbacks.nut` and Radar carrier files are scoped overrides of inspected shipped scripts;
other loadout/schema mods require a manual merge. Stock game scripts and native
DLLs are not overwritten.
