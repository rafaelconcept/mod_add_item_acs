local cs = CS

local Directory = cs.System.IO.Directory
local Path = cs.System.IO.Path
local Application = cs.UnityEngine.Application
local SearchOption = cs.System.IO.SearchOption
local AppDomain = cs.System.AppDomain
local BindingFlags = cs.System.Reflection.BindingFlags

ITEMS = {
    items = {},
    lastLoadMessage = "",
    runtimeCandidates = {},
    lastSource = "init"
}

local function setStatus(msg, source)
    ITEMS.lastLoadMessage = msg
    if source ~= nil and source ~= "" then
        ITEMS.lastSource = source
    end
    print("[ITEMS] " .. tostring(msg))
end

local function getThingMgr()
    local mgr = nil
    pcall(function()
        mgr = CS.XiaWorld.ThingMgr.Instance
    end)
    if mgr ~= nil then
        return mgr
    end
    if ThingMgr ~= nil then
        return ThingMgr
    end
    return nil
end

local function normalizeContent(content)
    if content == nil then
        return ""
    end
    if string.find(content, "%z") ~= nil then
        content = content:gsub("%z", "")
    end
    return content
end

local function trim(s)
    if s == nil then
        return nil
    end
    return s:match("^%s*(.-)%s*$")
end

local function pushName(name, seen)
    local n = trim(name)
    if n == nil or n == "" then
        return false
    end
    if seen[n] then
        return false
    end
    seen[n] = true
    table.insert(ITEMS.items, n)
    return true
end

local function getItemType()
    return CS.XiaWorld.g_emThingType.Item
end

local function tryGetDef(itemName)
    local mgr = getThingMgr()
    if mgr == nil then
        return nil
    end

    local itemType = getItemType()
    local def = nil
    local ok = pcall(function()
        def = mgr:GetDef(itemType, itemName)
    end)
    if ok and def ~= nil then
        return def
    end
    return nil
end

local function pushNameIfValid(name, seen)
    local n = trim(name)
    if n == nil or n == "" then
        return false
    end
    if seen[n] then
        return false
    end

    local def = tryGetDef(n)
    if def ~= nil then
        return pushName(n, seen)
    end
    return false
end

local function pushNameFromDef(defObj, seen)
    if defObj == nil then
        return false
    end

    local name = nil
    pcall(function()
        name = defObj.Name
    end)
    if name == nil or name == "" then
        pcall(function()
            name = defObj.m_Name
        end)
    end

    if name ~= nil and name ~= "" then
        return pushName(name, seen)
    end
    return false
end

local function scanContainer(container, seen)
    if container == nil then
        return 0
    end

    local added = 0

    local okPairs = pcall(function()
        for key, value in pairs(container) do
            if type(key) == "string" and pushNameIfValid(key, seen) then
                added = added + 1
            end

            if value ~= nil then
                if pushNameFromDef(value, seen) then
                    added = added + 1
                elseif type(value) == "string" and pushNameIfValid(value, seen) then
                    added = added + 1
                end
            end
        end
    end)

    local count = 0
    local hasCount = false
    pcall(function()
        count = container.Count
        hasCount = true
    end)

    if hasCount and count > 0 then
        for i = 0, count - 1 do
            local element = nil
            local okElement = pcall(function()
                element = container[i]
            end)
            if okElement and element ~= nil then
                if pushNameFromDef(element, seen) then
                    added = added + 1
                elseif type(element) == "string" and pushNameIfValid(element, seen) then
                    added = added + 1
                else
                    local key = nil
                    local value = nil
                    pcall(function()
                        key = element.Key
                    end)
                    pcall(function()
                        value = element.Value
                    end)

                    if type(key) == "string" and pushNameIfValid(key, seen) then
                        added = added + 1
                    end
                    if value ~= nil then
                        if pushNameFromDef(value, seen) then
                            added = added + 1
                        elseif type(value) == "string" and pushNameIfValid(value, seen) then
                            added = added + 1
                        end
                    end
                end
            end
        end
    elseif not okPairs then
        pcall(function()
            local enumerator = container:GetEnumerator()
            while enumerator:MoveNext() do
                local current = enumerator.Current
                if current ~= nil then
                    if pushNameFromDef(current, seen) then
                        added = added + 1
                    else
                        local key = nil
                        local value = nil
                        pcall(function()
                            key = current.Key
                        end)
                        pcall(function()
                            value = current.Value
                        end)

                        if type(key) == "string" and pushNameIfValid(key, seen) then
                            added = added + 1
                        end
                        if value ~= nil then
                            if pushNameFromDef(value, seen) then
                                added = added + 1
                            elseif type(value) == "string" and pushNameIfValid(value, seen) then
                                added = added + 1
                            end
                        end
                    end
                end
            end
        end)
    end

    return added
