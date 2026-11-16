local Helpers = dofile("Tests/helpers.lua")
local function Copy(value)
    if type(value) ~= "table" then return value end
    local result = {}
    for key, entry in pairs(value) do result[key] = Copy(entry) end
    return result
end

for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " Escape option", function()
        it("applies immediately, survives reload, and unregisters when disabled or reset", function()
            local env = Helpers.loadAddon({ client = client })
            local function pressEscape()
                for _, name in pairs(env.UISpecialFrames) do
                    local frame = env[name]
                    if frame and frame:IsShown() then frame:Hide() end
                end
            end
            local function toggle(enabled)
                local checkbox = env.DCI_Config_Checkbox_CloseOnEscape
                checkbox:SetChecked(enabled)
                checkbox:Fire("OnClick")
            end
            env.addon.ToggleDCIFrame()
            assert(env.addon.db.CloseOnEscape == false)
            pressEscape()
            assert(env.DCIFrame:IsShown())
            toggle(true)
            toggle(true)
            local count = 0
            for _, name in ipairs(env.UISpecialFrames) do
                if name == "DCIFrame" then count = count + 1 end
            end
            assert(count == 1)
            pressEscape()
            assert(not env.DCIFrame:IsShown())
            env = Helpers.loadAddon({ client = client, profiles = Copy(env.DCI_ProfilesDB), character = Copy(env.DCI_CharDB), saved = Copy(env.DCI_DB) })
            env.addon.ToggleDCIFrame()
            pressEscape()
            assert(not env.DCIFrame:IsShown())
            env.addon.ToggleDCIFrame()
            toggle(false)
            pressEscape()
            assert(env.DCIFrame:IsShown())
            toggle(true)
            env.addon.InitializeSavedVariables(true)
            env.addon.UpdateDCISettings()
            pressEscape()
            assert(env.DCIFrame:IsShown())
            assert(env.DCI_Config_Checkbox_CloseOnEscape:GetChecked() == false)
        end)
    end)
end
