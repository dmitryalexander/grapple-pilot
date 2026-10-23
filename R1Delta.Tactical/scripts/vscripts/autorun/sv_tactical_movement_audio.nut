if (!("Tactical" in getroottable())) IncludeScript("tactical/server",getroottable())
// Audio-only observer: never writes movement, grapple, rope or control state.
if("TACMovementAudio_Stop" in getroottable())TACMovementAudio_Stop()
::TACMovementAudio <- {enabled=true,generation=UniqueString("audio"),actors=[],error=null,events={},frames=0}
::TACMovementAudio_Emit <- function(p,event)
{
    EmitSoundOnEntityOnlyToPlayer(p,p,"TACPM."+event)
    if(!(event in TACMovementAudio.events))TACMovementAudio.events[event] <- 0
    TACMovementAudio.events[event]++
}
::TACMovementAudio_StopLoop <- function(p,event)
{
    if(IsValid(p) && event!="")StopSoundOnEntity(p,"TACPM."+event)
}
::TACMovementAudio_Stop <- function()
{
    TACMovementAudio.enabled=false
    foreach(a in TACMovementAudio.actors)if(IsValid(a.player))
    {
        TACMovementAudio_StopLoop(a.player,a.loop)
        TACMovementAudio_StopLoop(a.player,"slide.start."+a.surface)
    }
}
::TACMovementAudio_Surface <- function(name,grapple=false)
{
    name=name.tolower()
    if(name.find("wood")!=null)return "wood"
    if(name.find("sand")!=null)return "sand"
    if(name.find("mud")!=null || name.find("slime")!=null)return "mud"
    if(name.find("water")!=null || name.find("splash")!=null)return grapple ? "default" : "water"
    if(name.find("grass")!=null || name.find("foliage")!=null || name.find("brush")!=null)return grapple ? "dirt" : "grass"
    if(name.find("dirt")!=null || name.find("snow")!=null || name.find("carpet")!=null)return "dirt"
    if(name.find("metal")!=null || name.find("grate")!=null || name.find("vent")!=null || name.find("chain")!=null)return "solidmetal"
    return "concrete"
}
::TACMovementAudio_Ground <- function(p)
{
    local origin=p.GetOrigin()
    local t=TraceLine(origin+Vector(0,0,8),origin-Vector(0,0,48),p,TRACE_MASK_SHOT,TRACE_COLLISION_GROUP_NONE)
    return TACMovementAudio_Surface(t.surfaceName)
}
::TACMovementAudio_HookSurface <- function(p,g)
{
    local normal=("hookNormal" in g) ? g.hookNormal : Vector(0,0,1)
    local t=TraceLine(g.anchor+normal*6,g.anchor-normal*6,p,TRACE_MASK_SHOT,TRACE_COLLISION_GROUP_NONE)
    return TACMovementAudio_Surface(t.surfaceName,true)
}
::TACMovementAudio_State <- function(p)
{
    foreach(a in TACMovementAudio.actors)if(a.player==p)return a
    local a={player=p,phase="idle",shot=-1.0,attach=-1,loop="",slide=false,surface="concrete",hookSurface="concrete",speed=0.0,bumpAt=-10.0,boostAt=-1000.0}
    TACMovementAudio.actors.append(a)
    return a
}
::TACMovementAudio_Update <- function(p)
{
    local a=TACMovementAudio_State(p)
    local eligible=Tactical_Allowed() && GetMapName()!="mp_lobby" && IsPrivateMatch() && IsAlive(p) && p.IsHuman() && !p.IsTitan()
    if(!eligible)
    {
        TACMovementAudio_StopLoop(p,a.loop)
        if(a.slide)TACMovementAudio_StopLoop(p,"slide.start."+a.surface)
        a.loop="";a.slide=false;a.phase="idle";a.shot=-1.0;a.attach=-1
        return
    }
    local g=("tacGrapple" in p.s) ? p.s.tacGrapple : null
    local phase=g!=null ? g.phase : "idle"
    local deployed=phase!="idle"
    if(g!=null && deployed && g.started!=a.shot)
    {
        // Release-return also updates started; it is not a second shot.
        if(phase!="release_return" && phase!="miss_return")TACMovementAudio_Emit(p,"grapple.fire")
        a.shot=g.started
    }
    if(g!=null && (phase=="clamped" || phase=="pulling") && g.attachCount!=a.attach)
    {
        a.hookSurface=TACMovementAudio_HookSurface(p,g)
        TACMovementAudio_Emit(p,"grapple.impact."+a.hookSurface)
        a.attach=g.attachCount
    }
    local returning=phase=="release_return" || phase=="miss_return"
    local loop=phase=="pulling" ? "grapple.traverse" : (returning ? "grapple.retract" : "")
    if(loop!=a.loop)
    {
        TACMovementAudio_StopLoop(p,a.loop)
        if(loop!="")TACMovementAudio_Emit(p,loop)
        a.loop=loop
    }
    if(returning && (a.phase=="pulling" || a.phase=="clamped"))TACMovementAudio_Emit(p,"grapple.extract."+a.hookSurface)
    if(phase=="idle" && a.phase!="idle")TACMovementAudio_Emit(p,"grapple.reset")
    a.phase=phase

    local slide=("TACSlide" in getroottable()) && TACSlide.enabled && ("tacSlideState" in p.s) && p.s.tacSlideState.active && p.IsOnGround() && !deployed
    // Boost jet is emitted directly only when the server accepts an impulse.
    local speed=p.GetVelocity().Length2D()
    if(slide)
    {
        local surface=TACMovementAudio_Ground(p)
        if(!a.slide)TACMovementAudio_Emit(p,"slide.start."+surface)
        else if(surface!=a.surface)
        {
            TACMovementAudio_StopLoop(p,"slide.start."+a.surface)
            TACMovementAudio_Emit(p,"slide.stop."+a.surface)
            TACMovementAudio_Emit(p,"slide.start."+surface)
        }
        else if(a.speed-speed>100.0 && Time()-a.bumpAt>0.2)
        {
            TACMovementAudio_Emit(p,"slide.bump."+surface);a.bumpAt=Time()
        }
        a.surface=surface
    }
    else if(a.slide)
    {
        TACMovementAudio_StopLoop(p,"slide.start."+a.surface)
        TACMovementAudio_Emit(p,"slide.stop."+a.surface)
    }
    a.slide=slide;a.speed=speed
}
::TACMovementAudio_Run <- function(generation)
{
    while(!("GetPlayerArray" in getroottable()) || !("EmitSoundOnEntityOnlyToPlayer" in getroottable()) || !("IsPrivateMatch" in getroottable()))wait 0.1
    while(TACMovementAudio.enabled && TACMovementAudio.generation==generation)
    {
        foreach(p in GetPlayerArray())if(IsValid(p))
        {
            try{TACMovementAudio_Update(p)}
            catch(err)
            {
                TACMovementAudio.error=err.tostring()
                local a=TACMovementAudio_State(p);TACMovementAudio_StopLoop(p,a.loop);a.loop=""
                TACMovementAudio_StopLoop(p,"slide.start."+a.surface);a.slide=false
            }
        }
        for(local i=TACMovementAudio.actors.len()-1;i>=0;i--)if(!IsValid(TACMovementAudio.actors[i].player))TACMovementAudio.actors.remove(i)
        TACMovementAudio.frames++
        WaitFrame()
    }
}
thread TACMovementAudio_Run(TACMovementAudio.generation)
