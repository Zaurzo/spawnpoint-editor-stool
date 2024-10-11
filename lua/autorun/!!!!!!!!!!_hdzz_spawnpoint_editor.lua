local Player = FindMetaTable( "Player" )
local Entity = FindMetaTable( "Entity" )

local game_CleanupMap = game.CleanUpMap
local ents_FindByClass = ents.FindByClass
local ran = math.random
local hookAdd = hook.Add

local pairs = pairs

local SetPos = Entity.SetPos
local SetAng = Player.SetEyeAngles

local Remove = Entity.Remove
local Class = Entity.GetClass
local msg = Msg

local saveDir = "hdzz_spawn_point_editor/"..game.GetMap()

local function GetTool(ply)
    local wep = ply:GetWeapon('gmod_tool')
    if !IsValid(wep) then return nil end

    local tool = wep:GetToolObject()
    if !tool then return nil end

    return tool
end

if !file.Exists(saveDir, "DATA") then
    file.CreateDir(saveDir)
end

local function insert(tbl, val)
    tbl[#tbl+1] = val
end

local function SafeRemove(ent)
    if ent and ent:IsValid() then Remove(ent) end
end

local function AddModels()
    if CLIENT then return end

    local list = ents_FindByClass("info_player_start")

    for i = 1, #list do
        local spawnpoint = list[i]

        if !spawnpoint.HDZZ_Model then
            spawnpoint.HDZZ_Model = ents.Create("hdzz_spawn_point")

            local m = spawnpoint.HDZZ_Model
            m:SetModel("models/editor/playerstart.mdl")
            m:SetPos(spawnpoint:GetPos())
            m:SetAngles(spawnpoint:GetAngles())
            m:Spawn()

            m.Fake_Parent = spawnpoint
            m:SetNWBool("InfoPlayer_HDZZ", true)

            spawnpoint:DeleteOnRemove(m)
        end
    end
end

local function GetRandomSpawn()
    local points = {}

    local iplystr, hspwp = ents_FindByClass("info_player_start"), ents_FindByClass("hdzz_spawn_point")

    for i = 1, #iplystr do
        insert(points, iplystr[i])
    end

    for i = 1, #hspwp do
        local point = hspwp[i]
        local parent = point:GetParent()
        
        if !IsValid(parent) or parent:GetClass() ~= "info_player_start" then
            insert(points, point)
        end
    end

    local point = points[ran(#points)]
    if !point then return nil end
    
    return point:GetPos(), point:GetAngles()
end

local function RemoveGreenGuy(ply)
    if IsValid(ply.HDZZ_SpawnPoint) then
        ply.HDZZ_SpawnPoint:SetNoDraw(true)
    end 
end

game.CleanUpMap = function(send, filter, ...)
    if !filter then filter = {} end
    insert(filter,"hdzz_spawn_point")

    return game_CleanupMap(send, filter, ...)
end

Msg = function(txt, ...)
    if txt == "[PlayerSelectSpawn] Error! No spawn points!\n" and #ents_FindByClass("hdzz_spawn_point") > 0 then return end
    return msg(txt, ...)
end

Entity.Remove = function(self, ...)
    if IsValid(self) and Class(self) == "hdzz_spawn_point" and !self.Fake_Parent then return end
    return Remove(self, ...)
end

Entity.GetClass = function(self, ...)
    if IsValid(self) and Class(self, ...) == "hdzz_spawn_point" then return "info_player_start" end
    return Class(self, ...)
end

ents.FindByClass = function(class, ...)
    local foundEntities = ents_FindByClass(class, ...)

    if class == "info_player_start" then
        for index, point in pairs(ents_FindByClass("hdzz_spawn_point")) do
            if !point.Fake_Parent then insert(foundEntities,point) end
        end
    end

    return foundEntities
end

if SERVER then
    timer.Simple(0.1, function()
        AddModels()

        -- Initalize saved points
        local files, dirs = file.Find(saveDir.."/*", "DATA")

        for i = 1, #files do
            local fil = saveDir .. "/" .. files[i]
            local tabs = util.JSONToTable(file.Read(fil, "DATA"))

            for index, data in pairs(tabs) do
                local point = ents.Create("hdzz_spawn_point")
        
                if IsValid(point) then
                    point:SetPos(data.pos)
                    point:SetAngles(data.ang)
                    point:Spawn()
                    point:SetNWString("SP_Owner", data.owner)
                end
            end
        end
    end)
else
    surface.CreateFont( "HDZZ_Spawnpoint_Editor_Font", {
        font = "Trebuchet24",
        size = 14,
        antialias = true,
        outline = true,
    } )
end

hookAdd("OnEntityCreated", "hdzz_spawnpoint_editor_control", function(ent)
    if IsValid(ent) and Class(ent) == "hdzz_spawn_point" then
        ent.HDZZ_SpawnPoint_D = true
        ent.FullRemove = function(self, ply)
            if self and self:IsValid() then 
                if self.FullRemovedReload then
                    local tool = ply:GetActiveWeapon()
                    if IsValid(tool) and Class(tool) == "gmod_tool" then
                        if !ply.UndoList_HDZZ then ply.UndoList_HDZZ = {} end

                        ply.UndoList_HDZZ[#ply.UndoList_HDZZ+1] = {
                            pos = self:GetPos(),
                            ang = self:GetAngles(),
                            oid = self:GetNWString("SP_Owner"),
                        }
                    end
                end

                Remove(self) 
            end
        end
    end
end)

hookAdd("PlayerSelectSpawn", "hdzz_spawnpoint_editor_control", function(ply)
    local pos, ang = GetRandomSpawn()
    if !pos or !ang then return end

    SetPos(ply, pos)
    SetAng(ply, ang)
end)

local ts = tostring
local mf = math.floor
hookAdd("HUDPaint", "hdzz_spawn_editor_render", function()
    local ply = LocalPlayer()
    local tol = GetTool(ply)
    local wep = ply:GetActiveWeapon()
    local tr = ply:GetEyeTrace()
    local greenguy = ply.HDZZ_SpawnPoint

    if tr.HitNormal:Angle().x == -0.000 then RemoveGreenGuy(ply) return end
    if !IsValid(wep) or wep:GetClass() ~= "gmod_tool" or !tol or tol.Name ~= "#Tool.hdzz_spawnpoint_editor.name" then return end
    
    if !IsValid(greenguy) then return end

    local pos = greenguy:GetPos()
    local pos_ts = pos:ToScreen()

    local ang = greenguy:GetAngles()
    local x,y,z = mf(pos.x), mf(pos.y), mf(pos.z)

    draw.SimpleText("POS: "..x.." "..y.." "..z, "HDZZ_Spawnpoint_Editor_Font", pos_ts.x, pos_ts.y, Color(255,255,255), TEXT_ALIGN_CENTER)
    draw.SimpleText("ROT: "..mf(ang.y), "HDZZ_Spawnpoint_Editor_Font", pos_ts.x, pos_ts.y + 15, Color(255,255,255), TEXT_ALIGN_CENTER)
end)

hookAdd("PostDrawTranslucentRenderables", "hdzz_spawn_editor_render", function()
    local ply = LocalPlayer()
    local tol = GetTool(ply)
    local wep = ply:GetActiveWeapon()

    local tr = ply:GetEyeTrace()
    local pos = tr.HitPos

    local greenguy = ply.HDZZ_SpawnPoint

    if tr.HitNormal:Angle().x == -0.000 then RemoveGreenGuy(ply) return end
    if !IsValid(wep) or wep:GetClass() ~= "gmod_tool" or !tol or tol.Name ~= "#Tool.hdzz_spawnpoint_editor.name" then RemoveGreenGuy(ply) return end
    
    if !IsValid(greenguy) then
        ply.HDZZ_SpawnPoint = ents.CreateClientProp("models/editor/playerstart.mdl")
        ply.HDZZ_SpawnPoint:SetNoDraw(true)
    else
        greenguy:SetMaterial("lights/white002")
        greenguy:SetColor(Color(0,255,0))
        greenguy:SetPos(pos)
        greenguy:SetAngles(ply:GetNWAngle("spawnpoint_ang", Angle(0,0,0)))
        greenguy:SetNoDraw(false)
        greenguy:DrawShadow(false)
    end
end)

hookAdd("PlayerButtonDown", "HDZZ_spawn_point_editor_clear", function(ply, button)
    local tool = ply:GetActiveWeapon()
    local list = GetTool(ply)
    local name = list and list.Name or ""

    if tool and tool:IsValid() and tool:GetClass() == "gmod_tool" and name == "#Tool.hdzz_spawnpoint_editor.name" then
        if button == KEY_E then
            list.ClearPoints(tool, ply)
        elseif button == KEY_U then
            list.Undo(tool, ply)
        elseif button == KEY_P then
            if SERVER then
                if ply.UndoList_HDZZ or ply.UndoList_HDZZ_CLEAR then
                    ply.UndoList_HDZZ = nil
                    ply.UndoList_HDZZ_CLEAR = nil

                    net.Start("hdzz_spawn_editor_undo_notify")
                    net.Send(ply)
                end
            end
        elseif button == KEY_M then
            local list = ents_FindByClass("info_player_start")

            for i = 1, #list do
                local point = list[i]

                SafeRemove(point.HDZZ_Model)
                Remove(point)
            end
        end
    end
end)

hookAdd("PostCleanupMap", "hdzz_add_models_spe_control", function()
    AddModels()

    -- Extra measure
    timer.Simple(0.1, function()
        AddModels()
    end)
end)