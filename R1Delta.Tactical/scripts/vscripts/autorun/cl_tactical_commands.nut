// Define namespaced commands after sign-on; never assign the user's keys/cvars.
::TACPM_LoadCommands <- function()
{
    while(!("GetLocalClientPlayer" in getroottable()))wait 0.1
    local p=GetLocalClientPlayer()
    while(!IsValid(p)){wait 0.1;p=GetLocalClientPlayer()}
    wait 0.5
    p.ClientCommand("exec tactical_commands")
    IncludeScript("autorun/cl_tactical_grapple_aim",getroottable())
    IncludeScript("autorun/cl_tactical_grapple_flight",getroottable())
    IncludeScript("autorun/cl_tactical_hud",getroottable())
}
thread TACPM_LoadCommands()
