local Helpers = {}

Helpers.clients = {
    { name = "Classic Era", interface = 11509, branch = "classic_era", game = "vanilla" },
    { name = "Anniversary", interface = 20506, branch = "classic_anniversary", game = "tbc" },
    { name = "Mists", interface = 50504, branch = "classic", game = "mists" },
    { name = "Forever", interface = 16001, branch = "forever", game = "camelot", scrollBoxLoot = true },
}

function Helpers.readFile(path)
    local file = assert(io.open(path, "r"))
    local contents = file:read("*a")
    file:close()
    return contents:gsub("\r\n", "\n")
end

-- Explicit frame methods: unknown methods fail, rather than silently succeeding.
function Helpers.loadAddon(options)
    options = options or {}
    local env = setmetatable({}, { __index = _G })
    env._G = env
    env.addon = {}
    env.addonName = options.addonName or "DeleteCheapestItem"
    env.client = options.client or Helpers.clients[1]
    env.bags, env.items, env.loot, env.looted, env.deleted, env.sold = {}, {}, {}, {}, {}, {}
    env.callbacks, env.hooks, env.messages = {}, {}, {}
    env.timers, env.time = {}, 0
    env.openBags = {}
    env.DCI_DB = options.saved or {}
    env.SlashCmdList, env.StaticPopupDialogs = {}, {}
    env.NUM_BAG_SLOTS = 4
    env.NUM_TOTAL_EQUIPPED_BAG_SLOTS = env.client.scrollBoxLoot and 5 or 4
    env.YES, env.NO, env.DELETE, env.NEVER, env.ERROR_CAPS = "Yes", "No", "Delete", "Never", "Error"
    env.DELETE_ITEM = "Destroy %s?"
    env.RETRIEVING_ITEM_INFO = "Retrieving item information"
    env.ERR_INV_FULL = "Inventory is full"
    env.ITEM_BIND_QUEST = "Quest item"
    for quality = 0, 5 do env["ITEM_QUALITY" .. quality .. "_DESC"] = "Quality " .. quality end

    local methods = {}
    local newFrame
    for name in ("SetFrameStrata SetMovable SetOwner SetBackdropColor SetTextColor SetAlpha " ..
        "SetTexture SetVertexColor SetTexCoord SetBlendMode SetAllPoints StartMoving StopMovingOrSizing " ..
        "AddDoubleLine AddLine SetItemByID SetNumeric SetMaxLetters SetAutoFocus SetFocus ClearFocus"):gmatch("%S+") do
        methods[name] = function() end
    end
    function methods:SetScript(event, fn) self.scripts[event] = fn end
    function methods:SetFrameLevel(level) self.frameLevel = level end
    function methods:GetFrameLevel()
        return self.frameLevel or (self.parent and self.parent:GetFrameLevel() + 1) or 0
    end
    function methods:GetScript(event) return self.scripts[event] end
    function methods:HookScript(event, fn)
        local prior = self.scripts[event]
        self.scripts[event] = function(...)
            if prior then prior(...) end
            fn(...)
        end
    end
    function methods:Fire(event, ...)
        if self.scripts[event] then self.scripts[event](self, ...) end
    end
    function methods:Show()
        if not self.shown then self.shown = true; self:Fire("OnShow") end
    end
    function methods:Hide()
        if self.shown then self.shown = false; self:Fire("OnHide") end
    end
    function methods:IsShown() return self.shown end
    function methods:IsVisible() return self.shown and (not self.parent or self.parent:IsVisible()) end
    function methods:Enable() self.enabled = true; self:Fire("OnEnable") end
    function methods:Disable() self.enabled = false; self:Fire("OnDisable") end
    function methods:SetChecked(value) self.checked = value end
    function methods:GetChecked() return self.checked end
    function methods:SetText(text) self.text = text end
    function methods:GetText() return self.text end
    function methods:SetDefaultText(text) self.text = text end
    function methods:SetWidth(width) self.width = width end
    function methods:GetWidth() return self.width or 100 end
    function methods:SetSize(width, height) self.width, self.height = width, height end
    function methods:GetSize() return self.width or 100, self.height or 20 end
    function methods:SetPoint(...) self.point = { ... } end
    function methods:GetPoint() return unpack(self.point or { "TOPLEFT", nil, "TOPRIGHT", 6, -16 }) end
    function methods:ClearAllPoints() self.point = nil end
    function methods:GetName() return self.name end
    function methods:GetID() return self.id end
    function methods:RegisterEvent(event) self.events[event] = true end
    function methods:UnregisterEvent(event) self.events[event] = nil end
    function methods:GetChildren() return unpack(self.children) end
    function methods:GetRegions() return unpack(self.regions) end
    function methods:CreateFontString(name)
        local region = newFrame("FontString", name)
        region.parent = self
        table.insert(self.regions, region)
        return region
    end
    methods.CreateTexture = methods.CreateFontString
    function methods:GetHighlightTexture() return newFrame("Texture") end
    function methods:SetScrollChild(child) self.scrollChild = child end
    function methods:SetVerticalScroll(value) self.scroll = value end
    function methods:SetupMenu(fn) self.menu = fn end

    newFrame = function(kind, name, parent, template)
        local frame = setmetatable({ name = name, parent = parent, children = {}, regions = {}, scripts = {},
            events = {}, shown = true, enabled = true }, { __index = methods })
        if name then env[name] = frame end
        if parent then table.insert(parent.children, frame) end
        if template == "UIPanelScrollFrameTemplate" then
            frame.ScrollBar = newFrame("Slider", name .. "ScrollBar", frame)
        elseif template == "WowStyle1DropdownTemplate" then
            frame.Text = newFrame("FontString")
        elseif template == "DefaultPanelFlatTemplate" then
            assert(env.client.game == "camelot", "Forever's frame template used on another client")
            frame.NineSlice = newFrame("Frame", nil, frame)
            frame.NineSlice:SetFrameLevel(500)
            frame.TitleContainer = newFrame("Frame", nil, frame)
            frame.TitleContainer:SetFrameLevel(510)
            frame.TitleContainer.TitleText = frame.TitleContainer:CreateFontString()
        elseif template == "BasicFrameTemplate" then
            frame.CloseButton = newFrame("Button", nil, frame, "UIPanelCloseButtonDefaultAnchors")
        elseif template == "UIPanelCloseButtonDefaultAnchors" then
            frame:SetFrameLevel(510)
            frame:SetPoint("TOPRIGHT", env.client.game == "camelot" and -2 or 1, env.client.game == "camelot" and 1 or 0)
            frame:SetScript("OnClick", function() env.HideUIPanel(parent) end)
        end
        return frame
    end
    env.CreateFrame = newFrame
    env.UIParent = newFrame("Frame", "UIParent")
    env.GameTooltip = newFrame("GameTooltip", "GameTooltip")
    for _, name in ipairs({ "LootFrame", "MerchantFrame", "QuestFrame", "QuestFrameRewardPanel",
        "QuestFrameDetailPanel", "QuestInfoFrame", "GroupLootContainer", "GroupLootFrame1", "MailFrame", "OpenMailFrame" }) do
        newFrame("Frame", name):Hide()
    end
    if env.client.scrollBoxLoot then
        env.LootFrame.ScrollBox = newFrame("Frame")
        newFrame("Frame", "ContainerFrameCombinedBags"):Hide()
    else
        for i = 1, 4 do
            local button = newFrame("Button", "LootButton" .. i)
            button.slot = i
        end
    end
    env.DEFAULT_CHAT_FRAME = { AddMessage = function(_, text) table.insert(env.messages, text) end }
    env.GetLocale = function() return options.locale or "enUS" end
    env.GetBuildInfo = function() return "test", "test", "test", env.client.interface end
    env.GetTime = function() return env.time end
    env.C_Timer = { After = function(_, callback) table.insert(env.timers, callback) end }
    function env.runTimers()
        local timers = env.timers
        env.timers = {}
        env.time = env.time + 0.01
        for _, callback in ipairs(timers) do callback() end
    end
    env.UnitAffectingCombat = function() return env.inCombat or false end
    env.IsBagOpen = function(bag) return env.openBags[bag] or false end
    env.GetMoneyString = function(amount) return tostring(amount) .. "c" end
    env.HideUIPanel = function(frame) frame:Hide() end
    env.C_AddOns = { GetAddOnMetadata = function(name, key)
        assert(name == env.addonName and key == "Version")
        return options.version or "@project-version@"
    end }
    env.C_Item = {
        GetItemInfo = function(id)
            local item = env.items[id]
            if not item or item.pending then return nil end
            return item.name, item.link, item.quality, 1, 1, "Misc", "Junk", 20, "", 134400, item.price
        end,
        GetItemIconByID = function() return 134400 end,
        GetItemQualityColor = function() return 1, 1, 1, "ffffff" end,
        IsBound = function(location)
            return env.bags[location.bag].slots[location.slot].boundFallback or false
        end,
    }
    env.ItemLocation = { CreateFromBagAndSlot = function(_, bag, slot) return { bag = bag, slot = slot } end }
    env.C_Container = {
        GetContainerNumSlots = function(bag) return env.bags[bag] and env.bags[bag].size or 0 end,
        GetContainerItemInfo = function(bag, slot) return env.bags[bag] and env.bags[bag].slots[slot] end,
        GetContainerItemQuestInfo = function(bag, slot)
            local item = env.C_Container.GetContainerItemInfo(bag, slot)
            return item and item.quest or { isQuestItem = false }
        end,
        GetContainerNumFreeSlots = function(bag)
            local data = env.bags[bag]
            if not data then return 0, 0 end
            local count = data.size
            for _ in pairs(data.slots) do count = count - 1 end
            return count, data.family or 0
        end,
        PickupContainerItem = function(bag, slot)
            if env.pickupFails then return end
            local item = env.bags[bag].slots[slot]
            env.cursor = { "item", env.wrongCursorID or item.itemID }
            env.pickedUp = { bag, slot, item }
            env.bags[bag].slots[slot] = nil
        end,
        UseContainerItem = function(bag, slot) table.insert(env.sold, { bag, slot }) end,
    }
    env.GetCursorInfo = function() if env.cursor then return unpack(env.cursor) end end
    env.ClearCursor = function()
        if env.pickedUp then
            local p = env.pickedUp
            env.bags[p[1]].slots[p[2]] = p[3]
        end
        env.cursor, env.pickedUp = nil, nil
    end
    env.DeleteCursorItem = function()
        if env.deleteFails then return end
        table.insert(env.deleted, env.cursor[2])
        env.cursor, env.pickedUp = nil, nil
    end
    env.StaticPopup_Show = function(key, text1, text2, data)
        env.popup = { key = key, text1 = text1, text2 = text2, data = data }
    end
    env.Settings = {
        RegisterCanvasLayoutCategory = function(frame, name)
            env.category = { GetID = function() return 42 end, name = name, frame = frame }
            return env.category
        end,
        RegisterAddOnCategory = function(category) env.registeredCategory = category end,
        OpenToCategory = function(id) env.openedCategory = id end,
    }
    env.EventRegistry = { RegisterCallback = function(_, event, fn, owner)
        env.callbacks[event] = function(...) fn(owner, ...) end
    end }
    env.hooksecurefunc = function(name, fn)
        assert(name == "QuestInfoItem_OnClick")
        env.hooks[name] = fn
    end
    env.GetNumLootItems = function() return #env.loot end
    env.LootSlotHasItem = function(slot) return env.loot[slot] ~= nil end
    env.GetLootSlotType = function(slot) return env.loot[slot].kind or 1 end
    env.GetLootSlotLink = function(slot) return env.loot[slot].link end
    env.GetLootSlotInfo = function(slot)
        local item = env.loot[slot]
        return 134400, item.name, item.quantity or 1, nil, item.quality or 0, false, item.quest
    end
    env.LootSlot = function(slot) table.insert(env.looted, slot) end
    env.GetNumQuestChoices = function() return #(env.choices or {}) end
    env.GetNumQuestRewards = function() return #(env.rewards or {}) end
    env.GetNumQuestItems = function() return 0 end
    env.GetQuestItemInfo = function(kind, i)
        local item = (kind == "choice" and env.choices or env.rewards)[i]
        return item.name, 134400, item.quantity or 1, item.quality or 1, true, item.itemID
    end
    env.GetQuestItemLink = function(kind, i)
        return (kind == "choice" and env.choices or env.rewards)[i].link
    end

    function env.addItem(id, price, overrides)
        local item = { name = "Item " .. id, quality = 0, price = price,
            link = "|cffaaaaaa|Hitem:" .. id .. ":0|h[Item " .. id .. "]|h|r" }
        for key, value in pairs(overrides or {}) do item[key] = value end
        env.items[id] = item
        return item
    end
    function env.putItem(bag, slot, id, overrides)
        env.bags[bag] = env.bags[bag] or { size = 8, slots = {} }
        local item = env.items[id] or env.addItem(id, 1)
        local entry = { itemID = id, hyperlink = item.link, stackCount = 1,
            quality = item.quality, isLocked = false, isBound = false }
        for key, value in pairs(overrides or {}) do entry[key] = value end
        env.bags[bag].slots[slot] = entry
        return entry
    end
    function env.fire(event, ...)
        if env.DCIFrame.events[event] then env.DCIFrame:Fire("OnEvent", event, ...) end
    end
    function env.acceptPopup()
        env.StaticPopupDialogs[env.popup.key].OnAccept({}, env.popup.data)
    end
    for line in Helpers.readFile("DeleteCheapestItem.toc"):gmatch("[^\r\n]+") do
        if line:match("%.lua$") then
            local chunk = assert(loadfile(line))
            setfenv(chunk, env)(env.addonName, env.addon)
        end
    end
    env.addon.MAX_ITEM_FRAMES = 5
    if options.initialize ~= false then env.fire("ADDON_LOADED", env.addonName) end
    return env
end

return Helpers
