util.AddNetworkString('spawnpoint_editor')
util.AddNetworkString('spawnpoint_editor_action')

net.Receive('spawnpoint_editor', function(len, ply)
    if not ply:IsSuperAdmin() then return end

    local point = net.ReadEntity()
    if not point:IsValid() then return end

    ply:SetPos(point:GetPos())
    ply:SetEyeAngles(point:GetAngles())
end)

net.Receive('spawnpoint_editor_action', function(len, ply)
    if not ply:IsSuperAdmin() then return end

    local point = net.ReadEntity()
    if not point:IsValid() then return end

    local int = net.ReadUInt(2)

    if int == 1 then
        point:SetPos(net.ReadVector())
    elseif int == 2 then
        point:SetAngles(net.ReadAngle())
    else
        point:Remove()
    end
end)
