-- ========== 设置你要显示的伪货币数量 ==========
local FAKE_G_AMOUNT = 78787878      -- G币数量
local FAKE_UC_AMOUNT = 99999991    -- UC数量  
local FAKE_SILVER_AMOUNT = 78916613 -- 银币数量（商店兑换用）
-- ============================================

local function wrapModule(moduleName, wrapFunc)
    local mod = package.loaded[moduleName]
    if mod then
        wrapFunc(mod)
    else
        package.preload[moduleName] = function()
            package.preload[moduleName] = nil
            local m = require(moduleName)
            wrapFunc(m)
            return m
        end
    end
end

local function hookLogicItemUtils(mod)
    if not mod or not mod.GetItemCount then return end
    local orig = mod.GetItemCount
    mod.GetItemCount = function(nItemId, bForever)
        local result = orig(nItemId, bForever)
        if nItemId and tonumber(nItemId) == 1109 then return FAKE_G_AMOUNT end
        if nItemId and tonumber(nItemId) == 1006 then return FAKE_UC_AMOUNT end
        if nItemId and tonumber(nItemId) == 1001 then return FAKE_SILVER_AMOUNT end
        local ok, ShopSystem = pcall(require, "client.logic.shop.logic_shop")
        if ok and ShopSystem and ShopSystem.jkActivePrice and ShopSystem.jkActivePrice.couponId then
            if tonumber(nItemId) == tonumber(ShopSystem.jkActivePrice.couponId) then
                return FAKE_G_AMOUNT
            end
        end
        return result
    end
end

local function hookMallSystem(mod)
    if not mod or not mod.GetItemCountInBag then return end
    local orig = mod.GetItemCountInBag
    mod.GetItemCountInBag = function(item_id)
        local result = orig(item_id)
        if item_id and tonumber(item_id) == 1109 then return FAKE_G_AMOUNT end
        if item_id and tonumber(item_id) == 1006 then return FAKE_UC_AMOUNT end
        if item_id and tonumber(item_id) == 1001 then return FAKE_SILVER_AMOUNT end
        local ok, ShopSystem = pcall(require, "client.logic.shop.logic_shop")
        if ok and ShopSystem and ShopSystem.jkActivePrice and ShopSystem.jkActivePrice.couponId then
            if tonumber(item_id) == tonumber(ShopSystem.jkActivePrice.couponId) then
                return FAKE_G_AMOUNT
            end
        end
        return result
    end
end

local function hookStoreUtils()
    pcall(function()
        local StoreUtils = require("client.slua.logic.store.utils.store_utils")
        if not StoreUtils or not StoreUtils.GetMoneyInfo then return end
        local orig = StoreUtils.GetMoneyInfo
        StoreUtils.GetMoneyInfo = function()
            local info = orig()
            info.nDiamond = FAKE_G_AMOUNT
            info.nUC = FAKE_UC_AMOUNT
            info.nSilver = FAKE_SILVER_AMOUNT
            return info
        end
    end)
end

pcall(function()
    wrapModule("client.slua.logic.common.Logic_ItemUtils", hookLogicItemUtils)
    wrapModule("client.logic.mall.logic_mall", hookMallSystem)
    hookStoreUtils()
    if DataMgr then
        DataMgr.eternal_diamond = FAKE_G_AMOUNT
        DataMgr.ticket = FAKE_UC_AMOUNT
        DataMgr.diamond = FAKE_SILVER_AMOUNT
    end
    if EventSystem and EVENTTYPE_DATA_MGR then
        local ev = _G.EVENTID_DATAMGR_ETERNAL_DIAMOND_CHANGE
        if ev then EventSystem:postEvent(EVENTTYPE_DATA_MGR, ev, FAKE_G_AMOUNT) end
        local evUC = _G.EVENTID_DATAMGR_TICKET_CHANGE
        if evUC then EventSystem:postEvent(EVENTTYPE_DATA_MGR, evUC, FAKE_UC_AMOUNT) end
        local evD = _G.EVENTID_DATAMGR_DIAMOND_CHANGE
        if evD then EventSystem:postEvent(EVENTTYPE_DATA_MGR, evD, FAKE_SILVER_AMOUNT) end
    end
    print("[FakeGCurrency] 已加载 - G=" .. FAKE_G_AMOUNT .. " UC=" .. FAKE_UC_AMOUNT .. " Silver=" .. FAKE_SILVER_AMOUNT)
end)

-- 使用定时器持续刷新（配合现有定时器系统）
if _G.Mytimer_ticker then
    _G.Mytimer_ticker.AddTimerLoop(3, function()
        pcall(function()
            hookStoreUtils()
            if DataMgr then
                DataMgr.eternal_diamond = FAKE_G_AMOUNT
                DataMgr.ticket = FAKE_UC_AMOUNT
                DataMgr.diamond = FAKE_SILVER_AMOUNT
            end
            if EventSystem and EVENTTYPE_DATA_MGR then
                if _G.EVENTID_DATAMGR_ETERNAL_DIAMOND_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_DATA_MGR, _G.EVENTID_DATAMGR_ETERNAL_DIAMOND_CHANGE, FAKE_G_AMOUNT)
                end
                if _G.EVENTID_DATAMGR_TICKET_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_DATA_MGR, _G.EVENTID_DATAMGR_TICKET_CHANGE, FAKE_UC_AMOUNT)
                end
                if _G.EVENTID_DATAMGR_DIAMOND_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_DATA_MGR, _G.EVENTID_DATAMGR_DIAMOND_CHANGE, FAKE_SILVER_AMOUNT)
                end
            end
        end)
    end, -1, 1)
elseif _G.SetTimer then
    _G.SetTimer(3, function()
        pcall(function()
            hookStoreUtils()
            if DataMgr then
                DataMgr.eternal_diamond = FAKE_G_AMOUNT
                DataMgr.ticket = FAKE_UC_AMOUNT
                DataMgr.diamond = FAKE_SILVER_AMOUNT
            end
            if EventSystem and EVENTTYPE_DATA_MGR then
                if _G.EVENTID_DATAMGR_ETERNAL_DIAMOND_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_DATA_MGR, _G.EVENTID_DATAMGR_ETERNAL_DIAMOND_CHANGE, FAKE_G_AMOUNT)
                end
                if _G.EVENTID_DATAMGR_TICKET_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_DATA_MGR, _G.EVENTID_DATAMGR_TICKET_CHANGE, FAKE_UC_AMOUNT)
                end
                if _G.EVENTID_DATAMGR_DIAMOND_CHANGE then
                    EventSystem:postEvent(EVENTTYPE_DATA_MGR, _G.EVENTID_DATAMGR_DIAMOND_CHANGE, FAKE_SILVER_AMOUNT)
                end
            end
        end)
    end)
end

_G.FakeGCurrency = { Amount = FAKE_G_AMOUNT, UC = FAKE_UC_AMOUNT, Silver = FAKE_SILVER_AMOUNT }
function _G.FakeGCurrency.OnLogin() end

-- ==================== 大厅/车库载具展示（追加，保留原特效） ====================
pcall(function()
    local DataMgr = require("client.logic.data.data_mgr")
    local ModuleManager = require("client.module_framework.ModuleManager")

    local MyThemeVehicleManager = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.ThemeVehicleManager)
    local MyGarageThemeSystem = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.GarageThemeSystem)

    if MyThemeVehicleManager then
        MyThemeVehicleManager.ShowThemeVehicle = function(self)
            if self then
                self:_ShowSelfVehicle()
            end
        end
    end

    if MyGarageThemeSystem then
        local O_GetSelfVehicleIDs = MyGarageThemeSystem.GetSelfGarageVehicleIDs
        MyGarageThemeSystem.GetSelfGarageVehicleIDs = function(self)
            if not self then return {} end

            if MyGarageThemeSystem:IsInGarageTheme() then
                local Result = {}
                local mylist = {
                    1961070, 1961071, 1961072, 1961073,
                    1908117, 1908118, 1908119, 1903230, 1903231, 1903232
                }
                local MaxNum = self:GetMaxPositionNum() or 0
                for i = 1, MaxNum do
                    table.insert(Result, mylist[i] or 0)
                end
                return Result
            end
            return O_GetSelfVehicleIDs(self)
        end
    end

    if MyThemeVehicleManager and MyThemeVehicleManager._ShowSelfVehicle then
        local O_ShowSelfVehicle = MyThemeVehicleManager._ShowSelfVehicle
        MyThemeVehicleManager._ShowSelfVehicle = function(self)
            if not self then return end

            -- 先调用原有逻辑（保留特效）
            if O_ShowSelfVehicle then
                O_ShowSelfVehicle(self)
            end

            -- 自定义大厅载具展示逻辑
            local VehicleRefitHandler = require("client.network.Protocol.VehicleRefitHandler")
            if not VehicleRefitHandler then return end

            local VehicleIDs = self:GetSelfVehicleIDs() or {}

            for Position, ItemID in pairs(VehicleIDs) do
                local StyleList = VehicleRefitHandler.GetCarStyleList(ItemID, nil, nil) or {}

                local LogicVehicleAccessory = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicVehicleAccessory)
                local accessoryList = LogicVehicleAccessory and LogicVehicleAccessory:GetEquipedAccessoryList(ItemID) or {}

                local LogicVehicleExtendedFeature = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.LogicVehicleExtendedFeature)
                local ChassisLight = LogicVehicleExtendedFeature and LogicVehicleExtendedFeature:GetEquipedChassisLightData(ItemID) or nil

                self:_TryCreateVehicleModel(
                    ItemID,
                    StyleList,
                    true,
                    Position,
                    accessoryList,
                    7302002,
                    DataMgr and DataMgr.roleData and DataMgr.roleData.uid
                )
            end
            self:OnVehicleChange()
        end
    end
end)


-- ==================== 个人资料伪造模块 ====================
-- 功能：段位、巅峰赛、赛季之旅徽章、等级、头像、头像框

