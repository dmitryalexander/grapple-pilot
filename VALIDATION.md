# Tactical candidate verification

Offline checks establish packaging and source integration, not a working native
tactical. `offline-validation.json` records checks and installer fixture results.
Live startup and four menu choices were observed in an isolated test game.
Native custom weapon class registration failed, so the logical Grapple item
now maps to native Radar Pulse with a private tactical_grapple mod. No full
gameplay acceptance is claimed. Evidence is in development live/ JSON files.

The extracted AbilitySelect menu has five scripted button slots (0–4). Shipped
OnOpenAbilitySelectMenu reads GetAllItemsOfType and populates those buttons.
Adding a fourth PILOT_SPECIAL therefore needs no replacement menu layout.
`_items.nut` preserves stock registrations and adds Grapple/unlock level 1;
`_pdef.nut` preserves IDs 0–44 and appends Grapple as 45. Stock loadout handling
puts the selected special into offhand slot 1. The private native-carrier branch calls
the server bridge, which verifies actual slot/weapon ownership and eligibility.

Required native checks before accepting the build:

- Cold startup: UI/client/server compile; addon schema mounts before persistence
  initialization; private carrier equipping succeeds.
- Four distinct menu options, correct text/icon, selection/navigation, saved
  selection. Primary weapon still determines the pilot appearance.
- Original three tacticals work normally; Grapple is available only when chosen.
  Holding the normal tactical key fires once; second press releases while busy.
- Clamp versus miss recovery, stale HUD, native bar, sound, death, respawn,
  reconnect, team/class change, map transition, embark/disembark.
- Switching away cancels Grapple/hides its aim cue and indicator; switching back
  cannot refill. Stock tactical HUD remains unaffected.
- Slide hopping/momentum and native air-jump limits; two independent players,
  remote host/client consistency, keyboard/controller.
- Change saved custom loadouts back to stock before removal; profile restore and
  uninstall. Production-profile compatibility has not been established.

Prior Powder/Cooldown gameplay acceptance does not validate the new native
menu/offhand/persistence path. Building the ZIP does not launch the game.


Latest Tactical-only revision: removes both custom center recharge rails, uses
a dedicated lower-left Grapple icon and native server-driven recharge bar, and
reduces boostAdd456 to392.16 (14%) with cap600 unchanged. Source/isolated addon
synchronized and package checked offline. Diagnostic endpoint refused connection
after editing, so this revision has not been visually or gameplay verified.
Existing native Radar data does not support modded hud_icon; shipped HUD comment
and direct icon/alert HUD assignments provide the replacement path. Check stock
icon restoration after changing loadouts, native bar, stale state and respawn.
