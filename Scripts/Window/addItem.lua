addItem = {}

function addItem:Init(window)
    local function getDiagLabelText()
        if ITEMS ~= nil and ITEMS.GetUILabel ~= nil then
            return ITEMS.GetUILabel()
        end
        return "Defs:0 Src:? Cand:0"
    end

    local function isTemplateDefName(defName)
        if defName == nil then
            return true
        end
        if string.match(defName, "Base$") then
            return true
        end
        return false
    end

    local function normalizeDisplayName(defName, thingName)
        if thingName == nil or thingName == "" or thingName == "LOST ITEM" then
            return defName
        end
        return thingName
    end

    local function readField(obj, fieldName)
        local value = nil
        pcall(function()
            value = obj[fieldName]
        end)
        if value == nil then
            return ""
        end
        return tostring(value)
    end

    local function clipText(text, maxLen)
        if text == nil then
            return ""
        end
        if string.len(text) <= maxLen then
            return text
        end
        return string.sub(text, 1, maxLen) .. "..."
    end

    local function buildDefDebug(itemName, thingName, defName, parentName, texPath)
        local tn = thingName ~= "" and thingName or "-"
        local dn = defName ~= "" and defName or "-"
        local pn = parentName ~= "" and parentName or "-"
        local tx = texPath ~= "" and texPath or "-"
        return string.format("ID:%s TN:%s N:%s P:%s T:%s", clipText(itemName, 20), clipText(tn, 16), clipText(dn, 16), clipText(pn, 16), clipText(tx, 16))
    end

    local function getAllProperties(defObj)
        local props = {}
        if defObj == nil then
            return props
        end

        local BindingFlags = CS.System.Reflection.BindingFlags
        if BindingFlags == nil then
            return props
        end

        pcall(function()
            local flags = BindingFlags.Instance | BindingFlags.Public
            local defType = defObj:GetType()
            local properties = defType:GetProperties(flags)
            
            -- Get ALL properties without filtering
            for i = 0, properties.Length - 1 do
                local prop = properties[i]
                local propName = tostring(prop.Name)
                local canRead = false
                pcall(function() canRead = prop.CanRead end)
                
                if canRead then
                    local indexParams = 0
                    pcall(function() indexParams = prop:GetIndexParameters().Length end)
                    
                    if indexParams == 0 then
                        local value = nil
                        local okRead = pcall(function()
                            value = prop:GetValue(defObj, nil)
                        end)
                        
                        if okRead and value ~= nil then
                            local valStr = tostring(value)
                            table.insert(props, {name = propName, value = valStr})
                        end
                    end
                end
            end
        end)

        return props
    end

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

    local function setPrompt(target, value)
        if target == nil then
            return
        end
        pcall(function()
            target.promptText = value
        end)
    end

    local contentPane = window.window.contentPane
    local addItemUI = contentPane:GetChild("addItemUI")

    self.war = true
    -- Buttons and controls
    self.list = addItemUI:GetChild("list")
    self.pageLabel2 = addItemUI:GetChild("label_2")
    self.pageLabel3 = addItemUI:GetChild("label_3")
    self.bntUpPage = addItemUI:GetChild("upPage")
    self.bntDownPage = addItemUI:GetChild("downPage")
    self.bntSearch = addItemUI:GetChild("search")
    self.bntAddItem = addItemUI:GetChild("addItem")
    self.bntCheckKey = addItemUI:GetChild("checkKey")
    self.bntCheckNearKey = addItemUI:GetChild("checkNearKey")
    self.bntIsKey = addItemUI:GetChild("isKey")
    self.bntIsStore = addItemUI:GetChild("isStore")
    self.inputItemName = addItemUI:GetChild("itemName")
    self.inputNum = addItemUI:GetChild("num")
    self.inputKeyX = addItemUI:GetChild("keyX")
    self.inputKeyY = addItemUI:GetChild("keyY")
    self.dropMenu = addItemUI:GetChild("dropMenu")
    self.bntRefresh = addItemUI:GetChild("refresh")
    self.storeList = addItemUI:GetChild("storeList")

    setText(self.bntUpPage, "Previous")
    setText(self.bntDownPage, "Next")
    setText(self.bntSearch, "Search")
    setText(self.bntAddItem, "Add")
    setText(self.bntCheckNearKey, "Check")
    setText(self.bntCheckKey, "Auto")
    setText(self.bntIsKey, "Use Coordinates")
    setText(self.bntIsStore, "Use Storage")
    setText(self.bntRefresh, "Refresh Storage")
    setText(self.pageLabel3, "Select an item and target location")

    setPrompt(self.inputItemName, "Enter item name")
    setPrompt(self.inputKeyX, "X")
    setPrompt(self.inputKeyY, "Y")
    setPrompt(self.inputNum, "Count")

    pcall(function()
        self.inputItemName.text = ""
    end)
    pcall(function()
        self.inputKeyX.text = ""
    end)
    pcall(function()
        self.inputKeyY.text = ""
    end)

    addItem:ArrowButton()


    -- Default hint
    self.inputNum.text = "1"

    local loadedCount = 0
    if ITEMS ~= nil and ITEMS.EnsureLoaded ~= nil then
        loadedCount = ITEMS.EnsureLoaded()
    end

    self.allItems = {}
    self.debugProps = {}
    self.debugPropIndex = 1
    self.debugItemName = ""
    local skippedTemplate = 0
    local lostLabelCount = 0
    
    for i, name in ipairs(ITEMS.items) do
        if name ~= "" and not isTemplateDefName(name) then
            local def = nil
            local okDef = pcall(function()
                def = ThingMgr:GetDef(CS.XiaWorld.g_emThingType.Item, name)
            end)
            if okDef and def ~= nil then
                local thingName = readField(def, "ThingName")
                if thingName == nil or thingName == "" or thingName == "LOST ITEM" then
                    lostLabelCount = lostLabelCount + 1
                end

                local defName = readField(def, "Name")
                local parentName = readField(def, "Parent")
                if parentName == "" then
                    parentName = readField(def, "ParentName")
                end
                local texPath = readField(def, "TexPath")
                local debugText = buildDefDebug(name, thingName, defName, parentName, texPath)

                table.insert(self.allItems, {
                    icon = texPath ~= "" and texPath or "thing://2,Item_SmallBell,Item_IronBlock",
                    title = normalizeDisplayName(name, thingName),
                    itemName = name,
                    debug = debugText,
                })
            end
        elseif name ~= "" then
            skippedTemplate = skippedTemplate + 1
        end
    end

    if #self.allItems == 0 then
        local msg = "No item defs loaded"
        if ITEMS ~= nil and ITEMS.lastLoadMessage ~= nil and ITEMS.lastLoadMessage ~= "" then
            msg = ITEMS.lastLoadMessage
        end
        self.pageLabel3.text = string.format("%s | %s", msg, getDiagLabelText())
    else
        self.pageLabel3.text = string.format("%s Show:%d Lost:%d Tpl:%d | Click item to debug props", getDiagLabelText(), #self.allItems, lostLabelCount, skippedTemplate)
    end

    self.displayedItems = self.allItems
    self.itemsPerPage = 24
    self.currentPage = 1
    self.totalPages = math.ceil(#self.displayedItems / self.itemsPerPage)

    self.bntUpPage.onClick:Add(function()
        self:GoToPage(self.currentPage - 1)
    end)
    self.bntDownPage.onClick:Add(function()
        self:GoToPage(self.currentPage + 1)
    end)
    self.bntSearch.onClick:Add(function()
        self:SearchItems()
    end)

    self.bntAddItem.onClick:Add(function()
        self:BntAddItem()
    end)

    if self.bntCheckNearKey then
        self.bntCheckNearKey.onClick:Add(function()
            self:BntCheckNearKey()
        end)
    else
        print("[Error] bntCheckNearKey button does not exist or is not bound!")
    end

    self.bntIsKey.grayed = true
    self.bntIsKey.touchable = false

    self.bntIsKey.onClick:Add(function()
        self:ChangeAddWar()
    end)

    self.bntIsStore.onClick:Add(function()
        self:ChangeAddWar()
    end)

    self.bntRefresh.onClick:Add(function()
        -- If debugging props, show next property
        if #self.debugProps > 0 then
            self.debugPropIndex = self.debugPropIndex + 1
            if self.debugPropIndex > #self.debugProps then
                self.debugPropIndex = 1
            end
            self:ShowDebugProps()
        else
            -- Normal refresh behavior
            if ITEMS ~= nil and ITEMS.OnInit ~= nil then
                ITEMS.OnInit()
            end
            self.pageLabel3.text = getDiagLabelText()
            self:ArrowButton()
        end
    end)

    self.list.onClickItem:Add(function(context)
        local item = context.data
        local data = item.data
        if data then
            print("Selected item:", data.title, data.itemName)
            self.selectedItemName = data.itemName
            self.titleName = data.title
            self:LoadPage(self.currentPage)
            
            -- Load relevant properties of this item
            local def = nil
            local okDef = pcall(function()
                def = ThingMgr:GetDef(CS.XiaWorld.g_emThingType.Item, data.itemName)
            end)
            
            if okDef and def ~= nil then
                self.debugProps = getAllProperties(def)
                self.debugPropIndex = 1
                self.debugItemName = data.itemName
                self:ShowDebugProps()
            else
                self.pageLabel3.text = "Failed to load def for " .. data.itemName
            end
        else
            print("Clicked item has no bound data")
        end
    end)
    
    self:LoadPage(1)
end

function addItem:ShowDebugProps()
    if #self.debugProps == 0 then
        self.pageLabel3.text = "No properties found!"
        return
    end
    
    -- Show only 1 property at a time
    local prop = self.debugProps[self.debugPropIndex]
    local val = prop.value
    if string.len(val) > 50 then
        val = string.sub(val, 1, 50) .. "..."
    end
    
    local total = #self.debugProps
    local header = string.format("[%d/%d]", self.debugPropIndex, total)
    self.pageLabel3.text = header .. " " .. prop.name .. " = " .. val .. " (Refresh=Next)"
end

function addItem:BntAddItem()
    if self.war then
        self:IsKeyAddItem()
    else
        if self.store then
            print("Selected storage:", self.store.Name)
            local listKey = self:GetAreasSpacesKey(self.store)
            self:IsAreasAddItem(listKey)
        else
            print("No valid storage selected")
            self.pageLabel3.text = string.format("No valid storage selected")
        end

    end
end

function addItem:ArrowButton()
    self.storeList:RemoveChildrenToPool()
    print("[XiuXian Assistant]===>>> Start searching for storage")
    local typename = "Storage"
    self.areas = CS.XiaWorld.AreaMgr.Instance:GetAreas(typename)

    if self.areas == nil or self.areas.Count == 0 then
        print("No storage found")
        self.pageLabel3.text = string.format("No storage found")
        local item = self.storeList:AddItemFromPool()
        item.title = "No storage found"
        return
    end
    self.selectedItem = nil
    for i = 0, self.areas.Count - 1 do
        local area = self.areas[i]
        local item = self.storeList:AddItemFromPool()
        item.title = area.Name
        item.onClick:Add(function()
            self.store = area
            self.pageLabel3.text = string.format("Current selected storage: %s", area.Name)
            if self.selectedItem and self.selectedItem ~= item then
                self.selectedItem.grayed = false
            end
            item.grayed = true
            self.selectedItem = item
        end)
    end
end

function addItem:CheckXYC(keyX, keyY, count)

    if not keyX or keyX < 1 then
        world:ShowMsgBox("Invalid X coordinate input", "Error")
        self.pageLabel3.text = string.format("Invalid X coordinate input!")
        return false
    end

    if not keyY or keyY < 1 then
        world:ShowMsgBox("Invalid Y coordinate input", "Error")
        self.pageLabel3.text = string.format("Invalid Y coordinate input!")
        return false
    end

    if not count or count < 1 then
        world:ShowMsgBox("Please enter a valid positive integer count", "Error")
        self.pageLabel3.text = string.format("Invalid count input!")
        return false
    end

    return true
end

function addItem:BntCheckNearKey()
    local keyX = tonumber(self.inputKeyX.text)
    local keyY = tonumber(self.inputKeyY.text)
    if not self:CheckXYC(keyX, keyY, 1) then
        return
    end
    local mapKey = (keyY - 1) + (keyX - 1) * Map.Size
    local thingsData = Map.Things
    local radius = 2
    local noSelf = true
    local freeKey = thingsData:GetFreeGird(mapKey, radius, noSelf)

    if freeKey > 0 then
        local x = math.floor((freeKey - freeKey % Map.Size) / Map.Size) + 1
        local y = freeKey % Map.Size + 1
        self.inputKeyX.text = x
        self.inputKeyY.text = y
        print("Free space coordinates:", x, y)
    else
        print("No empty space nearby")
    end
end


function addItem:IsKeyAddItem()
    local itemName = self.selectedItemName
    if itemName == nil or itemName == "" then
        self.pageLabel3.text = string.format("Please select an item first")
        return
    end
    local keyX = tonumber(self.inputKeyX.text)
    local keyY = tonumber(self.inputKeyY.text)
    local count = tonumber(self.inputNum.text)

    if not self:CheckXYC(keyX, keyY, count) then
        return
    end

    local maps = World.map
    local found = false
    local mapKey = (keyY - 1) + (keyX - 1) * Map.Size
    if self:CheckKey(mapKey) then
        found = true
    end

    if not found then
        self.pageLabel3.text = string.format("Add failed, current coordinate may already contain another item!")
        return
    end

    local thingItem = ThingMgr:AddItemThing(mapKey, itemName, maps, count, false)
    thingItem:FoundMe()
    self.pageLabel3.text = string.format(count .. " " .. self.titleName .. " added successfully!")
end

function addItem:GetAreas(typename)
    local areas = CS.XiaWorld.AreaMgr.Instance:GetAreas(typename)
    if areas == nil or areas.Count == 0 then
        print("No area found with type " .. typename)
        return nil
    else
        print("Found " .. areas.Count .. " area(s) with type " .. typename)
        return areas
    end
end

function addItem:GetAreasSpacesKey(area)
    local listKey = {}
    local spaces = area.m_lisFreeSpace
    print("[XiuXian Assistant]======>>> spaces", spaces)
    for i = 0, spaces.Count - 1 do
        local space = spaces[i]
        local key = space.Key;
        table.insert(listKey, key)
    end
    return listKey
end

function addItem:IsAreasAddItem(listKey)
    local itemName = self.selectedItemName
    local count = tonumber(self.inputNum.text)
    local maps = World.map
    local isKey = nil
    for _, key in ipairs(listKey) do
        if self:CheckKey(key) then
            isKey = key
            break
        end
    end
    if isKey then
        local thingItem = ThingMgr:AddItemThing(isKey, itemName, maps, count, false)
        thingItem:FoundMe()
    else
        self.pageLabel3.text = string.format("Current storage is full, please select another storage!")
        return
    end
end

function addItem:LoadPage(page)
    self.totalPages = math.ceil(#self.displayedItems / self.itemsPerPage)
    if self.totalPages == 0 then
        self.totalPages = 1
    end

    self.list:RemoveChildrenToPool()
    local startIdx = (page - 1) * self.itemsPerPage + 1
    local endIdx = math.min(page * self.itemsPerPage, #self.displayedItems)

    for i = startIdx, endIdx do
        local data = self.displayedItems[i]
        local item = self.list:AddItemFromPool()
        item.icon = data.icon
        item.title = data.title
        item.data = data
    end

    self.pageLabel2.text = string.format("Page %d / %d", self.currentPage, self.totalPages)
    self.bntUpPage.grayed = (self.currentPage == 1)
    self.bntDownPage.grayed = (self.currentPage == self.totalPages)
end

function addItem:GoToPage(page)
    if page < 1 or page > self.totalPages then
        return
    end
    self.currentPage = page
    self:LoadPage(self.currentPage)
end

function addItem:SearchItems()
    local keyword = self.inputItemName.text
    print("[XiuXian Assistant] Search keyword:", keyword)

    if keyword == nil or keyword == "" then
        self.displayedItems = self.allItems
    else
        self.displayedItems = {}
        for _, item in ipairs(self.allItems) do
            if string.find(item.title, keyword) then
                table.insert(self.displayedItems, item)
            end
        end
    end

    self.currentPage = 1
    self:LoadPage(self.currentPage)
end

-- Check whether an item can be placed at the current coordinate
function addItem:CheckKey(mapKey)
    local thingType = CS.XiaWorld.g_emThingType.Item;
    local thing = Map.Things:GetThingAtGrid(mapKey, thingType);
    if thing == nil then
        return true;
    else
        return false;
    end
end

function addItem:ChangeAddWar()
    self.war = not self.war
    if self.war then
        -- When war is true, disable bntIsKey and enable bntIsStore
        self.bntIsKey.grayed = true
        self.bntIsKey.touchable = false
        self.bntIsStore.grayed = false
        self.bntIsStore.touchable = true
    else
        -- When war is false, disable bntIsStore and enable bntIsKey
        self.bntIsKey.grayed = false
        self.bntIsKey.touchable = true
        self.bntIsStore.grayed = true
        self.bntIsStore.touchable = false
    end
end

return addItem