if (!("Tactical" in getroottable())) IncludeScript("tactical/server",getroottable())
// Experimental server-only movement approximation. No client animation/prediction.
// Starts automatically on a hosted server once map scripts are initialized.
if ( !( "TACSlide" in getroottable() ) )
{
    ::TACSlide <- {
        enabled = false,
        generation = 0,
        minEntrySpeed = 200.0,
        deceleration = 50.0,
        velocityRetention = 0.7,
        minExitSpeed = 125.0,
        reentryDelay = 0.0
    }
}

// Values extracted from the installed R2 client player schema and pilot_base.set.
// Refresh them on explicit reload as well as on a new server VM.
TACSlide.minEntrySpeed = 200.0
// User-selected entry kick +20%; ceiling subsequently raised to 600.
TACSlide.deceleration = 50.0
TACSlide.velocityRetention <- 0.7
TACSlide.minExitSpeed = 125.0
TACSlide.reentryDelay = 0.0

::TACSlide_UpdatePlayer <- function( player, dt, now )
{
    if ( !( "tacSlideState" in player.s ) || player.s.tacSlideState.generation != TACSlide.generation )
    {
        player.s.tacSlideState <- {
            generation = TACSlide.generation,
            crouched = true,
            grounded = false,
            previousVelocity = Vector( 0, 0, 0 ),
            active = false,
            readyTime = 0.0,
            lastBoostTime = -1000.0,
            speed = 0.0,
            direction = Vector( 0, 0, 0 ),
            airStarted = -1.0
        }
    }
    local s = player.s.tacSlideState
    if(!Tactical_Allowed())return
    local charge=Tactical_State(player)
    local velocity = player.GetVelocity()
    // Grapple owns velocity while attached. Preserve its release momentum and
    // allow a crouched landing to re-enter sliding after the tether lets go.
    if ( "TACGrapple_IsActive" in getroottable() && TACGrapple_IsActive(player) )
    {
        s.active = false
        s.grounded = false
        if ( s.airStarted < 0.0 ) s.airStarted = Time()
        s.previousVelocity = velocity
        return
    }
    // Input is visible before the engine finishes lowering the crouch hull.
    // Waiting for IsCrouched() can miss the standing speed at slide entry.
    local crouched = player.IsCrouched()
    if ( "gameUI" in player.s && IsValid( player.s.gameUI ) && "crouch" in player.s.gameUI.s.buttonState )
        crouched = ButtonPressed( player, "crouch" ) || crouched
    // Hold-crouch does not emit the early game_ui signal in this TAC build.
    // The control aliases relay button edges explicitly, before hull slowdown.
    if ( "tacSlideControls" in player.s )
        crouched = crouched || player.s.tacSlideHeld || player.s.tacSlideToggled
    local grounded = player.IsOnGround()
    local eligible = IsAlive( player ) && !player.IsTitan() && !player.IsWallRunning() && !player.IsWallHanging() && !player.IsMantling() && !player.IsZiplining()
    local wasSliding = s.active
    local takingOff = eligible && !grounded && s.grounded
    local landing = eligible && grounded && !s.grounded && s.airStarted >= 0.0 && now - s.airStarted >= 0.03

    if ( takingOff )
    {
        s.airStarted = now
        // Keep horizontal slide momentum on a jump. Leave vertical jump physics
        // and all subsequent air strafing to the engine.
        local horizontalSpeed = velocity.Length2D()
        if ( wasSliding && velocity.z > 0.0 && horizontalSpeed > 1.0 && horizontalSpeed < s.speed )
        {
            local carry = s.speed
            velocity = Vector( velocity.x * carry / horizontalSpeed, velocity.y * carry / horizontalSpeed, velocity.z )
            player.SetVelocity( velocity )
        }
    }
    if ( !eligible )
        s.airStarted = -1.0

    if ( !eligible || !grounded || !crouched )
    {
        if ( s.active && grounded )
            s.readyTime = now + TACSlide.reentryDelay
        s.active = false
    }

    // Use the previous standing velocity: crouching can already reduce speed.
    local crouchEntry = s.grounded && crouched && !s.crouched
    if ( eligible && grounded && crouched && ( crouchEntry || landing ) && now >= s.readyTime )
    {
        local entry = Vector( s.previousVelocity.x, s.previousVelocity.y, 0 )
        local speed = entry.Length2D()
        local requiredSpeed = landing ? TACSlide.minExitSpeed : TACSlide.minEntrySpeed
        if ( speed >= requiredSpeed )
        {
            s.direction = entry * ( 1.0 / speed )
            // Run->crouch and crouched landing intentionally share this EXACT
            // boost recharge rule. Do not introduce a stronger landing boost.
            // Add the selected boost; the selected ceiling limits only
            // added speed, not pre-existing momentum above that ceiling.
            s.speed = speed
            if ( now >= charge.bEnd && Tactical.settings.boostAdd>0.0 && speed < Tactical.settings.boostCap )
            {
                s.speed = min( speed + Tactical.settings.boostAdd, Tactical.settings.boostCap )
                s.lastBoostTime = now
                Tactical_Boost(player,now)
            }
            s.active = true
            player.SetVelocity( Vector( s.direction.x * s.speed, s.direction.y * s.speed, velocity.z ) )
            // Passive acceptance evidence: actual immediate engine velocity,
            // not only the requested target. This does not prove later feel.
            s.lastEntry <- { time=now, incomingSpeed=speed, targetSpeed=s.speed,
                observedVelocity=player.GetVelocity(), landing=landing }
        }
    }
    else if ( s.active )
    {
        // R1's crouch friction can cause a sharp speed loss at landing. It is
        // not sufficient evidence of a wall; confirm it with the actual hull.
        local along = velocity.x * s.direction.x + velocity.y * s.direction.y
        local blocked = false
        if ( along < s.speed * 0.3 )
        {
            local start = player.GetOrigin() + Vector( 0, 0, 1 )
            local finish = start + s.direction * max( 4.0, s.speed * dt )
            local trace = TraceHull( start, finish, player.GetBoundingMins(), player.GetBoundingMaxs(), player, TRACE_MASK_PLAYERSOLID_BRUSHONLY, TRACE_COLLISION_GROUP_PLAYER )
            blocked = trace.fraction < 0.1
        }
        if ( blocked )
        {
            s.active = false
            s.readyTime = now + TACSlide.reentryDelay
        }
        else
        {
            s.speed = max( 0.0, s.speed * pow( TACSlide.velocityRetention, dt ) - TACSlide.deceleration * dt )
            if ( s.speed < TACSlide.minExitSpeed )
            {
                s.active = false
                s.readyTime = now + TACSlide.reentryDelay
            }
            else
                player.SetVelocity( Vector( s.direction.x * s.speed, s.direction.y * s.speed, velocity.z ) )
        }
    }

    s.crouched = crouched
    s.grounded = eligible && grounded
    s.previousVelocity = velocity
    if ( grounded )
        s.airStarted = -1.0
}

