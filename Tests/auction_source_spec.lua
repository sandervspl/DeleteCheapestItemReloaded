local Helpers = dofile("Tests/helpers.lua")

local function installProviders(env)
    env.Auctionator = { API = { v1 = { GetAuctionPriceByItemID = function() return 100 end } } }
    env.TSM_API = {
        ToItemString = function(link) return "i:" .. link:match("item:(%d+)") end,
        GetCustomPriceValue = function(source, itemString)
            assert.equals("Dbminbuyout", source)
            assert.equals("i:10", itemString)
            return 300
        end,
    }
end

local function generateMenu(dropdown)
    local buttons = {}
    local root = { CreateButton = function(_, text, callback)
        local button = { text = text, callback = callback, enabled = true }
        function button:SetEnabled(value) self.enabled = value end
        table.insert(buttons, button)
        return button
    end }
    dropdown.menu(dropdown, root)
    return buttons
end

for _, client in ipairs(Helpers.clients) do
    describe(client.name .. " auction price source", function()
        it("uses automatic order by default and the selected provider when chosen", function()
            local env = Helpers.loadAddon({ client = client, beforeLoad = installProviders })
            local addon = env.addon
            addon.db.AuctionPriceHidePoorQuality = false
            env.addItem(10, 5)
            assert.equals("auto", addon.db.AuctionPriceSource)
            assert.equals(95, addon.ItemInfo[10].auctionPricePer)
            assert.equals("Auctionator", env.DCI_AuctionSource)

            addon.SetAuctionPriceSource("TSM")
            assert.equals("TSM", addon.db.AuctionPriceSource)
            assert.equals(285, addon.ItemInfo[10].auctionPricePer)
            assert.equals("TSM", env.DCI_AuctionSource)
        end)

        it("falls back to automatic order when the selected provider is not installed", function()
            local env = Helpers.loadAddon({ client = client, beforeLoad = installProviders })
            env.addon.SetAuctionPriceSource("Auctioneer")
            assert.is_true(env.addon.UseAuctionPrices())
            assert.equals("Auctionator", env.DCI_AuctionSource)
        end)

        it("re-resolves the provider when the profile changes", function()
            local env = Helpers.loadAddon({ client = client, beforeLoad = installProviders })
            env.addon.SetAuctionPriceSource("TSM")
            assert.is_true(env.addon.UseAuctionPrices())
            assert.equals("TSM", env.DCI_AuctionSource)
            env.addon.db.AuctionPriceSource = "auto"
            env.addon.ApplyProfile()
            assert.is_true(env.addon.UseAuctionPrices())
            assert.equals("Auctionator", env.DCI_AuctionSource)
        end)

        it("lists every provider in settings and disables those that are not installed", function()
            local env = Helpers.loadAddon({ client = client, beforeLoad = installProviders })
            local dropdown = env.DCI_Config_Dropdown_AuctionPriceSource
            assert.equals(env.DCI_Config_AuctionFrame, dropdown.parent)
            assert.equals("Automatic", dropdown.Text:GetText())

            local buttons = generateMenu(dropdown)
            local byText = {}
            for _, button in ipairs(buttons) do byText[button.text] = button end
            assert.equals(7, #buttons)
            assert.is_true(byText["Automatic"].enabled)
            assert.is_true(byText["Auctionator"].enabled)
            assert.is_true(byText["TSM"].enabled)
            assert.is_false(byText["Auctioneer (not installed)"].enabled)
            assert.is_false(byText["auxForever (not installed)"].enabled)

            byText["TSM"].callback()
            assert.equals("TSM", env.addon.db.AuctionPriceSource)
            assert.equals("TSM", dropdown.text)
            assert.equals("TSM", env.DCI_AuctionSource)
        end)
    end)
end
