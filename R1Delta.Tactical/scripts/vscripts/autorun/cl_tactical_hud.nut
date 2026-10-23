IncludeScript("tactical/client",getroottable())
// Display-only observer. Never sends gameplay state, deadlines or configuration.
if("TacticalHUD_Stop" in getroottable())TacticalHUD_Stop()
::TacticalHUD <- {enabled=true,generation=UniqueString("tacticalHUD"),screens=[],icons=[],cockpit=null,
    signature="",seen=-10.0,error=null}
::TacticalHUD_Clear <- function()
{
    foreach(screen in TacticalHUD.screens)if(IsValid(screen))screen.Destroy()
    TacticalHUD.screens.clear();TacticalHUD.icons.clear();TacticalHUD.cockpit=null
}
::TacticalHUD_Stop <- function(){TacticalHUD.enabled=false;TacticalHUD_Clear()}
::TacticalHUD_Run <- function(generation)
{
    try
    {
        PrecacheHUDMaterial("HUD/tactical_grapple_hud")
        while(TacticalHUD.enabled && TacticalHUD.generation==generation)
        {
            local p=GetLocalClientPlayer();local values=null
            if(IsValid(p) && IsAlive(p) && !p.IsTitan() && IsValid(p.GetCockpit()))
            {
                local record="";local best=-1
                foreach(e in GetClientEntArrayBySignifier("info_target"))
                {
                    if(!IsValid(e) || e.GetOwner()!=p)continue
                    local name=e.GetName()
                    if(name.find("tactical_status:")!=0)continue
                    local fields=split(name,":")
                    if(fields.len()!=6)continue
                    local sequence=fields[1].tointeger()
                    if(sequence>best){record=name;values=fields;best=sequence}
                }
                if(record!="" && record!=TacticalHUD.signature)
                {
                    TacticalHUD.signature=record;TacticalHUD.seen=Time()
                }
                if(Time()-TacticalHUD.seen>0.6)values=null // missing/stale never looks ready
            }
            if(values==null)
            {
                TacticalHUD_Clear()
                if(IsValid(p))Tactical_UpdateNativeBar(p,0.0)
            }
            else
            {
                // Native lower-left tactical slot is the sole Grapple recharge display.
                // Boost readiness remains audible; no rails near the aiming point.
                local progress=max(0.0,min(1.0,values[2].tofloat()/100.0))
                Tactical_UpdateNativeBar(p,values[4]=="1" ? 1.0 : min(0.99,progress))
            }
            WaitFrame()
        }
    }
    catch(error)
    {
        TacticalHUD.error=error.tostring();TacticalHUD_Clear()
        printt("[TacticalHUD] Disabled after error:",error)
    }
}
thread TacticalHUD_Run(TacticalHUD.generation)
