addon.name      = 'tally'
addon.author    = 'Sithel Credit: Xavie and AddonsXI'
addon.version   = '1.3.1'
addon.desc      = 'Shows conquest regions,outposts, & currency in an ImGui window'

require('common')
local chat         = require('chat')
local imgui        = require('imgui')
local settings     = require('settings')
local REGION_ZONES = require('data/region_zones')
local ffi          = require('ffi')
local d3d          = require('d3d8')
local d3d8dev      = d3d.get_device()
local myNation     = -1

ffi.cdef[[
    HRESULT __stdcall D3DXCreateTextureFromFileA(
        IDirect3DDevice8* pDevice,
        const char* pSrcFile,
        IDirect3DTexture8** ppTexture
    );
]]

------------------------------------------------------------
-- SETTINGS 
------------------------------------------------------------
local default_settings = T{
    theme = 'gold',
    window_pos = T{ 100, 100 },
    last_tab   = T{ 1 },
}
local user_settings = settings.load(default_settings)

------------------------------------------------------------
-- THEME LOADER 
------------------------------------------------------------
local function loadTheme(name)
    return require('data/theme_' .. name)
end

local current_loaded_theme_name = nil
local theme = nil
local function updateActiveTheme()
    local target_theme = (user_settings and user_settings.theme) or 'gold'
    if current_loaded_theme_name ~= target_theme then
        theme = loadTheme(target_theme)
        current_loaded_theme_name = target_theme
    end
end

------------------------------------------------------------
-- Settings Logic
------------------------------------------------------------
local function SaveSettings()
    settings.save()
end
settings.register('settings', 'settings_update', function(new_settings)
    user_settings = new_settings
    updateActiveTheme()
end)

------------------------------------------------------------
-- Currency & Nation Icons
------------------------------------------------------------
local icons = {}
local function load_icon(filename)
    local path = addon.path .. 'assets\\' .. filename
    local ptr  = ffi.new('IDirect3DTexture8*[1]')
    if ffi.C.D3DXCreateTextureFromFileA(d3d8dev, path, ptr) == ffi.C.S_OK then
        local tex = ffi.new('IDirect3DTexture8*', ptr[0])
        d3d.gc_safe_release(tex)
        return tex
    end
    return nil
end

------------------------------------------------------------
-- UI STATE
------------------------------------------------------------
local regionSearch = T{''}
local activeTab    = 1

------------------------------------------------------------
-- PACKET CONSTANTS
------------------------------------------------------------
local BASE_OFFSET = 0x1D
local OFFSET_STEP = 4

------------------------------------------------------------
-- REGIONS / CONTROLLERS
------------------------------------------------------------
local REGIONS = {
    { name = 'Ronfaure - West Ronfaure',                 color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Zulkheim - Valkurm Dunes',                 color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Norvallen - Jugner Forest',                color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Gustaberg - North Gustaberg',              color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Derfland - Pashhow Marshlands',            color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Sarutabaruta - West Sarutabaruta',         color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Kolshushu - Buburimu Peninsula',           color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Aragoneu - Meriphataud Mountains',         color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Fauregandi - Beaucedine Glacier',          color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Valdeaunia - Xarcabard',                   color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Qufim - Qufim Island',                     color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Li\'Telor - Sanctuary of Zi\'Tah',         color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Kuzotz - Eastern Altepa Desert',           color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Vollbow - Cape Teriggan',                  color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Elshimo Lowlands - Yuhtunga Jungle',       color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Elshimo Uplands - Yhoator Jungle',         color = {0.90, 0.90, 1.0, 1.0} },
    { name = 'Tu\'Lia - No Outpost Warp',                color = {1.0, 0.6, 0.6, 1.0} },
    { name = 'Movalpolos - No Outpost Warp',             color = {1.0, 0.6, 0.6, 1.0} },
    { name = 'Tavnazian - Lufaise Meadows',              color = {0.90, 0.90, 1.0, 1.0} },
}