-- ========== 征服者段位设置 ==========
local CURRENT_SEGMENT = 801          -- 801=征服者
local CONQUEROR_STARS = 91           -- 星星数
local CURRENT_RATING = 4200 + (CONQUEROR_STARS - 1) * 100  -- 13200分

-- ========== 生涯最高段位 ==========
local HISTORY_SEGMENT = 801

-- ========== 巅峰赛设置 ==========
local PEAK_CURRENT_SEGMENT = 1541    -- 当前巅峰段位
local PEAK_HISTORY_SEGMENT = 1301    -- 历史最高
local PEAK_RATING = 8000

-- ========== 赛季之旅徽章 ==========
local JOURNEY_BADGE_LEVEL = 17
local JOURNEY_BADGE_VISUAL_LEVEL = 3
local JOURNEY_BADGE_GLOW_TASKS = 3
local JOURNEY_GLOW_RANKS = { 701, 702, 703, 801 }
local ENABLE_SEASON_YEAR_BADGE = true
local SHOW_SEASON_SERIES_MEDAL = true
local SEASON_SERIES_SEGMENT = 0

-- ========== 个人资料底部数据 ==========
local SEASON_RATING = 8500
local SEASON_RANK = "44"
local ACHIEVEMENT_POINTS = 9500
local PLAYED_YEARS = 10
local CONQUEROR_TITLE_ID = 0

-- ========== 基础设置（会被定时器刷新） ==========
local PLAYER_LEVEL = 100
local AVATAR_ID = 30396
local AVATAR_BOX_ID = 2002901

-- ==================== 定时器刷新头像/等级 ====================
local function refresh_basic_data()
    pcall(function()
        if _G.DataMgr and _G.DataMgr.roleData then
            -- 等级
            _G.DataMgr.roleData.level = PLAYER_LEVEL
            -- 头像
            _G.DataMgr.roleData.pic_url = AVATAR_ID
            _G.DataMgr.roleData.headIconUrl = AVATAR_ID
            _G.DataMgr.roleData.pic_url_check_open = true
            -- 头像框
            _G.DataMgr.roleData.cur_avatar_box_id = AVATAR_BOX_ID
        end
    end)
end

if _G.Mytimer_ticker then
    -- 延迟2秒启动
    _G.Mytimer_ticker.AddTimer(2, refresh_basic_data)
    -- 每1秒刷新一次（防止被游戏覆盖）
    _G.Mytimer_ticker.AddTimerLoop(1, refresh_basic_data, -1, 1)
else
    refresh_basic_data()
end

-- ==================== 段位系统常量 ====================
local SEGMENT_TYPE = {
    solo = 1, double = 2, team = 3,
    fpp_solo = 4, fpp_double = 5, fpp_team = 6,
}
local RANK_MODES = { "solo", "duo", "squad", "fppsolo", "fppduo", "fppsquad" }
local ZONE_COUNT = 6

local RoleInfoSystem = require("client.logic.roleinfo.logic_roleinfo")
if not RoleInfoSystem then
    print("[SetRoleInfo] RoleInfoSystem not found")
    return
end

local function log_msg(...)
    print("[SetRoleInfo]", ...)
end

-- ==================== 辅助函数 ====================
local function stars_from_rating(rating)
    rating = tonumber(rating) or 0
    if rating < 4200 then return 0 end
    return math.max(0, math.floor((rating - 4200) / 100) + 1)
end

local function rating_from_stars(stars)
    stars = tonumber(stars) or 0
    if stars <= 0 then return 0 end
    return 4200 + (stars - 1) * 100
end

local function is_self_uid(uid)
    if not DataMgr or not DataMgr.roleData or not DataMgr.roleData.uid then return false end
    return tonumber(uid) == tonumber(DataMgr.roleData.uid)
end

local function get_fake_registertime()
    local ok, TimeUtil = pcall(require, "client.common.time_util")
    local now = (ok and TimeUtil and TimeUtil.GetServerTimeInSec and TimeUtil.GetServerTimeInSec()) or os.time()
    return now - (PLAYED_YEARS * 365 * 86400)
end

-- ==================== 征服者称号ID ====================
local function resolve_conqueror_title_id()
    if CONQUEROR_TITLE_ID and CONQUEROR_TITLE_ID > 0 then
        return CONQUEROR_TITLE_ID
    end
    local bestId, bestPri = nil, -1
    pcall(function()
        local tbl = CDataTable and CDataTable.GetTable and CDataTable.GetTable("SegmentTitleConfig")
        if not tbl then return end
        for id, cfg in pairs(tbl) do
            if cfg and not cfg.IfDefaultTitle then
                local pri = tonumber(cfg.Priority) or 0
                local tid = tonumber(cfg.ID) or tonumber(id)
                if tid and pri > bestPri then
                    bestPri = pri
                    bestId = tid
                end
            end
        end
    end)
    return bestId or 0
end

-- ==================== 构建假数据 ====================
local function build_zone_segments(seg)
    return {
        [SEGMENT_TYPE.solo] = seg,
        [SEGMENT_TYPE.double] = seg,
        [SEGMENT_TYPE.team] = seg,
        [SEGMENT_TYPE.fpp_solo] = seg,
        [SEGMENT_TYPE.fpp_double] = seg,
        [SEGMENT_TYPE.fpp_team] = seg,
    }
end

local function build_allzone_segment(seg)
    local t = {}
    for z = 1, ZONE_COUNT do
        t[z] = build_zone_segments(seg)
    end
    return t
end

local function build_rankdata(rating)
    local rd = {}
    local entry = { rank_rating = rating }
    for z = 1, ZONE_COUNT do
        rd[z] = {}
        for _, mode in ipairs(RANK_MODES) do
            rd[z][mode] = entry
        end
    end
    return rd
end

local function build_hsegment_title(titleId)
    if not titleId or titleId <= 0 then return nil end
    local det = {}
    for z = 1, ZONE_COUNT do
        det[z] = {}
        for modeId = 1, 6 do
            det[z][modeId] = { id = titleId }
        end
    end
    return det
end

-- ==================== 巅峰赛数据 ====================
local function build_peakgame_list(segmentId, maxSegmentId, rating)
    local ok, PeakGameConfig = pcall(require, "client.logic.PeakGame.PeakGameConfig")
    if not ok or not PeakGameConfig then return nil end
    local bt = PeakGameConfig.BattleType.Squad
    local list = {}
    for z = 1, ZONE_COUNT do
        list[z] = {
            [bt] = {
                rating = rating or PeakGameConfig.DefaultPeakGameRating,
                segment_id = segmentId or PeakGameConfig.DefaultPeakGameSegment,
                max_segment_id = maxSegmentId or segmentId or PeakGameConfig.DefaultPeakGameSegment,
            },
        }
    end
    return list
end

local function build_peakgame_segment_info(segmentId, maxSegmentId, rating)
    local list = build_peakgame_list(segmentId, maxSegmentId, rating)
    if not list then return nil end
    local seasonId = (DataMgr and DataMgr.season_id) or 0
    return { curr_season_id = seasonId, list = list }
end

local function build_peakgame_rating_info(segmentId, maxSegmentId, rating)
    return build_peakgame_list(segmentId, maxSegmentId, rating)
end

-- ==================== 赛季之旅徽章 ====================
local function build_season_year_badge(level)
    local ok, cfg = pcall(require, "client.logic.season_year.config.season_year_config")
    if not ok or not cfg then return nil end
    local EB = cfg.EBadgePartType
    local Done = cfg.ERankTaskStatus.Completed
    level = tonumber(level) or 1

    local gem = { [1] = { finish_count = level, status = Done } }
    local base = { [1] = { finish_count = level, status = Done } }

    local glowTasks = tonumber(JOURNEY_BADGE_GLOW_TASKS) or 3
    local glow = {}
    for i = 1, glowTasks do
        glow[i] = {
            finish_count = 1,
            status = Done,
            trigger_value = JOURNEY_GLOW_RANKS[i] or 801,
        }
    end

    local crown = {}
    local crownMax = cfg.CrownTaskMaxCount or 10
    local crownStage = math.min(tonumber(JOURNEY_BADGE_VISUAL_LEVEL) or 3, level)
    for i = 1, crownMax do
        crown[i] = { finish_count = crownStage, status = Done }
    end

    return {
        [EB.Gem] = gem,
        [EB.Base] = base,
        [EB.Glow] = glow,
        [EB.Crown] = crown,
    }
end

local function get_season_year_id()
    local ok, season_year_util = pcall(require, "client.logic.season_year.util.season_year_util")
    if ok and season_year_util and season_year_util.GetSeasonYearId then
        return season_year_util.GetSeasonYearId()
    end
    return 1
end

local function get_season_series_segment_id()
    if tonumber(SEASON_SERIES_SEGMENT) and SEASON_SERIES_SEGMENT > 0 then
        return SEASON_SERIES_SEGMENT
    end
    local segId
    pcall(function()
        local logic_leisure_season = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_leisure_season)
        if logic_leisure_season and logic_leisure_season.GetLeisureDefaultID then
            segId = logic_leisure_season:GetLeisureDefaultID()
        end
    end)
    if not segId or segId == 0 then
        pcall(function()
            local row = CDataTable and CDataTable.GetTableData and CDataTable.GetTableData("LeisureSeasonParamCfg", "MinSegmentId")
            if row and row.Value then segId = tonumber(row.Value) end
        end)
    end
    return segId or 101
end

-- ==================== 徽章UI渲染 ====================
local function badge_for_widget_render(badgeData)
    if not badgeData then return nil end
    local ok, cfg = pcall(require, "client.logic.season_year.config.season_year_config")
    if not ok or not cfg then return badgeData end
    local EB = cfg.EBadgePartType
    local Done = cfg.ERankTaskStatus.Completed
    local vis = math.min(3, tonumber(JOURNEY_BADGE_VISUAL_LEVEL) or 3)
    local out = {}
    for partType, partInfo in pairs(badgeData) do
        out[partType] = {}
        for taskId, taskInfo in pairs(partInfo) do
            local fc = taskInfo.finish_count
            local st = taskInfo.status or Done
            if partType == EB.Gem or partType == EB.Base then
                fc = vis
            elseif partType == EB.Glow then
                fc = 1
            elseif partType == EB.Crown then
                fc = vis
            end
            out[partType][taskId] = {
                finish_count = fc,
                status = st,
                trigger_value = taskInfo.trigger_value,
            }
        end
    end
    return out
