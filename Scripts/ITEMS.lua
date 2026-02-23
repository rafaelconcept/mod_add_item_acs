local cs = CS

local Directory = cs.System.IO.Directory
local Path = cs.System.IO.Path
local Application = cs.UnityEngine.Application
local SearchOption = cs.System.IO.SearchOption

XIAUXIAN_ITEMS = { items = {} }

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

    local persistentPath = nil
    local appId = nil
    pcall(function()
        persistentPath = Application.persistentDataPath
    end)
    pcall(function()
        appId = Application.identifier
    end)

    print("[ITEMS] Application.identifier:", tostring(appId))
    print("[ITEMS] Application.persistentDataPath:", tostring(persistentPath))

    if persistentPath ~= nil and persistentPath ~= "" then
        table.insert(folders, combinePath(persistentPath, "Settings", "ThingDef", "Item"))
    end

    if appId ~= nil and appId ~= "" then
        local androidDataRoot = "/storage/emulated/0/Android/data/" .. appId .. "/files"
        table.insert(folders, combinePath(androidDataRoot, "Settings", "ThingDef", "Item"))

        local sdcardDataRoot = "/sdcard/Android/data/" .. appId .. "/files"
        table.insert(folders, combinePath(sdcardDataRoot, "Settings", "ThingDef", "Item"))
    end

    table.insert(folders, "Settings/ThingDef/Item")
    table.insert(folders, "Settings\\ThingDef\\Item")

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

local function normalizeContent(content)
    if content == nil then
        return ""
    end

    if string.find(content, "%z") ~= nil then
        content = content:gsub("%z", "")
    end

    return content
end

local function tryGetThingDef(itemType, name)
    if name == nil or name == "" then
        return nil
    end

    local mgr = getThingMgr()
    if mgr ~= nil then
        local okDef2, thingDef2 = pcall(function()
            return mgr:GetDef(itemType, name)
        end)
        if okDef2 and thingDef2 ~= nil then
            return thingDef2
        end
    end

    return nil
end

local function pushName(name, seen)
    if name == nil then
        return
    end

    local trimmed = name:match("^%s*(.-)%s*$")
    if trimmed == nil or trimmed == "" then
        return
    end

    if not seen[trimmed] then
        seen[trimmed] = true
        table.insert(XIAUXIAN_ITEMS.items, trimmed)
    end
end

local function pushNameIfValid(name, seen)
    local itemType = CS.XiaWorld.g_emThingType.Item
    local thingDef = tryGetThingDef(itemType, name)
    if thingDef ~= nil then
        pushName(name, seen)
        return true
    end
    return false
end

local function pushNameFromDef(def, seen)
    if def == nil then
        return false
    end

    local name = nil
    pcall(function()
        name = def.Name
    end)
    if name == nil or name == "" then
        pcall(function()
            name = def.m_Name
        end)
    end

    if name ~= nil and name ~= "" then
        pushName(name, seen)
        return true
    end

    return false
end