local CONTROLLERS = {
    [0] = { name = 'San d\'Oria', color = {1.0, 0.2, 0.2, 1.0} },
    [1] = { name = 'Bastok',      color = {0.2, 0.5, 1.0, 1.0} },
    [2] = { name = 'Windurst',    color = {0.0, 1.0, 0.0, 1.0} },
    [3] = { name = 'Beastmen',    color = {1.0, 0.6, 0.0, 1.0} },
}

local variables = {
    show_window       = T{ true },
    regionControllers = T{},
    awaitingPacket    = false,
}

------------------------------------------------------------
-- Currency
------------------------------------------------------------
local currency = {
    cp_sandoria        = nil,
    cp_bastok          = nil,
    cp_windurst        = nil,
    beastmen_seals     = nil,
    kindred_seals      = nil,
    ancient_beastcoins = nil,
    imperial           = nil,
}

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function split_region_area(fullname)
    local region, area = fullname:match('^(.-)%s*%-%s*(.+)$')
    return region or fullname, area or ''
end

local function requestConquest()
    local packet = struct.pack('L', 0)
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x5A, packet:totable())
end

local function requestCurrency()
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x010F, struct.pack('L', 0):totable())
end

local function update_character_nation()
    local player = AshitaCore:GetMemoryManager():GetPlayer()
    if player then
        myNation = player:GetNation()
    else
        myNation = -1
    end
end

local function reset_character_data()
    myNation = -1
    currency.cp_sandoria        = nil
    currency.cp_bastok          = nil
    currency.cp_windurst        = nil
    currency.beastmen_seals     = nil
    currency.kindred_seals      = nil
    currency.ancient_beastcoins = nil
    currency.imperial           = nil
end

------------------------------------------------------------
-- EVENTS
------------------------------------------------------------
ashita.events.register('load', 'tally_load_cb', function()
    icons.sandoria     = load_icon('san_dorian_flag.png')
    icons.bastok       = load_icon('bastokan_flag.png')
    icons.windurst     = load_icon('windurstian_flag.png')
    icons.beastman     = load_icon('beastman_flag.png')
    icons.kindred      = load_icon('kindreds_seal.png')
    icons.beastcoin    = load_icon('ancient_beastcoin.png')
    icons.beastmens    = load_icon('beastmens_seal.png')
    icons.sandoriacur  = load_icon('sandoria_icon.png')
    icons.bastokcur    = load_icon('bastok_icon.png')
    icons.windurstcur  = load_icon('windurst_icon.png')
    icons.imperialcur  = load_icon('imperial_icon.png')

    ashita.tasks.once(1, function()
        variables.awaitingPacket = true
        update_character_nation()
        requestConquest()
        requestCurrency()
    end)
end)

ashita.events.register('login', 'login_cb', function()
    reset_character_data()
    local loaded = settings.load(default_settings)
    if loaded then
        user_settings = loaded
    end
    updateActiveTheme()
    ashita.tasks.once(3, function()
        update_character_nation()
        requestConquest()
        requestCurrency()
    end)
end)
    
ashita.events.register('packet_in', 'packet_zone_cb', function(e)
    if e.id == 0x0A then
        ashita.tasks.once(3, function()
            --update_character_nation()
            requestCurrency()
            requestConquest()
        end)
    end
end)

ashita.events.register('unload', 'tally_unload_cb', function()
    reset_character_data()
end)

ashita.events.register('packet_in', 'packet_in_cb', function(e)
    if e.id == 0x5E then
        update_character_nation()
        currency.imperial = struct.unpack('H', e.data, 0xB0 + 1)

        for i = 1, #REGIONS do
            local offset = BASE_OFFSET + (i - 1) * OFFSET_STEP
            local rawOwner = struct.unpack('B', e.data, offset + 1)
            variables.regionControllers[i] = rawOwner - 1
        end
        variables.awaitingPacket = false
        return
    end

    if e.id == 0x0113 then
        update_character_nation()
        currency.cp_sandoria        = struct.unpack('I', e.data, 0x04 + 1)
        currency.cp_bastok          = struct.unpack('I', e.data, 0x08 + 1)
        currency.cp_windurst        = struct.unpack('I', e.data, 0x0C + 1)
        currency.beastmen_seals     = struct.unpack('H', e.data, 0x10 + 1)
        currency.kindred_seals      = struct.unpack('H', e.data, 0x12 + 1)
        currency.ancient_beastcoins = struct.unpack('H', e.data, 0x1A + 1)
        return
    end
end)