end

local function combinePath(a, b, c, d)
    local p = Path.Combine(a, b)
    if c ~= nil then
        p = Path.Combine(p, c)
    end
    if d ~= nil then
        p = Path.Combine(p, d)
    end
    return p
end

local function getCandidateFolders()
    local folders = {}

    -- Try relative paths first
    table.insert(folders, "files/Settings/ThingDef/Item")
    table.insert(folders, "files\\Settings\\ThingDef\\Item")
    table.insert(folders, "Settings/ThingDef/Item")
    table.insert(folders, "Settings\\ThingDef\\Item")
    
    -- Android persistent data path
    local persistentDataPath = nil
    pcall(function()
        persistentDataPath = Application.persistentDataPath
    end)
    if persistentDataPath ~= nil and persistentDataPath ~= "" then
        table.insert(folders, combinePath(persistentDataPath, "files", "Settings", "ThingDef", "Item"))
        table.insert(folders, combinePath(persistentDataPath, "Settings", "ThingDef", "Item"))
    end
    
    -- Game data path
    local dataPath = nil
    pcall(function()
        dataPath = Application.dataPath
    end)
    if dataPath ~= nil and dataPath ~= "" then
        table.insert(folders, combinePath(dataPath, "files", "Settings", "ThingDef", "Item"))
        table.insert(folders, combinePath(dataPath, "Settings", "ThingDef", "Item"))
    end
    
    -- Current working directory
    local cwd = nil
    pcall(function()
        cwd = Directory.GetCurrentDirectory()
    end)
    if cwd ~= nil and cwd ~= "" then
        table.insert(folders, combinePath(cwd, "files", "Settings", "ThingDef", "Item"))
        table.insert(folders, combinePath(cwd, "Settings", "ThingDef", "Item"))
    end

    return folders
end

local function getXmlFiles(folder)
    if folder == nil or folder == "" then
        return nil
    end

    local exists = false
    local okExists, existsResult = pcall(function()
        return Directory.Exists(folder)
    end)
    if okExists and existsResult then
        exists = true
    end

    if not exists then
        return nil
    end

    local okFiles, files = pcall(function()
        return Directory.GetFiles(folder, "*.xml")
    end)

    if okFiles then
        return files
    end

    return nil
end

local function getXmlFilesRecursive(folder)
    if folder == nil or folder == "" then
        return nil
    end

    local exists = false
    local okExists, existsResult = pcall(function()
        return Directory.Exists(folder)
    end)
    if okExists and existsResult then
        exists = true
    end

    if not exists then
        return nil
    end

    local okFiles, files = pcall(function()
        return Directory.GetFiles(folder, "*.xml", SearchOption.AllDirectories)
    end)

    if okFiles then
        return files
    end

    return nil
end

local function parseXmlNames(content, seen)
    if content == nil or content == "" then
        return 0
    end

    local added = 0

    -- Match: <ThingDef Type="Item" Name="ItemName" ...>
    for name in content:gmatch('Type%s*=%s*"Item"[^>]-Name%s*=%s*"([^"]+)"') do
        if pushName(name, seen) then
            added = added + 1
        end
    end
    
    -- Also try reverse order: Name then Type
    for name in content:gmatch('Name%s*=%s*"([^"]+)"[^>]-Type%s*=%s*"Item"') do
        if pushName(name, seen) then
            added = added + 1
        end
    end

    return added
