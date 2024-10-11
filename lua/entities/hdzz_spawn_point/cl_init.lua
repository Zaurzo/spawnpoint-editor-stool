include("shared.lua")

function ENT:Draw()
    local ply = LocalPlayer()

    local wep = ply:GetActiveWeapon()
    local tol = ply:GetTool()

    if !IsValid(wep) or wep:GetClass() ~= "gmod_tool" or !tol or tol.Name ~= "#Tool.hdzz_spawnpoint_editor.name" then return end
    if !self:GetNWBool("InfoPlayer_HDZZ",false) and self:GetNWString("SP_Owner") ~= tostring(ply:AccountID()) then return end

    self:DrawModel()
end