end

local function get_display_badge()
    local full = build_season_year_badge(JOURNEY_BADGE_LEVEL)
    if not full then return nil end
    return badge_for_widget_render(full)
end

-- ==================== 服务器缓存 ====================
local function get_fake_badge_part_cfg()
    local ok, cfg = pcall(require, "client.logic.season_year.config.season_year_config")
    if not ok or not cfg then return {} end
    local yearId = get_season_year_id()
    if _G.SetRoleInfo_badge_part_cfg and _G.SetRoleInfo_badge_part_cfg[yearId] then
        return _G.SetRoleInfo_badge_part_cfg[yearId]
    end
    apply_server_badge_cfg_cache()
    return (_G.SetRoleInfo_badge_part_cfg and _G.SetRoleInfo_badge_part_cfg[yearId]) or {}
end

local function build_badge_part_cfg_list(count, stageId)
    local list = {}
    for i = 1, count do
        list[i] = {
            task_id = i,
            task_stage_id = stageId,
            finish_value = stageId,
            badge_cfg = { task_desc_id = 0, task_title_id = 0 },
        }
    end
    return list
end

local function apply_server_badge_cfg_cache()
    pcall(function()
        local ok, cfg = pcall(require, "client.logic.season_year.config.season_year_config")
        if not ok or not cfg then return end
        local logic_season_year_badge = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_season_year_badge)
        if not logic_season_year_badge then return end
        local yearId = get_season_year_id()
        local EB = cfg.EBadgePartType
        local stage = math.min(3, tonumber(JOURNEY_BADGE_VISUAL_LEVEL) or 3)
        logic_season_year_badge.serverBadgeCfg = logic_season_year_badge.serverBadgeCfg or {}
        logic_season_year_badge.serverBadgeCfg[yearId] = {
            [EB.Gem] = build_badge_part_cfg_list(1, stage),
            [EB.Base] = build_badge_part_cfg_list(1, stage),
            [EB.Glow] = build_badge_part_cfg_list(JOURNEY_BADGE_GLOW_TASKS, 1),
            [EB.Crown] = build_badge_part_cfg_list(cfg.CrownTaskMaxCount or 10, stage),
        }
        logic_season_year_badge.seasonYearTaskInfo = logic_season_year_badge.seasonYearTaskInfo or {}
        logic_season_year_badge.seasonYearTaskInfo[1] = {
            task_id = 1,
            status = cfg.ERankTaskStatus.Completed,
            finish_count = JOURNEY_BADGE_LEVEL,
        }
        local taskYearId = yearId
        logic_season_year_badge.serverYearTaskCfg = logic_season_year_badge.serverYearTaskCfg or {}
        logic_season_year_badge.serverYearTaskCfg[taskYearId] = {
            task_cfgs = {
                [1] = {
                    reward_itemid_1 = 0,
                    reward_cnt_1 = 0,
                    reward_valid_hours_1 = 0,
                    task_desc_id = 0,
                },
            },
        }
        _G.SetRoleInfo_badge_part_cfg = _G.SetRoleInfo_badge_part_cfg or {}
        _G.SetRoleInfo_badge_part_cfg[yearId] = logic_season_year_badge.serverBadgeCfg[yearId]
    end)
end

local function cache_badge_all_year_ids(displayBadge)
    if not displayBadge then return end
    pcall(function()
        local logic_season_year_badge = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_season_year_badge)
        if not logic_season_year_badge then return end
        logic_season_year_badge.seasonYearBadgeInfo = logic_season_year_badge.seasonYearBadgeInfo or {}
        local ids = {}
        local yid = get_season_year_id()
        ids[yid] = true
        if yid == 0 then ids[1] = true end
        pcall(function()
            if DataMgr and DataMgr.season_id and CDataTable and CDataTable.GetTableData then
                local row = CDataTable.GetTableData("SeasonInfo", DataMgr.season_id)
                if row and row.SeasonYearID then ids[row.SeasonYearID] = true end
            end
        end)
        for id, _ in pairs(ids) do
            logic_season_year_badge.seasonYearBadgeInfo[id] = displayBadge
        end
    end)
end

-- ==================== Ace印记 ====================
local function apply_ace_imprint_self()
    local ace_config = require("client.slua.umg.ace_imprint.config.ace_config")
    local baseId = 10
    local showCnt = tonumber(JOURNEY_BADGE_LEVEL) or 17
    local showId = baseId + showCnt
    if DataMgr and DataMgr.roleData then
        DataMgr.roleData.ace_show_type = ace_config.EAceShowType.Honer
        DataMgr.roleData.ace_imprint_base_id = baseId
        DataMgr.roleData.ace_imprint_show_id = showId
        DataMgr.roleData.ace_imprint_show_cnt = showCnt
    end
    if DataMgr then
        DataMgr.ace_show_type = ace_config.EAceShowType.Honer
        DataMgr.ace_imprint_base_id = baseId
        DataMgr.ace_imprint_show_id = showId
        DataMgr.ace_imprint_show_cnt = showCnt
    end
    pcall(function()
        if LobbySystem and LobbySystem.roleData then
            LobbySystem.roleData.ace_show_type = ace_config.EAceShowType.Honer
            LobbySystem.roleData.ace_imprint_base_id = baseId
            LobbySystem.roleData.ace_imprint_show_id = showId
            LobbySystem.roleData.ace_imprint_show_cnt = showCnt
        end
    end)
end

-- ==================== 徽章UI辅助 ====================
local function try_set_badge_center_number(badge_ui, num)
    if not badge_ui or not badge_ui.UIRoot then return end
    local root = badge_ui.UIRoot
    local textNames = {
        "TextBlock_Level", "TextBlock_Num", "TextBlock_Number", "TextBlock_Num04",
        "TextBlock_Gem", "TextBlock_0", "TextBlock_1", "TextBlock_5", "TextBlock_6",
        "TextBlock_3", "TextBlock_4",
    }
    local str = tostring(num)
    local function try_widget(w)
        if w and w.SetText then
            w:SetText(str)
            return true
        end
    end
    for _, name in ipairs(textNames) do
        if try_widget(root[name]) then return end
    end
    for lv = 0, 3 do
        local panel = root["Panel_GemCrown" .. lv]
        if panel then
            for _, name in ipairs(textNames) do
                if try_widget(panel[name]) then return end
            end
        end
    end
end

local function hide_kingmark_placeholder(root)
    if not root then return end
    pcall(function()
        if root.Image_69 then
            root.Image_69:SetVisibility(UEnums.ESlateVisibility.Collapsed)
        end
    end)
end

local function apply_journey_kingmark_fallback(ui)
    if not ui or not ui.UIRoot or not ui.UIRoot.SizeBox_Badge_Root then return false end
    local root = ui.UIRoot
    local box = root.SizeBox_Badge_Root
    pcall(function()
        if ui._SetRoleInfo_journey_kingmark and ui._SetRoleInfo_journey_kingmark.Close then
            ui._SetRoleInfo_journey_kingmark:Close()
        end
    end)
    local child = nil
    pcall(function()
        if UIManager and UIManager.UI_Config and UIManager.UI_Config.Common_KingMark_UIBP_2 then
            child = ui:CreateChildWindow(box, UIManager.UI_Config.Common_KingMark_UIBP_2, 4)
        end
    end)
    if not child then
        pcall(function()
            local UIComponentModule = require("client.slua.component.UIComponentModule.UIComponentModule")
            if UIComponentModule and UIComponentModule.InitWithParentComponent then
                child = UIComponentModule:InitWithParentComponent(
                    ui, UIComponentModule.Config.Common_KingMark_UIBP_2, box, 4
                )
            end
        end)
    end
    if child and child.SetWidgetInfo then
        ui._SetRoleInfo_journey_kingmark = child
        child:SetWidgetInfo(10, { advance_num = JOURNEY_BADGE_LEVEL, history_num = 0 })
        try_set_badge_center_number(child, JOURNEY_BADGE_LEVEL)
        pcall(function()
            if child.Show then child:Show() end
            if child.UIRoot and child.UIRoot.SetVisibility then
                child.UIRoot:SetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
            end
        end)
        return true
    end
    return false
end

local function apply_journey_season_badge_widget(ui, renderBadge)
    if not ui or not ui.UIRoot or not renderBadge then return false end
    local root = ui.UIRoot
    local box = root.SizeBox_Badge_Root
    if not box then return false end

    local ok_apply = false
    if ui.season_year_badge and ui.season_year_badge.SetBadgeInfo then
        ui.season_year_badge:SetBadgeInfo(renderBadge, false)
        try_set_badge_center_number(ui.season_year_badge, JOURNEY_BADGE_LEVEL)
        ok_apply = true
    end

    if not ok_apply and UIManager and UIManager.UI_Config and UIManager.UI_Config.Lobby_Season_Badge_Item_UIBP then
        pcall(function()
            if ui.season_year_badge and ui.CloseChildWindow then
                ui:CloseChildWindow(ui.season_year_badge)
            end
        end)
        ui.season_year_badge = nil
        pcall(function()
            ui.season_year_badge = ui:CreateChildWindow(
                box, UIManager.UI_Config.Lobby_Season_Badge_Item_UIBP, renderBadge
            )
        end)
        if (not ui.season_year_badge) then
            pcall(function()
                local UIComponentModule = require("client.slua.component.UIComponentModule.UIComponentModule")
                if UIComponentModule and UIComponentModule.InitWithParentComponent then
                    ui.season_year_badge = UIComponentModule:InitWithParentComponent(
                        ui, UIComponentModule.Config.SeasonYear_Badge_Item_UIBP, box, renderBadge
                    )
                end
            end)
        end
        if ui.season_year_badge and ui.season_year_badge.SetBadgeInfo then
            ui.season_year_badge:SetBadgeInfo(renderBadge, false)
            try_set_badge_center_number(ui.season_year_badge, JOURNEY_BADGE_LEVEL)
            ok_apply = true
        end
    end
    return ok_apply
