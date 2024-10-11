local PANEL = {}
local view = {}

local function nodeDoClick(self)
    local ent = self.ent
    if not IsValid(ent) then return end

    local parent = self.parent
    local pos, ang = ent:GetPos(), ent:GetAngles()

    parent:SetComponentValues('Position', pos.x, pos.y, pos.z)
    parent:SetComponentValues('Rotation', ang.x, ang.y, ang.z)

    parent.selected = ent
end

local function nodeDoDoubleClick(self)
    net.Start('spawnpoint_editor')
    net.WriteEntity(self.ent)
    net.SendToServer()
end

local function buttonDoClick(self)
    local selected = self.parent.selected
    if not IsValid(selected) then return end

    net.Start('spawnpoint_editor_action')
    net.WriteEntity(selected)
    net.WriteUInt(3, 2)
    net.SendToServer()
end

function PANEL:Init()
    if IsValid(_SpawnPointEditorV2Window) then
        _SpawnPointEditorV2Window:Remove()
    end

    _SpawnPointEditorV2Window = self

    self:SetSize(1000, 500)
    self:Center()
    self:MakePopup()
    self:SetTitle('Spawnpoint Editor')

    local dtree = self:Add('DTree')

    dtree:Dock(LEFT)
    dtree:SetSize(150, 500)

    local sidebar = self:Add('DPanel')

    sidebar:SetSize(235, 465)
    sidebar:SetPos(770, 30)

    sidebar.Paint = function() end

    self:ThreeComponent(sidebar, 'Position')
    self:ThreeComponent(sidebar, 'Rotation')

    local removeButton = self:Button(sidebar)

    removeButton.DoClick = buttonDoClick
    removeButton.parent = self

    removeButton:SetText('Remove Spawn Point')

    for k, ent in ipairs(ents.FindByClass('spawnpoint_editor')) do
        local node = dtree:AddNode('Spawn Point [' .. k .. ']')

        node.parent = self
        node.ent = ent
        node.Label.ent = ent

        node.DoClick = nodeDoClick
        node.Label.DoDoubleClick = nodeDoDoubleClick
    end

    local screen = self:Add('DPanel')

    screen:SetSize(500, 700)
    screen:SetPos(160, 30)

    screen.Paint = function()
        local selected = self.selected
        if not IsValid(selected) then return end

        local x, y = _frame:GetPos()
        local ang = selected:GetAngles()

        ang.y = ang.y + 180

        view.origin = selected:WorldSpaceCenter() + selected:GetForward() * 75 + vector_up * 5
        view.angles = ang
        view.x = x + 160
        view.y = y + 30
        view.w = 600
        view.h = 464
        view.drawviewmodel = false
        view.fov = 100

        local old = DisableClipping(true)

        render.RenderView(view)

        DisableClipping(old)
    end

    self.Tree = dtree
    self.Screen = screen
end

local function componentOnValueChange(self, ...)
    self.parent:ComponentValueChange(self.name, self.id, ...)
end

function PANEL:ThreeComponent(bar, name)
    local tab = {}

    if not self.ComponentTab then
        self.ComponentTab = {}
    end

    local label = bar:Add('DLabel')

    label:Dock(TOP)
    label:SetText(name)
    label:SetFont('SpawnPointEditor.2')
    label:DockMargin(0, 10, 0, 5)

    local contents = bar:Add('DSizeToContents')

    contents:SetSizeX(true)
    contents:Dock(TOP)
    contents:InvalidateLayout()

    for i = 1, 3 do
        local component = contents:Add('DTextEntry')

        component:SetText('0')
        component:Dock(LEFT)
        component:SetSize(74, 0)
        component:DockMargin(0, 0, 2, 0)

        component.id = i
        component.name = name
        component.parent = self

        component.OnValueChange = componentOnValueChange

        tab[i] = component
    end

    self.ComponentTab[name] = tab

    return tab
end

function PANEL:Button(bar)
    local contents = bar:Add('DSizeToContents')

    contents:SetSizeX(false)
    contents:Dock(TOP)
    contents:DockPadding(0, 0, 10, 0)
    contents:InvalidateLayout()
    contents:DockMargin(0, 15, 0, 0)

    local button = contents:Add('DButton')
    button:Dock(FILL)

    return button
end

function PANEL:SetComponentValues(name, val1, val2, val3)
    local componentTab = self.ComponentTab
    if not componentTab or not componentTab[name] then return end

    componentTab = componentTab[name]

    componentTab[1]:SetValue(val1)
    componentTab[2]:SetValue(val2)
    componentTab[3]:SetValue(val3)
end

function PANEL:ComponentValueChange(name, id, value)
    local selected = self.selected
    if not IsValid(selected) then return end

    value = tonumber(value)
    if not isnumber(value) then return end

    if name == 'Position' then
        local pos = selected:GetPos()
        pos[id] = value

        net.Start('spawnpoint_editor_action')
        net.WriteEntity(selected)
        net.WriteUInt(1, 2)
        net.WriteVector(pos)
        net.SendToServer()

        return
    end

    if name == 'Rotation' then
        local ang = selected:GetAngles()
        ang[id] = value

        net.Start('spawnpoint_editor_action')
        net.WriteEntity(selected)
        net.WriteUInt(2, 2)
        net.WriteAngle(ang)
        net.SendToServer()

        return
    end
end

concommand.Add('spawnpoint_editor_window', function()
    vgui.Create('SpawnPointEditor')
end)

derma.DefineControl('SpawnPointEditor', 'Spawnpoint Editor Window', PANEL, 'DFrame')
