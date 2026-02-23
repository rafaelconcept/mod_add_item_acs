npcAttribute = {}

function npcAttribute:Init(window, npc)
    local contentPane = window.window.contentPane
    local npcUI = contentPane:GetChild("npcUI")
    local item = npcUI:GetChildAt(0)

    self.n30 = item:GetChild("n30")
    self.n31 = item:GetChild("n31")
    self.n32 = item:GetChild("n32")

    self.attribute = {
        'Charisma', 'Intelligence', 'Luck', 'Perception', 'Physique',
        'Mining', 'Social Contact', 'Fight', 'Farming', 'Art',
        'Qi', 'Building', 'Cooking', 'DouFa', 'Manual',
        'Medicine', 'DanQi', 'Fabao', 'Fight Skill', 'Formation',
    }

    local wuWei = CS.XiaWorld.g_emNpcBasePropertyType
    local attribute = CS.XiaWorld.g_emNpcSkillType
    self.props = {
        wuWei.Charisma, wuWei.Intelligence, wuWei.Luck, wuWei.Perception, wuWei.Physique,
        attribute.Mining, attribute.SocialContact, attribute.Fight, attribute.Farming, attribute.Art,
        attribute.Qi, attribute.Building, attribute.Cooking, attribute.DouFa, attribute.Manual,
        attribute.Medicine, attribute.DanQi, attribute.Fabao, attribute.FightSkill, attribute.Zhen,
    }

    self.attributeValue = {}

    if npc then
        print(npc.Name)
        self:GetWuWei(npc)
        self:GetAttribute(npc)
        self.baseData = npc.PropertyMgr.BaseData
        self.skillData = npc.PropertyMgr.SkillData
    else
        for _ = 1, #self.attribute do
            table.insert(self.attributeValue, 0)
        end
    end

    self.n30:RemoveChildrenToPool()
    self.n31:RemoveChildrenToPool()
    self.n32:RemoveChildrenToPool()

    for i = 1, #self.attribute do
        local item = self.n30:AddItemFromPool()
        local label = item:GetChild("label")
        label.text = self.attribute[i]
    end

    for i = 1, #self.attributeValue do
        local item = self.n31:AddItemFromPool()
        local intValue = math.floor(self.attributeValue[i])
        item.title = tostring(intValue)

        local input = item:GetChild("title")
        input.text = tostring(intValue)

        input.onChanged:Clear()
        input.onChanged:Add(function()
            local newValue = tonumber(input.text)
            if newValue then
                self.attributeValue[i] = newValue
                print(string.format("Attribute [%s] updated to %d", self.attribute[i], newValue))
            else
                print("Invalid input, please enter a number")
                input.text = tostring(self.attributeValue[i])
            end
        end)
    end

    for i = 1, #self.attribute do
        local item = self.n32:AddItemFromPool()
        item.title = "Modify"

        item.onClick:Clear()
        item.onClick:Add(function()
            print(string.format("Start modifying attribute [%s]: %s", self.attribute[i], self.attributeValue[i]))

            if i < 6 then
                self.baseData:SetBaseValue(self.props[i], self.attributeValue[i])
            else
                self.skillData:AddSkillLevelOverAddion(self.props[i], self.attributeValue[i])
            end
        end)
    end
end


function npcAttribute:GetWuWei(npc)
    for i = 1, math.min(5, #self.props) do
        local p = self.props[i]
        local value = npc.PropertyMgr.BaseData:GetValue(p)
        table.insert(self.attributeValue, value)
    end
end

function npcAttribute:GetAttribute(npc)
    for i = 6, #self.props do
        local p = self.props[i]
        local value = npc.PropertyMgr.SkillData:GetSkillLevel(p)
        table.insert(self.attributeValue, value)
    end
end

return npcAttribute