end

-- ==================== 应用段位到个人资料 ====================
local function apply_history_max_segment(profile)
    if not profile or type(profile) ~= "table" then return end
    profile.history_max_segment_level = profile.history_max_segment_level or {}
    profile.history_max_segment_season_id = profile.history_max_segment_season_id or {}
    for z = 1, ZONE_COUNT do
        profile.history_max_segment_level[z] = HISTORY_SEGMENT
        profile.history_max_segment_season_id[z] = profile.history_max_segment_season_id[z]
            or (DataMgr and DataMgr.season_id) or 0
    end
end

local function get_star_rating()
    if tonumber(CURRENT_SEGMENT) ~= 801 then
        return tonumber(CURRENT_RATING) or 0
    end
    local stars = tonumber(DISPLAY_STARS) or 0
    if stars > 0 then
        return rating_from_stars(stars)
    end
    return tonumber(CURRENT_RATING) or 0
end

local function apply_profile_badge_fields(profile)
    if not profile or type(profile) ~= "table" then return end
    local fullBadge = build_season_year_badge(JOURNEY_BADGE_LEVEL)
    local displayBadge = fullBadge and badge_for_widget_render(fullBadge) or nil
    if fullBadge then
        profile.season_year_badge_info = fullBadge
        local yearId = get_season_year_id()
        profile.season_year_badge = profile.season_year_badge or {}
        profile.season_year_badge[yearId] = displayBadge or fullBadge
    end
    local ace_config = require("client.slua.umg.ace_imprint.config.ace_config")
    profile.ace_show_type = ace_config.EAceShowType.Honer
    profile.ace_imprint_base_id = 10
    profile.ace_imprint_show_id = 10 + JOURNEY_BADGE_LEVEL
    profile.ace_imprint_show_cnt = JOURNEY_BADGE_LEVEL
    profile.casual_segment_id = get_season_series_segment_id()
end

local function apply_profile_rank_fields(profile)
    if not profile or type(profile) ~= "table" then return end
    local titleId = resolve_conqueror_title_id()
    local rating = get_star_rating()

    profile.segment_info = build_allzone_segment(CURRENT_SEGMENT)
    profile.rankdata = build_rankdata(rating)
    profile.cur_max_segment_level = CURRENT_SEGMENT
    apply_history_max_segment(profile)

    local htitle = build_hsegment_title(titleId)
    if htitle then
        profile.hsegment_title_det = htitle
    end

    local peakInfo = build_peakgame_segment_info(PEAK_CURRENT_SEGMENT, PEAK_CURRENT_SEGMENT, PEAK_RATING)
    if peakInfo then
        profile.peakgame_segment_info = peakInfo
    end
    profile.peakgame_history_max_segment = PEAK_HISTORY_SEGMENT
end

local function apply_profile_extras(profile)
    if not profile or type(profile) ~= "table" then return end
    apply_profile_rank_fields(profile)
    apply_profile_badge_fields(profile)
    if is_self_uid(profile.uid) then
        profile.registertime = get_fake_registertime()
    end
end

-- ==================== 强制徽章 ====================
local function ensure_force_badge()
    local full = build_season_year_badge(JOURNEY_BADGE_LEVEL)
    if full then
        _G.SetRoleInfo_force_badge_full = full
        _G.SetRoleInfo_force_badge = get_display_badge() or badge_for_widget_render(full)
    end
    return _G.SetRoleInfo_force_badge
end

local function apply_season_year_badge_cache()
    if not ENABLE_SEASON_YEAR_BADGE then return end
    local displayBadge = ensure_force_badge()
    if not displayBadge then return end
    pcall(function()
        local logic_season_year_badge = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_season_year_badge)
        if not logic_season_year_badge then return end
        cache_badge_all_year_ids(displayBadge)
        logic_season_year_badge.loginDays = JOURNEY_BADGE_LEVEL
        local cfg = require("client.logic.season_year.config.season_year_config")
        logic_season_year_badge.badgeShowType = cfg.EBadgeShowType.Show
        apply_server_badge_cfg_cache()
        apply_ace_imprint_self()
    end)
end

-- ==================== UI强制刷新 ====================
local function force_classic_career_highest(ui)
    if not ui or not ui.UIRoot then return end
    local root = ui.UIRoot
    local seasonId = (DataMgr and DataMgr.season_id) or 0
    local w = root.Common_RankIntegralLevel_Style_Large_UIBP_C_2
    if not w then return end
    pcall(function()
        if w.SetRankInteralBySeason then
            w:SetRankInteralBySeason(HISTORY_SEGMENT, nil, seasonId)
        elseif w.SetRankInteralWithSegmentTitle then
            w:SetRankInteralWithSegmentTitle(HISTORY_SEGMENT, nil, seasonId, 0, get_star_rating())
        elseif w.SetRankInteral then
            w:SetRankInteral(HISTORY_SEGMENT, nil)
        end
    end)
end

local function force_roleinfo_journey_badge(ui)
    if not ui or not ui.UIRoot then return end
    local root = ui.UIRoot
    local renderBadge = ensure_force_badge()
    if not renderBadge then return end

    if LocUtil and root.TextBlock_47 then
        pcall(function() root.TextBlock_47:SetText(LocUtil.GetLocalizeResStr(85103)) end)
    end
    if root.TextBlock_21 and LocUtil then
        pcall(function() root.TextBlock_21:SetText(LocUtil.GetLocalizeResStr(68405)) end)
    end
    ui:SetWidgetVisible(root.SizeBox_Badge_Root, true)
    hide_kingmark_placeholder(root)
    if root.PeakGame_RankIntegralLevel_Style_Large_UIBP_C_1 then
        ui:SetWidgetVisible(root.PeakGame_RankIntegralLevel_Style_Large_UIBP_C_1, SHOW_SEASON_SERIES_MEDAL)
    end

    local ok = apply_journey_season_badge_widget(ui, renderBadge)
    if not ok then
        apply_journey_kingmark_fallback(ui)
    end
end

local function force_roleinfo_profile_slots(ui)
    force_classic_career_highest(ui)
    force_roleinfo_journey_badge(ui)
end

local function apply_roleinfo_badges_ui()
    apply_season_year_badge_cache()
    pcall(function()
        local ui = UIManager.GetUI(UIManager.UI_Config.roleinfo_segment)
        if not ui or not ui.UIRoot then return end
        local root = ui.UIRoot

        force_roleinfo_profile_slots(ui)

        if SHOW_SEASON_SERIES_MEDAL and root.PeakGame_RankIntegralLevel_Style_Large_UIBP_C_1 then
            ui:SetWidgetVisible(root.PeakGame_RankIntegralLevel_Style_Large_UIBP_C_1, true)
            local leisure_season_util = require("client.slua.logic.leisure.leisure_season_util")
            leisure_season_util.SetRankBigIcon(
                root.PeakGame_RankIntegralLevel_Style_Large_UIBP_C_1,
                get_season_series_segment_id()
            )
            if ui.RefreshCasualSegment then
                ui:RefreshCasualSegment()
            end
        end
    end)
end

-- ==================== DataMgr数据注入 ====================
local function apply_data_mgr_ranks()
    if not DataMgr or not DataMgr.roleData then return end
    local rd = DataMgr.roleData
    local cur = CURRENT_SEGMENT
    local rating = get_star_rating()

    rd.segment = rd.segment or {}
    rd.segment.solo = cur
    rd.segment.double = cur
    rd.segment.team = cur
    rd.segment.fpp_solo = cur
    rd.segment.fpp_double = cur
    rd.segment.fpp_team = cur
    rd.allzoneSegment = build_allzone_segment(cur)

    rd.rankdata = build_rankdata(rating)

    local titleId = resolve_conqueror_title_id()
    if titleId > 0 then
        rd.allzoneSegmentTitle = build_hsegment_title(titleId)
    end

    DataMgr.isSeasonStarOpen = true
    rd.is_season_star_open = true

    pcall(function()
        local SeasonSystem = require("client.logic.season.logic_season")
        SeasonSystem.segment.team.level = cur
        SeasonSystem.segment.team.rating = rating
    end)

    pcall(function()
        DataMgr.maxSegmentSquad = DataMgr.maxSegmentSquad or { zoneid = 1, SegmentLevel = 0 }
        DataMgr.maxSegmentSquad.SegmentLevel = cur
        DataMgr.maxSegmentSquad.zoneid = 1
    end)

    local peakList = build_peakgame_rating_info(PEAK_CURRENT_SEGMENT, PEAK_CURRENT_SEGMENT, PEAK_RATING)
    if peakList then
        rd.peakgame_rating_info = peakList
    end
    rd.peakgame_history_max_segment = PEAK_HISTORY_SEGMENT
    rd.casual_segment_id = get_season_series_segment_id()
    DataMgr.registertime = get_fake_registertime()
end

