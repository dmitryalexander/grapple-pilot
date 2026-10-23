// HOST FILE: loaded only by the server VM. Seconds and Source velocity units.
// Edit before starting a map; no client command can change these settings.
Tactical_Configure({
    grappleSeconds = 10.0, // tunable approximation, not verified native R2 timing
    missSeconds = 1.0,     // tunable recovery for misses / pre-clamp cancellations
    boostSeconds = 2.0,    // extracted R2 slide_boost_cooldown default
    boostAdd = 392.16,      // Tactical: 14% below Powder's 456; not native R2 timing
    boostCap = 600.0       // added-speed ceiling, never a global speed clamp
})