::TACSlide_Run <- function( generation )
{
    local last = Time()
    while ( TACSlide.enabled && TACSlide.generation == generation )
    {
        local now = Time()
        local dt = min( max( now - last, 0.0 ), 0.05 )
        last = now
        foreach ( player in GetPlayerArray() )
        {
            if ( !IsValid( player ) )
                continue
            try
            {
                TACSlide_UpdatePlayer( player, dt, now )
            }
            catch ( error )
            {
                // Fail closed; report the first incompatible engine call.
                TACSlide.enabled = false
                printt( "[TACSlide] Disabled after script error:", error )
                return
            }
        }
        wait 0.016
    }
}

::TACSlide_Enable <- function()
{
    if(!Tactical_Allowed())return
    if ( TACSlide.enabled )
        return
    if ( !( "commandsRegistered" in TACSlide ) || !TACSlide.commandsRegistered )
    {
        AddClientCommandCallback( "tactical_slide_down", TACSlide_InputDown )
        AddClientCommandCallback( "tactical_slide_up", TACSlide_InputUp )
        AddClientCommandCallback( "tactical_slide_toggle", TACSlide_InputToggle )
        TACSlide.commandsRegistered <- true
    }
    TACSlide.generation++
    TACSlide.enabled = true
    thread TACSlide_Run( TACSlide.generation )
    printt( "[TACSlide] Experimental sliding enabled for this server." )
}

::TACSlide_InputInit <- function( player )
{
    if ( !( "tacSlideControls" in player.s ) )
    {
        player.s.tacSlideHeld <- false
        player.s.tacSlideToggled <- player.IsCrouched()
        player.s.tacSlideControls <- true
    }
}

::TACSlide_InputDown <- function( player, ... )
{
    TACSlide_InputInit( player )
    player.s.tacSlideHeld = true
    return true
}

::TACSlide_InputUp <- function( player, ... )
{
    TACSlide_InputInit( player )
    player.s.tacSlideHeld = false
    return true
}

::TACSlide_InputToggle <- function( player, ... )
{
    TACSlide_InputInit( player )
    player.s.tacSlideToggled = !player.s.tacSlideToggled
    return true
}

::TACSlide_Disable <- function()
{
    TACSlide.enabled = false
    TACSlide.generation++
    printt( "[TACSlide] Sliding disabled." )
}

::TACSlide_AutoStart <- function()
{
    while ( !("AddClientCommandCallback" in getroottable()) || !("GetPlayerArray" in getroottable()) ) wait 0.1
    wait 0.2
    TACSlide_Enable()
}
thread TACSlide_AutoStart()
printt( "[TACSlide] Saved R2 profile loaded; waiting for host map initialization." )