local function apply_personal_basic()
    local ok, RoleInfoMainSystem = pcall(require, "client.logic.roleinfo.logic_new_roleinfo")
    if not ok or not RoleInfoMainSystem then return end
    local pbi = RoleInfoSystem.PersonalBasicInfo
    if not pbi or type(pbi) ~= "table" then return end

    pbi.all_segment_info = build_allzone_segment(CURRENT_SEGMENT)
    local titleId = resolve_conqueror_title_id()
    if titleId > 0 then
        pbi.hsegment_title_det = build_hsegment_title(titleId)
    end

    local zoneId = 1
    if RoleInfoMainSystem.GetShowRoleinfoOfZoneID then
        zoneId = RoleInfoMainSystem.GetShowRoleinfoOfZoneID() or 1
    end
    if zoneId == 0 then zoneId = 1 end
    local zs = pbi.all_segment_info[zoneId]
    if zs then
        local fields = {
            "role_segment_solo", "role_segment_double", "role_segment_team",
            "role_segmentFPP_solo", "role_segmentFPP_double", "role_segmentFPP_team",
            "curr_role_segment_solo", "curr_role_segment_double", "curr_role_segment_team",
            "curr_role_segmentFPP_solo", "curr_role_segmentFPP_double", "curr_role_segmentFPP_team",
        }
        local vals = {
            zs[SEGMENT_TYPE.solo], zs[SEGMENT_TYPE.double], zs[SEGMENT_TYPE.team],
            zs[SEGMENT_TYPE.fpp_solo], zs[SEGMENT_TYPE.fpp_double], zs[SEGMENT_TYPE.fpp_team],
            zs[SEGMENT_TYPE.solo], zs[SEGMENT_TYPE.double], zs[SEGMENT_TYPE.team],
            zs[SEGMENT_TYPE.fpp_solo], zs[SEGMENT_TYPE.fpp_double], zs[SEGMENT_TYPE.fpp_team],
        }
        for i, f in ipairs(fields) do
            pbi[f] = vals[i]
        end
    end
    pbi.role_all_zone_segment_max = CURRENT_SEGMENT
end

-- ==================== 最终应用 ====================
local function apply_extra_settings()
    if DataMgr and DataMgr.roleData then
        DataMgr.roleData.level = PLAYER_LEVEL
        DataMgr.roleData.pic_url = AVATAR_ID
        DataMgr.roleData.headIconUrl = AVATAR_ID
        DataMgr.roleData.pic_url_check_open = true
        DataMgr.roleData.cur_avatar_box_id = AVATAR_BOX_ID
        print(string.format("[SetRoleInfo] 已设置: 等级=%d, 头像=%d, 头像框=%d", PLAYER_LEVEL, AVATAR_ID, AVATAR_BOX_ID))
    end
end

local function apply_history_to_self_caches()
    if not DataMgr or not DataMgr.roleData or not DataMgr.roleData.uid then return end
    local uid = tonumber(DataMgr.roleData.uid)
    local ok, logic_profile = pcall(function()
        return ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_profile)
    end)
    if ok and logic_profile then
        for _, bucket in ipairs({ logic_profile.dicFriend, logic_profile.dicStranger }) do
            if bucket and bucket[uid] then
                apply_profile_extras(bucket[uid])
            end
        end
        local profile = logic_profile:GetLocalProfile(uid) or logic_profile:GetLocalProfile(uid, true)
        if profile then
            apply_profile_extras(profile)
        end
    end
end

-- ==================== UI补丁 ====================
local function patch_conqueror_star_ui()
    if _G.SetRoleInfo_star_ui_patched then return end

    pcall(function()
        local RIClass = require("client.slua.umg.rankIntegral.RankIntegralIconSmall")
        if RIClass and RIClass.SetRankInteralWithSegmentTitle and not RIClass._SetRoleInfo_orig_RII then
            RIClass._SetRoleInfo_orig_RII = RIClass.SetRankInteralWithSegmentTitle
            RIClass.SetRankInteralWithSegmentTitle = function(self, segment, textName, seasonId, titleId, rating)
                if tonumber(segment) == 801 and (not rating or tonumber(rating) == 0) then
                    rating = get_star_rating()
                end
                return RIClass._SetRoleInfo_orig_RII(self, segment, textName, seasonId, titleId, rating)
            end
        end
    end)

    pcall(function()
        local BaseClass = require("client.slua.umg.rankIntegral.RankSmall_Sub_Base_UIBP")
        if BaseClass and BaseClass.SetRankInteralWithSegmentTitle and not BaseClass._SetRoleInfo_orig_Base then
            BaseClass._SetRoleInfo_orig_Base = BaseClass.SetRankInteralWithSegmentTitle
            BaseClass.SetRankInteralWithSegmentTitle = function(self)
                if tonumber(self.rankIntegral) == 801 and (not self.rating or tonumber(self.rating) == 0) then
                    self.rating = get_star_rating()
                end
                return BaseClass._SetRoleInfo_orig_Base(self)
            end
        end
    end)

    pcall(function()
        local logic_segment_title = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.logic_segment_title)
        if logic_segment_title and not logic_segment_title._SetRoleInfo_orig_MaxTitle then
            logic_segment_title._SetRoleInfo_orig_MaxTitle = logic_segment_title.SetMaxSegmentRankInteralWithTitle
            logic_segment_title.SetMaxSegmentRankInteralWithTitle = function(self, widget, allSegmentInfo, allZoneSegmentTitle, seasonId)
                if not slua.isValid(widget) or not allSegmentInfo then
                    return logic_segment_title._SetRoleInfo_orig_MaxTitle(self, widget, allSegmentInfo, allZoneSegmentTitle, seasonId)
                end
                local maxSegment, zoneid, modeid = self:GetMaxSegementLevelWithZoneAndModeId(allSegmentInfo)
                if not maxSegment or maxSegment <= 0 then
                    return logic_segment_title._SetRoleInfo_orig_MaxTitle(self, widget, allSegmentInfo, allZoneSegmentTitle, seasonId)
                end
                widget:SetWidgetVisibility(UEnums.ESlateVisibility.SelfHitTestInvisible)
                if seasonId and seasonId ~= 0 and seasonId ~= DataMgr.season_id then
                    widget:SetRankInteralBySeason(maxSegment, nil, seasonId)
                    return
                end
                local segmentTitleId = self:GetSegmentTitleId(allZoneSegmentTitle, zoneid, modeid)
                local rating = (tonumber(maxSegment) == 801) and get_star_rating() or nil
                local sid = seasonId or DataMgr.season_id
                if not segmentTitleId or tonumber(segmentTitleId) == 0 then
                    if rating and rating > 0 then
                        widget:SetRankInteralWithSegmentTitle(maxSegment, nil, sid, 0, rating)
                    else
                        widget:SetRankInteralBySeason(maxSegment, nil, sid)
                    end
                else
                    widget:SetRankInteralWithSegmentTitle(maxSegment, nil, sid, segmentTitleId, rating)
                end
            end
        end
    end)

    pcall(function()
        local LobbySocialSystem = require("client.slua.logic.lobby.Left.logic_lobby_social")
        if LobbySocialSystem and not LobbySocialSystem._SetRoleInfo_self_prof then
            LobbySocialSystem._SetRoleInfo_self_prof = true
            local orig = LobbySocialSystem.GetSelfProfile
            LobbySocialSystem.GetSelfProfile = function()
                local p = orig()
                if p and tonumber(CURRENT_SEGMENT) == 801 then
                    p.rankdata = build_rankdata(get_star_rating())
                end
                if p and ENABLE_SEASON_YEAR_BADGE then
                    apply_profile_badge_fields(p)
                end
                return p
            end
        end
        if LobbySocialSystem and LobbySocialSystem.GetAceImprintShowId and not LobbySocialSystem._SetRoleInfo_ace_show then
            LobbySocialSystem._SetRoleInfo_ace_show = true
            local origAce = LobbySocialSystem.GetAceImprintShowId
            LobbySocialSystem.GetAceImprintShowId = function(uid)
                if is_self_uid(uid) and ENABLE_SEASON_YEAR_BADGE then
                    return 10 + JOURNEY_BADGE_LEVEL, 10, JOURNEY_BADGE_LEVEL
                end
                return origAce(uid)
            end
        end
    end)

    pcall(function()
        local SeasonHandler = require("client.network.Protocol.SeasonHandler")
        SeasonHandler.rank_rating = get_star_rating()
    end)

    _G.SetRoleInfo_star_ui_patched = true
end

