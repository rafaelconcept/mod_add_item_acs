itemEditor = {}

local BindingFlags = CS.System.Reflection.BindingFlags

local function toText(value)
    if value == nil then
        return ""
    end
    return tostring(value)
end

local function getThingDisplayName(thing)
    if thing == nil then
        return "Unknown"
    end

    local displayName = nil
    local idName = nil

    pcall(function()
        if thing.def ~= nil then
            displayName = thing.def.ThingName
            idName = thing.def.Name
        end
    end)

    local displayText = toText(displayName)
    local idText = toText(idName)

    if displayText == "" or displayText == "LOST ITEM" then
        if idText ~= "" then
            return idText
        end
        return "Unknown"
    end

    if idText ~= "" and idText ~= displayText then
        return string.format("%s (%s)", displayText, idText)
    end
    return displayText
end

local function getThingMapKey(thing)
    local mapKey = nil
    pcall(function()
        mapKey = thing.Key
    end)
    if mapKey == nil then
        pcall(function()
            mapKey = thing.m_nKey
        end)
    end
    return mapKey
end

local function keyToXY(mapKey)
    if mapKey == nil or Map == nil or Map.Size == nil or Map.Size <= 0 then
        return nil, nil
    end
    local size = Map.Size
    local x = math.floor((mapKey - mapKey % size) / size) + 1
    local y = (mapKey % size) + 1
    return x, y
end

local function canEditType(typeName)
    if typeName == nil or typeName == "" then
        return false
    end
    if string.find(typeName, "System.Int", 1, true) then
        return true
    end
    if string.find(typeName, "System.Single", 1, true) then
        return true
    end
    if string.find(typeName, "System.Double", 1, true) then
        return true
    end
    if string.find(typeName, "System.Boolean", 1, true) then
        return true
    end
    if string.find(typeName, "System.String", 1, true) then
        return true
    end
    return false
end

local function convertInput(rawText, typeName)
    local text = tostring(rawText or "")

    if string.find(typeName, "System.Int", 1, true) then
        local numberValue = tonumber(text)
        if numberValue == nil then
            return nil
        end
        return math.floor(numberValue)
    end

    if string.find(typeName, "System.Single", 1, true) or string.find(typeName, "System.Double", 1, true) then
        return tonumber(text)
    end

    if string.find(typeName, "System.Boolean", 1, true) then
        local lower = string.lower(text)
        if lower == "1" or lower == "true" or lower == "yes" then
            return true
        end
        if lower == "0" or lower == "false" or lower == "no" then
            return false
        end
        return nil
    end

    return text
end

function itemEditor:Init(window)
    local contentPane = window.window.contentPane
    local npcUI = contentPane:GetChild("npcUI")
    local root = npcUI:GetChildAt(0)

    self.nameColumn = root:GetChild("n30")
    self.valueColumn = root:GetChild("n31")
    self.actionColumn = root:GetChild("n32")
    self.listWidget = window:GetChild("npcList")

    self.windowRef = window
    self.mapItems = {}
    self.attrEntries = {}
    self.currentThing = nil

    self:ReloadItems(window)
end