end

local function parseRawTokens(content, seen)
    if content == nil or content == "" then
        return 0
    end

    local added = 0
    local scanned = 0
    for token in content:gmatch("([%a_][%w_]+)") do
        scanned = scanned + 1
        if scanned > 12000 then
            break
        end
        if #token >= 4 and #token <= 64 then
            if pushNameIfValid(token, seen) then
                added = added + 1
            end
        end
    end
    return added
end

local function loadFromThingMgr(seen)
    local mgr = getThingMgr()
    if mgr == nil then
        return 0
    end

    local added = 0
    local itemType = getItemType()

    local okTyped = pcall(function()
        local defs = mgr:GetDefs(itemType)
        added = added + scanContainer(defs, seen)
    end)

    if not okTyped then
        pcall(function()
            local defs = mgr:GetDefs()
            added = added + scanContainer(defs, seen)
        end)
    end

    local candidateFields = {
        "m_mapThingDef", "m_mapThingDefs", "m_mapDef", "m_mapDefs", "m_Defs", "Defs", "mapDefs", "m_ThingDefs", "ThingDefs"
    }

    for _, fieldName in ipairs(candidateFields) do
        local container = nil
        local okField = pcall(function()
            container = mgr[fieldName]
        end)
        if okField and container ~= nil then
            added = added + scanContainer(container, seen)
            local typedContainer = nil
            local okTypedContainer = pcall(function()
                typedContainer = container[itemType]
            end)
            if okTypedContainer and typedContainer ~= nil then
                added = added + scanContainer(typedContainer, seen)
            end
        end
    end

    return added
end

local function scanTypesByKeyword(keyword)
    local result = {}
    local seenType = {}
    local asms = AppDomain.CurrentDomain:GetAssemblies()
    local lowerKeyword = keyword:lower()

    for i = 0, asms.Length - 1 do
        local asm = asms[i]
        local okTypes, types = pcall(function()
            return asm:GetTypes()
        end)
        if okTypes and types ~= nil then
            for t = 0, types.Length - 1 do
                local fullName = tostring(types[t].FullName)
                if fullName ~= nil then
                    local lowerName = fullName:lower()
                    if lowerName:find(lowerKeyword, 1, true) then
                        if not seenType[fullName] then
                            seenType[fullName] = true
                            table.insert(result, types[t])
                        end
                    end
                end
            end
        end
    end

    return result
end