-- ==================== 徽章和休闲赛季补丁 ====================
local function patch_badge_and_leisure_hooks()
    if _G.SetRoleInfo_badge_hooks_patched then return end
    _G.SetRoleInfo_badge_hooks_patched = true

    pcall(function()
        local season_year_util = require("client.logic.season_year.util.season_year_util")
        if season_year_util and season_year_util.CheckFunctionIsOpen and not season_year_util._SetRoleInfo_orig_CheckOpen then
            season_year_util._SetRoleInfo_orig_CheckOpen = season_year_util.CheckFunctionIsOpen
            season_year_util.CheckFunctionIsOpen = function()
                if ENABLE_SEASON_YEAR_BADGE then return true end
                return season_year_util._SetRoleInfo_orig_CheckOpen()
            end
        end
    end)

    pcall(function()
        local logic_season_year_badge = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_season_year_badge)
        if logic_season_year_badge and logic_season_year_badge.GetCurSeasonYearBadgeInfo
            and not logic_season_year_badge._SetRoleInfo_orig_GetBadge then
            logic_season_year_badge._SetRoleInfo_orig_GetBadge = logic_season_year_badge.GetCurSeasonYearBadgeInfo
            local origGetBadge = logic_season_year_badge._SetRoleInfo_orig_GetBadge
            logic_season_year_badge.GetCurSeasonYearBadgeInfo = function(self)
                apply_season_year_badge_cache()
                if ENABLE_SEASON_YEAR_BADGE and _G.SetRoleInfo_force_badge then
                    return _G.SetRoleInfo_force_badge
                end
                local data = origGetBadge(self)
                if ENABLE_SEASON_YEAR_BADGE and (not data or not next(data)) then
                    return ensure_force_badge() or data
                end
                return data
            end
        end
        if logic_season_year_badge and logic_season_year_badge.on_get_season_year_badge_info_rsp
            and not logic_season_year_badge._SetRoleInfo_wrapped_badge_rsp then
            logic_season_year_badge._SetRoleInfo_wrapped_badge_rsp = true
            local orig = logic_season_year_badge.on_get_season_year_badge_info_rsp
            logic_season_year_badge.on_get_season_year_badge_info_rsp = function(self, badge_info)
                if ENABLE_SEASON_YEAR_BADGE then
                    apply_season_year_badge_cache()
                    if EventSystem and EVENTTYPE_SEASON_YEAR and EVENTID_SEASON_YEAR_BADGE_UPDATE then
                        EventSystem:postEvent(EVENTTYPE_SEASON_YEAR, EVENTID_SEASON_YEAR_BADGE_UPDATE)
                    end
                    return
                end
                orig(self, badge_info)
            end
        end
        if logic_season_year_badge and logic_season_year_badge.on_get_season_year_badge_cfg_rsp
            and not logic_season_year_badge._SetRoleInfo_wrapped_cfg_rsp then
            logic_season_year_badge._SetRoleInfo_wrapped_cfg_rsp = true
            local origCfg = logic_season_year_badge.on_get_season_year_badge_cfg_rsp
            logic_season_year_badge.on_get_season_year_badge_cfg_rsp = function(self, info)
                origCfg(self, info)
                apply_server_badge_cfg_cache()
            end
        end
        if logic_season_year_badge and logic_season_year_badge.GetBadgeShowType
            and not logic_season_year_badge._SetRoleInfo_orig_ShowType then
            logic_season_year_badge._SetRoleInfo_orig_ShowType = logic_season_year_badge.GetBadgeShowType
            logic_season_year_badge.GetBadgeShowType = function(self)
                if ENABLE_SEASON_YEAR_BADGE then
                    local cfg = require("client.logic.season_year.config.season_year_config")
                    return cfg.EBadgeShowType.Show
                end
                return logic_season_year_badge._SetRoleInfo_orig_ShowType(self)
            end
        end
        if logic_season_year_badge and logic_season_year_badge.GetCurSeasonYearBadgeCfg
            and not logic_season_year_badge._SetRoleInfo_orig_GetCfg then
            logic_season_year_badge._SetRoleInfo_orig_GetCfg = logic_season_year_badge.GetCurSeasonYearBadgeCfg
            logic_season_year_badge.GetCurSeasonYearBadgeCfg = function(self)
                apply_server_badge_cfg_cache()
                local cfg = logic_season_year_badge._SetRoleInfo_orig_GetCfg(self)
                if cfg and next(cfg) then return cfg end
                local yearId = get_season_year_id()
                return self.serverBadgeCfg and self.serverBadgeCfg[yearId] or {}
            end
        end
    end)

    pcall(function()
        local season_year_badge_util = require("client.logic.season_year.util.season_year_badge_util")
        if season_year_badge_util.CheckGotBadge and not season_year_badge_util._SetRoleInfo_orig_Got then
            season_year_badge_util._SetRoleInfo_orig_Got = season_year_badge_util.CheckGotBadge
            season_year_badge_util.CheckGotBadge = function(badgeData)
                if ENABLE_SEASON_YEAR_BADGE and _G.SetRoleInfo_force_badge then
                    return true
                end
                return season_year_badge_util._SetRoleInfo_orig_Got(badgeData)
            end
        end
        if season_year_badge_util.GetBadgeShowType and not season_year_badge_util._SetRoleInfo_orig_UtilShow then
            season_year_badge_util._SetRoleInfo_orig_UtilShow = season_year_badge_util.GetBadgeShowType
            season_year_badge_util.GetBadgeShowType = function()
                if ENABLE_SEASON_YEAR_BADGE then
                    local cfg = require("client.logic.season_year.config.season_year_config")
                    return cfg.EBadgeShowType.Show
                end
                return season_year_badge_util._SetRoleInfo_orig_UtilShow()
            end
        end
        if season_year_badge_util.GetCurSeasonYearBadgeInfo and not season_year_badge_util._SetRoleInfo_orig_GetInfo then
            season_year_badge_util._SetRoleInfo_orig_GetInfo = season_year_badge_util.GetCurSeasonYearBadgeInfo
            season_year_badge_util.GetCurSeasonYearBadgeInfo = function()
                apply_season_year_badge_cache()
                if ENABLE_SEASON_YEAR_BADGE and _G.SetRoleInfo_force_badge then
                    return _G.SetRoleInfo_force_badge
                end
                local data = season_year_badge_util._SetRoleInfo_orig_GetInfo()
                if ENABLE_SEASON_YEAR_BADGE and (not data or not next(data)) then
                    return ensure_force_badge() or data
                end
                return data
            end
        end
        if season_year_badge_util.GetCurSeasonYearBadgePartCfgInfo and not season_year_badge_util._SetRoleInfo_orig_PartCfg then
            season_year_badge_util._SetRoleInfo_orig_PartCfg = season_year_badge_util.GetCurSeasonYearBadgePartCfgInfo
            season_year_badge_util.GetCurSeasonYearBadgePartCfgInfo = function(partType)
                local c = season_year_badge_util._SetRoleInfo_orig_PartCfg(partType)
                if c and next(c) then return c end
                local fake = get_fake_badge_part_cfg()
                return fake[partType] or {}
            end
        end
        if season_year_badge_util.GetSeasonYearBadge and not season_year_badge_util._SetRoleInfo_orig_GetByUid then
            season_year_badge_util._SetRoleInfo_orig_GetByUid = season_year_badge_util.GetSeasonYearBadge
            season_year_badge_util.GetSeasonYearBadge = function(uid)
                if is_self_uid(uid) and ENABLE_SEASON_YEAR_BADGE and _G.SetRoleInfo_force_badge then
                    return _G.SetRoleInfo_force_badge
                end
                return season_year_badge_util._SetRoleInfo_orig_GetByUid(uid)
            end
        end
    end)

    pcall(function()
        local BadgeClass = require("client.slua.umg.Lobby_SeasonUI.Season2026.Item.Lobby_Season_Badge_Item_UIBP")
        if BadgeClass and BadgeClass.SetBadgeInfo and not BadgeClass._SetRoleInfo_orig_SetBadge then
            BadgeClass._SetRoleInfo_orig_SetBadge = BadgeClass.SetBadgeInfo
            BadgeClass.SetBadgeInfo = function(self, badgeData, bPlayLevelUpAni)
                local renderData = _G.SetRoleInfo_force_badge
                    or badge_for_widget_render(badgeData) or badgeData
                BadgeClass._SetRoleInfo_orig_SetBadge(self, renderData, bPlayLevelUpAni)
                if ENABLE_SEASON_YEAR_BADGE then
                    try_set_badge_center_number(self, JOURNEY_BADGE_LEVEL)
                end
            end
        end
        if BadgeClass and BadgeClass.SetBadgeGemInfo and not BadgeClass._SetRoleInfo_orig_SetGem then
            BadgeClass._SetRoleInfo_orig_SetGem = BadgeClass.SetBadgeGemInfo
            BadgeClass.SetBadgeGemInfo = function(self, gemData, newActiveGemData)
                apply_server_badge_cfg_cache()
                return BadgeClass._SetRoleInfo_orig_SetGem(self, gemData, newActiveGemData)
            end
        end
        if BadgeClass and BadgeClass.PlayBadgePartLevelUpAnimation and not BadgeClass._SetRoleInfo_orig_Anim then
            BadgeClass._SetRoleInfo_orig_Anim = BadgeClass.PlayBadgePartLevelUpAnimation
            BadgeClass.PlayBadgePartLevelUpAnimation = function(self, partType, level, bPlayAnimation)
                level = math.min(3, math.max(0, tonumber(level) or 0))
                return BadgeClass._SetRoleInfo_orig_Anim(self, partType, level, bPlayAnimation)
            end
        end
    end)

    pcall(function()
        local RoleInfoUI = require("client.slua.umg.PersonSpace.Lobby_RoleInfo_Segment180_UIBP")
        if RoleInfoUI and RoleInfoUI.OnSeasonYearBadgeUpdate and not RoleInfoUI._SetRoleInfo_wrapped_badge_ui then
            RoleInfoUI._SetRoleInfo_wrapped_badge_ui = true
            local orig = RoleInfoUI.OnSeasonYearBadgeUpdate
            RoleInfoUI.OnSeasonYearBadgeUpdate = function(self)
                apply_season_year_badge_cache()
                local renderBadge = ensure_force_badge()
                if renderBadge then
                    apply_journey_season_badge_widget(self, renderBadge)
                    if not (self.season_year_badge and self.season_year_badge.UIRoot) then
                        apply_journey_kingmark_fallback(self)
                    end
                else
                    orig(self)
                end
                force_roleinfo_profile_slots(self)
            end
        end
        if RoleInfoUI and RoleInfoUI.OnGetSelfRoleInfoCallBack and not RoleInfoUI._SetRoleInfo_wrapped_hist then
            RoleInfoUI._SetRoleInfo_wrapped_hist = true
            local origCb = RoleInfoUI.OnGetSelfRoleInfoCallBack
            RoleInfoUI.OnGetSelfRoleInfoCallBack = function(self, list)
                if list and list[1] then
                    apply_history_max_segment(list[1])
                    apply_profile_badge_fields(list[1])
                end
                origCb(self, list)
                force_roleinfo_profile_slots(self)
            end
        end
        if RoleInfoUI and RoleInfoUI.UpdateUI and not RoleInfoUI._SetRoleInfo_wrapped_updateui then
            RoleInfoUI._SetRoleInfo_wrapped_updateui = true
            local origUp = RoleInfoUI.UpdateUI
            RoleInfoUI.UpdateUI = function(self)
                origUp(self)
                force_roleinfo_profile_slots(self)
            end
        end
        if RoleInfoUI and RoleInfoUI.OnPostInitialize and not RoleInfoUI._SetRoleInfo_wrapped_post then
            RoleInfoUI._SetRoleInfo_wrapped_post = true
            local origPost = RoleInfoUI.OnPostInitialize
            RoleInfoUI.OnPostInitialize = function(self, ...)
                apply_season_year_badge_cache()
                origPost(self, ...)
                local function refresh()
                    apply_season_year_badge_cache()
                    force_roleinfo_profile_slots(self)
                end
                refresh()
                if self.AddTimerOnce then
                    self:AddTimerOnce(0.05, refresh)
                    self:AddTimerOnce(0.15, refresh)
                    self:AddTimerOnce(0.5, refresh)
                    self:AddTimerOnce(1.0, refresh)
                    self:AddTimerOnce(2.0, refresh)
                end
            end
        end
        if RoleInfoUI and RoleInfoUI.RefreshAceImprint and not RoleInfoUI._SetRoleInfo_wrapped_ace then
            RoleInfoUI._SetRoleInfo_wrapped_ace = true
            local origAce = RoleInfoUI.RefreshAceImprint
            RoleInfoUI.RefreshAceImprint = function(self)
                apply_ace_imprint_self()
                origAce(self)
                hide_kingmark_placeholder(self.UIRoot)
            end
        end
    end)

    pcall(function()
        local RoleInfoMainSystem = require("client.logic.roleinfo.logic_new_roleinfo")
        if RoleInfoMainSystem and RoleInfoMainSystem.GetHistotyMaxSegmentAndSeasonId
            and not RoleInfoMainSystem._SetRoleInfo_orig_hist then
            RoleInfoMainSystem._SetRoleInfo_orig_hist = RoleInfoMainSystem.GetHistotyMaxSegmentAndSeasonId
            RoleInfoMainSystem.GetHistotyMaxSegmentAndSeasonId = function(historyLevels, seasonTable)
                if tonumber(HISTORY_SEGMENT) and HISTORY_SEGMENT > 0 then
                    local sid = (DataMgr and DataMgr.season_id) or 0
                    if seasonTable and next(seasonTable) then
                        for z, s in pairs(seasonTable) do
                            if tonumber(s) and s > sid then sid = s end
                        end
                    end
                    return HISTORY_SEGMENT, sid
                end
                return RoleInfoMainSystem._SetRoleInfo_orig_hist(historyLevels, seasonTable)
            end
        end
    end)

    pcall(function()
        local AchUI = require("client.slua.umg.Lobby_SeasonUI.Season2026.Lobby_Season_AnnualAchievement_UIBP")
        if AchUI and AchUI.UpdateUI and not AchUI._SetRoleInfo_wrapped_update then
            AchUI._SetRoleInfo_wrapped_update = true
            local origUp = AchUI.UpdateUI
            AchUI.UpdateUI = function(self)
                apply_season_year_badge_cache()
                origUp(self)
                if ENABLE_SEASON_YEAR_BADGE and _G.SetRoleInfo_force_badge then
                    local renderBadge = badge_for_widget_render(_G.SetRoleInfo_force_badge)
                    if self.CompBadge01 and self.CompBadge01.SetBadgeInfo then
                        self.CompBadge01:SetBadgeInfo(renderBadge, true)
                    end
                end
            end
        end
    end)

    pcall(function()
        local SeasonSystem = require("client.logic.season.logic_season")
        if SeasonSystem and SeasonSystem.GetBestSegment and not SeasonSystem._SetRoleInfo_orig_best then
            SeasonSystem._SetRoleInfo_orig_best = SeasonSystem.GetBestSegment
            SeasonSystem.GetBestSegment = function()
                if ENABLE_SEASON_YEAR_BADGE then
                    return CURRENT_SEGMENT
                end
                return SeasonSystem._SetRoleInfo_orig_best()
            end
        end
    end)

    pcall(function()
        local logic_leisure_season = ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_leisure_season)
        if logic_leisure_season and not logic_leisure_season._SetRoleInfo_orig_GetSeg then
            logic_leisure_season._SetRoleInfo_orig_GetSeg = logic_leisure_season.GetLeisureSegmentID
            logic_leisure_season.GetLeisureSegmentID = function(self)
                return get_season_series_segment_id()
            end
            logic_leisure_season._SetRoleInfo_orig_GetSegUID = logic_leisure_season.GetLeisureSegmentIDByUID
            logic_leisure_season.GetLeisureSegmentIDByUID = function(self, uid)
                if is_self_uid(uid) then
                    return get_season_series_segment_id()
                end
                return logic_leisure_season._SetRoleInfo_orig_GetSegUID(self, uid)
            end
        end
    end)
