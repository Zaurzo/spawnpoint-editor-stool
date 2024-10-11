TOOL.Name = '#tool.spawnpoint_editor.name'
TOOL.Category = 'Construction'
TOOL.Description = '#tool.spawnpoint_editor.desc'

TOOL.Information = {
    { name = 'left' },
    { name = 'right' },
    { name = 'reload' }
}

local angleSet = {
    Angle(),
    Angle(0, 90),
    Angle(0, 180),
    Angle(0, 270)
}

if SERVER then
    -- Main Functions

    local mapSpawnsRemoved = {}
    local savedFileName = 'spawnpoint_editor_v2.' .. game.GetMap() .. '.json'

    local function createSpawnPoint(pos, ang)
        local spawnPoint = ents.Create('info_player_start')
        if not spawnPoint:IsValid() then return end

        spawnPoint.IsFromSpawnPointEditor = true

        spawnPoint:SetPos(pos)
        spawnPoint:SetAngles(ang)
        spawnPoint:Spawn()

        timer.Simple(0, function()
            if spawnPoint:IsValid() then
                spawnPoint:AddEFlags(EFL_KEEP_ON_RECREATE_ENTITIES)
            end
        end)
    end

    hook.Add('InitPostEntity', 'spawnpoint_editor_v2_load_save', function()
        if not file.Exists(savedFileName, 'DATA') then return end

        local list = util.JSONToTable(file.Read(savedFileName, 'DATA'))
        if not list then return end

        local removeIds = {}

        for k, point in ipairs(list) do
            if point.removeid then
                removeIds[point.removeid] = true
            else
                createSpawnPoint(point.pos, point.ang)
            end
        end

        for k, ent in ipairs(ents.FindByClass('info_player_start')) do
            local hammerid = ent:GetInternalVariable('hammerid')

            if removeIds[hammerid] then
                mapSpawnsRemoved[hammerid] = true

                ent:Remove()
            end
        end
    end)

    hook.Add('ShutDown', 'spawnpoint_editor_v2_save', function()
        local points = {}

        for k, ent in ipairs(ents.FindByClass('info_player_start')) do
            local hammerid = ent:GetInternalVariable('hammerid')

            if mapSpawnsRemoved[hammerid] then
                mapSpawnsRemoved[hammerid] = nil
            elseif ent.IsFromSpawnPointEditor then
                table.insert(points, {
                    pos = ent:GetPos(),
                    ang = ent:GetAngles()
                })
            end
        end

        for id in pairs(mapSpawnsRemoved) do
            table.insert(points, { removeid = id })
        end

        file.Write(savedFileName, util.TableToJSON(points))
    end)

    function TOOL:Reload()
        local wep = self:GetWeapon()
        local index = wep:GetNWInt('SpawnPointEditorAngle', 1)

        index = index + 1

        if index > 4 then
            index = 1
        end

        wep.SpawnPointEditorAngle = angleSet[index]

        wep:SetNWInt('SpawnPointEditorAngle', index)
    end

    function TOOL:LeftClick(tr)
        createSpawnPoint(tr.HitPos, self:GetWeapon().SpawnPointEditorAngle or angleSet[1])

        return true
    end

    function TOOL:RightClick()
        local selected = self:GetWeapon().SpawnPointEditorSelected
        if not IsValid(selected) then return end

        local point = selected.SpawnPoint

        if not point then
            point = selected:GetParent()
        end

        local hammerid = point:GetInternalVariable('hammerid')

        if hammerid and hammerid ~= 0 then
            mapSpawnsRemoved[hammerid] = true
        end

        SafeRemoveEntity(point)
    end

    function TOOL:Think()
        local wep = self:GetWeapon()
        local tr = self:GetOwner():GetEyeTrace()

        local selected = wep.SpawnPointEditorSelected

        if IsValid(selected) then
            selected:SetNWBool('PointSelected', false)
        end

        for k, ent in ipairs(ents.FindAlongRay(tr.StartPos, tr.HitPos)) do
            if ent:GetClass() == 'spawnpoint_editor' then
                wep.SpawnPointEditorSelected = ent

                return ent:SetNWBool('PointSelected', true)
            end
        end

        wep.SpawnPointEditorSelected = nil
    end

    -- Hooks

    hook.Add('OnEntityCreated', 'SpawnPointEditor.SetupForEditor', function(spawnPoint)
        if spawnPoint:GetClass() ~= 'info_player_start' then return end

        timer.Simple(0, function()
            if not spawnPoint:IsValid() then return end

            local model = ents.Create('spawnpoint_editor')

            if spawnPoint.IsFromSpawnPointEditor and not model:IsValid() then
                return spawnPoint:Remove()
            end

            model:SetPos(spawnPoint:GetPos())
            model:SetAngles(spawnPoint:GetAngles())
            model:Spawn()
            model:SetParent(spawnPoint)

            model.SpawnPoint = spawnPoint
        end)
    end)

    hook.Add('PlayerSelectSpawn', 'SpawnPointEditor.AddSpawnPoints', function()
        local GM = gmod.GetGamemode()
        if not GM then return end

        local spawnPoints = GM.SpawnPoints
        if not spawnPoints or not istable(spawnPoints) then return end

        local lookup = {}

        for k, spawnPoint in ipairs(spawnPoints) do
            lookup[spawnPoint] = true
        end

        for k, spawnPoint in ipairs(ents.GetAll()) do
            if not lookup[spawnPoint] and spawnPoint:GetClass() == 'info_player_start' then
                table.insert(spawnPoints, spawnPoint)
            end
        end
    end)

    -- Console Commands

    local game_CleanUpMap = game.CleanUpMap

    local function reset(ignoreCreatedPoints)
        mapSpawnsRemoved = {}

        local filter = {}
        local n = 1

        for k, ent in ipairs(ents.GetAll()) do
            local classname = ent:GetClass()

            if classname ~= 'info_player_start' then
                filter[n] = classname
                n = n + 1
            elseif not ignoreCreatedPoints and ent.IsFromSpawnPointEditor and IsValid(ent:GetChildren()[1]) then
                ent:Remove()
            end
        end

        game_CleanUpMap(true, filter)
    end

    concommand.Add('spawnpoint_editor_removeall', function(ply)
        if not ply:IsSuperAdmin() then return end

        for k, ent in ipairs(ents.GetAll()) do
            if ent:GetClass() == 'info_player_start' then
                local hammerid = ent:GetInternalVariable('hammerid')

                if hammerid and hammerid ~= 0 then
                    mapSpawnsRemoved[hammerid] = true
                end

                ent:Remove()
            end
        end
    end)

    concommand.Add('spawnpoint_editor_removeall_map', function(ply)
        if not ply:IsSuperAdmin() then return end

        for k, ent in ipairs(ents.FindByClass('info_player_start')) do
            local hammerid = ent:GetInternalVariable('hammerid')

            if hammerid and hammerid ~= 0 then
                mapSpawnsRemoved[hammerid] = true

                ent:Remove()
            end
        end
    end)

    concommand.Add('spawnpoint_editor_removeall_created', function(ply)
        if not ply:IsSuperAdmin() then return end

        for k, ent in ipairs(ents.GetAll()) do
            if ent.IsFromSpawnPointEditor and ent:GetClass() == 'info_player_start' and IsValid(ent:GetChildren()[1]) then
                ent:Remove()
            end
        end
    end)

    concommand.Add('spawnpoint_editor_restore', function(ply)
        if ply:IsSuperAdmin() then
            reset(true)
        end
    end)

    concommand.Add('spawnpoint_editor_reset', function(ply)
        if ply:IsSuperAdmin() then
            reset()
        end
    end)

    function game.CleanUpMap(b, filter, ...)
        if not filter then
            filter = {}
        end

        filter[#filter + 1] = 'info_player_start'

        return game_CleanUpMap(b, filter, ...)
    end
else
    local csEnt
    local color_white = Color(255, 255, 255)
    local settings = { model = 'models/editor/playerstart.mdl' }

    language.Add('tool.spawnpoint_editor.name', 'Spawn Point Editor')
    language.Add('tool.spawnpoint_editor.desc', 'Create and delete spawn points within the map!')
    language.Add('tool.spawnpoint_editor.left', 'Create spawn point')
    language.Add('tool.spawnpoint_editor.right', 'Remove spawn point')
    language.Add('tool.spawnpoint_editor.reload', 'Rotate spawn point')

    surface.CreateFont('SpawnPointEditor', {
        font = 'Trebuchet24',
        size = 14,
        antialias = true,
        outline = true
    })

    surface.CreateFont('SpawnPointEditor.2', {
        font = 'Trebuchet24',
        size = 28,
        antialias = true,
        outline = true
    })

    function TOOL:DrawHUD()
        local pos, ang

        cam.Start3D()

        if not IsValid(csEnt) then
            csEnt = ClientsideModel('models/editor/playerstart.mdl')
            csEnt:SetNoDraw(true)
        else
            pos = LocalPlayer():GetEyeTrace().HitPos

            if pos then
                ang = angleSet[self:GetWeapon():GetNWInt('SpawnPointEditorAngle', 1)]

                settings.pos = pos
                settings.angle = ang

                render.SuppressEngineLighting(true)
                render.Model(settings, csEnt)
                render.SuppressEngineLighting(false)
            end
        end

        cam.End3D()
    end

    function TOOL.BuildCPanel(panel)
        if not LocalPlayer():IsSuperAdmin() then return end

        panel:Button('Remove All Existing Spawn Points', 'spawnpoint_editor_removeall')
        panel:Button('Remove All Map Spawn Points', 'spawnpoint_editor_removeall_map')
        panel:Button('Remove All Custom Spawn Points', 'spawnpoint_editor_removeall_created')
        panel:Button('Restore Map Spawn Points', 'spawnpoint_editor_restore')
        panel:Button('Reset', 'spawnpoint_editor_reset')
    end
end
