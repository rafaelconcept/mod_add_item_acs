local Windows = GameMain:GetMod("Windows")
local home = Windows:CreateWindow("XiuXianHome")

-- Force load itemEditor module if not already loaded
if itemEditor == nil then
    pcall(function()
        require("itemEditor")
    end)
end

function home:OnInit()
    local function setText(target, value)
        if target == nil then
            return
        end
        pcall(function()
            target.title = value
        end)
        pcall(function()
            target.text = value
        end)
    end

    self.window.contentPane = UIPackage.CreateObject("XiuXianAssistant", "Home")
    self.window:Center()
    print("[XiuXian Assistant width]======>>>>", self.window.contentPane.width)
    print("[XiuXian Assistant height]======>>>>", self.window.contentPane.height)
    self.window.closeButton = self:GetChild("frame"):GetChild("n5");
    self.controller = self.window.contentPane:GetController("c1")
    self.title = self:GetChild("frame"):GetChild("title");
    self.title.text = string.format("XiuXian Assistant")
    self.bntAddItems = self:GetChild("bnt_1")
    self.bntNpcAttributes = self:GetChild("bnt_2")
    self.bntClose = self:GetChild("close")
    self.label = self:GetChild("label")
    self.wuwei = self:GetChild("wuwei")
    self.shuxing = self:GetChild("shuxing")

    setText(self.bntAddItems, "Add Items")
    setText(self.bntNpcAttributes, "NPC Attributes")
    setText(self.bntClose, "Close")
    setText(self.wuwei, "Max Base Stats")
    setText(self.shuxing, "Max Skills")
    self.label.text = string.format("Please select an NPC")

    -- Track current mode (0=AddItems, 1=NpcAttributes, 2=ItemEditor)
    self.currentMode = 0

    local function switchToAddItems()
        self.currentMode = 0
        pcall(function()
            self.controller.selectedIndex = 0
        end)
        setText(self.bntAddItems, "Add Items")
        setText(self.wuwei, "Max Base Stats")
        setText(self.shuxing, "Max Skills")
        self.label.text = "Item Manager"
        self.wuwei.onClick:Clear()
        self.shuxing.onClick:Clear()
        addItem:ArrowButton()
    end

    local function switchToNpcAttributes()
        self.currentMode = 1
        pcall(function()
            self.controller.selectedIndex = 1
        end)
        setText(self.bntAddItems, "Add Items")
        setText(self.wuwei, "Max Base Stats")
        setText(self.shuxing, "Max Skills")
        self.label.text = "Please select an NPC"
        
        self.npcList = self:GetChild("npcList")
        self:GetAllNpc()

        self.wuwei.onClick:Clear()
        self.shuxing.onClick:Clear()
        self.wuwei.onClick:Add(function()
            self:setWuWei()
        end)
        self.shuxing.onClick:Add(function()
            self:setAttribute()
        end)
    end

    local function switchToItemEditor()
        if itemEditor == nil or itemEditor.Init == nil then
            self.label.text = "Item Editor module not available"
            return
        end
        
        self.currentMode = 2
        pcall(function()
            self.controller.selectedIndex = 2
        end)
        setText(self.bntAddItems, "Add Items")
        setText(self.wuwei, "Refresh Items")
        setText(self.shuxing, "Reload Selected")
        self.label.text = "Item Editor: click items to edit"

        self.wuwei.onClick:Clear()
        self.shuxing.onClick:Clear()
        self.wuwei.onClick:Add(function()
            pcall(function()
                itemEditor:ReloadItems(self)
            end)
        end)
        self.shuxing.onClick:Add(function()
            pcall(function()
                itemEditor:ReloadSelected(self)
            end)
        end)

        pcall(function()
            itemEditor:Init(self)
        end)
    end

    -- Add Items button - stays as Add Items, always goes to state 0
    self.bntAddItems.onClick:Add(function()
        switchToAddItems()
    end)

    -- NPC Attributes button - toggle between NPC and Item Editor
    self.bntNpcAttributes.onClick:Add(function()
        if self.currentMode == 1 then
            -- Currently in NPC mode, switch to Item Editor
            if itemEditor == nil or itemEditor.Init == nil then
                self.label.text = "Item Editor NOT LOADED"
                return
            end
            switchToItemEditor()
        else
            -- Not in NPC mode, switch to NPC
            switchToNpcAttributes()
        end
    end)

    self.bntClose.onClick:Add(function()
        self:Hide()
    end)

    addItem:Init(self)
    npcAttribute:Init(self, self.npc)

    -- Force load itemEditor if not already loaded
    if itemEditor == nil or itemEditor.Init == nil then
        -- Try multiple loading strategies
        local loaded = false
        
        -- Strategy 1: require with different paths
        pcall(function()
            itemEditor = require("itemEditor")
            loaded = true
        end)
        
        -- Strategy 2: dofile with mod path
        if not loaded or itemEditor == nil then
            local modPath = GameMain:GetModPath("XiuXianAssistant")
            if modPath then
                pcall(function()
                    dofile(modPath .. "/Scripts/Window/itemEditor.lua")
                    loaded = itemEditor ~= nil
                end)
            end
        end
        
        -- Strategy 3: loadfile with mod path
        if not loaded or itemEditor == nil then
            local modPath = GameMain:GetModPath("XiuXianAssistant")
            if modPath then
                pcall(function()
                    local loader = loadfile(modPath .. "/Scripts/Window/itemEditor.lua")
                    if loader then
                        loader()
                        loaded = itemEditor ~= nil
                    end
                end)
            end
        end
        
        if itemEditor == nil then
            self.label.text = "ERROR: itemEditor module not loading"
        end
    end