end

-- ==================== UI事件刷新 ====================
local function post_ui_refresh_events()
    pcall(function()
        if EventSystem and EVENTTYPE_ROLEINFO and EVENTID_ROLEINFO_UPDATE_ROLEINFO then
            EventSystem:postEvent(EVENTTYPE_ROLEINFO, EVENTID_ROLEINFO_UPDATE_ROLEINFO)
        end
        if EventSystem and EVENTTYPE_PEAKGAME and EVENTID_PEAKGAME_RATING_NOTIFY then
            EventSystem:postEvent(EVENTTYPE_PEAKGAME, EVENTID_PEAKGAME_RATING_NOTIFY)
        end
        if EventSystem and EVENTTYPE_SEASON_YEAR and EVENTID_SEASON_YEAR_BADGE_UPDATE then
            EventSystem:postEvent(EVENTTYPE_SEASON_YEAR, EVENTID_SEASON_YEAR_BADGE_UPDATE)
        end
        if EventSystem and EVENTTYPE_LEISURE_SEASON and EVENTID_LEISURE_SEASON_SEGMENT_NOTIFY then
            EventSystem:postEvent(EVENTTYPE_LEISURE_SEASON, EVENTID_LEISURE_SEASON_SEGMENT_NOTIFY)
        end
        if EventSystem and EVENTTYPE_DATA_MGR and EVENTID_ACE_IMPRINT_UPDATE then
            EventSystem:postEvent(EVENTTYPE_DATA_MGR, EVENTID_ACE_IMPRINT_UPDATE)
        end
    end)
end

-- ==================== 底部资料统计 ====================
local function apply_bottom_profile_stats()
    if not DataMgr or not DataMgr.roleData or not DataMgr.roleData.uid then return end
    local uid = tonumber(DataMgr.roleData.uid)
    local ratingStr = tostring(SEASON_RATING)
    for zoneId = 1, ZONE_COUNT do
        RoleInfoSystem.CurrSeasonTPPTotalScore[zoneId] = SEASON_RATING
        RoleInfoSystem.CurrSeasonFPPTotalScore[zoneId] = SEASON_RATING
        RoleInfoSystem.CurrSeasonTPPTotalRank[zoneId] = SEASON_RANK
        RoleInfoSystem.CurrSeasonFPPTotalRank[zoneId] = SEASON_RANK
        RoleInfoSystem.PersonalTotalScoreInfo[zoneId] = { role_totalscore = ratingStr }
        RoleInfoSystem.PersonalTotalRankInfo[zoneId] = { role_totalrank = SEASON_RANK }
        RoleInfoSystem.FPPPersonalTotalScoreInfo[zoneId] = { role_totalscore = ratingStr }
        RoleInfoSystem.FPPPersonalTotalRankInfo[zoneId] = { role_totalrank = SEASON_RANK }
    end
    if RoleInfoSystem.SetElementToString then
        pcall(function()
            RoleInfoSystem.SetElementToString(RoleInfoSystem.PersonalTotalScoreInfo)
            RoleInfoSystem.SetElementToString(RoleInfoSystem.PersonalTotalRankInfo)
            RoleInfoSystem.SetElementToString(RoleInfoSystem.FPPPersonalTotalScoreInfo)
            RoleInfoSystem.SetElementToString(RoleInfoSystem.FPPPersonalTotalRankInfo)
        end)
    end
    local ok, AchieveHandler = pcall(require, "client.network.Protocol.AchieveHandler")
    if ok and AchieveHandler then
        AchieveHandler.resSummaryTb[uid] = AchieveHandler.resSummaryTb[uid] or {}
        AchieveHandler.resSummaryTb[uid].achieve_score = ACHIEVEMENT_POINTS
        AchieveHandler.resSummaryTb[uid].uid = uid
    end
    apply_data_mgr_ranks()
    apply_ace_imprint_self()
    patch_conqueror_star_ui()
    pcall(function()
        local SeasonHandler = require("client.network.Protocol.SeasonHandler")
        if tonumber(CURRENT_SEGMENT) == 801 then
            SeasonHandler.rank_rating = get_star_rating()
        end
    end)
    patch_badge_and_leisure_hooks()
    apply_season_year_badge_cache()
    apply_roleinfo_badges_ui()
    apply_personal_basic()
    apply_history_to_self_caches()
    apply_extra_settings()
    post_ui_refresh_events()
end

-- ==================== 主函数 ====================
local function apply_all()
    apply_bottom_profile_stats()
end

local function install_refresh_hooks()
   
    patch_conqueror_star_ui()
    patch_badge_and_leisure_hooks()

    pcall(function()
        if RoleInfoSystem.get_role_basic_info_rsp and not RoleInfoSystem._SetRoleInfo_wrapped then
            RoleInfoSystem._SetRoleInfo_wrapped = true
            local orig = RoleInfoSystem.get_role_basic_info_rsp
            RoleInfoSystem.get_role_basic_info_rsp = function(list)
                orig(list)
                if list and list[1] then
                    apply_profile_rank_fields(list[1])
                    apply_history_max_segment(list[1])
                    apply_profile_badge_fields(list[1])
                end
                apply_all()
            end
        end
    end)

    if Timer and Timer.New then
        if _G.SetRoleInfo_timer then
            pcall(function() _G.SetRoleInfo_timer:Stop() end)
        end
        _G.SetRoleInfo_timer = Timer.New(function()
            apply_all()
        end, 3, 0)
        _G.SetRoleInfo_timer:Start()
    end
end

-- ==================== 启动 ====================
ensure_force_badge()
apply_all()
install_refresh_hooks()

log_msg(string.format(
    "征服者 %d | 星星=%d | 积分=%d | 旅程徽章=%d | 休闲赛季段位=%d | 等级=%d",
    CURRENT_SEGMENT, CONQUEROR_STARS, get_star_rating(),
    JOURNEY_BADGE_LEVEL, get_season_series_segment_id(), PLAYER_LEVEL
))





-- ==================== 收藏等级伪造（赛季手册/收藏家系统） ====================

