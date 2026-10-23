IncludeScript("tactical/client",getroottable())
// Camera-attached HUD ring; world debug lines trail during camera rotation.
if("TACGrappleAim_Stop" in getroottable())TACGrappleAim_Stop()
if(!("TACGrappleAim" in getroottable()))
    ::TACGrappleAim <- {generation=0,enabled=false,validTarget=false,error=null}
if(!("screen" in TACGrappleAim))TACGrappleAim.screen <- null
if(!("circle" in TACGrappleAim))TACGrappleAim.circle <- null
if(!("cockpit" in TACGrappleAim))TACGrappleAim.cockpit <- null
TACGrappleAim.xScreen <- null
TACGrappleAim.xIcon <- null
TACGrappleAim.generation++
TACGrappleAim.enabled=true
TACGrappleAim.error=null
TACGrappleAim.stage <- "starting"
TACGrappleAim.xScale <- 1.0
TACGrappleAim.lastTime <- Time()
TACGrappleAim.connected <- false
TACGrappleAim.attached <- false
TACGrappleAim.phase <- "idle"
::TACGrappleAim_Stop <- function()
{
    TACGrappleAim.enabled=false
    TACGrappleAim.generation++
    if(IsValid(TACGrappleAim.screen))TACGrappleAim.screen.Destroy()
    if("xScreen" in TACGrappleAim && IsValid(TACGrappleAim.xScreen))TACGrappleAim.xScreen.Destroy()
    TACGrappleAim.screen=null
    TACGrappleAim.circle=null
    TACGrappleAim.cockpit=null
    TACGrappleAim.xScreen=null
    TACGrappleAim.xIcon=null
}
::TACGrappleAim_Run <- function(generation)
{
    try
    {
        TACGrappleAim.stage="precache"
        PrecacheHUDMaterial("HUD/crosshairs/titan_shotgun_circle_single")
        PrecacheHUDMaterial("HUD/crosshairs/hit_indicator")
        TACGrappleAim.stage="waiting for pilot"
        while(TACGrappleAim.enabled && TACGrappleAim.generation==generation)
        {
            local p=GetLocalClientPlayer()
            if(IsValid(p) && IsAlive(p) && Tactical_ClientHasGrapple(p) && IsValid(p.GetCockpit()))
            {
                local cockpit=p.GetCockpit()
                if(!IsValid(TACGrappleAim.screen) || TACGrappleAim.cockpit!=cockpit)
                {
                    if(IsValid(TACGrappleAim.screen))TACGrappleAim.screen.Destroy()
                    if(IsValid(TACGrappleAim.xScreen))TACGrappleAim.xScreen.Destroy()
                    TACGrappleAim.stage="create screen"
                    TACGrappleAim.screen=Create_PilotVGUI("vgui_icon",cockpit,p,3.0,3.0)
                    TACGrappleAim.cockpit=cockpit
                    TACGrappleAim.stage="get circle"
                    TACGrappleAim.circle=HudElement("CenterIcon",TACGrappleAim.screen.GetPanel())
                    TACGrappleAim.circle.SetImage("HUD/crosshairs/titan_shotgun_circle_single")
                    TACGrappleAim.xScreen=Create_PilotVGUI("vgui_icon",cockpit,p,30.0,30.0)
                    TACGrappleAim.xIcon=HudElement("CenterIcon",TACGrappleAim.xScreen.GetPanel())
                    TACGrappleAim.xIcon.SetImage("HUD/crosshairs/hit_indicator")
                    TACGrappleAim.xIcon.SetColor(255,255,255,255)
                    TACGrappleAim.xBaseWidth <- TACGrappleAim.xIcon.GetWidth().tofloat()
                    TACGrappleAim.xBaseHeight <- TACGrappleAim.xIcon.GetHeight().tofloat()
                    TACGrappleAim.xBasePos <- TACGrappleAim.xIcon.GetPos()
                    TACGrappleAim.xScale=1.0
                }
                local eye=p.EyePosition()
                local forward=p.GetViewVector()
                local connected=false
                local attached=false
                local phase="idle"
                local phaseTime=-1.0
                foreach(target in GetClientEntArrayBySignifier("info_target"))
                {
                    if(target.GetOwner()!=p)continue
                    local name=target.GetName()
                    if(name.find("tactical_grapple_active")==0)
                    {
                        connected=true
                        if(name.find("tactical_grapple_active_attached")==0)attached=true
                    }
                    if(name.find("tactical_grapple_anim:")==0)
                    {
                        local fields=split(name,":")
                        if(fields.len()>=6 && fields[2].tofloat()>=phaseTime)
                        {
                            phaseTime=fields[2].tofloat()
                            phase=fields[1]
                        }
                    }
                }
                // Use the cable's coherent phase record first. In particular,
                // a release record wins over an older replicated active marker.
                if(phaseTime>=0)
                {
                    connected=phase=="hit" || phase=="attached"
                    attached=phase=="attached"
                }
                else phase=attached ? "attached" : (connected ? "hit" : "idle")
                TACGrappleAim.connected <- connected
                TACGrappleAim.attached <- attached
                TACGrappleAim.phase=phase
                local now=Time()
                local dt=max(0.0,min(0.1,now-TACGrappleAim.lastTime))
                TACGrappleAim.lastTime=now
                // Deployed retains its accepted size; clamp draws inward over .10s.
                local targetScale=attached ? 0.65 : 1.0
                if(!attached)TACGrappleAim.xScale=1.0
                else TACGrappleAim.xScale=max(targetScale,TACGrappleAim.xScale-dt*3.5)
                local width=TACGrappleAim.xBaseWidth*TACGrappleAim.xScale
                local height=TACGrappleAim.xBaseHeight*TACGrappleAim.xScale
                TACGrappleAim.xIcon.SetSize(width,height)
                TACGrappleAim.xIcon.SetPos(TACGrappleAim.xBasePos[0]+(TACGrappleAim.xBaseWidth-width)*0.5,TACGrappleAim.xBasePos[1]+(TACGrappleAim.xBaseHeight-height)*0.5)
                local surfaceMask=TRACE_MASK_SHOT & ~(CONTENTS_MONSTER | CONTENTS_HITBOX | CONTENTS_PLAYERCLIP | CONTENTS_MONSTERCLIP)
                local hit=TraceLine(eye,eye+forward*1650.0,p,surfaceMask,TRACE_COLLISION_GROUP_NONE)
                local valid=hit.fraction<1.0 && !hit.startSolid && !hit.hitSky && (hit.endPos-eye).Length()>=33.0
                TACGrappleAim.validTarget=valid
                TACGrappleAim.circle.SetColor(valid ? 50 : 255,valid ? 240 : 255,valid ? 70 : 255,255)
                TACGrappleAim.xIcon.SetColor(255,255,255,255)
                if(connected)
                {
                    TACGrappleAim.circle.Hide()
                    TACGrappleAim.xIcon.Show()
                }
                else
                {
                    TACGrappleAim.circle.Show()
                    TACGrappleAim.xIcon.Hide()
                }
                TACGrappleAim.stage="running"
            }
            else
            {
                TACGrappleAim.connected=false
                TACGrappleAim.attached=false
                TACGrappleAim.phase="idle"
                if(TACGrappleAim.circle!=null)TACGrappleAim.circle.Hide()
                if(TACGrappleAim.xIcon!=null)TACGrappleAim.xIcon.Hide()
            }
            wait 0.016
        }
    }
    catch(error)
    {
        TACGrappleAim.error=error.tostring()
        TACGrappleAim.enabled=false
        if(IsValid(TACGrappleAim.screen))TACGrappleAim.screen.Destroy()
        if(IsValid(TACGrappleAim.xScreen))TACGrappleAim.xScreen.Destroy()
        TACGrappleAim.screen=null
        TACGrappleAim.circle=null
        printt("[TACGrappleAim] Disabled after error:",TACGrappleAim.stage,error)
    }
}
thread TACGrappleAim_Run(TACGrappleAim.generation)

