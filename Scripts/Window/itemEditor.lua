-- Item Editor Module - must be global
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
    self.windowRef = window
    self.mapItems = {}
    self.attrEntries = {}
    self.currentThing = nil
    
    -- Use npcList as the item list widget
    self.listWidget = window:GetChild("npcList")
    
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

    -- Render the item list
    for index, thing in ipairs(self.mapItems) do
        local item = self.listWidget:AddItemFromPool()
        local title = getThingDisplayName(thing)
        
        -- Get coordinates
        local mapKey = getThingMapKey(thing)
        local x, y = keyToXY(mapKey)

        item.title = title

        item.onClick:Clear()
        item.onClick:Add(function()
            self.currentThing = thing
            self:BuildAttributeEditor(window, thing)
            
            -- Show full info when selected
            if x ~= nil and y ~= nil then
                window.label.text = string.format("✓ %s @ (%d,%d) | %d attrs", title, x, y, #self.attrEntries)
            else
                window.label.text = string.format("✓ %s | %d attrs", title, #self.attrEntries)
            end
        end)
    end

    window.label.text = string.format("Items: %d item(s)", #self.mapItems)
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
                        name = tostring(prop.Name),
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
                    name = tostring(field.Name),
                    typeName = typeName,
                    valueText = toText(value),
                    apply = function(v)
                        field:SetValue(thing, v)
                    end
                })
            end
        end
    end)

    -- Sort entries by name for readability
    table.sort(self.attrEntries, function(a, b)
        return a.name < b.name
    end)

    -- Update label to show attribute count
    if window.label then
        local title = getThingDisplayName(thing)
        window.label.text = string.format("Editing: %s | %d attributes", title, #self.attrEntries)
    end

    print("[Item Editor] Loaded " .. #self.attrEntries .. " attributes for item editing")
end

return itemEditor

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
    self.windowRef = window
    self.mapItems = {}
    self.filteredItems = {}
    self.attrEntries = {}
    self.currentThing = nil
    self.searchQuery = ""
    
    -- Use npcList as the item list widget
    self.listWidget = window:GetChild("npcList")
    
    self:ReloadItems(window)
end

function itemEditor:ReloadItems(window)
    if self.listWidget == nil then
        return
    end

    self.listWidget:RemoveChildrenToPool()
    self.mapItems = {}
    self.filteredItems = {}

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

    -- Apply filtering if search query exists
    self.filteredItems = self:FilterItems(self.searchQuery)
    self:RenderItemList(window)
end

function itemEditor:FilterItems(searchQuery)
    local query = string.lower(tostring(searchQuery or ""))
    local result = {}
    
    if query == "" then
        return self.mapItems
    end
    
    for _, thing in ipairs(self.mapItems) do
        local displayName = string.lower(getThingDisplayName(thing))
        if string.find(displayName, query, 1, true) then
            table.insert(result, thing)
        end
    end
    
    return result
end

function itemEditor:RenderItemList(window)
    self.listWidget:RemoveChildrenToPool()
    
    local itemsToShow = (#self.filteredItems > 0 or self.searchQuery ~= "") and self.filteredItems or self.mapItems
    
    for index, thing in ipairs(itemsToShow) do
        local item = self.listWidget:AddItemFromPool()
        local title = getThingDisplayName(thing)
        
        -- Get coordinates for later
        local mapKey = getThingMapKey(thing)
        local x, y = keyToXY(mapKey)

        item.title = title
        
        item.onClick:Clear()
        item.onClick:Add(function()
            self.currentThing = thing
            self:BuildAttributeEditor(window, thing)
            
            -- Show full info (name + location) when selected
            if x ~= nil and y ~= nil then
                window.label.text = string.format("✓ %s @ (%d,%d) | %d attrs", title, x, y, #self.attrEntries)
            else
                window.label.text = string.format("✓ %s | %d attrs", title, #self.attrEntries)
            end
        end)
    end

    local count = #itemsToShow
    local msg = string.format("Items: %d item(s)", count)
    if self.searchQuery ~= "" then
        msg = string.format("Items: %d/%d found", #self.filteredItems, #self.mapItems)
    end
    
    if window.label then
        window.label.text = msg
    end
end

function itemEditor:SearchItems(window, query)
    self.searchQuery = query or ""
    self.filteredItems = self:FilterItems(self.searchQuery)
    self:RenderItemList(window)
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
                        name = tostring(prop.Name),
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
                    name = tostring(field.Name),
                    typeName = typeName,
                    valueText = toText(value),
                    apply = function(v)
                        field:SetValue(thing, v)
                    end
                })
            end
        end
    end)

    -- Sort entries by name for readability
    table.sort(self.attrEntries, function(a, b)
        return a.name < b.name
    end)

    -- Update label to show attribute count
    if window.label then
        local title = getThingDisplayName(thing)
        window.label.text = string.format("Editing: %s | %d editable attributes", title, #self.attrEntries)
    end

    print("[Item Editor] Loaded " .. #self.attrEntries .. " attributes for item editing")
end

return itemEditor