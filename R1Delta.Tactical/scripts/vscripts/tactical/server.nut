// Only the equipped native offhand grants Grapple. No additive grapple command.
function Tactical_HasGrapple(p)
{
    if(!IsValid(p) || p.IsTitan())return false
    local weapon=p.GetOffhandWeapon(1)
    return IsValid(weapon) && weapon.GetClassname()=="mp_ability_sonar" && weapon.HasMod("tactical_grapple")
}
// Included only from sv_ autoruns. No client callbacks accept gameplay settings.
// R1 callback registries key FunctionToString(callback); named declarations are
// required here. Anonymous root-slot closures report a null name in this build.
function Tactical_OnSpawn(p){if(IsValid(p))Tactical_Reset(p)}
function Tactical_OnDisconnect(p)
{
    if(!IsValid(p))return
    Tactical_Reset(p)
    local s=Tactical_State(p)
    if(IsValid(s.marker))s.marker.Kill()
    s.marker=null
}
if (!("Tactical" in getroottable()))
{
    ::Tactical <- {settings={grappleSeconds=10.0,missSeconds=1.0,boostSeconds=2.0,boostAdd=392.16,boostCap=600.0},
        sequence=0,conflict=false,error=null,enabled=true}
    ::Tactical_Configure <- function(values)
    {
        // Validate the entire update before committing anything, including NaN.
        local next={}
        foreach(key,value in values)
        {
            if(!(key in Tactical.settings))throw "Unknown Tactical setting: "+key
            if(typeof value!="integer" && typeof value!="float")throw "Tactical settings must be numeric"
            local limit=(key=="boostAdd" || key=="boostCap") ? 5000.0 : 300.0
            if(!(value>=0.0 && value<=limit))throw "Tactical setting out of range: "+key
            next[key] <- value.tofloat()
        }
        foreach(key,value in next)Tactical.settings[key]=value
    }
    ::Tactical_Allowed <- function()
    {
        // Powder/prototype use these root tables. Refuse even disabled remnants:
        // changing alternatives requires a fresh VM, not a risky hot handoff.
        if("R1Slide" in getroottable() || "R1Grapple" in getroottable() || "CDSlide" in getroottable() || "CDGrapple" in getroottable())
        {
            if(!Tactical.conflict)printt("[Tactical] Powder/Cooldown/prototype detected; Tactical movement blocked. Restart with one addon.")
            Tactical.conflict=true
        }
        return Tactical.enabled && !Tactical.conflict
    }
    ::Tactical_Sound <- function(p,event)
    {
        // Audio failure must not roll back or disable authoritative gameplay.
        try{EmitSoundOnEntityOnlyToPlayer(p,p,"Tactical."+event)}catch(error){Tactical.error=error.tostring()}
    }
    ::Tactical_State <- function(p)
    {
        if(!("tacticalState" in p.s))
        {
            local now=Time();local cfg=Tactical.settings
            p.s.tacticalState <- {gEnd=now+cfg.grappleSeconds,gDuration=cfg.grappleSeconds,
                bEnd=now+cfg.boostSeconds,bDuration=cfg.boostSeconds,pending=false,latched=false,
                wasAlive=IsAlive(p),marker=null,gCooling=cfg.grappleSeconds>0,bCooling=cfg.boostSeconds>0}
        }
        return p.s.tacticalState
    }
    ::Tactical_GrappleBegin <- function(p)
    {
        local s=Tactical_State(p)
        s.pending=true;s.latched=false;s.gCooling=true
        Tactical_Sound(p,"recharge")
    }
    ::Tactical_GrappleEnd <- function(p)
    {
        local s=Tactical_State(p)
        if(!s.pending)return // return animation / repeated cleanup cannot restart it
        s.pending=false
        s.gDuration=s.latched ? Tactical.settings.grappleSeconds : Tactical.settings.missSeconds
        s.gEnd=Time()+s.gDuration
    }
    ::Tactical_Boost <- function(p,now)
    {
        local s=Tactical_State(p)
        s.bDuration=Tactical.settings.boostSeconds;s.bEnd=now+s.bDuration;s.bCooling=true
        // Exact accepted-impulse event, independent of the slower audio observer.
        try{EmitSoundOnEntityOnlyToPlayer(p,p,"TACPM.slide.boost")}catch(error){Tactical.error=error.tostring()}
    }
    ::Tactical_Reset <- function(p)
    {
        // Death/spawn reset AFTER detachment, so no shorter miss recovery wins.
        if("TACGrapple_Detach" in getroottable())TACGrapple_Detach(p,"lifecycle")
        if("tacGrapple" in p.s)p.s.tacGrapple.held=false
        if("tacSlideState" in p.s){p.s.tacSlideState.active=false;p.s.tacSlideState.grounded=false;p.s.tacSlideState.airStarted=-1.0}
        if("tacSlideHeld" in p.s){p.s.tacSlideHeld=false;p.s.tacSlideToggled=false}
        local s=Tactical_State(p);local now=Time();local cfg=Tactical.settings
        s.pending=false;s.latched=false
        s.gDuration=cfg.grappleSeconds;s.gEnd=now+s.gDuration;s.gCooling=s.gDuration>0
        s.bDuration=cfg.boostSeconds;s.bEnd=now+s.bDuration;s.bCooling=s.bDuration>0
        s.wasAlive=IsAlive(p)
    }
    ::Tactical_OnDeath <- function(p,damageInfo){if(IsValid(p))Tactical_Reset(p)}
    ::Tactical_Percent <- function(deadline,duration,now)
    {
        if(duration<=0.0)return 100
        return (100.0*max(0.0,min(1.0,1.0-(deadline-now)/duration))).tointeger()
    }
    ::Tactical_Run <- function()
    {
        while(!("GetPlayerArray" in getroottable()) || !("AddDeathCallback" in getroottable()) || !("AddCallback_OnPlayerRespawned" in getroottable()) || !("AddCallback_OnClientDisconnected" in getroottable()))wait 0.1
        while(!("deathCallbacks" in level) || !("onPlayerRespawnedCallbacks" in level) || !("onClientDisconnectingCallbacks" in level))wait 0.1
        AddDeathCallback("player",Tactical_OnDeath)
        AddCallback_OnPlayerRespawned(Tactical_OnSpawn)
        AddCallback_OnClientDisconnected(Tactical_OnDisconnect)
        while(Tactical.enabled)
        {
            local allowed=Tactical_Allowed();local now=Time();Tactical.sequence++
            foreach(p in GetPlayerArray())if(IsValid(p))
            {
                local s=Tactical_State(p)
                if(!allowed)
                {
                    if("TACGrapple_Detach" in getroottable())TACGrapple_Detach(p,"conflict")
                    if(IsValid(s.marker))s.marker.Kill()
                    s.marker=null
                    continue
                }
                local alive=IsAlive(p)
                if(s.wasAlive && !alive)Tactical_Reset(p) // callback fallback
                s.wasAlive=alive
                local eligible=alive && !p.IsTitan() && GetMapName()!="mp_lobby"
                local busy=s.pending
                if("tacGrapple" in p.s)busy=busy || p.s.tacGrapple.active || p.s.tacGrapple.missActive
                local selected=Tactical_HasGrapple(p)
                local gReady=selected && !busy && now>=s.gEnd
                local bReady=now>=s.bEnd && Tactical.settings.boostAdd>0.0 && Tactical.settings.boostCap>0.0
                if(s.gCooling && !busy && now>=s.gEnd){if(eligible && selected)Tactical_Sound(p,"ready");s.gCooling=false}
                if(s.bCooling && now>=s.bEnd){if(eligible && bReady)Tactical_Sound(p,"ready");s.bCooling=false}
                if(!eligible)
                {
                    if(IsValid(s.marker))s.marker.Kill()
                    s.marker=null
                    continue
                }
                // Read-only client display: percentages from server time, no client
                // deadlines/settings or client-originated readiness messages.
                if(!IsValid(s.marker))
                {
                    s.marker=CreateEntity("info_target");s.marker.SetOwner(p)
                    s.marker.kv.spawnflags=1;s.marker.SetOrigin(p.EyePosition())
                    DispatchSpawn(s.marker);AddOwnedEntity(p,s.marker)
                }
                s.marker.SetOrigin(p.EyePosition())
                local gp=!selected ? -1 : (s.pending ? 0 : Tactical_Percent(s.gEnd,s.gDuration,now))
                local bp=Tactical_Percent(s.bEnd,s.bDuration,now)
                s.marker.SetName("tactical_status:"+Tactical.sequence+":"+gp+":"+bp+":"+(gReady ? 1 : 0)+":"+(bReady ? 1 : 0))
            }
            wait 0.1
        }
    }
    IncludeScript("tactical/settings",getroottable())
    thread Tactical_Run()
}
