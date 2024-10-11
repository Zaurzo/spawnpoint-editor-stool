if SERVER then
    AddCSLuaFile()

    local spawnpoints do
        local function getMapSpawnPoints()
            local map = 'maps/' .. game.GetMap()
            local data = file.Read(map .. '_l_0.lmp', 'GAME')

            if not data then
                local bsp = file.Open(map .. '.bsp', 'rb', 'GAME')
                if not bsp or bsp:Read(4) ~= 'VBSP' then return false end
    
                bsp:Size()
    
                local bspVersion = bsp:ReadLong()
                if bspVersion > 21 then return false end

                local pos, len
    
                if bspVersion ~= 21 then
                    pos, len = bsp:ReadLong(), bsp:ReadLong()
                else
                    local ofs = bsp:ReadLong()
                    local len = bsp:ReadLong()
                    local version = bsp:ReadLong()
    
                    if ofs <= 8 then
                        pos, len = len, version
                    else
                        pos, len = ofs, len
                    end
                end

                bsp:Seek(pos)

                data = bsp:Read(len)

                bsp:Close()
            end

            if not data then return false end

            if string.sub(data, 0, 4) == 'LZMA' then
                local size = string.sub(data, 5, 8)
                local lzmaSize do
                    local a, b, c, d = string.byte(string.sub(data, 9, 12), 1, 4)

                    if d then
                        lzmaSize = bit.bor(bit.lshift(d, 24), bit.lshift(c, 16), bit.lshift(b, 8), a)
                    elseif c then
                        lzmaSize = bit.bor(bit.lshift(c, 16), bit.lshift(b, 8), a)
                    elseif b then
                        lzmaSize = bit.bor(bit.lshift(b, 8), a)
                    else
                        lzmaSize = a
                    end
                end

                if lzmaSize <= 0 then return false end

                data = util.Decompress(string.sub(data, 13, 17) .. size .. '\0\0\0\0' .. string.sub(data, 18, 18 + lzmaSize)) or data
            end

            local spawnpoints = {}

            for entData in string.gmatch(string.gsub(data, '\n', ''), '%b{}') do
                local bspEntity = {}

                for key, value in string.gmatch(entData, '"(.-)".-"(.-)"') do
                    local tab = bspEntity[key]

                    if tab then
                        if istable(tab) then
                            tab[#tab + 1] = value
                        else
                            bspEntity[key] = { tab, value }
                        end
                    else
                        bspEntity[key] = value
                    end
                end

                if bspEntity.classname == 'info_player_start' then
                    local origin = bspEntity.origin

                    if origin then
                        bspEntity.origin = util.StringToType(origin, 'vector')
                    end

                    local angles = bspEntity.angles

                    if angles then
                        bspEntity.angles = util.StringToType(angles, 'angle')
                    end

                    spawnpoints[#spawnpoints + 1] = bspEntity
                end
            end

            return spawnpoints
        end

        spawnpoints = getMapSpawnPoints()
    end

    PrintTable(spawnpoints)

    local function reset(ignoreCreatedPoints)
        local filter = {} 
        local n = 1
        
        for k, ent in ipairs(ents.GetAll()) do
            local classname = ent:GetClass()

            if classname ~= 'info_player_start' then
                filter[n] = classname
                n = n + 1
            elseif not ignoreCreatedPoints and ent.IsFromSpawnPointEditor and ent:GetOwner():IsValid() and IsValid(ent:GetChildren()[1]) then
                ent:Remove()
            end
        end

        game.CleanUpMap(true, filter)
    end

    concommand.Add('spawnpoint_editor_removeall', function(ply)
        if not ply:IsAdmin() then return end

        for k, ent in ipairs(ents.GetAll()) do
            if ent:GetClass() == 'info_player_start' then
                ent:Remove()
            end
        end
    end)

    concommand.Add('spawnpoint_editor_removeall_created', function(ply)
        if not ply:IsAdmin() then return end

        for k, ent in ipairs(ents.GetAll()) do
            if ent.IsFromSpawnPointEditor and ent:GetClass() == 'info_player_start' and ent:GetOwner():IsValid() and IsValid(ent:GetChildren()[1]) then
                ent:Remove()
            end
        end
    end)

    concommand.Add('spawnpoint_editor_restore', function(ply)
        if ply:IsAdmin() then
            reset(true)
        end
    end)

    concommand.Add('spawnpoint_editor_reset', function(ply)
        if ply:IsAdmin() then
            reset()
        end
    end)
else
    function TOOL.BuildCPanel(panel)
        local isAdmin = LocalPlayer():IsAdmin()

        panel:Button('Remove All Your Spawn Points', 'spawnpoint_editor_removeall_created')

        if isAdmin then
            panel:Button('Remove All Existing Spawn Points', 'spawnpoint_editor_removeall')
            panel:Button('Restore Map Spawn Points', 'spawnpoint_editor_restore')
            panel:Button('Reset', 'spawnpoint_editor_reset')
        end
    end
end