function itemEditor:ReloadItems(window)
    if self.listWidget == nil then
        return
    end

    self.listWidget:RemoveChildrenToPool()
    self.mapItems = {}

    local itemList = nil
    local otherList = nil
    pcall(function()
        itemList = ThingMgr:GetThingList(CS.XiaWorld.g_emThingType.Item)
    end)
    pcall(function()
        otherList = ThingMgr:GetThingList(CS.XiaWorld.g_emThingType.None)
    end)

    local function appendThings(things)
        if things == nil then
            return
        end
        for _, thing in pairs(things) do
            if thing ~= nil then
                table.insert(self.mapItems, thing)
            end
        end
    end

    appendThings(itemList)
    appendThings(otherList)

    for index, thing in ipairs(self.mapItems) do
        local item = self.listWidget:AddItemFromPool()
        local title = getThingDisplayName(thing)
        item.title = string.format("%d: %s", index, title)

        item.onClick:Clear()
        item.onClick:Add(function()
            self.currentThing = thing
            self:BuildAttributeEditor(window, thing)

            local mapKey = getThingMapKey(thing)
            local x, y = keyToXY(mapKey)
            if x ~= nil and y ~= nil then
                window.label.text = string.format("Selected item: %s @ (%d,%d)", title, x, y)
            else
                window.label.text = string.format("Selected item: %s", title)
            end
        end)
    end

    window.label.text = string.format("Item Editor: %d map items", #self.mapItems)
end

function itemEditor:ReloadSelected(window)
    if self.currentThing == nil then
        window.label.text = "Select an item first"
        return
    end
    self:BuildAttributeEditor(window, self.currentThing)
end

function itemEditor:BuildAttributeEditor(window, thing)
    if thing == nil then
        return
    end

    self.nameColumn:RemoveChildrenToPool()
    self.valueColumn:RemoveChildrenToPool()
    self.actionColumn:RemoveChildrenToPool()
    self.attrEntries = {}

    local function addEntry(entry)
        if entry == nil or entry.name == nil or entry.typeName == nil then
            return
        end
        if canEditType(entry.typeName) then
            table.insert(self.attrEntries, entry)
        end
    end

    pcall(function()
        local thingType = thing:GetType()
        local flags = BindingFlags.Instance | BindingFlags.Public

        local properties = thingType:GetProperties(flags)
        for i = 0, properties.Length - 1 do
            local prop = properties[i]
            local canRead = false
            local canWrite = false
            local indexCount = 0

            pcall(function()
                canRead = prop.CanRead
                canWrite = prop.CanWrite
                indexCount = prop:GetIndexParameters().Length
            end)

            if canRead and canWrite and indexCount == 0 then
                local value = nil
                local okRead = pcall(function()
                    value = prop:GetValue(thing, nil)
                end)
                if okRead and value ~= nil then
                    local typeName = tostring(prop.PropertyType.FullName)
                    addEntry({
                        name = "P:" .. tostring(prop.Name),
                        typeName = typeName,
                        valueText = toText(value),
                        apply = function(v)
                            prop:SetValue(thing, v, nil)
                        end
                    })
                end
            end
        end

        local fields = thingType:GetFields(flags)
        for i = 0, fields.Length - 1 do
            local field = fields[i]
            local value = nil
            local okRead = pcall(function()
                value = field:GetValue(thing)
            end)
            if okRead and value ~= nil then
                local typeName = tostring(field.FieldType.FullName)
                addEntry({
                    name = "F:" .. tostring(field.Name),
                    typeName = typeName,
                    valueText = toText(value),
                    apply = function(v)
                        field:SetValue(thing, v)
                    end
                })
            end
        end
    end)

    local maxRows = math.min(#self.attrEntries, 80)
    for index = 1, maxRows do
        local entry = self.attrEntries[index]

        local nameItem = self.nameColumn:AddItemFromPool()
        local typeLabel = entry.typeName
        if string.len(typeLabel) > 24 then
            typeLabel = string.sub(typeLabel, 1, 24) .. "..."
        end
        nameItem:GetChild("label").text = string.format("%d) %s", index, entry.name)

        local valueItem = self.valueColumn:AddItemFromPool()
        local valueInput = valueItem:GetChild("title")
        valueInput.text = tostring(entry.valueText)

        local actionItem = self.actionColumn:AddItemFromPool()
        actionItem.title = "Apply"
        actionItem.onClick:Clear()
        actionItem.onClick:Add(function()
            local converted = convertInput(valueInput.text, entry.typeName)
            if converted == nil then
                window.label.text = string.format("Invalid value for %s", entry.name)
                return
            end

            local okApply = pcall(function()
                entry.apply(converted)
            end)

            if okApply then
                window.label.text = string.format("Updated %s", entry.name)
            else
                window.label.text = string.format("Failed to update %s", entry.name)
            end
        end)
    end

    if #self.attrEntries == 0 then
        window.label.text = "No editable simple attributes found for selected item"
    end
end

return itemEditor