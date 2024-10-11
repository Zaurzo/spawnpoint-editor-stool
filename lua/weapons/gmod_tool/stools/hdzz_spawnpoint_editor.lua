TOOL.Category = "HDZZ Tools"
TOOL.Name = "#Tool.hdzz_spawnpoint_editor.name"
TOOL.Description = "#Tool.hdzz_spawnpoint_editor.desc"
TOOL.Information = {
    {name="left"},
    {name="right"},
    {name="blank"},
    {name="reload"},
    {name="use"},
    {name="info",icon="gui/hdzz/key_m.png"},
    {name="blank"},
    {name="info_1",icon="gui/hdzz/key_u.png"},
    {name="info_2",icon="gui/hdzz/key_p.png"},
}

TOOL.Icons = {
    "gui/hdzz/key_p.png",
    "gui/hdzz/key_u.png",
    "gui/hdzz/key_m.png",
}

if SERVER then
    util.AddNetworkString("hdzz_spawn_editor_undo_notify")
end

if CLIENT then
    language.Add("Tool.hdzz_spawnpoint_editor.name", "Spawnpoint Editor")
    language.Add("Tool.hdzz_spawnpoint_editor.desc", "Edit or Add Spawnpoints for this map!")

    language.Add("Tool.hdzz_spawnpoint_editor.left", "Add Spawnpoint")
    language.Add("Tool.hdzz_spawnpoint_editor.right", "Rotate Spawnpoint")
    language.Add("Tool.hdzz_spawnpoint_editor.reload", "Remove Spawnpoint")

    language.Add("Tool.hdzz_spawnpoint_editor.use", "Clear All Self-Made Spawnpoints")
    language.Add("Tool.hdzz_spawnpoint_editor.0", "Clear All Map Spawnpoints")
    language.Add("Tool.hdzz_spawnpoint_editor.info_1", "Undo Last Action")
    language.Add("Tool.hdzz_spawnpoint_editor.info_2", "Clear Undo List")

    language.Add("Tool.hdzz_spawnpoint_editor.blank", " ")

    net.Receive("hdzz_spawn_editor_undo_notify", function()
        LocalPlayer():EmitSound("hdzz/spawn_editor/undo_all.wav")
        notification.AddLegacy("Cleared Undo List!", 2, 3)
    end)
end

local saveDir = "hdzz_spawn_point_editor/"..game.GetMap()
local mapDir =  saveDir.."/"..game.GetMap()

local function DeleteList(ply)
    if !file.Exists(mapDir.."_"..tostring(ply:AccountID())..".json", "DATA") then return end
    file.Delete(mapDir.."_"..tostring(ply:AccountID())..".json")
end

local function RefreshList(ply)
    timer.Simple(0.1, function()
        local points = points or {}
        local list = ents.FindByClass("hdzz_spawn_point")

        if !file.Exists(saveDir, "DATA") then return end
        if #list <= 0 then DeleteList(ply) return end

        for i = 1, #list do
            local point = list[i]
            if point:GetNWBool("InfoPlayer_HDZZ", false) then continue end

            local pointTable = {
                pos = point:GetPos(),
                ang = point:GetAngles(),
                owner = point:GetNWString("SP_Owner"),
            }

            points[#points+1] = pointTable
        end

        local tab = util.TableToJSON(points, true)
        file.Write(mapDir.."_"..tostring(ply:AccountID())..".json", tab)
    end)
end

function TOOL:LeftClick()
    if CLIENT then return end

    local tr = self:GetOwner():GetEyeTrace()
    if tr.HitNormal:Angle().x == -0.000 then return false end

    local point = ents.Create("hdzz_spawn_point")
    point:SetPos(tr.HitPos)
    point:SetAngles(self:GetOwner():GetNWAngle("spawnpoint_ang", Angle(0,0,0)))
    point:Spawn()

    point:SetNWString("SP_Owner", tostring(self:GetOwner():AccountID()))
    RefreshList(self:GetOwner())

    return true
end

local angs = {
    Angle(0,0,0),
    Angle(0,90,0),
    Angle(0,180,0),
    Angle(0,270,0),
}

function TOOL:RightClick(tr)
    if CLIENT then return end

    local pre = self:GetOwner():GetNWAngle("spawnpoint_ang", Angle(0,0,0))
    local ang = pre == angs[1] and angs[2] or pre == angs[2] and angs[3] or pre == angs[3] and angs[4] or Angle(0,0,0)

    self:GetOwner():SetNWAngle("spawnpoint_ang",ang)
end

local function GetValidPoint(ply)
    local t = {}

    local _ents = ents.FindAlongRay( ply:GetShootPos(), ply:GetEyeTrace().HitPos, Vector(-5,-5,-38), Vector(5,5,38) )
    for i = 1, #_ents do
        local ent = _ents[i]
        
        if ent.HDZZ_SpawnPoint_D then
            t[#t+1] = ent
        end
    end

    return t[1]
end

function TOOL:Reload()
    if CLIENT then return end

    local point = GetValidPoint(self:GetOwner())
    if !IsValid(point) or (!point:GetNWBool("InfoPlayer_HDZZ",false) and point:GetNWString("SP_Owner") ~= tostring(self:GetOwner():AccountID())) then return end

    if IsValid(point.Fake_Parent) then
        point.Fake_Parent:Remove()
    end

    point.FullRemovedReload = true
    point:FullRemove(self:GetOwner())
    RefreshList(self:GetOwner())
end

function TOOL:Undo()
    if CLIENT then return end

    local ply = self:GetOwner()

    local list = ply.UndoList_HDZZ
    local list_clear = ply.UndoList_HDZZ_CLEAR

    if list_clear and #list_clear > 0 then
        for i = 1, #list_clear do
            local data = list_clear[i]
            local spawn = ents.Create("hdzz_spawn_point")

            spawn:SetPos(data.pos)
            spawn:SetAngles(data.ang)
            spawn:Spawn()
            spawn:SetNWString("SP_Owner", data.oid)
        end

        ply.UndoList_HDZZ_CLEAR = {}

        return
    end

    if list and #list > 0 then
        for index, data in pairs(list) do
            if data then
                local spawn = ents.Create("hdzz_spawn_point")
                spawn:SetPos(data.pos)
                spawn:SetAngles(data.ang)
                spawn:Spawn()
                spawn:SetNWString("SP_Owner", data.oid)
                ply.UndoList_HDZZ[index] = nil
            end

            return
        end
    end
end

function TOOL:ClearPoints()
    if CLIENT then return end

    local ply = self:GetOwner()
    ply.UndoList_HDZZ_CLEAR = {}

    local list_clear = ply.UndoList_HDZZ_CLEAR
    local list = ents.FindByClass("hdzz_spawn_point")

    for i = 1, #list do
        local spawnpoint = list[i]

        if spawnpoint:GetNWString("SP_Owner") == tostring(ply:AccountID()) then
            spawnpoint:FullRemove()

            list_clear[#list_clear+1] = {
                pos = spawnpoint:GetPos(),
                ang = spawnpoint:GetAngles(),
                oid = spawnpoint:GetNWString("SP_Owner"),
            }
        end
    end

    DeleteList(ply)
end