local function scanContainerForNames(container, seen)
    if container == nil then
        return 0
    end

    local added = 0

    local okPairs = pcall(function()
        for key, value in pairs(container) do
            local keyAdded = false
            if type(key) == "string" then
                if pushNameIfValid(key, seen) then
                    keyAdded = true
                    added = added + 1
                end
            end

            if not keyAdded and value ~= nil then
                if pushNameFromDef(value, seen) then
                    added = added + 1
                elseif type(value) == "string" then
                    if pushNameIfValid(value, seen) then
                        added = added + 1
                    end
                else
                    local valueName = nil
                    pcall(function()
                        valueName = value.Name
                    end)
                    if valueName ~= nil and valueName ~= "" and pushNameIfValid(valueName, seen) then
                        added = added + 1
                    end
                end
            end
        end
    end)

    local hasCount = false
    local count = 0
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
                elseif type(element) == "string" then
                    if pushNameIfValid(element, seen) then
                        added = added + 1
                    end
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
        local okEnum = pcall(function()
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

        if not okEnum then
            return added
        end
    end

    return added
end

local function loadFromThingMgr(seen)
    local itemType = CS.XiaWorld.g_emThingType.Item
    local addedTotal = 0

    local mgr = getThingMgr()
    if mgr == nil then
        return 0
    end

    local okDefsA = pcall(function()
        local defs = mgr:GetDefs(itemType)
        addedTotal = addedTotal + scanContainerForNames(defs, seen)
    end)
    if not okDefsA then
        pcall(function()
            local defs = mgr:GetDefs()
            addedTotal = addedTotal + scanContainerForNames(defs, seen)
        end)
    end

    local fieldNames = {
        "m_mapThingDef",
        "m_mapThingDefs",
        "m_mapDef",
        "m_mapDefs",
        "m_Defs",
        "Defs",
        "mapDefs"
    }

    for _, fieldName in ipairs(fieldNames) do
        local container = nil
        local okField = pcall(function()
            container = mgr[fieldName]
        end)

        if okField and container ~= nil then
            addedTotal = addedTotal + scanContainerForNames(container, seen)

            local typedContainer = nil
            local okTyped = pcall(function()
                typedContainer = container[itemType]
            end)
            if okTyped and typedContainer ~= nil then
                addedTotal = addedTotal + scanContainerForNames(typedContainer, seen)
            end
        end
    end

    print("[ITEMS] Fallback ThingMgr loaded names: " .. tostring(addedTotal))
    return addedTotal
end

local function extractThingDefNamesFromContent(content, seen)
    if content == nil or content == "" then
        return 0
    end

    local count = 0

    for name in content:gmatch('<ThingDef[^>]-Name%s*=%s*"([^"]+)"') do
        pushName(name, seen)
        count = count + 1
    end

    for name in content:gmatch("<ThingDef[^>]-Name%s*=%s*'([^']+)'") do
        pushName(name, seen)
        count = count + 1
    end

    for name in content:gmatch('<ThingDef[^>]*>%s*<Name>%s*([^<]+)%s*</Name>') do
        pushName(name, seen)
        count = count + 1
    end

    return count
end


function XIAUXIAN_ITEMS.OnInit()
    XIAUXIAN_ITEMS.items = {}
    local seen = {}

    local loadedFolder = nil
    local loadedMode = nil
    local files = nil
    for _, folder in ipairs(getCandidateFolders()) do
        print("[ITEMS] Trying folder:", tostring(folder))

        local tryFiles = getXmlFiles(folder)
        if tryFiles ~= nil and tryFiles.Length > 0 then
            loadedFolder = folder
            files = tryFiles
            loadedMode = "direct"
            break
        end

        local tryRecursiveFiles = getXmlFilesRecursive(folder)
        if tryRecursiveFiles ~= nil and tryRecursiveFiles.Length > 0 then
            loadedFolder = folder
            files = tryRecursiveFiles
            loadedMode = "recursive"
            break
        end
    end

    if files == nil then
        print("[ITEMS] Could not locate ThingDef item folder. Trying ThingMgr fallback...")
        loadFromThingMgr(seen)
        print("[ITEMS] Loaded successfully, total items: " .. tostring(#XIAUXIAN_ITEMS.items))
        return
    end

    for i = 0, files.Length - 1 do
        local fullPath = files[i]
        local file = io.open(fullPath, "rb")
        if file ~= nil then
            local content = normalizeContent(file:read("*a"))
            file:close()

            extractThingDefNamesFromContent(content, seen)
        end
    end

    if #XIAUXIAN_ITEMS.items == 0 then
        print("[ITEMS] XML parsing yielded zero items. Trying ThingMgr fallback...")
        loadFromThingMgr(seen)
    end

    print("[ITEMS] Loaded from: " .. tostring(loadedFolder) .. " (" .. tostring(loadedMode) .. ")")
    print("[ITEMS] Loaded successfully, total items: " .. tostring(#XIAUXIAN_ITEMS.items))
end

function XIAUXIAN_ITEMS.EnsureLoaded()
    if XIAUXIAN_ITEMS.items ~= nil and #XIAUXIAN_ITEMS.items > 0 then
        return #XIAUXIAN_ITEMS.items
    end

    XIAUXIAN_ITEMS.OnInit()
    return #XIAUXIAN_ITEMS.items
end