end

function home:setWuWei()
    local propMgr = self.npc.PropertyMgr.BaseData
    local enum = CS.XiaWorld.g_emNpcBasePropertyType
    local props = {
        enum.Charisma,
        enum.Intelligence,
        enum.Luck,
        enum.Perception,
        enum.Physique,
    }
    local maxValue = 2000
    for _, p in ipairs(props) do
        propMgr:SetBaseValue(p, maxValue)
    end
end

function home:setAttribute()
    local propMgr = self.npc.PropertyMgr.SkillData
    local enum = CS.XiaWorld.g_emNpcSkillType
    local props = {
        enum.Mining,
        enum.SocialContact,
        enum.Fight,
        enum.Farming,
        enum.Art,
        enum.Qi,
        enum.Building,
        enum.Cooking,
        enum.DouFa,
        enum.Manual,
        enum.Medicine,
        enum.DanQi,

        --enum.Fabao,
        --enum.FightSkill,
        --enum.Zhen,
    }
    local maxValue = 2000
    for _, p in ipairs(props) do
        propMgr:AddSkillLevelAddion(p, maxValue)
    end
end

function home:GetAllNpc()
    self.npcList:RemoveChildrenToPool()
    local data = Map.Things
    if data ~= nil then
        local npcs = data:GetActiveNpcs()
        print("Active NPC count:", npcs.Count)

        self.selectedItem = nil

        for i = 0, npcs.Count - 1 do
            local npc = npcs[i]
            print("NPC name:", npc.Name, "ID:", npc.ID)
            local item = self.npcList:AddItemFromPool()
            item.title = npc.Name

            item.grayed = false

            item.onClick:Add(function()
                print("Selected NPC:", npc.Name)
                self.npc = npc
                self.label.text = string.format("Current selected NPC: %s", npc.Name)

                if self.selectedItem and self.selectedItem ~= item then
                    self.selectedItem.grayed = false
                end

                item.grayed = true
                self.selectedItem = item

                npcAttribute:Init(self, npc)
            end)
        end
    else
        print("ThingsData is not initialized, Instance is nil")
    end
end
