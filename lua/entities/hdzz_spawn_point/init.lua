AddCSLuaFile("cl_init.lua")
AddCSLuaFile("shared.lua")
include("shared.lua")

local x = Vector(15,15,38)
function ENT:Initialize()
    self:SetModel("models/editor/playerstart.mdl")
    self:DrawShadow(false)

    self:SetCollisionBounds(x,-x)
end