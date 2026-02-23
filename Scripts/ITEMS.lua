local cs = CS

local Directory = cs.System.IO.Directory
local Path = cs.System.IO.Path
local Application = cs.UnityEngine.Application
local SearchOption = cs.System.IO.SearchOption

ITEMS = { items = {} }

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

local function extractThingDefName(filePath)
    local file = io.open(filePath, "r")
    if not file then
        print("[ITEMS] Failed to open file:", filePath)
        return
    end
    local content = file:read("*a")
    file:close()

    local count = 0
    for name in content:gmatch('<ThingDef[^>]-Name="([^"]+)"') do
        table.insert(ITEMS.items, name)
        count = count + 1
    end
end


function ITEMS.OnInit()
    ITEMS.items = {}
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
        print("[ITEMS] Could not locate ThingDef item folder. Item list will be empty.")
        return
    end

    for i = 0, files.Length - 1 do
        local fullPath = files[i]
        local file = io.open(fullPath, "r")
        if file ~= nil then
            local content = file:read("*a")
            file:close()

            for name in content:gmatch('<ThingDef[^>]-Name="([^"]+)"') do
                if not seen[name] then
                    seen[name] = true
                    table.insert(ITEMS.items, name)
                end
            end
        end
    end

    print("[ITEMS] Loaded from: " .. tostring(loadedFolder) .. " (" .. tostring(loadedMode) .. ")")
    print("[ITEMS] Loaded successfully, total items: " .. tostring(#ITEMS.items))
end