-- 全局伪造参数（可随时修改）
_G.FAKE_LEVEL = _G.FAKE_LEVEL or 100              -- 伪造的收藏等级
_G.FAKE_DAN = _G.FAKE_DAN or 100                  -- 伪造的段位/阶级
_G.FAKE_LEVEL_NAME = _G.FAKE_LEVEL_NAME or "Collection Champion"  -- 伪造的称号名称
_G.FAKE_SCORE = _G.FAKE_SCORE or 99999            -- 伪造的收藏积分

-- ========== 防止重复Hook的标志 ==========


-- ========== 1. Hook网络协议处理器 ==========
local function hook_collect_handler()
    local handler = package.loaded["client.network.Protocol.CollectHandler"] or package.loaded["CollectHandler"]
    if not handler and not rawget(package.loaded, "client.network.Protocol.CollectHandler") then
        pcall(require, "client.network.Protocol.CollectHandler")
    end
    
    for path, mod in pairs(package.loaded or {}) do
        if type(mod) == "table" and mod.on_get_collect_sys_main_data_rsp and not rawget(mod, "_collection_handler_hooked") then
            rawset(mod, "_collection_handler_hooked", true)
            local orig = mod.on_get_collect_sys_main_data_rsp
            
            mod.on_get_collect_sys_main_data_rsp = function(err_code, collect_data, param)
                if collect_data and type(collect_data) == "table" then
                    rawset(collect_data, "total_score", _G.FAKE_SCORE)
                    rawset(collect_data, "cur_season_collect_score", _G.FAKE_SCORE)
                    local ss = rawget(collect_data, "season_score")
                    if type(ss) == "table" then
                        for k in pairs(ss) do ss[k] = _G.FAKE_SCORE end
                    else
                        rawset(collect_data, "season_score", { [1] = _G.FAKE_SCORE, [2] = _G.FAKE_SCORE })
                    end
                end
                return orig(err_code, collect_data, param)
            end
            return true
        end
    end
    return false
end

-- ========== 2. Hook模块管理器 ==========
local function hook_module_manager()
    for path, mod in pairs(package.loaded or {}) do
        if type(mod) == "table" and mod.GetModule and mod.LobbyModuleConfig and mod.LobbyModuleConfig.collect_module and not rawget(mod, "_collection_getmodule_hooked") then
            rawset(mod, "_collection_getmodule_hooked", true)
            local orig_get = mod.GetModule
            local collect_key = mod.LobbyModuleConfig.collect_module
            
            mod.GetModule = function(self, name)
                local inst = orig_get(self, name)
                if inst and name == collect_key then
                    patch_collect_module(inst)
                    inject_collect_data()
                end
                return inst
            end
            return true
        end
    end
    return false
end

-- ========== 3. 获取收藏模块 ==========
local function get_collect_module()
    local ModuleManager = _G.ModuleManager
    if not ModuleManager then
        for _, mod in pairs(package.loaded or {}) do
            if type(mod) == "table" and mod.GetModule and mod.LobbyModuleConfig and mod.LobbyModuleConfig.collect_module then
                ModuleManager = mod
                break
            end
        end
    end
    
    if ModuleManager and ModuleManager.GetModule and ModuleManager.LobbyModuleConfig then
        local ok, cm = pcall(ModuleManager.GetModule, ModuleManager, ModuleManager.LobbyModuleConfig.collect_module)
        if ok and cm then return cm end
    end
    
    for path, mod in pairs(package.loaded or {}) do
        if type(mod) == "table" and mod.GetLevelDataByScore and mod.GetSeasonLevelByScore then
            return mod
        end
    end
    return nil
end

-- ========== 4. 修补收藏模块 ==========
local function patch_collect_module(mod)
    if not mod or rawget(mod, "_collection_level_patched") then return false end
    rawset(mod, "_collection_level_patched", true)

    if mod.GetLevelDataByScore then
        rawset(mod, "GetLevelDataByScore", function(self, score, isSeason)
            return _G.FAKE_LEVEL, _G.FAKE_LEVEL_NAME, _G.FAKE_DAN
        end)
    end

    if mod.GetSeasonLevelByScore then
        rawset(mod, "GetSeasonLevelByScore", function(self, score, seasonId)
            return _G.FAKE_LEVEL, true, _G.FAKE_LEVEL_NAME
        end)
    end

    if mod.GetCollectScoreByCollectData then
        rawset(mod, "GetCollectScoreByCollectData", function(self, collect_data)
            return _G.FAKE_SCORE, _G.FAKE_SCORE
        end)
    end

    local collect_data = rawget(mod, "collect_data")
    if collect_data and type(collect_data) == "table" then
        rawset(collect_data, "total_score", _G.FAKE_SCORE)
        if not rawget(collect_data, "season_score") then rawset(collect_data, "season_score", {}) end
        local season = (rawget(mod, "GetSeasonId") and mod:GetSeasonId()) or 1
        collect_data.season_score[season] = _G.FAKE_SCORE
        rawset(collect_data, "cur_season_collect_score", _G.FAKE_SCORE)
    end

    if rawget(mod, "OnGetMainData") or mod.OnGetMainData then
        local orig_on_get = rawget(mod, "OnGetMainData") or mod.OnGetMainData
        rawset(mod, "OnGetMainData", function(self, err_code, data, param)
            if data and type(data) == "table" then
                rawset(data, "total_score", _G.FAKE_SCORE)
                if not rawget(data, "season_score") then rawset(data, "season_score", {}) end
                local season = (rawget(self, "GetSeasonId") and self:GetSeasonId()) or 1
                if type(data.season_score) == "table" then
                    data.season_score[season] = _G.FAKE_SCORE
                end
                rawset(data, "cur_season_collect_score", _G.FAKE_SCORE)
            end
            orig_on_get(self, err_code, data, param)
        end)
    end

    return true
end

-- ========== 5. 注入数据 ==========
local function inject_collect_data()
    pcall(function()
        local cm = get_collect_module()
        if cm then
            local collect_data = rawget(cm, "collect_data")
            if collect_data and type(collect_data) == "table" then
                rawset(collect_data, "total_score", _G.FAKE_SCORE)
                if not rawget(collect_data, "season_score") then rawset(collect_data, "season_score", {}) end
                local season = (rawget(cm, "GetSeasonId") and cm:GetSeasonId()) or 1
                if type(collect_data.season_score) == "table" then
                    collect_data.season_score[season] = _G.FAKE_SCORE
                end
                rawset(collect_data, "cur_season_collect_score", _G.FAKE_SCORE)
            end
        end
    end)
    
    pcall(function()
        if _G.DataMgr and _G.DataMgr.roleData then
            if not _G.DataMgr.roleData.brief_collect_data then _G.DataMgr.roleData.brief_collect_data = {} end
            _G.DataMgr.roleData.brief_collect_data.total_score = _G.FAKE_SCORE
            _G.DataMgr.roleData.brief_collect_data.cur_season_collect_score = _G.FAKE_SCORE
        end
    end)
end

-- ========== 6. Hook收藏界面UI ==========
local function hook_collect_road_ui()
    for path, mod in pairs(package.loaded or {}) do
        if type(mod) == "table" and mod.ShowCollect and mod.ShowSeasonCollect and not rawget(mod, "_collection_road_hooked") then
            rawset(mod, "_collection_road_hooked", true)
            local orig_show = mod.ShowCollect
            
            if orig_show then
                rawset(mod, "ShowCollect", function(self)
                    local mm = _G.ModuleManager
                    if not mm then
                        for _, m in pairs(package.loaded or {}) do
                            if type(m) == "table" and m.GetModule and m.LobbyModuleConfig then
                                mm = m
                                break
                            end
                        end
                    end
                    
                    if mm and mm.LobbyModuleConfig and mm.LobbyModuleConfig.collect_module then
                        local ok, cm = pcall(mm.GetModule, mm, mm.LobbyModuleConfig.collect_module)
                        if ok and cm and rawget(cm, "collect_data") then
                            local cd = rawget(cm, "collect_data")
                            if type(cd) == "table" then
                                rawset(cd, "total_score", _G.FAKE_SCORE)
                                if not rawget(cd, "season_score") then rawset(cd, "season_score", {}) end
                                cd.season_score[(rawget(cm, "GetSeasonId") and cm:GetSeasonId()) or 1] = _G.FAKE_SCORE
                                rawset(cd, "cur_season_collect_score", _G.FAKE_SCORE)
                            end
                        end
                    end
                    return orig_show(self)
                end)
            end
            return true
        end
    end
    return false
end

-- ========== 7. 一次性安装所有Hook ==========
local function install_collect_hooks()
    hook_collect_handler()
    hook_module_manager()
    hook_collect_road_ui()
    
    for path, mod in pairs(package.loaded or {}) do
        if type(mod) == "table" and mod.GetLevelDataByScore and mod.GetSeasonLevelByScore and not rawget(mod, "_collection_level_patched") then
            patch_collect_module(mod)
        end
    end
    
    local cm = get_collect_module()
    if cm then
        patch_collect_module(cm)
    end
    inject_collect_data()
    
    print("[收藏伪造] Hook已安装，等级=" .. _G.FAKE_LEVEL .. " 积分=" .. _G.FAKE_SCORE)
end

-- ========== 8. 导出控制函数 ==========
_G.CollectFake = {
    Apply = function()
        install_collect_hooks()
    end,
    SetLevel = function(n)
        _G.FAKE_LEVEL = tonumber(n) or _G.FAKE_LEVEL
        install_collect_hooks()
        return _G.FAKE_LEVEL
    end,
    SetName = function(name)
        _G.FAKE_LEVEL_NAME = tostring(name) or _G.FAKE_LEVEL_NAME
    end,
    SetScore = function(n)
        _G.FAKE_SCORE = tonumber(n) or _G.FAKE_SCORE
        install_collect_hooks()
        return _G.FAKE_SCORE
    end,
    SetDan = function(n)
        _G.FAKE_DAN = tonumber(n) or _G.FAKE_DAN
    end,
}
