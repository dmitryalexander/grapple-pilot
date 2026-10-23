# Grapple Pilot — 0.1.0-prototype


Adds a selectable Grapple pilot tactical to Titanfall 1 / R1Delta.

[Download the prototype ZIP](https://github.com/dmitryalexander/grapple-pilot/releases/tag/v0.1.0-prototype) · [Installation](INSTALL.md) · [Validation limits](VALIDATION.md)

**Experimental prerelease:** the current build has a reported computer freeze
whose cause has not been established. Latest HUD/boost changes have only offline
validation; multiplayer and full lifecycle acceptance remain pending. Back up
your profile and test in a private session. This is not a stability-certified build.

The internal addon name remains `R1Delta.Tactical` for compatibility. This is an
alternative to Powder/Cooldown, and every participating host/client needs the same
version. No new pilot character models are included.

Adds **Grapple** as a fourth pilot tactical beside **Cloak, Stim and Active Radar
Pulse**. Select it in the normal pilot loadout's Tactical Ability menu and use
your existing tactical key. It occupies that slot. Tap again to release.
Holding is intended to count as one press; that native behavior needs testing.

All pilots retain universal slide hopping and the extra slide impulse. Grapple
reuses the existing server-authoritative tether/swing and imported R2 audio
work. Cloak, Stim and Radar Pulse keep their stock behavior. Grapple uses a private
mod on the native Radar offhand; its script preserves the stock fallback. Guns
and R1's weapon-based pilot appearance keep their selection rules. No model imports are active.

The isolated in-game test has reached the private lobby and shown all four
choices. Grapple selection is confirmed visible by the user. Full input,
recharge and multiplayer regression checks are still pending. The menu icon
now uses a separate dark pilot-and-tether silhouette matching stock R1 styling;
its final in-game appearance awaits review. See [VALIDATION.md](VALIDATION.md).

| Host setting | Default | Meaning |
| --- | ---: | --- |
| `grappleSeconds` | 10 s | Recharge after releasing a hook that clamped |
| `missSeconds` | 1 s | Recovery after a miss or cancellation before clamping |
| `boostSeconds` | 2 s | Minimum interval between accepted extra slide impulses |
| `boostAdd` | 392.16 | Speed added by an accepted slide impulse |
| `boostCap` | 600 | Added-speed ceiling; existing faster momentum survives |

Edit `scripts/vscripts/tactical/settings.nut` on the host before map startup.
Clients have no setting override command. Grapple's 10/1-second values are tunable
approximations, not measured R2 timings. The slide interval is an extracted R2
default; the impulse is 14% below Powder (456 to 392.16), with the same 600 ceiling. Power Cell does
not alter these custom server deadlines. Physics and prediction approximate R2.

Grapple uses a distinct pilot/tether icon and server-driven recharge bar in the
normal lower-left tactical slot. The native Radar carrier icon is overridden
only for the selected Grapple mod. No recharge rails appear near the crosshair.
Movement boost readiness uses audio feedback; no separate visual boost bar.
Missing/stale reports do not display Grapple readiness. Boost audio plays only
for an accepted impulse. Imported R2 grapple/slide sounds and subtle ready
feedback remain. The aiming cue is unchanged.

Death/respawn cancel the hook and restart full grapple/boost recovery. Reconnect
and map changes create fresh state with full recovery. Changing away from Grapple
cancels the tether; switching back in the same life retains the deadline.
Detachment does not fabricate ground contact or refill native air jumps.

Use Tactical as an alternative to Powder or Cooldown. The installer refuses
their presence and shared-file overlaps. See [INSTALL.md](INSTALL.md) before
switching or removing it. Model importing/converter work is set aside; historical
research and all development tools are excluded from the installable package.

## Build the release

Run `python tools/build_release.py` (Python standard library only). The builder verifies the manifest and writes a ZIP and SHA256 checksum to `dist/`.
