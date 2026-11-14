-- Credit:
    -- Xavie for help with currency parsing
    -- AddonsXI for the original Conquest Addon
    addon.name      = 'tally'
    addon.author    = 'Sithel'
    addon.version   = '1.5.1'
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

    -- Settings
    local default_settings = T{
        theme = 'gold',
        window_pos = T{ 100, 100 },
        last_tab = T{ 1 },
        scale = 1.0,
        opacity = 0.90,

        tag_state = T{
            stored = 0,
            has_tag = false,
            max_stored = 3,
            next_tag_time = 0,
        },
        mog_locker_expire = 0,
    }

    local user_settings = settings.load(default_settings)
    local activeCharacter = nil

    -- Currency
    local currency = {
        cp_sandoria         = nil,
        cp_bastok           = nil,
        cp_windurst         = nil,
        beastmen_seals      = nil,
        kindred_seals       = nil,
        ancient_beastcoins  = nil,
        imperial            = nil,
        nyzul_tokens        = nil,
        imp_tags            = nil,
        ap_mamool           = nil,
        ap_periqia          = nil,
        ap_lebros           = nil,
        ap_ilrusi           = nil,
        ap_leujaoam         = nil,
        cerulean_shards     = nil,
        haap_points         = nil,
        mog_locker_expire   = nil,
    }

    local tag_state = {
        stored = 0,
        has_tag = false,
        total = 0,
        max_stored = 3,
        max_total = 4,
        next_tag_time = 0,
        current_assault = 0,
        rytaal_initialized = false,
    }

    local ki_list = {}

    local function update_tag_total()
        local has_ki = (ki_list and ki_list[787] == true) or (tag_state.has_tag == true)
        local ki_bonus = has_ki and 1 or 0
        tag_state.total = tag_state.stored + ki_bonus
        currency.imp_tags = tag_state.stored
    end

    local function save_tag_state()
        if not user_settings then return end

        user_settings.tag_state = user_settings.tag_state or T{}

        if tag_state.stored and tag_state.stored >= 0 and tag_state.stored <= tag_state.max_stored then
            user_settings.tag_state.stored          = tag_state.stored
            user_settings.tag_state.has_tag         = tag_state.has_tag
            user_settings.tag_state.max_stored      = tag_state.max_stored
            user_settings.tag_state.next_tag_time   = tag_state.next_tag_time
            user_settings.tag_state.current_assault = tag_state.current_assault

            settings.save()
        end
    end

    local function load_saved_tag_state()
        if not user_settings or not user_settings.tag_state then return end

        local saved = user_settings.tag_state

        tag_state.stored             = (saved.stored ~= nil) and saved.stored or 0
        tag_state.has_tag            = saved.has_tag or false
        tag_state.max_stored         = saved.max_stored or 3
        tag_state.max_total          = tag_state.max_stored + 1
        tag_state.next_tag_time      = saved.next_tag_time or 0
        tag_state.current_assault    = saved.current_assault or 0
        tag_state.rytaal_initialized = true

        update_tag_total()
    end

    local function player_name()
        local party = AshitaCore:GetMemoryManager():GetParty()
        if (not party) then return nil end
        local name = party:GetMemberName(0)
        if (not name or name == '') then
            return nil
        end
        return name
    end

    local function load_character_settings()
        local name = player_name()
        if name and name ~= activeCharacter then
            activeCharacter = name
            user_settings = settings.load(default_settings)
            load_saved_tag_state()
            if user_settings and user_settings.mog_locker_expire then
                currency.mog_locker_expire = user_settings.mog_locker_expire
            end
        elseif not user_settings then
            user_settings = settings.load(default_settings)
            load_saved_tag_state()
            if user_settings and user_settings.mog_locker_expire then
                currency.mog_locker_expire = user_settings.mog_locker_expire
            end
        end
    end

    load_character_settings()

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

    local function SaveSettings()
        settings.save()
    end

    local Colors = {
        Missing = { 0.90, 0.50, 0.50, 1.0 },
        Have    = { 0.50, 0.70, 0.50, 1.0 },
    }

    local Icons = {
        Times = '\xef\x81\x97',
        Check = '\xef\x81\x98',
    }

    -- UI state & packet
    local regionSearch = T{''}
    local activeTab = 1
    local BASE_OFFSET = 0x1D
    local OFFSET_STEP = 4

    local CCWHITE = { 1.0, 1.0, 1.0, 1.0 }
    local CCRED   = { 1.0, 0.6, 0.6, 1.0 }

    -- Regions & Controllers
    local REGIONS = {
        { name = 'Ronfaure - West Ronfaure',                 color = CCWHITE },
        { name = 'Zulkheim - Valkurm Dunes',                 color = CCWHITE },
        { name = 'Norvallen - Jugner Forest',                color = CCWHITE },
        { name = 'Gustaberg - North Gustaberg',              color = CCWHITE },
        { name = 'Derfland - Pashhow Marshlands',            color = CCWHITE },
        { name = 'Sarutabaruta - West Sarutabaruta',         color = CCWHITE },
        { name = 'Kolshushu - Buburimu Peninsula',           color = CCWHITE },
        { name = 'Aragoneu - Meriphataud Mountains',         color = CCWHITE },
        { name = 'Fauregandi - Beaucedine Glacier',          color = CCWHITE },
        { name = 'Valdeaunia - Xarcabard',                   color = CCWHITE },
        { name = 'Qufim - Qufim Island',                     color = CCWHITE },
        { name = 'Li\'Telor - Sanctuary of Zi\'Tah',         color = CCWHITE },
        { name = 'Kuzotz - Eastern Altepa Desert',           color = CCWHITE },
        { name = 'Vollbow - Cape Teriggan',                  color = CCWHITE },
        { name = 'Elshimo Lowlands - Yuhtunga Jungle',       color = CCWHITE },
        { name = 'Elshimo Uplands - Yhoator Jungle',         color = CCWHITE },
        { name = 'Tavnazian - Lufaise Meadows',              color = CCWHITE },
        { name = 'Tu\'Lia - No Outpost Warp',                color = CCRED },
        { name = 'Movalpolos - No Outpost Warp',             color = CCRED },
    }

    local CONTROLLERS = {
        [0] = { name = 'San d\'Oria', color = {1.0, 0.2, 0.2, 1.0} },
        [1] = { name = 'Bastok',      color = {0.2, 0.5, 1.0, 1.0} },
        [2] = { name = 'Windurst',    color = {0.0, 1.0, 0.0, 1.0} },
        [3] = { name = 'Beastmen',    color = {1.0, 0.6, 0.0, 1.0} },
    }

    local variables = {
        show_window = T{ true },
        regionControllers = T{},
        awaitingPacket = false,
        dumped0113 = false,
    }

    -- Imperial Army ID Tags and Rytaal
    local RYTAAL_MENU_ID            = 268
    local MENU_OFFSET_MENU_ID       = 0x2C
    local MENU_PARAM_TAG_STOCK      = 0x0C
    local MENU_PARAM_ASSAULT        = 0x10
    local MENU_PARAM_HAVE_TAG       = 0x14
    local MENU_PARAM_TAG_TIME       = 0x18
    local ASSAULT_TAG_EPOCH         = 1009983600
    local ASSAULT_DEFAULT_MAX_STOCK = 3

    local ASSAULT_ORDERS = {
        [762] = 'Leujaoam Sanctum',
        [763] = 'Mamool Ja T.G.',
        [764] = 'Lebros Cavern',
        [765] = 'Periqia',
        [766] = 'Ilrusi Atoll'
    }

    local function format_lease_time(timestamp)
        if not timestamp or timestamp <= 0 then
            return 'Unknown'
        end
        return os.date('%Y/%m/%d %H:%M:%S', timestamp)
    end

    -- Register settings
    settings.register('settings', 'settings_update', function(new_settings)
        user_settings = new_settings
        updateActiveTheme()
        load_saved_tag_state()
    end)

    -- Icons
    local icons = {}

    local function load_icon(filename)
        local path = addon.path .. 'assets\\' .. filename
        local ptr = ffi.new('IDirect3DTexture8*[1]')
        if ffi.C.D3DXCreateTextureFromFileA(d3d8dev, path, ptr) == ffi.C.S_OK then
            local tex = ffi.new('IDirect3DTexture8*', ptr[0])
            d3d.gc_safe_release(tex)
            return tex
        end
        return nil
    end

    -- Helpers
    local function truncate_string(str, max_len)
        if not str then return '' end
        if #str > max_len then
            return str:sub(1, max_len - 1) .. '.'
        end
        return str
    end

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
        currency.nyzul_tokens       = nil
        currency.imp_tags           = nil
        currency.ap_mamool          = nil
        currency.ap_periqia         = nil
        currency.ap_lebros          = nil
        currency.ap_ilrusi          = nil
        currency.ap_leujaoam        = nil
        currency.cerulean_shards    = nil
        currency.haap_points        = nil
        currency.mog_locker_expire  = nil

        tag_state.stored = 0
        tag_state.has_tag = false
        tag_state.total = 0
        tag_state.max_stored = ASSAULT_DEFAULT_MAX_STOCK
        tag_state.max_total = 4
        tag_state.next_tag_time = 0
        tag_state.rytaal_initialized = false
    end

    local function update_from_rytaal(stock, mission, have_tag, anchor)
        if stock == nil or stock < 0 or stock > 4 then
            return
        end

        tag_state.rytaal_initialized = true
        tag_state.stored = stock

        if mission and ASSAULT_ORDERS[mission] then
            tag_state.current_assault = mission
        end

        if ki_list[787] ~= nil then
            tag_state.has_tag = ki_list[787]
        else
            tag_state.has_tag = (have_tag ~= nil and have_tag ~= 0)
        end

        if stock > tag_state.max_stored then
            tag_state.max_stored = stock
        end

        if stock >= tag_state.max_stored then
            tag_state.next_tag_time = 0
        elseif anchor ~= nil and anchor > 0 then
            tag_state.next_tag_time = anchor + ASSAULT_TAG_EPOCH
        else
            tag_state.next_tag_time = 0
        end

        update_tag_total()
        save_tag_state()
    end

    local function format_tag_time(seconds)
        if seconds <= 0 then
            return 'Ready'
        end

        local hours = math.floor(seconds / 3600)
        local minutes = math.floor((seconds % 3600) / 60)
        local secs = seconds % 60

        return string.format('%02dh:%02dm:%02ds', hours, minutes, secs)
    end

    local TAG_INTERVAL = 86400

    local function update_tag_regeneration()
        if not tag_state.rytaal_initialized then
            return
        end
        if tag_state.next_tag_time <= 0 then
            return
        end

        local now = os.time()
        if now < tag_state.next_tag_time then
            return
        end

        local elapsed = math.floor((now - tag_state.next_tag_time) / TAG_INTERVAL) + 1
        local old_stored = tag_state.stored

        tag_state.stored = math.min(
            tag_state.stored + elapsed,
            tag_state.max_stored
        )
        if tag_state.stored >= tag_state.max_stored then
            tag_state.next_tag_time = 0
        else
            tag_state.next_tag_time =
                tag_state.next_tag_time + (elapsed * TAG_INTERVAL)
        end
        update_tag_total()
        if tag_state.stored ~= old_stored then
            save_tag_state()
        end
    end

    local function get_tag_timer()
        if not tag_state.rytaal_initialized then
            return 'See Rytaal'
        end
        update_tag_regeneration()
        if tag_state.stored >= tag_state.max_stored then
            return 'Full'
        end
        if tag_state.next_tag_time > 0 then
            local remaining = tag_state.next_tag_time - os.time()

            if remaining > 0 then
                return format_tag_time(remaining)
            end
        end
        return 'See Rytaal'
    end

    local function get_current_assault()
        for id, name in pairs(ASSAULT_ORDERS) do
            if ki_list[id] == true then
                if tag_state.current_assault ~= id then
                    tag_state.current_assault = id
                    save_tag_state()
                end
                return name
            end
        end

        if tag_state.current_assault and tag_state.current_assault > 0 then
            if ki_list[tag_state.current_assault] == false then
                tag_state.current_assault = 0
                save_tag_state()
                return nil
            end

            return ASSAULT_ORDERS[tag_state.current_assault]
        end

        return nil
    end

    -- Events
    ashita.events.register('load', 'tally_load_cb', function()
        icons.sandoria      = load_icon('san_dorian_flag.png')
        icons.bastok        = load_icon('bastokan_flag.png')
        icons.windurst      = load_icon('windurstian_flag.png')
        icons.beastman      = load_icon('beastman_flag.png')
        icons.kindred       = load_icon('kindreds_seal.png')
        icons.beastcoin     = load_icon('ancient_beastcoin.png')
        icons.beastmens     = load_icon('beastmens_seal.png')
        icons.sandoriacur   = load_icon('sandoria_icon.png')
        icons.bastokcur     = load_icon('bastok_icon.png')
        icons.windurstcur   = load_icon('windurst_icon.png')
        icons.imperialcur   = load_icon('imperial_icon.png')
        icons.nyzul_tokens  = load_icon('tokens_icon.png')
        icons.imp_tags      = load_icon('imp_tag_icon.png')
        icons.assaults      = load_icon('assault_icon.png')
        icons.haap          = load_icon('haap_icon.png')
        icons.henm          = load_icon('henm_icon.png')

        load_character_settings()

        ashita.tasks.once(1, function()
            variables.awaitingPacket = true
            update_character_nation()
            requestConquest()
            requestCurrency()
        end)
    end)

    ashita.events.register('login', 'login_cb', function()
        reset_character_data()
        load_character_settings()
        updateActiveTheme()

        ashita.tasks.once(3, function()
            update_character_nation()
            requestConquest()
            requestCurrency()
        end)
    end)

    ashita.events.register('unload', 'tally_unload_cb', function()
        reset_character_data()
    end)

    -- Packet in
    ashita.events.register('packet_in', 'tally_packet_in_cb', function(e)
        if e.id == 0x000A then
            ashita.tasks.once(3, function()
                requestCurrency()
                requestConquest()
            end)
            return
        end

        if e.id == 0x002A then
            if e.size >= 12 then
                local menu_type = struct.unpack('H', e.data, 0x04 + 1)
                if menu_type == 0xE701 then
                    local raw_time = struct.unpack('I', e.data, 0x08 + 1)
                    if raw_time > 0 then
                        local calculated_time = raw_time + ASSAULT_TAG_EPOCH - 172800

                        if calculated_time > 1735689600 and calculated_time < 2524646400 then
                            currency.mog_locker_expire = calculated_time
                            user_settings.mog_locker_expire = currency.mog_locker_expire
                            settings.save()
                        end
                    end
                end
            end
            return
        end

        if e.id == 0x0055 then
            local ki_type = ashita.bits.unpack_be(e.data_raw, 0x84 * 8, 8)
            local idBase = ki_type * 512
            local heldBit = 0x04 * 8

            for i = 0, 511 do
                ki_list[idBase + i] =
                    (ashita.bits.unpack_be(e.data_raw, heldBit + i, 1) == 1)
            end

            if ki_list[787] ~= nil then
                tag_state.has_tag = ki_list[787]
            
                update_tag_total()
                save_tag_state()
            end
            
            return
        end

        if e.id == 0x005E then
            update_character_nation()
            currency.imperial = struct.unpack('I', e.data, 0xB0 + 1)

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
            currency.nyzul_tokens       = struct.unpack('I', e.data, 0x4C + 1)
            currency.ap_leujaoam        = struct.unpack('I', e.data, 0x80 + 1)
            currency.ap_mamool          = struct.unpack('I', e.data, 0x84 + 1)
            currency.ap_lebros          = struct.unpack('I', e.data, 0x88 + 1)
            currency.ap_periqia         = struct.unpack('I', e.data, 0x8C + 1)
            currency.ap_ilrusi          = struct.unpack('I', e.data, 0x90 + 1)
            currency.cerulean_shards    = struct.unpack('I', e.data, 0x50 + 1)
            currency.haap_points        = struct.unpack('I', e.data, 0xE0 + 1)

            return
        end

        if e.id == 0x0034 then
            if e.data == nil or #e.data < MENU_OFFSET_MENU_ID + 2 then
                return
            end
            local menu_id = struct.unpack('H', e.data, MENU_OFFSET_MENU_ID + 1)

            if menu_id ~= RYTAAL_MENU_ID then
                return
            end
            if #e.data < MENU_PARAM_TAG_TIME + 4 then
                return
            end

            local stock     = struct.unpack('L', e.data, MENU_PARAM_TAG_STOCK + 1)
            local mission   = struct.unpack('L', e.data, MENU_PARAM_ASSAULT + 1)
            local have_tag  = struct.unpack('L', e.data, MENU_PARAM_HAVE_TAG + 1)
            local anchor    = struct.unpack('L', e.data, MENU_PARAM_TAG_TIME + 1)

            update_from_rytaal(stock, mission, have_tag, anchor)
            return
        end
    end)

    -- Command
    ashita.events.register('command', 'tally_command_cb', function(e)
        local args = e.command:args()
        if (#args == 0 or args[1] ~= '/tally') then return end

        e.blocked = true
        variables.show_window[1] = not variables.show_window[1]
    end)

    -- Currency Row
    local WHITE = {1.0, 1.0, 1.0, 1.0}
    local GREEN = {0.50, 0.70, 0.5, 1.0}

    local function currency_row(icon_key, label, amount, scale)
        local ic = icons[icon_key]
        local icon_size = math.max(12, math.floor(15 * scale))

        if ic then
            imgui.Image(tonumber(ffi.cast('uint32_t', ic)), {icon_size, icon_size})
        else
            imgui.Dummy({icon_size, icon_size})
        end

        imgui.SameLine()
        imgui.Text(label)

        if amount ~= nil then
            local str = tostring(amount)
            local text_w = imgui.CalcTextSize(str)
            local avail = imgui.GetContentRegionAvail()
            local avail_w = type(avail) == 'table' and (avail.x or avail[1] or 0) or tonumber(avail) or 0
            imgui.SameLine(math.max(0, avail_w - text_w - (16 * scale)))
            imgui.TextColored(WHITE, str)
        else
            local str = '...'
            local text_w = imgui.CalcTextSize(str)
            local avail = imgui.GetContentRegionAvail()
            local avail_w = type(avail_res) == 'table' and (avail_res.x or avail_res[1] or 0) or tonumber(avail) or 0
            imgui.SameLine(math.max(0, avail_w - text_w - (16 * scale)))
            imgui.TextDisabled(str)
        end
    end

    -- Imperial Tag Row
    local function imperial_tag_row(scale)
        local ic = icons.imp_tags
        local icon_size = math.max(12, math.floor(15 * scale))

        if ic then
            imgui.Image(tonumber(ffi.cast('uint32_t', ic)), {icon_size, icon_size})
        else
            imgui.Dummy({icon_size, icon_size})
        end

        imgui.SameLine()
        imgui.Text('Imperial Tag')

        if not tag_state.rytaal_initialized then
            local str = '...'
            local text_w = imgui.CalcTextSize(str)
            local avail = imgui.GetContentRegionAvail()
            local avail_w = type(avail) == 'table' and (avail.x or avail[1] or 0) or tonumber(avail) or 0
            imgui.SameLine(avail_w - text_w - (16 * scale))
            imgui.TextDisabled(str)
            return
        end

        local timer = get_tag_timer()
        local str = string.format('%d/%d', tag_state.stored, tag_state.max_stored)
        local text_w = imgui.CalcTextSize(str)

        -- Measure timer text width if it's showing [Ready] or [See Rytaal], otherwise estimate small icon width (~16px)
        local extra_w = 16 * scale
        if timer == 'Ready' then
            extra_w = imgui.CalcTextSize('[Ready]') + 4
        elseif timer == 'See Rytaal' then
            extra_w = imgui.CalcTextSize('[See Rytaal]') + 4
        end

        local avail = imgui.GetContentRegionAvail()
        local avail_w = type(avail) == 'table' and (avail.x or avail[1] or 0) or tonumber(avail) or 0

        -- Position everything cleanly based on the combined width plus our 16 * scale margin buffer
        imgui.SameLine(avail_w - text_w - extra_w - (16 * scale))
        imgui.TextColored(WHITE, str)

        imgui.SameLine()

        if timer == 'Ready' then
            imgui.TextColored({0.0, 1.0, 0.0, 1.0}, '[Ready]')
        elseif timer == 'See Rytaal' then
            imgui.TextDisabled('[See Rytaal]')
        else
            imgui.TextColored({0.5, 0.7, 0.5, 1.0}, "\xef\x80\xab")
        end

        if imgui.IsItemHovered() then
            if ki_list[787] ~= nil then
                tag_state.has_tag = ki_list[787]
                update_tag_total()
            end

            local total_usable = tag_state.stored + (tag_state.has_tag and 1 or 0)
            local total_max_usable = tag_state.max_stored + 1

            local text = string.format(
                'Rytaal Stored: %d / %d\nTotal Usable: %d / %d',
                tag_state.stored,
                tag_state.max_stored,
                total_usable,
                total_max_usable
            )

            if tag_state.stored >= tag_state.max_stored then
                text = text .. '\nNext Tag: Full'
            elseif tag_state.next_tag_time > 0 then
                local remaining = tag_state.next_tag_time - os.time()

                if remaining > 0 then
                    text = text .. '\nNext Tag: ' .. format_tag_time(remaining)
                else
                    text = text .. '\nNext Tag: Ready'
                end
            end

            imgui.SetTooltip(text)
        end
    end

    -- Imperial KI Row
    local function imperial_ki_row(scale)
        local ic = icons.imp_tags
        local icon_size = math.max(12, math.floor(15 * scale))

        if ic then
            imgui.Image(tonumber(ffi.cast('uint32_t', ic)), {icon_size, icon_size})
        else
            imgui.Dummy({icon_size, icon_size})
        end

        imgui.SameLine()
        imgui.Text('Imperial Tag K.I.')

        local have_ki = ki_list[787] == true or tag_state.has_tag == true
        local str = have_ki and Icons.Check or Icons.Times
        local text_w = imgui.CalcTextSize(str)
        local avail = imgui.GetContentRegionAvail()
        local avail_w = type(avail) == 'table' and (avail.x or avail[1] or 0) or tonumber(avail) or 0

        imgui.SameLine(avail_w - text_w - (16 * scale))
        imgui.PushStyleColor(ImGuiCol_Text, have_ki and Colors.Have or Colors.Missing)
        imgui.Text(str)
        imgui.PopStyleColor()

        local assault_name = get_current_assault()

        if assault_name and assault_name ~= '' then
            local Color1 = { 0.50, 0.70, 0.50, 1.00 } -- Light Green
            local Color2 = { 0.50, 0.70, 0.50, 1.00 } -- Light Green

            imgui.Indent(25 * scale)
            imgui.TextColored(Color1, 'Assault Orders K.I.')

            local chk_w = imgui.CalcTextSize(Icons.Check)
            local avail_sub = imgui.GetContentRegionAvail()
            local avail_sub_w = type(avail_sub) == 'table' and (avail_sub.x or avail_sub[1] or 0) or tonumber(avail_sub) or 0

            imgui.SameLine(avail_sub_w - chk_w)
            imgui.PushStyleColor(ImGuiCol_Text, Colors.Have)
            imgui.Text(Icons.Check)
            imgui.PopStyleColor()

            imgui.TextColored(Color2, tostring(assault_name))
            imgui.Unindent(25 * scale)
        end
    end

    -- Seal Row
    local function seal_row(icon_key, label, stored, tooltip_text, scale)
        local ic = icons[icon_key]
        local icon_size = math.max(12, math.floor(15 * scale))

        if ic then
            imgui.Image(tonumber(ffi.cast('uint32_t', ic)), {icon_size, icon_size})
        else
            imgui.Dummy({icon_size, icon_size})
        end

        imgui.SameLine()
        imgui.Text(label)

        if tooltip_text and imgui.IsItemHovered() then
            imgui.SetTooltip(tooltip_text)
        end

        if stored ~= nil then
            local str = tostring(stored)
            local text_w = imgui.CalcTextSize(str)
            local avail = imgui.GetContentRegionAvail()
            local avail_w = type(avail) == 'table' and (avail.x or avail[1] or 0) or tonumber(avail) or 0
            imgui.SameLine(avail_w - text_w - (16 * scale))
            imgui.TextColored(WHITE, str)
        else
            local str = '...'
            local text_w = imgui.CalcTextSize(str)
            local avail = imgui.GetContentRegionAvail()
            local avail_w = type(avail) == 'table' and (avail.x or avail[1] or 0) or tonumber(avail) or 0
            imgui.SameLine(avail_w - text_w - (16 * scale))
            imgui.TextDisabled(str)
        end
    end

    -- Nation Row
    local function nation_label_with_star(icon_key, label, amount, nationId, scale)
        local ic = icons[icon_key]
        local icon_size = math.max(12, math.floor(15 * scale))

        if ic then
            imgui.Image(tonumber(ffi.cast('uint32_t', ic)), {icon_size, icon_size})
        else
            imgui.Dummy({icon_size, icon_size})
        end

        imgui.SameLine()
        imgui.Text(label)

        if myNation == nationId then
            imgui.SameLine()
            imgui.TextColored({1.0, 1.0, 1.0, 1.0}, "*")
            
            if imgui.IsItemHovered() then
                imgui.SetTooltip(' Your current Nation.')
            end
        end

        if amount ~= nil then
            local str = tostring(amount)
            local text_w = imgui.CalcTextSize(str)
            local avail = imgui.GetContentRegionAvail()
            local avail_w = type(avail) == 'table' and (avail.x or avail[1] or 0) or tonumber(avail) or 0
            imgui.SameLine(avail_w - text_w - (16 * scale))
            imgui.TextColored(WHITE, str)
        else
            local str = '...'
            local text_w = imgui.CalcTextSize(str)
            local avail = imgui.GetContentRegionAvail()
            local avail_w = type(avail) == 'table' and (avail.x or avail[1] or 0) or tonumber(avail) or 0
            imgui.SameLine(avail_w - text_w - (16 * scale))
            imgui.TextDisabled(str)
        end
    end

    -- Tab Button
    local function TabButton(label, id, tabColors, width, scale)
        local is_active = (activeTab == id)

        if is_active then
            imgui.PushStyleColor(ImGuiCol_Button, tabColors.active)
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, tabColors.active)
            imgui.PushStyleColor(ImGuiCol_ButtonActive, tabColors.active)
            imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 })
        else
            imgui.PushStyleColor(ImGuiCol_Button, tabColors.base)
            imgui.PushStyleColor(ImGuiCol_ButtonHovered, tabColors.hover)
            imgui.PushStyleColor(ImGuiCol_ButtonActive, tabColors.hover)
            imgui.PushStyleColor(ImGuiCol_Text, tabColors.disable or { 0.65, 0.65, 0.65, 1.0 })
        end

        if imgui.Button(label, {width, 24 * scale}) then
            activeTab = id

            if user_settings and user_settings.last_tab then
                user_settings.last_tab[1] = id
                settings.save()
            end
        end

        imgui.PopStyleColor(4)
    end

    -- Render
    ashita.events.register('d3d_present', 'tally_present_cb', function()
        load_character_settings()
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
        imgui.SetNextWindowBgAlpha(user_settings.opacity or 0.90)

        local scale = user_settings.scale or 1.0
        local base_width = 410
        -- Floor at 350px for low scales, scale dynamically above 1.0
        local scaled_width = math.max(380, base_width * scale)

        imgui.SetNextWindowSize({ scaled_width, 0 }, ImGuiCond_Always)
        local window_flags = ImGuiWindowFlags_AlwaysAutoResize

        local font      = imgui.GetFont()
        local font_size = imgui.GetFontSize() * scale
        imgui.PushFont(font, font_size)

        if not imgui.Begin('Tally', variables.show_window, window_flags) then
            imgui.End()
            imgui.PopFont()
            theme.pop()
            return
        end

        local tabColors = theme.tabButton

        -- Dynamic Tab Width Calculation
        local avail_res = imgui.GetContentRegionAvail()
        local avail_w = type(avail_res) == 'table' and (avail_res.x or avail_res[1] or 0) or tonumber(avail_res) or 0
        local style = imgui.GetStyle()
        local item_spacing_x = (style and style.ItemSpacing) and style.ItemSpacing.x or 4

        -- Allocate tab button widths with balanced padding
        local tab_btn_width = (avail_w - (3 * item_spacing_x)) / 4

        -- Tab Buttons
        TabButton('Regions', 1, tabColors, tab_btn_width, scale)
        imgui.SameLine()
        TabButton('Areas', 2, tabColors, tab_btn_width, scale)
        imgui.SameLine()
        TabButton('Currency', 3, tabColors, tab_btn_width, scale)
        imgui.SameLine()
        TabButton('Settings', 4, tabColors, tab_btn_width, scale)

        imgui.Separator()
        imgui.Spacing()

        -- TAB 1: REGIONS
        if activeTab == 1 then
            imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 })
            local open_conquest_header = imgui.CollapsingHeader('Conquest Control & Outpost Area', ImGuiTreeNodeFlags_DefaultOpen)
            imgui.PopStyleColor()

            if open_conquest_header then
                imgui.Separator()
                if #variables.regionControllers == 0 then
                    imgui.Text('No data...')
                else
                    local controllerCounts = {[0]=0, [1]=0, [2]=0, [3]=0}

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

                    for idx, id in ipairs(sortedControllers) do
                        local nation = CONTROLLERS[id]

                        if nation then
                            imgui.PushStyleColor(ImGuiCol_Text, nation.color)

                            local ic = icons[
                                id == 0 and 'sandoria' or
                                id == 1 and 'bastok' or
                                id == 2 and 'windurst' or
                                id == 3 and 'beastman'
                            ]

                            if ic then
                                imgui.Image(tonumber(ffi.cast('uint32_t', ic)), {20 * scale, 20 * scale})
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

                                    local shortRegion = truncate_string(regionName, 17)
                                    local shortArea   = truncate_string(areaName, 17)

                                    imgui.PushStyleColor(ImGuiCol_Text, region.color)
                                    imgui.Columns(2, nil, false)

                                    -- Set first column width dynamically based on scale
                                    imgui.SetColumnWidth(0, 185 * scale)

                                    imgui.Text(shortRegion)
                                    if imgui.IsItemHovered() then imgui.SetTooltip(regionName) end

                                    imgui.NextColumn()
                                    imgui.Text(shortArea)
                                    if imgui.IsItemHovered() then imgui.SetTooltip(areaName) end

                                    imgui.Columns(1)
                                    imgui.PopStyleColor()

                                    found = true
                                end
                            end

                            if not found then
                                imgui.TextDisabled('No regions controlled.')
                            end

                            imgui.Unindent()
                            if idx < #sortedControllers then
                                imgui.Separator()
                            end
                        end
                    end
                end
            end
        end

        -- TAB 2: REGION AREAS
        if activeTab == 2 then
            imgui.PushItemWidth(200 * scale)
            imgui.InputText('Search##regionsearch', regionSearch, 255)
            imgui.PopItemWidth()

            local query = regionSearch[1]:lower()
            local regionList = {}

            for region, zones in pairs(REGION_ZONES) do
                if query == '' then
                    table.insert(regionList, {name = region, zones = zones})
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
                        table.insert(regionList, {name = region, zones = zones})
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

            local avail_res = imgui.GetContentRegionAvail()
            local avail_w = type(avail_res) == 'table' and (avail_res.x or avail_res[1] or 0) or tonumber(avail_res) or 0

            imgui.Columns(2, nil, false)
            imgui.SetColumnWidth(0, avail_w * 0.52)

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

        -- TAB 3: CURRENCY
        if activeTab == 3 then
            local muted_color = tabColors.disable or { 0.65, 0.65, 0.65, 1.0 }

            -- Conquest
            imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 })
            local open_conquest = imgui.CollapsingHeader('Conquest', ImGuiTreeNodeFlags_DefaultOpen)
            imgui.PopStyleColor()

            if open_conquest then
                imgui.PushStyleColor(ImGuiCol_Text, muted_color)
                imgui.Spacing()
                local nations = {
                    {key = 'sandoriacur',   label = "San d'Oria",   amount = currency.cp_sandoria, id = 0},
                    {key = 'bastokcur',     label = "Bastok",       amount = currency.cp_bastok, id = 1},
                    {key = 'windurstcur',   label = "Windurst",     amount = currency.cp_windurst, id = 2},
                }

                for _, n in ipairs(nations) do
                    nation_label_with_star(n.key, n.label, n.amount, n.id, scale)
                end
                imgui.Spacing()
                imgui.PopStyleColor()
            end

            -- Mog Locker
            imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 })
            local open_mog = imgui.CollapsingHeader('Mog Locker', ImGuiTreeNodeFlags_DefaultOpen)
            imgui.PopStyleColor()

            if open_mog then
                imgui.PushStyleColor(ImGuiCol_Text, muted_color)
                imgui.Spacing()
                imgui.Text('Expiration Lease Date')
                if currency.mog_locker_expire ~= nil and currency.mog_locker_expire > 0 then
                    imgui.TextColored(GREEN, format_lease_time(currency.mog_locker_expire))
                else
                    imgui.TextDisabled('See Mog House Moogle...')
                end
                imgui.Spacing()
                imgui.PopStyleColor()
            end

            -- Aht Urhgan | Assault | Nyzul
            imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 })
            local open_aht = imgui.CollapsingHeader('Aht Urhgan | Assault | Nyzul', ImGuiTreeNodeFlags_DefaultOpen)
            imgui.PopStyleColor()

            if open_aht then
                imgui.PushStyleColor(ImGuiCol_Text, muted_color)
                imgui.Spacing()
                currency_row('imperialcur', "Imperial Standing", currency.imperial, scale)
                imperial_tag_row(scale)
                imperial_ki_row(scale)
                imgui.Spacing()
                imgui.PopStyleColor()
            end

            -- Seals | Coins | Shards | Points
            imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 })
            local open_seals = imgui.CollapsingHeader('Seals | Coins | Shards | Points', ImGuiTreeNodeFlags_DefaultOpen)
            imgui.PopStyleColor()

            if open_seals then
                imgui.PushStyleColor(ImGuiCol_Text, muted_color)
                imgui.Spacing()
                seal_row('beastmens', "Beastmen's Seals", currency.beastmen_seals, nil, scale)
                seal_row('kindred', "Kindred's Seals", currency.kindred_seals, nil, scale)
                seal_row('beastcoin', "Ancient Beastcoins", currency.ancient_beastcoins, nil, scale)
                seal_row('henm', "Cerulean Shards (HENM)", currency.cerulean_shards, "Available only on Horizon", scale)
                seal_row('haap', "H.A.A.P. Points", currency.haap_points, "Available only on Horizon", scale)
                imgui.Spacing()
                imgui.PopStyleColor()
            end

            -- Assault Points
            imgui.PushStyleColor(ImGuiCol_Text, { 1.0, 1.0, 1.0, 1.0 })
            local open_assault = imgui.CollapsingHeader('Assault Points', ImGuiTreeNodeFlags_DefaultOpen)
            imgui.PopStyleColor()

            if open_assault then
                imgui.PushStyleColor(ImGuiCol_Text, muted_color)
                imgui.Spacing()
                currency_row('assaults', "Leujaoam Sanctum", currency.ap_leujaoam, scale)
                currency_row('assaults', "Mamool Ja T. Grounds", currency.ap_mamool, scale)
                currency_row('assaults', "Lebros Cavern", currency.ap_lebros, scale)
                currency_row('assaults', "Periqia", currency.ap_periqia, scale)
                currency_row('assaults', "Ilrusi Atoll", currency.ap_ilrusi, scale)
                imgui.Spacing()
                imgui.PopStyleColor()
            end
        end

        -- TAB 4: SETTINGS
        if activeTab == 4 then
            if imgui.Button('Update Info', {140 * scale, 24 * scale}) then
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

            local themes = { 'gold', 'rose', 'blue', 'red', 'green', 'purple', 'orange', 'ice', 'gray'}
            local current = user_settings.theme or 'gold'

            imgui.PushItemWidth(140 * scale)
            if imgui.BeginCombo("##ct_theme_select", string.upper(current)) then
                for _, t in ipairs(themes) do
                    local selected = (t == current)

                    if imgui.Selectable(string.upper(t), selected) then
                        user_settings.theme = t
                        SaveSettings()
                        updateActiveTheme()
                    end
                    if selected then 
                        imgui.SetItemDefaultFocus() 
                    end
                end
                imgui.EndCombo()
            end
            imgui.PopItemWidth()

            imgui.Spacing()
            imgui.Separator()
            imgui.Spacing()

            imgui.Text('Interface Scale')
            variables.pendingScale = variables.pendingScale or user_settings.scale or 1.0
            local scale_ref = { variables.pendingScale }

            imgui.PushItemWidth(140 * scale)
            if imgui.SliderFloat('##ScaleSlider', scale_ref, 0.7, 2.0, '%.2f') then
                variables.pendingScale = scale_ref[1]
            end

            if imgui.IsItemDeactivatedAfterEdit() then
                user_settings.scale = variables.pendingScale
                settings.save()
            end
            imgui.PopItemWidth()

            imgui.Text('Window Opacity')
            variables.pendingOpacity = variables.pendingOpacity or user_settings.opacity or 0.90
            local opacity_ref = { variables.pendingOpacity }

            imgui.PushItemWidth(140 * scale)
            if imgui.SliderFloat('##OpacitySlider', opacity_ref, 0.1, 1.0, '%.2f') then
                variables.pendingOpacity = opacity_ref[1]
            end

            if imgui.IsItemDeactivatedAfterEdit() then
                user_settings.opacity = variables.pendingOpacity
                settings.save()
            end
            imgui.PopItemWidth()
        end

        imgui.End()
        imgui.PopFont()
        theme.pop()
    end)