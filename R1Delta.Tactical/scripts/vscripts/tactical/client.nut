function Tactical_ClientHasGrapple(p)
{
    if(!IsValid(p) || p.IsTitan())return false
    local w=p.GetOffhandWeapon(1)
    return IsValid(w) && w.GetClassname()=="mp_ability_sonar" && w.HasMod("tactical_grapple")
}
// Only this custom tactical's native HUD bar is driven from server status.
function Tactical_UpdateNativeBar(p,fraction)
{
    if(!IsValid(p) || !IsValid(p.GetCockpit()))return
    local cockpit=p.GetCockpit()
    if(!("offhandHud" in cockpit.s) || !(1 in cockpit.s.offhandHud))return
    local hud=cockpit.s.offhandHud[1];local weapon=p.GetOffhandWeapon(1)
    if(!Tactical_ClientHasGrapple(p))
    {
        if("tacticalIcon" in hud && hud.tacticalIcon && IsValid(weapon))
        {
            local stock=weapon.GetWeaponInfoFileKeyField("hud_icon")
            hud.icon.SetImage(stock);hud.alert.SetImage(stock)
            hud.tacticalIcon=false
        }
        return
    }
    weapon.s.nextChargeTime <- 0.0 // stock HUD skips its automatic progress source
    hud.icon.SetImage("HUD/tactical_grapple_hud")
    hud.alert.SetImage("HUD/tactical_grapple_hud")
    hud.tacticalIcon <- true
    hud.showBar=true;hud.count.Hide()
    hud.bar.SetBarProgressSource(ProgressSource.PROGRESS_SOURCE_SCRIPTED)
    hud.bar.SetBarProgressRemap(0.0,1.0,0.0,1.0)
    hud.bar.SetBarProgressAndRate(max(0.0,min(1.0,fraction)),0.0)
    hud.bar.Show()
}
