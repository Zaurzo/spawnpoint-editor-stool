AddCSLuaFile()

ENT.Base = 'base_gmodentity'
ENT.Type = 'anim'

function ENT:Initialize()
    self:SetModel('models/editor/playerstart.mdl')
    self:DrawShadow(false)
    self:AddEFlags(EFL_KEEP_ON_RECREATE_ENTITIES)
end

if CLIENT then
    local colorMat = Material('debug/debugdrawflat')

    function ENT:DrawRegular()
        render.SuppressEngineLighting(true)
        render.SetColorModulation(1, 1, 1)
    
        self:DrawModel()

        render.SuppressEngineLighting(false)
        render.MaterialOverride()
    end

    function ENT:Draw()
        if IsValid(_SpawnPointEditorV2Window) and _SpawnPointEditorV2Window.selected == self then
            return self:DrawRegular()
        end

        local ply = LocalPlayer()
        if not ply:IsValid() or not ply:Alive() then return end

        local owner = self:GetOwner()
        if ply ~= owner and owner:IsValid() and not ply:IsAdmin() then return end

        local tool = ply:GetTool()
        if not tool then return end

        local name = tool.Name
        if name ~= '#tool.spawnpoint_editor.name' then return end

        local wep = ply:GetActiveWeapon()
        if not wep:IsValid() or wep:GetClass() ~= 'gmod_tool' then return end

        render.SuppressEngineLighting(true)

        if self:GetNWBool('PointSelected') then
            render.MaterialOverride(colorMat)
            render.SetColorModulation(1, 0, 0)
        else
            render.SetColorModulation(1, 1, 1)
        end
        
        self:DrawModel()

        render.SuppressEngineLighting(false)
        render.MaterialOverride()
    end
end