ashita.events.register('command', 'tally_command_cb', function(e)
    local args = e.command:args()
    if (#args == 0 or args[1] ~= '/tally') then return end
    e.blocked = true
    variables.show_window[1] = not variables.show_window[1]
end)

------------------------------------------------------------
-- Currency Helpers
------------------------------------------------------------
local GOLD = {1.0, 0.85, 0.2, 1.0}
-- Icons for smperial standing
local function currency_row(icon_key, label, amount)
    local ic = icons[icon_key]
    if ic then
        imgui.Image(tonumber(ffi.cast('uint32_t', ic)), {15, 15})
    else
        imgui.Dummy({15, 15})
    end
    imgui.SameLine()
    imgui.Text(label)
    imgui.SameLine(240)
    if amount ~= nil then
        imgui.TextColored(GOLD, tostring(amount))
    else
        imgui.TextDisabled('...')
    end
end
-- Icons for seal and beastcoins
local function seal_row(icon_key, label, stored)
    local ic = icons[icon_key]
    if ic then
        imgui.Image(tonumber(ffi.cast('uint32_t', ic)), {15, 15})
    else
        imgui.Dummy({17, 17})
    end
    imgui.SameLine()
    imgui.Text(label)
    imgui.SameLine(240)
    if stored ~= nil then
        imgui.TextColored(GOLD, tostring(stored))
    else
        imgui.TextDisabled('...')
    end
end
-- Icons for nation cp
local function nation_label_with_star(icon_key, label, amount, nationId)
    local ic = icons[icon_key]
    if ic then
        imgui.Image(tonumber(ffi.cast('uint32_t', ic)), {15, 15})
    else
        imgui.Dummy({15, 15})
    end
    imgui.SameLine()
    imgui.Text(label)
    if myNation == nationId then
        imgui.SameLine()
        imgui.TextColored({1.0, 0.85, 0.2, 1.0}, "*")
        --imgui.TextColored({1.0, 0.85, 0.2, 1.0}, "\xef\x80\x85") --Star
        --imgui.TextColored({1.0, 0.85, 0.2, 0.7}, "\xef\x94\xa1") --Crown
    end
    imgui.SameLine(240)
    if amount ~= nil then
        imgui.TextColored(GOLD, tostring(amount))
    else
        imgui.TextDisabled("...")
    end
end

------------------------------------------------------------
-- TAB BUTTON
------------------------------------------------------------
local function TabButton(label, id, tabColors)
    if activeTab == id then
        imgui.PushStyleColor(ImGuiCol_Button,        tabColors.active)
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, tabColors.active)
        imgui.PushStyleColor(ImGuiCol_ButtonActive,  tabColors.active)
    else
        imgui.PushStyleColor(ImGuiCol_Button,        tabColors.base)
        imgui.PushStyleColor(ImGuiCol_ButtonHovered, tabColors.hover)
        imgui.PushStyleColor(ImGuiCol_ButtonActive,  tabColors.hover)
    end

    if imgui.Button(label, {80, 24}) then
        activeTab = id
        if user_settings and user_settings.last_tab then
            user_settings.last_tab[1] = id
            settings.save()
        end
    end
    imgui.PopStyleColor(3)
end

