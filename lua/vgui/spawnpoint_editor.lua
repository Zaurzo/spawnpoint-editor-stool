local PANEL = {}
local view = {}

local function nodeDoClick(self)
    self.parent.selected = self.ent
end

function PANEL:Init()
    _SpawnPointEditorV2Window = self

    self:SetSize(1000, 500)
    self:Center()
    self:MakePopup()
    self:SetTitle('Spawnpoint Editor')

    local dtree = self:Add('DTree')

    dtree:Dock(LEFT)
    dtree:SetSize(150, 500)

    for k, ent in ipairs(ents.FindByClass('spawnpoint_editor')) do
        local node = dtree:AddNode('Spawn Point [' .. k .. ']')

        node.parent = self
        node.ent = ent 

        node.DoClick = nodeDoClick
    end

    local screen = self:Add('DPanel')

    screen:SetSize(700, 700)
    screen:SetPos(160, 30)

    screen.Paint = function()
        local selected = self.selected
        if not IsValid(selected) then return end

        local x, y = _frame:GetPos()
        local ang = selected:GetAngles()

        draw.SimpleText('Position:', "SpawnPointEditor.2", 500, 50, color_white)

        ang.y = ang.y + 180

        view.origin = selected:WorldSpaceCenter() + selected:GetForward() * 75
        view.angles = ang
        view.x = x + 160
        view.y = y + 30
        view.w = 464
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

derma.DefineControl('SpawnPointEditor', 'Spawnpoint Editor Window', PANEL, 'DFrame')