function ITEMS.DumpTypeCandidates(keyword)
    local kw = keyword or "def"
    local types = scanTypesByKeyword(kw)
    print("[ITEMS] Candidate types for '" .. kw .. "': " .. tostring(#types))
    local maxPrint = math.min(#types, 60)
    for i = 1, maxPrint do
        local t = types[i]
        print("[ITEMS][TYPE] " .. tostring(t.FullName))
    end
end

local function addRuntimeCandidateName(typeObj)
    if typeObj == nil then
        return
    end
    local fullName = tostring(typeObj.FullName)
    for _, existing in ipairs(ITEMS.runtimeCandidates) do
        if existing == fullName then
            return
        end
    end
    table.insert(ITEMS.runtimeCandidates, fullName)
end

local function tryGetInstanceFromType(typeObj)
    if typeObj == nil then
        return nil
    end

    local flags = BindingFlags.Public | BindingFlags.NonPublic | BindingFlags.Static

    local instance = nil
    pcall(function()
        local prop = typeObj:GetProperty("Instance", flags)
        if prop ~= nil then
            instance = prop:GetValue(nil, nil)
        end
    end)
    if instance ~= nil then
        return instance
    end

    pcall(function()
        local field = typeObj:GetField("Instance", flags)
        if field ~= nil then
            instance = field:GetValue(nil)
        end
    end)
    if instance ~= nil then
        return instance
    end

    pcall(function()
        local prop = typeObj:GetProperty("Inst", flags)
        if prop ~= nil then
            instance = prop:GetValue(nil, nil)
        end
    end)
    if instance ~= nil then
        return instance
    end

    pcall(function()
        local field = typeObj:GetField("Inst", flags)
        if field ~= nil then
            instance = field:GetValue(nil)
        end
    end)

    return instance
end

local function scanObjectMembers(obj, seen)
    if obj == nil then
        return 0
    end

    local added = 0
    local flags = BindingFlags.Instance | BindingFlags.Public | BindingFlags.NonPublic

    pcall(function()
        local t = obj:GetType()
        local fields = t:GetFields(flags)
        for i = 0, fields.Length - 1 do
            local field = fields[i]
            local value = nil
            local okValue = pcall(function()
                value = field:GetValue(obj)
            end)
            if okValue and value ~= nil then
                added = added + scanContainer(value, seen)
            end
        end
    end)

    pcall(function()
        local t = obj:GetType()
        local props = t:GetProperties(flags)
        for i = 0, props.Length - 1 do
            local prop = props[i]
            local canRead = false
            pcall(function()
                canRead = prop.CanRead
            end)
            if canRead then
                local indexCount = 0
                pcall(function()
                    indexCount = prop:GetIndexParameters().Length
                end)
                if indexCount == 0 then
                    local value = nil
                    local okValue = pcall(function()
                        value = prop:GetValue(obj, nil)
                    end)
                    if okValue and value ~= nil then
                        added = added + scanContainer(value, seen)
                    end
                end
            end
        end
    end)

    return added
end

local function loadFromRuntimeTypeScan(seen)
    local keywords = { "thingdef", "itemdef", "defmanager", "database", "config", "thingmgr" }
    local added = 0

    for _, keyword in ipairs(keywords) do
        local types = scanTypesByKeyword(keyword)
        local maxTypes = math.min(#types, 120)
        for i = 1, maxTypes do
            local typeObj = types[i]
            addRuntimeCandidateName(typeObj)
            local instance = tryGetInstanceFromType(typeObj)
            if instance ~= nil then
                added = added + scanObjectMembers(instance, seen)
            end
        end
    end

    return added
end


function ITEMS.OnInit()
    ITEMS.items = {}
    ITEMS.runtimeCandidates = {}
    ITEMS.lastLoadMessage = "Loading from ThingMgr..."
    ITEMS.lastSource = "init"
    local seen = {}

    local mgr = nil
    pcall(function()
        mgr = CS.XiaWorld.ThingMgr.Instance
    end)
    if mgr == nil then
        ITEMS.lastLoadMessage = "ThingMgr not available"
        return
    end

    local itemType = getItemType()
    local ok, has, data = pcall(function()
        return mgr.m_mapThingDefs:TryGetValue(itemType)
    end)
    if not ok or not has or data == nil then
        ok, has, data = pcall(function()
            return mgr.m_mapThingDefs:TryGetValue(2)
        end)
    end

    if not ok or not has or data == nil then
        ITEMS.lastLoadMessage = "ThingMgr: no Item defs"
        return
    end

    local total = 0
    for k, v in pairs(data) do
        total = total + 1
        if type(k) == "string" then
            pushName(k, seen)
        elseif v ~= nil then
            pushNameFromDef(v, seen)
        end
    end

    ITEMS.lastLoadMessage = "ItemDefs total: " .. tostring(total)
    ITEMS.lastSource = "thingmgr"
end

function ITEMS.EnsureLoaded()
    if ITEMS.items ~= nil and #ITEMS.items > 0 then
        return #ITEMS.items
    end
    ITEMS.OnInit()
    return #ITEMS.items
end

function ITEMS.GetUILabel()
    local count = 0
    if ITEMS.items ~= nil then
        count = #ITEMS.items
    end

    local candidateCount = 0
    if ITEMS.runtimeCandidates ~= nil then
        candidateCount = #ITEMS.runtimeCandidates
    end

    local src = ITEMS.lastSource or "?"
    return string.format("Defs:%d Src:%s Cand:%d", count, tostring(src), candidateCount)
end
