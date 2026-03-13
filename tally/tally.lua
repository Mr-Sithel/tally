addon.name      = 'tally';
addon.author    = 'Sithel, Credit: AddonsXI';
addon.version   = '1.0.0';
addon.desc      = 'Shows conquest regions and outpost in an ImGui window.';

require('common');
local chat  = require('chat');
local imgui = require('imgui');

-- Packet 0x5E: controller bytes start at 0x1D and increment by 4.
local BASE_OFFSET = 0x1D;
local OFFSET_STEP = 4;

-- Regions 
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
};

local CONTROLLERS = {
    [1] = { name = 'San d\'Oria', color = {1.0, 0.2, 0.2, 1.0} },
    [2] = { name = 'Bastok',      color = {0.2, 0.5, 1.0, 1.0} },
    [3] = { name = 'Windurst',    color = {0.0, 1.0, 0.0, 1.0} },
    [4] = { name = 'Beastmen',    color = {1.0, 0.6, 0.0, 1.0} },
};

local variables = {
    show_window = { true },
    regionControllers = {},
    awaitingPacket = false,
};

local function split_region_area(fullname)
    local region, area = fullname:match("^(.-)%s*%-%s*(.+)$")
    return region or fullname, area or ""
end

-- Request packet from server
local function requestConquest()
    local packet = struct.pack('L', 0)
    AshitaCore:GetPacketManager():AddOutgoingPacket(0x5A, packet:totable())
end

-- Load
ashita.events.register('load', 'load_cb', function()
    ashita.tasks.once(1, function()
        variables.awaitingPacket = true
        requestConquest()
    end)
end)

-- Command
ashita.events.register('command', 'command_cb', function(e)
    local args = e.command:args()
    if (#args == 0 or args[1] ~= '/tally') then return end

    e.blocked = true
    variables.show_window[1] = not variables.show_window[1]
end)

-- Packet Handler
ashita.events.register('packet_in', 'packet_in_cb', function(e)
    if (e.id == 0x5E) then
        for i = 1, #REGIONS do
            local offset = BASE_OFFSET + (i - 1) * OFFSET_STEP
            variables.regionControllers[i] = struct.unpack('B', e.data, offset + 1)
        end
        variables.awaitingPacket = false
    end
end)

-- Draw
ashita.events.register('d3d_present', 'present_cb', function()
    if not variables.show_window[1] then return end

    imgui.SetNextWindowSize({ 360, 530 }, ImGuiCond_FirstUseEver)

    local window_flags = ImGuiWindowFlags_NoFocusOnAppearing
                       + ImGuiWindowFlags_NoNav

    if imgui.Begin('Tally', variables.show_window, window_flags) then
        if imgui.BeginTabBar('TallyTabs') then

            ----------------------------------------------------------------
            -- REGIONS TAB
            ----------------------------------------------------------------
            if imgui.BeginTabItem('Regions') then

                imgui.NewLine()
                imgui.SameLine(20)
                imgui.TextColored({0.5, 0.5, 0.5, 1.0}, 'Conquest Control')
                imgui.SameLine(200)
                imgui.TextColored({0.5, 0.5, 0.5, 1.0}, 'Outpost Area')
                imgui.Separator()
                -- Debug 
                -- imgui.ShowMetricsWindow()
                if #variables.regionControllers == 0 then
                    imgui.Text('No data...')
                else

                    --------------------------------------------------------
                    -- Count regions per controller
                    --------------------------------------------------------
                    local controllerCounts = { [1]=0, [2]=0, [3]=0, [4]=0 }

                    for i, region in ipairs(REGIONS) do
                        local owner = variables.regionControllers[i]
                        if controllerCounts[owner] then
                            controllerCounts[owner] = controllerCounts[owner] + 1
                        end
                    end

                    --------------------------------------------------------
                    -- Sort controllers by region count
                    --------------------------------------------------------
                    local sortedControllers = {1, 2, 3, 4}

                    table.sort(sortedControllers, function(a, b)
                        return controllerCounts[a] > controllerCounts[b]
                    end)

                    --------------------------------------------------------
                    -- Display sorted controllers
                    --------------------------------------------------------
                    for _, id in ipairs(sortedControllers) do
                        local nation = CONTROLLERS[id]

                        imgui.PushStyleColor(ImGuiCol_Text, nation.color)
                        imgui.Text(nation.name)
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

                imgui.EndTabItem()
            end

            ----------------------------------------------------------------
            -- SETTINGS TAB
            ----------------------------------------------------------------
            if imgui.BeginTabItem('Settings') then
                if imgui.Button('Update Regions', {140, 20}) then
                    variables.awaitingPacket = true
                    requestConquest()
                    print(chat.header('Tally'):append(chat.message('Regions Updated ...')))
                end
                imgui.SameLine()
                if imgui.IsItemHovered() then
                    imgui.SetTooltip('Manually update conquest tally if auto on load fails.')
                end

                imgui.NewLine()
                if imgui.Button('Reset Window Size', {140, 20}) then
                    imgui.SetWindowSize({ 360, 530 })
                end
                

                imgui.EndTabItem()
            end

            imgui.EndTabBar()
        end
    end
    imgui.End()
end)

