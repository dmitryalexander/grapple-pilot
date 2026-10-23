// Included into the server root by the Grapple autorun.
function Tactical_ActivateGrapple(player,weapon)
{
    if(!Tactical_Allowed() || !IsValid(player) || !IsAlive(player) || !Tactical_HasGrapple(player))return false
    if(!IsValid(weapon) || player.GetOffhandWeapon(1)!=weapon || weapon.GetWeaponOwner()!=player)return false
    if(player.GetCinematicEventFlags() & (CE_FLAG_CLASSIC_MP_SPAWNING | CE_FLAG_INTRO))return false
    local s=TACGrapple_State(player)
    if(!("lastTacticalPress" in s))s.lastTacticalPress <- -1000.0
    if(Time()-s.lastTacticalPress<0.15)return false
    s.lastTacticalPress=Time()
    if(s.active || s.missActive){TACGrapple_Detach(player,"cancelled");return true}
    try{TACGrapple_Fire(player)}
    catch(error){s.lastError <- error.tostring();TACGrapple_Detach(player,"fire error");return false}
    return s.active || s.missActive
}