------------------------------------------------------------
-- DRAW
------------------------------------------------------------
ashita.events.register('d3d_present', 'tally_present_cb', function()
    if not variables.show_window[1] then return end
    updateActiveTheme()
    if user_settings and user_settings.last_tab and activeTab ~= user_settings.last_tab[1] then
        if current_loaded_theme_name ~= nil then 
            activeTab = user_settings.last_tab[1]
        end
    end
    if not theme then return end

    theme.push()
    imgui.SetNextWindowSize(user_settings.window_pos, ImGuiCond_FirstUseEver)
    local window_flags = ImGuiWindowFlags_AlwaysAutoResize

    if not imgui.Begin('Tally', variables.show_window, window_flags) then
        imgui.End()
        theme.pop()
        return
    end
    local tabColors = theme.tabButton

    --------------------------------------------------------
    -- TAB BAR
    --------------------------------------------------------
    TabButton('Regions',  1, tabColors)
    imgui.SameLine()
    TabButton('Areas',    2, tabColors)
    imgui.SameLine()
    TabButton('Currency', 3, tabColors)
    imgui.SameLine()
    TabButton('Settings', 4, tabColors)
    imgui.Separator()
    imgui.Spacing()

    --------------------------------------------------------
    -- TAB 1: REGIONS
    --------------------------------------------------------
    if activeTab == 1 then
        imgui.NewLine()
        imgui.SameLine(20)
        imgui.TextColored({0.5, 0.5, 0.5, 1.0}, 'Conquest Control')
        imgui.SameLine(200)
        imgui.TextColored({0.5, 0.5, 0.5, 1.0}, 'Outpost Area')
        imgui.Separator()

        if #variables.regionControllers == 0 then
            imgui.Text('No data...')
        else
            local controllerCounts = { [0]=0, [1]=0, [2]=0, [3]=0 }
            for i = 1, #REGIONS do
                local owner = variables.regionControllers[i]
                if owner then
                    controllerCounts[owner] = (controllerCounts[owner] or 0) + 1
                end
            end

            local sortedControllers = {0, 1, 2, 3}
            table.sort(sortedControllers, function(a, b)
                return (controllerCounts[a] or 0) > (controllerCounts[b] or 0)
            end)
            for _, id in ipairs(sortedControllers) do
                local nation = CONTROLLERS[id]

                if nation then
                    imgui.PushStyleColor(ImGuiCol_Text, nation.color)

                    local ic = icons[
                        id == 0 and 'sandoria' or
                        id == 1 and 'bastok'   or
                        id == 2 and 'windurst' or
                        id == 3 and 'beastman'
                    ]
                    if ic then
                        imgui.Image(tonumber(ffi.cast('uint32_t', ic)), {20, 20})
                        imgui.SameLine()
                    end
                    local count = controllerCounts[id] or 0
                    imgui.Text(nation.name)
                    imgui.SameLine()
                    imgui.TextColored({1.0, 0.85, 0.2, 0.7}, string.format("(%d)", count))
                    imgui.PopStyleColor()

                    imgui.Indent()
                    local found = false
                    for i, region in ipairs(REGIONS) do
                        if variables.regionControllers[i] == id then
                            local regionName, areaName = split_region_area(region.name)

                            imgui.PushStyleColor(ImGuiCol_Text, region.color)
                            imgui.Columns(2, nil, false)

                            imgui.Text(regionName)
                            imgui.NextColumn()
                            imgui.Text(areaName)
                            imgui.Columns(1)

                            imgui.PopStyleColor()
                            found = true
                        end
                    end
                    if not found then
                        imgui.TextDisabled('No regions controlled.')
                    end
                    imgui.Unindent()
                    imgui.Separator()
                end
            end
        end
    end

    --------------------------------------------------------
    -- TAB 2: REGION AREAS
    --------------------------------------------------------
    if activeTab == 2 then
        imgui.PushItemWidth(200)
        imgui.InputText('Search##regionsearch', regionSearch, 255)
        imgui.PopItemWidth()

        local query = regionSearch[1]:lower()
        local regionList = {}
        for region, zones in pairs(REGION_ZONES) do
            if query == '' then
                table.insert(regionList, { name = region, zones = zones })
            else
                local regionMatch = region:lower():find(query, 1, true)
                local zoneMatch = false
                for _, zone in ipairs(zones) do
                    if zone:lower():find(query, 1, true) then
                        zoneMatch = true
                        break
                    end
                end
                if regionMatch or zoneMatch then
                    table.insert(regionList, { name = region, zones = zones })
                end
            end
        end

        table.sort(regionList, function(a, b)
            return a.name < b.name
        end)
        local totalLines = 0
        for _, r in ipairs(regionList) do
            totalLines = totalLines + 1 + #r.zones
        end

        local halfLines = math.ceil(totalLines / 2)
        local left, right = {}, {}
        local running = 0
        for _, r in ipairs(regionList) do
            local blockHeight = 1 + #r.zones
            if running + blockHeight <= halfLines then
                table.insert(left, r)
                running = running + blockHeight
            else
                table.insert(right, r)
            end
        end

        imgui.Columns(2, nil, false)
        for _, r in ipairs(left) do
            imgui.TextColored({1.0, 0.85, 0.2, 1.0}, r.name)
            for _, zone in ipairs(r.zones) do
                imgui.Text("  " .. zone)
            end
            imgui.Spacing()
        end
        imgui.NextColumn()
        for _, r in ipairs(right) do
            imgui.TextColored({1.0, 0.85, 0.2, 1.0}, r.name)
            for _, zone in ipairs(r.zones) do
                imgui.Text("  " .. zone)
            end
            imgui.Spacing()
        end
        imgui.Columns(1)
    end

    --------------------------------------------------------
    -- TAB 3: CURRENCY
    --------------------------------------------------------
    if activeTab == 3 then
        imgui.TextColored(GOLD, 'Conquest')
        imgui.Separator()
        imgui.Spacing()
        local nations = {
            { key = 'sandoriacur', label = "San d'Oria", amount = currency.cp_sandoria, id = 0 },
            { key = 'bastokcur',   label = "Bastok",      amount = currency.cp_bastok,   id = 1 },
            { key = 'windurstcur', label = "Windurst",   amount = currency.cp_windurst, id = 2 },
        }
        for _, n in ipairs(nations) do
            nation_label_with_star(n.key, n.label, n.amount, n.id)
        end

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        imgui.TextColored(GOLD, 'Aht Urhgan')
        imgui.Separator()
        imgui.Spacing()
        currency_row('imperialcur', "Imperial Standing", currency.imperial)

        imgui.Spacing()
        imgui.Separator()
        imgui.Spacing()
        imgui.TextColored(GOLD, 'Seals & Coins')
        imgui.Separator()
        imgui.Spacing()
        seal_row('beastmens', "Beastmen's Seals",   currency.beastmen_seals)
        seal_row('kindred',   "Kindred's Seals",    currency.kindred_seals)
        seal_row('beastcoin', "Ancient Beastcoins", currency.ancient_beastcoins)

    end

    --------------------------------------------------------
    -- TAB 4: SETTINGS
    --------------------------------------------------------
    if activeTab == 4 then
        if imgui.Button('Update Info', {140, 24}) then
            variables.awaitingPacket = true
            requestConquest()
            requestCurrency()
        end
        imgui.SameLine()
        if imgui.IsItemHovered() then
            imgui.SetTooltip('Manual update. (CP, ISP, Seals, Coins, Regions)')
        end
        
        imgui.Spacing()
        imgui.NewLine()
        imgui.Text('Theme')
        imgui.SameLine()
        imgui.TextDisabled('(?)')
        if imgui.IsItemHovered() then
            imgui.SetTooltip('Choose a color theme for the Tally window.')
        end

        local themes  = { 'gold', 'blue', 'red', 'green', 'purple', 'ice', 'gray'}
        local current = user_settings.theme
        imgui.PushItemWidth(140)
        if imgui.BeginCombo('##theme_select', current) then
            for _, t in ipairs(themes) do
                local selected = (t == current)
                if imgui.Selectable(t, selected) then
                    user_settings.theme = t
                    SaveSettings()
                    updateActiveTheme()
                end
                if selected then imgui.SetItemDefaultFocus() end
            end
            imgui.EndCombo()
        end
        imgui.PopItemWidth()
    end
    imgui.End()
    theme.pop()
end)