--[[
    PROJECT: RAGE CLIENT INSTRUMENTATION SUITE
    Entry Point: main.lua
    Usage: loadstring(game:HttpGet("https://raw.githubusercontent.com/<OWNER>/<REPO>/main/main.lua"))()
]]

-- Configuration: Set your repository raw URL or fallback source
local GITHUB_USER = "YourUsername"
local GITHUB_REPO = "YourRepository"
local GITHUB_BRANCH = "main"

local BASE_URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/", GITHUB_USER, GITHUB_REPO, GITHUB_BRANCH)

-- Helper to safely load remote modules or execute bundle
local function fetchScript(endpoint)
    local url = BASE_URL .. endpoint
    local success, response = pcall(function()
        return game:HttpGet(url)
    end)
    if success and response and #response > 0 then
        return response
    end
    return nil
end

-- Try loading the pre-bundled standalone script first
local bundleSource = fetchScript("dist/bundle.lua")

if bundleSource then
    local executable, compileErr = loadstring(bundleSource)
    if executable then
        executable()
    else
        warn("[RAGE LOADER] Failed to compile bundle from GitHub: " .. tostring(compileErr))
    end
else
    -- Fallback: Execute local bundle if running in workspace environment
    pcall(function()
        if readfile and isfile and isfile("dist/bundle.lua") then
            local localSource = readfile("dist/bundle.lua")
            local exec = loadstring(localSource)
            if exec then exec() end
        else
            warn("[RAGE LOADER] Unable to fetch remote distribution script. Please configure GITHUB_USER and GITHUB_REPO in main.lua.")
        end
    end)
end
