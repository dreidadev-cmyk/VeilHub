--[[
    VeilHub — remote/dumper.lua v0.0.1
    Extracts every RemoteEvent, RemoteFunction, BindableEvent,
    BindableFunction, and UnreliableRemoteEvent from the loaded game.
    Writes to a local file — no clipboard, no auto-copy.
    User must download the file from their executor workspace.
]]

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui        = game:GetService("StarterGui")

local LP = Players.LocalPlayer

-- ============================================================
-- OUTPUT SETTINGS
-- ============================================================
local OUTPUT_FILE = "veil_remotes_" .. tostring(game.PlaceId) .. ".txt"

-- ============================================================
-- FILE HELPERS (executor-dependent)
-- ============================================================
local has_file_api = (writefile ~= nil) and (readfile ~= nil)
local has_folder   = (makefolder ~= nil) and (isfolder ~= nil)

local function ensure_output_dir()
    if not has_folder then return end
    pcall(function()
        if not isfolder("VeilHub") then
            makefolder("VeilHub")
        end
    end)
end

local function write_output(content)
    if not has_file_api then
        warn("[Veil/remote] executor has no file API — cannot save. result below:")
        print(content)
        return false
    end
    ensure_output_dir()
    local ok = pcall(writefile, "VeilHub/" .. OUTPUT_FILE, content)
    if not ok then
        -- try without subfolder
        ok = pcall(writefile, OUTPUT_FILE, content)
    end
    return ok
end

-- ============================================================
-- NOTIFICATION HELPERS
-- ============================================================
local function notify(title, text, dur)
    pcall(function()
        StarterGui:SetCore("SendNotification", {
            Title = title, Text = text, Duration = dur or 4,
        })
    end)
end

-- ============================================================
-- REMOTE SCANNER
-- ============================================================
local REMOTE_CLASSES = {
    ["RemoteEvent"]              = true,
    ["RemoteFunction"]           = true,
    ["BindableEvent"]            = true,
    ["BindableFunction"]         = true,
    ["UnreliableRemoteEvent"]    = true,
}

local function scan_root(root_obj, label, results)
    if not root_obj then return end
    local ok = pcall(function()
        for _, obj in ipairs(root_obj:GetDescendants()) do
            if REMOTE_CLASSES[obj.ClassName] then
                table.insert(results, {
                    source    = label,
                    class     = obj.ClassName,
                    path      = obj:GetFullName(),
                    parent    = obj.Parent and obj.Parent:GetFullName() or "nil",
                    name      = obj.Name,
                })
            end
        end
    end)
    if not ok then
        warn("[Veil/remote] scan failed for " .. label)
    end
end

local function run_scan()
    local results = {}

    -- 1. ReplicatedStorage (the big one — most remotes live here)
    scan_root(ReplicatedStorage, "ReplicatedStorage", results)

    -- 2. Players.LocalPlayer's children (some remotes live here per-player)
    scan_root(LP, "Players.LocalPlayer", results)

    -- 3. workspace (rare, but some games put remotes in workspace)
    scan_root(workspace, "workspace", results)

    -- 4. StarterGui (rare)
    scan_root(game:GetService("StarterGui"), "StarterGui", results)

    -- 5. ServerStorage (usually empty for client, but try)
    pcall(function()
        local ss = game:GetService("ServerStorage")
        if ss then scan_root(ss, "ServerStorage", results) end
    end)

    -- 6. ServerScriptService (rare, usually empty)
    pcall(function()
        local sss = game:GetService("ServerScriptService")
        if sss then scan_root(sss, "ServerScriptService", results) end
    end)

    return results
end

-- ============================================================
-- FORMAT OUTPUT
-- ============================================================
local function format_results(results)
    local lines = {}
    local function add(s) table.insert(lines, s) end

    add("================================================================")
    add(" VeilHub — Remote Dump")
    add("================================================================")
    add(" Game PlaceId : " .. tostring(game.PlaceId))
    add(" Game JobId   : " .. tostring(game.JobId))
    add(" Collected by : " .. tostring(LP.Name) .. " (@" .. LP.Name .. ")")
    add(" Time         : " .. os.date("%Y-%m-%d %H:%M:%S"))
    add(" Executor     : " .. tostring(identifyexecutor and identifyexecutor() or "unknown"))
    add("================================================================")
    add("")
    add(string.format(" Total remotes found: %d", #results))
    add("")

    -- group by class
    local by_class = {}
    for _, r in ipairs(results) do
        by_class[r.class] = by_class[r.class] or {}
        table.insert(by_class[r.class], r)
    end

    -- stable class order
    local class_order = { "RemoteEvent", "RemoteFunction", "UnreliableRemoteEvent",
                          "BindableEvent", "BindableFunction" }
    for _, cls in ipairs(class_order) do
        if by_class[cls] then
            add("--------------------------------------------------------------")
            add(" " .. cls .. "  (" .. tostring(#by_class[cls]) .. ")")
            add("--------------------------------------------------------------")
            table.sort(by_class[cls], function(a, b) return a.path < b.path end)
            for _, r in ipairs(by_class[cls]) do
                add("  [" .. r.source .. "]")
                add("    Name   : " .. r.name)
                add("    Parent : " .. r.parent)
                add("    Path   : " .. r.path)
                add("")
            end
            by_class[cls] = nil
        end
    end

    -- any remaining class types
    for cls, list in pairs(by_class) do
        add("--------------------------------------------------------------")
        add(" " .. cls .. "  (" .. tostring(#list) .. ")")
        add("--------------------------------------------------------------")
        table.sort(list, function(a, b) return a.path < b.path end)
        for _, r in ipairs(list) do
            add("  [" .. r.source .. "]")
            add("    Name   : " .. r.name)
            add("    Parent : " .. r.parent)
            add("    Path   : " .. r.path)
            add("")
        end
    end

    add("")
    add("================================================================")
    add(" End of dump")
    add("================================================================")

    return table.concat(lines, "\n")
end

-- ============================================================
-- RUN
-- ============================================================
notify("Veil Remote Dumper", "Scanning remotes...", 3)

local results = run_scan()
local content = format_results(results)
local saved = write_output(content)

if saved then
    notify("Veil Remote Dumper",
        string.format("%d remotes saved to VeilHub/%s", #results, OUTPUT_FILE), 8)
    print(string.format("[Veil/remote] saved %d remotes to VeilHub/%s", #results, OUTPUT_FILE))
    print("[Veil/remote] open your executor's workspace folder to find the file")
    print("[Veil/remote] path: <executor_workspace>/VeilHub/" .. OUTPUT_FILE)
else
    notify("Veil Remote Dumper",
        "No file API — output printed to console only", 8)
    print("[Veil/remote] output printed above")
end
