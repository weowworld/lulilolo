local M = {}

-- ============ CONFIG ============
M.NAME_TAG_ID   = 2020003
M.TARGET_LABEL  = ""  -- 名牌框标签搜索

M.TITLE_ID      = 2494116
M.TITLE_LABEL   = ""  -- 称号标签搜索

M.DEBUG         = true
-- ================================

local S = _G.__PROFILE_SWAP_STATE or { hooked = false, ingameHooked = false, orig = {} }
_G.__PROFILE_SWAP_STATE = S

local function cfg() return _G.__PROFILE_SWAP_CFG or M end

local function log(tag, msg)
    if cfg().DEBUG then print("[" .. tag .. "] " .. tostring(msg)) end
end

local function cfgId(field)
    return tonumber(cfg()[field]) or 0
end

local ALIAS_STATE = { notHave = 0, have = 1, use = 2 }

local function normLabel(s)
    return tostring(s or ""):upper():gsub("[%s%-_%.]", "")
end

local function localizeAliasText(raw, id)
    raw = tostring(raw or "")
    if raw == "" then return "" end
    local ok, txt = pcall(function()
        local n = tonumber(raw)
        if n and LocUtil and LocUtil.GetLocalizeResStr then
            local s = LocUtil.GetLocalizeResStr(n)
            if s and s ~= "" then return s end
        end
        if LocUtil and LocUtil.LocalizeResFormatByStr then
            local s = LocUtil.LocalizeResFormatByStr(raw)
            if s and s ~= "" then return s end
        end
        return raw
    end)
    if ok and txt and txt ~= "" then return txt end
    ok, txt = pcall(function()
        if FuncUtil and FuncUtil.Gen_title and id then
            return FuncUtil.Gen_title(id, 0, {}, 0)
        end
    end)
    if ok and txt and txt ~= "" then return txt end
    return raw
end

local function aliasSearchKeys(id, row)
    local keys = {}
    local function add(v)
        v = normLabel(v)
        if v ~= "" then keys[v] = true end
    end
    if not row then return keys end
    add(row.AliasName)
    add(localizeAliasText(row.AliasName, id))
    add(row.AliasDesc)
    add(localizeAliasText(row.AliasDesc, id))
    add(row.AliasGetDesc)
    add(localizeAliasText(row.AliasGetDesc, id))
    pcall(function()
        local RT = require("client.slua.logic.roleInfo.logic_roleinfo_title")
        local info = RT.alias_list_info and RT.alias_list_info[id]
        if info then
            add(info.title)
            add(localizeAliasText(info.title, id))
        end
    end)
    return keys
end

-- ================= Name Tag =================

local function getNameFrameRow(id)
    id = tonumber(id)
    if not id or id <= 0 then return nil end
    local ok, row = pcall(function() return CDataTable.GetTableData("NameFrame", id) end)
    if ok and row then return row end
    return nil
end

local function findNameFrame(label)
    label = tostring(label or ""):upper()
    if label == "" then return 0, nil end
    local ok, tbl = pcall(function() return CDataTable.GetTable("NameFrame") end)
    if not ok or not tbl then return 0, nil end
    local bestId, bestRow, bestScore = 0, nil, -1
    for id, row in pairs(tbl) do
        if row then
            local text = (tostring(row.Name or "") .. " S" .. tostring(row.Season or "")):upper()
            local score = 0
            if text:find(label, 1, true) then score = score + 10 end
            if label:find("C1") and tostring(row.Season or "") == "1" then score = score + 2 end
            if score > bestScore then
                bestScore = score
                bestId = tonumber(id) or id
                bestRow = row
            end
        end
    end
    return bestId, bestRow
end

local function resolveNameTagId()
    local id = cfgId("NAME_TAG_ID")
    if id > 0 and getNameFrameRow(id) then return id end
    if id > 0 then return id end
    local found = findNameFrame(cfg().TARGET_LABEL)
    return found or 0
end

local function nameTagRowName(id)
    local row = getNameFrameRow(id)
    if not row then return "?" end
    return tostring(row.Name or "") .. " S" .. tostring(row.Season or "")
end

local function detectEquippedNameTag()
    local id = 0
    pcall(function()
        local NF = require("client.slua.logic.person_space.logic_roleinfo_nameframe")
        if tonumber(NF.nUsedID) and NF.nUsedID > 0 then id = NF.nUsedID end
    end)
    if id > 0 then return id end
    pcall(function()
        if DataMgr and DataMgr.roleData and DataMgr.roleData.nameFrameData then
            for k, v in pairs(DataMgr.roleData.nameFrameData) do
                if v and tonumber(v.is_used) == 1 then
                    id = tonumber(k) or k
                    return
                end
            end
        end
    end)
    if id > 0 then return id end
    pcall(function()
        local TeamUp = require("client.slua.logic.teamup.logic_team_up")
        local mi = TeamUp and TeamUp.GetMemberInfo and DataMgr and TeamUp.GetMemberInfo(DataMgr.roleData.uid)
        if mi and tonumber(mi.brand_id) and mi.brand_id > 0 then id = mi.brand_id end
    end)
    return id or 0
end

local function applyNameFrame(id)
    id = tonumber(id)
    if not id or id <= 0 then return false end
    if not DataMgr or not DataMgr.roleData then return false end

    DataMgr.roleData.nameFrameData = DataMgr.roleData.nameFrameData or {}
    local data = DataMgr.roleData.nameFrameData
    local cur = detectEquippedNameTag()

    data[id] = data[id] or { expire_ts = 0, is_used = 0 }
    if cur > 0 and cur ~= id and data[cur] then
        if not data[id].expire_ts or data[id].expire_ts == 0 then
            data[id].expire_ts = data[cur].expire_ts or 0
        end
        data[cur].is_used = 0
    end
    data[id].is_used = 1

    pcall(function()
        local NF = require("client.slua.logic.person_space.logic_roleinfo_nameframe")
        NF.nUsedID = id
    end)

    pcall(function()
        if DataMgr.ResetNameFrame and DataMgr.UseNameFrame then
            DataMgr.ResetNameFrame()
            DataMgr.UseNameFrame(id)
        end
    end)

    pcall(function()
        local uid = DataMgr.roleData.uid
        if not uid then return end
        local TeamUp = require("client.slua.logic.teamup.logic_team_up")
        local mi = TeamUp and TeamUp.GetMemberInfo and TeamUp.GetMemberInfo(uid)
        if mi then mi.brand_id = id end
    end)

    return true
end

local function refreshNameTagUi()
    pcall(function()
        EventSystem:postEvent(EVENTTYPE_ROLEINFO, EVENTID_ROLEINFO_UPDATE_NAME_FRAME)
        EventSystem:postEvent(EVENTTYPE_ROLEINFO, EVENTID_ROLEINFO_USE_NAME_FRAME, resolveNameTagId())
    end)
    pcall(function()
        if not UIManager or not UIManager.UI_Config then return end
        for key, conf in pairs(UIManager.UI_Config) do
            if type(key) == "string" and (key:find("Team") or key:find("team")) then
                local ui = UIManager.GetUI(conf)
                if ui and ui.menuList then
                    for _, menu in pairs(ui.menuList) do
                        if menu and menu.bIsSelf and menu.UpdateFrame and slua.isValid(menu.UIRoot) then
                            menu:UpdateFrame()
                        end
                    end
                end
            end
        end
    end)
end

-- ================= Title (Alias) =================

local function getAliasRow(id)
    id = tonumber(id)
    if not id or id <= 0 then return nil end
    local ok, row = pcall(function() return CDataTable.GetTableData("AliasCfg", id) end)
    if ok and row then return row end
    return nil
end

local function aliasDisplayTitle(id, row)
    row = row or getAliasRow(id)
    if not row then return "?" end
    local fromInfo
    pcall(function()
        local RT = require("client.slua.logic.roleInfo.logic_roleinfo_title")
        local info = RT.alias_list_info and RT.alias_list_info[id]
        if info and info.title and info.title ~= "" then fromInfo = info.title end
    end)
    if fromInfo and fromInfo ~= "" then return fromInfo end
    local ok, title = pcall(function()
        if FuncUtil and FuncUtil.Gen_title then
            return FuncUtil.Gen_title(id, 0, {}, 0)
        end
    end)
    if ok and title and title ~= "" then return title end
    return localizeAliasText(row.AliasName, id)
end

local function findAlias(label)
    local want = normLabel(label)
    if want == "" then return 0, nil end
    local ok, tbl = pcall(function() return CDataTable.GetTable("AliasCfg") end)
    if not ok or not tbl then return 0, nil end
    local bestId, bestRow, bestScore = 0, nil, -1
    for id, row in pairs(tbl) do
        if row then
            local score = 0
            for key in pairs(aliasSearchKeys(id, row)) do
                if key == want then
                    score = math.max(score, 30)
                elseif key:find(want, 1, true) or want:find(key, 1, true) then
                    score = math.max(score, 10)
                end
            end
            if score > bestScore then
                bestScore = score
                bestId = tonumber(id) or id
                bestRow = row
            end
        end
    end
    if bestId <= 0 then
        log("Title", "findAlias miss label=" .. tostring(label) .. " try DumpTitles")
    end
    return bestId, bestRow
end

local function patchServerAliasList(list, id)
    id = tonumber(id)
    if not id or id <= 0 or type(list) ~= "table" then return end
    local row = getAliasRow(id)
    if not row then return end
    local titleText = aliasDisplayTitle(id, row)

    for k, v in pairs(list) do
        if v and tonumber(k) ~= id and tonumber(v.state) == ALIAS_STATE.use then
            v.state = (tonumber(v.have_used) == 1) and ALIAS_STATE.have or ALIAS_STATE.notHave
        end
    end

    local entry = list[id] or {}
    entry.state = ALIAS_STATE.use
    entry.title = titleText
    entry.rank = entry.rank or 0
    entry.rank_id = entry.rank_id or 0
    entry.nation = entry.nation or ""
    entry.ext_info = entry.ext_info or {}
    entry.expire_ts = entry.expire_ts or 0
    entry.receive_time = entry.receive_time or 0
    entry.have_used = 1
    list[id] = entry
end

local function syncAliasListUI(id, titleText, row)
    id = tonumber(id)
    if not id or id <= 0 then return end
    row = row or getAliasRow(id)
    titleText = titleText or aliasDisplayTitle(id, row)
    pcall(function()
        local RT = require("client.slua.logic.roleInfo.logic_roleinfo_title")
        RT.selectAliasId = id
        for i, item in ipairs(RT.aliasList or {}) do
            if tonumber(item.id) == id then
                item.aliasState = ALIAS_STATE.use
                item.aliasTitle = titleText
                RT.aliasInfo = item
            elseif item.aliasState == ALIAS_STATE.use then
                item.aliasState = (tonumber(item.aliasIsHaveUse) == 1) and ALIAS_STATE.have or ALIAS_STATE.notHave
            end
        end
        for i, item in ipairs(RT.arr_temp or {}) do
            if tonumber(item.id) == id then
                item.aliasState = ALIAS_STATE.use
                item.aliasTitle = titleText
            elseif item.aliasState == ALIAS_STATE.use then
                item.aliasState = (tonumber(item.aliasIsHaveUse) == 1) and ALIAS_STATE.have or ALIAS_STATE.notHave
            end
        end
        if row and RT.aliasInfo and tonumber(RT.aliasInfo.id) == id then
            RT.aliasInfo.aliasState = ALIAS_STATE.use
            RT.aliasInfo.aliasTitle = titleText
        end
    end)
end

local function resolveTitleId()
    local id = cfgId("TITLE_ID")
    if id > 0 and getAliasRow(id) then return id end
    if id > 0 then return id end
    local found = findAlias(cfg().TITLE_LABEL)
    return found or 0
end

local function detectEquippedTitle()
    local id = 0
    pcall(function()
        if DataMgr and DataMgr.roleData and DataMgr.roleData.alias then
            id = tonumber(DataMgr.roleData.alias.id) or 0
        end
    end)
    if id > 0 then return id end
    pcall(function()
        local RT = require("client.slua.logic.roleInfo.logic_roleinfo_title")
        if RT.alias_list_info then
            for k, v in pairs(RT.alias_list_info) do
                if v and tonumber(v.state) == ALIAS_STATE.use then
                    id = tonumber(k) or k
                    return
                end
            end
        end
    end)
    if id > 0 then return id end
    pcall(function()
        local TeamUp = require("client.slua.logic.teamup.logic_team_up")
        local mi = TeamUp and TeamUp.GetMemberInfo and DataMgr and TeamUp.GetMemberInfo(DataMgr.roleData.uid)
        if mi and tonumber(mi.aliasid) and mi.aliasid > 0 then id = mi.aliasid end
    end)
    return id or 0
end

local function applyTitle(id)
    id = tonumber(id)
    if not id or id <= 0 then return false end
    if not DataMgr or not DataMgr.roleData then return false end
    local row = getAliasRow(id)
    if not row then
        log("Title", "apply fail no AliasCfg id=" .. tostring(id))
        return false
    end

    local titleText = aliasDisplayTitle(id, row)
    local cur = detectEquippedTitle()

    DataMgr.roleData.alias = DataMgr.roleData.alias or {}
    DataMgr.roleData.alias.id = id
    DataMgr.roleData.alias.title = titleText
    DataMgr.roleData.alias.nation = DataMgr.roleData.alias.nation or ""
    DataMgr.roleData.alias.rank_id = DataMgr.roleData.alias.rank_id or 0

    pcall(function()
        local RT = require("client.slua.logic.roleInfo.logic_roleinfo_title")
        RT.selectAliasId = id
        RT.alias_list_info = RT.alias_list_info or {}
        patchServerAliasList(RT.alias_list_info, id)
        syncAliasListUI(id, titleText, row)
    end)

    pcall(function()
        local uid = DataMgr.roleData.uid
        if not uid then return end
        local TeamUp = require("client.slua.logic.teamup.logic_team_up")
        local mi = TeamUp and TeamUp.GetMemberInfo and TeamUp.GetMemberInfo(uid)
        if mi then
            mi.aliasid = id
            mi.aliastitle = titleText
            mi.aliasnation = DataMgr.roleData.alias.nation or ""
            mi.aliasRankId = DataMgr.roleData.alias.rank_id or 0
            mi.alias = mi.alias or {}
            mi.alias.id = id
            mi.alias.title = titleText
            mi.alias.nation = mi.aliasnation
            mi.alias.rank_id = mi.aliasRankId
        end
    end)

    pcall(function()
        local uid = DataMgr.roleData.uid
        if not uid then return end
        local logic_profile = ModuleManager and ModuleManager.GetModule
            and ModuleManager.GetModule(ModuleManager.LobbyModuleConfig.logic_profile)
        local profile = logic_profile and logic_profile:GetLocalProfile(uid)
        if profile then
            profile.alias = profile.alias or {}
            profile.alias.id = id
            profile.alias.title = titleText
            profile.alias.nation = DataMgr.roleData.alias.nation or ""
            profile.alias.rank_id = DataMgr.roleData.alias.rank_id or 0
        end
    end)

    if cur > 0 and cur ~= id then
        log("Title", "swap " .. cur .. " -> " .. id .. " | " .. titleText)
    end
    return true
end

local function refreshTitleUi()
    pcall(function()
        EventSystem:postEvent(EVENTTYPE_ROLEINFO, EVENTID_ROLEINFO_UPDATE_ALL_TITLE)
    end)
    pcall(function()
        if not UIManager or not UIManager.UI_Config then return end
        for key, conf in pairs(UIManager.UI_Config) do
            if type(key) == "string" then
                local ui = UIManager.GetUI(conf)
                if ui then
                    if key:find("Personalization_Title", 1, true) and ui.UpdateCurrentAlias then
                        ui:UpdateCurrentAlias()
                    end
                    if key:find("Personalization_Title", 1, true) and ui.ItemGrid and ui.ItemGrid.RefreshAllItems then
                        ui.ItemGrid:RefreshAllItems()
                    end
                    if (key:find("Team", 1, true) or key:find("team", 1, true)) and ui.menuList then
                        for _, menu in pairs(ui.menuList) do
                            if menu and menu.bIsSelf and menu.UpdateAlias and slua.isValid(menu.UIRoot) then
                                if menu.UIRoot.Title_UIBP then
                                    menu:UpdateAlias(menu.UIRoot.Title_UIBP)
                                end
                                if menu.UIRoot.Title_UIBP_C_0 then
                                    menu:UpdateAlias(menu.UIRoot.Title_UIBP_C_0)
                                end
                            end
                        end
                    end
                end
            end
        end
    end)
end

-- ================= In-Game Title (PlayerState.AliasInfo) =================

local function selfUid()
    if DataMgr and DataMgr.roleData and DataMgr.roleData.uid then
        return tostring(DataMgr.roleData.uid)
    end
    return nil
end

local function isSelfUid(uid)
    local mine = selfUid()
    return mine and uid and tostring(uid) == mine
end

local function patchPlayerInfoAlias(info, id)
    id = tonumber(id) or resolveTitleId()
    if not info or not id or id <= 0 then return end
    info.alias = info.alias or {}
    info.alias.id = id
    info.alias.title = aliasDisplayTitle(id)
    info.alias.nation = info.alias.nation or ""
    info.alias.rank_id = info.alias.rank_id or 0
    info.alias.rank = info.alias.rank or 0
    info.alias.ext_info = info.alias.ext_info or {}
end

local function applyPlayerStateAlias(ps, id)
    id = tonumber(id) or resolveTitleId()
    if not ps or not id or id <= 0 then return false end
    if not slua or not slua.isValid or not slua.isValid(ps) then return false end
    local ok = pcall(function()
        local title = aliasDisplayTitle(id)
        ps.AliasInfo.aliasID = id
        ps.AliasInfo.aliasTitle = title
        ps.AliasInfo.aliasNation = ps.AliasInfo.aliasNation or ""
        ps.AliasInfo.aliasRank = ps.AliasInfo.aliasRank or 0
        ps.AliasInfo.aliasPartnerName = ps.AliasInfo.aliasPartnerName or ""
        ps.AliasInfo.aliasPartnerRelation = ps.AliasInfo.aliasPartnerRelation or 1
        ps.AliasInfo.aliasRankID = ps.AliasInfo.aliasRankID or 0
    end)
    return ok
end

local function applyIngameAlias()
    local id = resolveTitleId()
    if id <= 0 then return end
    local uid = selfUid()
    if not uid then return end

    pcall(function()
        local SPM = require("Server.Data.ServerPlayerDataMgr")
        local info = SPM.GetPlayerInfo and SPM.GetPlayerInfo(uid)
        if info then patchPlayerInfoAlias(info, id) end
    end)

    pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        local ps = GameplayData.GetPlayerState and GameplayData.GetPlayerState()
        if ps and isSelfUid(ps.UID) then applyPlayerStateAlias(ps, id) end
        local pc = GameplayData.GetPlayerController and GameplayData.GetPlayerController()
        if pc and slua.isValid(pc) and pc.PlayerState and slua.isValid(pc.PlayerState) then
            if isSelfUid(pc.PlayerState.UID) then applyPlayerStateAlias(pc.PlayerState, id) end
        end
    end)
end

local function overrideAliasTable(AliasInfo, uid)
    local id = resolveTitleId()
    if id <= 0 or not isSelfUid(uid) then return AliasInfo end
    AliasInfo = AliasInfo or {}
    AliasInfo.aliasID = id
    AliasInfo.aliasTitle = aliasDisplayTitle(id)
    AliasInfo.aliasNation = AliasInfo.aliasNation or ""
    AliasInfo.aliasRank = AliasInfo.aliasRank or 0
    AliasInfo.aliasPartnerName = AliasInfo.aliasPartnerName or ""
    AliasInfo.aliasPartnerRelation = AliasInfo.aliasPartnerRelation or 1
    AliasInfo.aliasRankID = AliasInfo.aliasRankID or 0
    return AliasInfo
end

local function patchMethod(suffix, method, wrapper)
    for path, mod in pairs(package.loaded) do
        if type(path) == "string" and path:find(suffix, 1, true) then
            local impl = mod.__inner_impl
            while impl do
                local orig = rawget(impl, method)
                if type(orig) == "function" then
                    local key = path .. "#" .. method
                    if not S.orig[key] then
                        S.orig[key] = orig
                        rawset(impl, method, function(...)
                            return wrapper(orig, ...)
                        end)
                        log("Hook", method .. " @ " .. suffix)
                        return true
                    end
                end
                impl = impl.__super_impl
            end
        end
    end
    return false
end

local function installIngameHooks()
    if S.ingameHooked then return end

    pcall(function()
        local SPM = require("Server.Data.ServerPlayerDataMgr")
        if SPM.OnSyncPlayerInfo and not S.orig.OnSyncPlayerInfo then
            S.orig.OnSyncPlayerInfo = SPM.OnSyncPlayerInfo
            SPM.OnSyncPlayerInfo = function(uid, info)
                if isSelfUid(uid) then patchPlayerInfoAlias(info) end
                return S.orig.OnSyncPlayerInfo(uid, info)
            end
            log("Hook", "OnSyncPlayerInfo")
        end
        if SPM.HandleAliasInfo and not S.orig.HandleAliasInfo then
            S.orig.HandleAliasInfo = SPM.HandleAliasInfo
            SPM.HandleAliasInfo = function(tInfo, container)
                local uid
                if container and container.UID then uid = container.UID end
                if isSelfUid(uid) or (tInfo and isSelfUid(tInfo.uid)) then
                    patchPlayerInfoAlias(tInfo)
                end
                local ret = S.orig.HandleAliasInfo(tInfo, container)
                if container and isSelfUid(container.UID) then
                    applyPlayerStateAlias(container)
                end
                return ret
            end
            log("Hook", "HandleAliasInfo")
        end
    end)

    pcall(function()
        local PSTF = require("GameLua.GameCore.Feature.PlayerStateSyncDataFeature")
        local impl = PSTF.__inner_impl or PSTF
        if impl.OnInitWithParams and not S.orig.PlayerStateSync_OnInit then
            S.orig.PlayerStateSync_OnInit = impl.OnInitWithParams
            impl.OnInitWithParams = function(self, uid, playerKey, playerType)
                if isSelfUid(uid) then
                    pcall(function()
                        local SPM = require("Server.Data.ServerPlayerDataMgr")
                        local pd = SPM.GetPlayerInfo(uid)
                        if pd then patchPlayerInfoAlias(pd) end
                    end)
                end
                S.orig.PlayerStateSync_OnInit(self, uid, playerKey, playerType)
                if isSelfUid(uid) and self.Owner then
                    applyPlayerStateAlias(self.Owner)
                end
            end
            log("Hook", "PlayerStateSyncDataFeature.OnInitWithParams")
        end
    end)

    pcall(function()
        if EventSystem and EVENTTYPE_PLAYER and EVENTID_SYNC_PLAYER_INFO and not S.ingameEvent then
            S.ingameEvent = EventSystem:registEvent(EVENTTYPE_PLAYER, EVENTID_SYNC_PLAYER_INFO, function(_, _, uid)
                if isSelfUid(uid) then
                    applyIngameAlias()
                    applyTitle(resolveTitleId())
                end
            end)
        end
    end)

    pcall(function() require("GameLua.Mod.BaseMod.Client.IngameTeamPanel.Items.IngamePositionItem_UI_New") end)
    pcall(function() require("GameLua.Mod.BaseMod.Client.TeamPanel.SIsLandPositionItemUI") end)

    patchMethod("IngamePositionItem_UI_New", "SetName", function(orig, self, bCanShow)
        local ps = self.SavedPlayerState
        if ps and slua.isValid(ps) and isSelfUid(ps.UID) then
            applyPlayerStateAlias(ps)
        end
        return orig(self, bCanShow)
    end)

    patchMethod("SIsLandPositionItemUI", "SetName", function(orig, self, name, aliasInfo, nUID)
        aliasInfo = overrideAliasTable(aliasInfo, nUID)
        return orig(self, name, aliasInfo, nUID)
    end)

    patchMethod("MainCity_PositionItem_UIBP", "SetName", function(orig, self, name, aliasInfo, nUID)
        aliasInfo = overrideAliasTable(aliasInfo, nUID)
        return orig(self, name, aliasInfo, nUID)
    end)

    patchMethod("OtherPositionItem_BP", "SetAliasInfo", function(orig, self, aliasInfo)
        pcall(function()
            local ps = self.SavedPlayerState
            if ps and isSelfUid(ps.UID) then
                aliasInfo = overrideAliasTable(aliasInfo, ps.UID)
            end
        end)
        return orig(self, aliasInfo)
    end)

    S.ingameHooked = true
end

-- ================= Hooks =================

local function installHooks()
    installIngameHooks()
    if S.hooked then return end

    pcall(function() require("client.slua.umg.team.TeamUp_Member_Menu_UIBP") end)

    patchMethod("TeamUp_Member_Menu_UIBP", "UpdateFrame", function(orig, self)
        if self.bIsSelf then applyNameFrame(resolveNameTagId()) end
        return orig(self)
    end)

    patchMethod("TeamUp_Member_Menu_UIBP", "UpdateAlias", function(orig, self, titleUi)
        if self.bIsSelf then applyTitle(resolveTitleId()) end
        return orig(self, titleUi)
    end)

    pcall(function() require("client.slua.umg.roleInfoNew.Personalization_Title_UIBP") end)

    patchMethod("Personalization_Title_UIBP", "RefreshTitleWidget", function(orig, self, widget, data)
        local tid = resolveTitleId()
        if tid > 0 and data and tonumber(data.id) == tid then
            data.aliasState = ALIAS_STATE.use
            data.aliasTitle = aliasDisplayTitle(tid)
        end
        return orig(self, widget, data)
    end)

    patchMethod("Personalization_Title_UIBP", "UpdateSelectedItemInfo", function(orig, self, itemData)
        applyTitle(resolveTitleId())
        syncAliasListUI(resolveTitleId())
        return orig(self, itemData)
    end)

    pcall(function()
        local NF = require("client.slua.logic.person_space.logic_roleinfo_nameframe")
        if NF.use_brand_rsp and not S.orig.use_brand_rsp then
            S.orig.use_brand_rsp = NF.use_brand_rsp
            NF.use_brand_rsp = function(res, id)
                applyNameFrame(resolveNameTagId())
                return S.orig.use_brand_rsp(res, resolveNameTagId())
            end
        end
    end)

    pcall(function()
        local rh = require("client.network.Protocol.RoleInfoHandler")
        if rh.on_use_brand_rsp and not S.orig.on_use_brand_rsp then
            S.orig.on_use_brand_rsp = rh.on_use_brand_rsp
            rh.on_use_brand_rsp = function(res, id)
                applyNameFrame(resolveNameTagId())
                return S.orig.on_use_brand_rsp(res, resolveNameTagId())
            end
        end
    end)

    pcall(function()
        local RT = require("client.slua.logic.roleInfo.logic_roleinfo_title")
        if RT.alias_list_res and not S.orig.alias_list_res then
            S.orig.alias_list_res = RT.alias_list_res
            RT.alias_list_res = function(res, list, red_point, alias)
                if tonumber(res) == 0 and type(list) == "table" then
                    patchServerAliasList(list, resolveTitleId())
                end
                local ret = S.orig.alias_list_res(res, list, red_point, alias)
                applyTitle(resolveTitleId())
                refreshTitleUi()
                return ret
            end
        end
        if RT.initAliasInfo and not S.orig.initAliasInfo then
            S.orig.initAliasInfo = RT.initAliasInfo
            RT.initAliasInfo = function()
                patchServerAliasList(RT.alias_list_info, resolveTitleId())
                S.orig.initAliasInfo()
                applyTitle(resolveTitleId())
            end
        end
        if RT.change_alias_rsp and not S.orig.change_alias_rsp then
            S.orig.change_alias_rsp = RT.change_alias_rsp
            RT.change_alias_rsp = function(res, id, rank_id)
                applyTitle(resolveTitleId())
                return S.orig.change_alias_rsp(res, resolveTitleId(), rank_id)
            end
        end
    end)

    pcall(function()
        local ch = require("client.network.Protocol.CharacterHandler")
        if ch.on_change_alias_rsp and not S.orig.on_change_alias_rsp then
            S.orig.on_change_alias_rsp = ch.on_change_alias_rsp
            ch.on_change_alias_rsp = function(res, id, rank_id)
                applyTitle(resolveTitleId())
                return S.orig.on_change_alias_rsp(res, resolveTitleId(), rank_id)
            end
        end
    end)

    S.hooked = true
end

-- ================= Apply / Schedule =================

local function applyAll()
    local nt = resolveNameTagId()
    if nt > 0 then applyNameFrame(nt) end
    local tl = resolveTitleId()
    if tl > 0 then
        applyTitle(tl)
        applyIngameAlias()
    end
end

local function refreshAll()
    refreshNameTagUi()
    refreshTitleUi()
end

local function tick()
    installHooks()
    applyAll()
end

_G.__PROFILE_SWAP_CFG = M
_G.ProfileSwap = M

local n = 0
local function schedule()
    n = n + 1
    tick()
    if n == 1 or n == 5 then
        refreshAll()
        local nt = resolveNameTagId()
        local tl = resolveTitleId()
        log("ProfileSwap", "NameTag " .. nt .. " | " .. nameTagRowName(nt) .. " | was " .. detectEquippedNameTag())
        if tl <= 0 then
            log("ProfileSwap", "Title NOT FOUND for label=" .. tostring(cfg().TITLE_LABEL) .. " -> DumpTitles('Weapon')")
        else
            log("ProfileSwap", "Title " .. tl .. " | " .. aliasDisplayTitle(tl) .. " | was " .. detectEquippedTitle())
        end
    end
    if n > 400 then
        local ingame = false
        pcall(function()
            if GameStatus and GameStatus.IsInFightingStatus then
                ingame = GameStatus.IsInFightingStatus()
            end
        end)
        if not ingame then return end
        n = 300
    end
    pcall(function()
        if _G.SetTimer then _G.SetTimer(0.3, schedule)
        elseif EventSystem and EventSystem.AddTimer then EventSystem:AddTimer(0.3, false, schedule) end
    end)
end

tick()
schedule()

-- ================= API =================

function M.SetNameTagId(id)
    M.NAME_TAG_ID = tonumber(id) or 0
    M.TARGET_LABEL = ""
    applyNameFrame(resolveNameTagId())
    refreshNameTagUi()
    log("NameTag", "SetId " .. resolveNameTagId())
end

function M.SetNameTagLabel(label)
    M.TARGET_LABEL = tostring(label or "")
    M.NAME_TAG_ID = 0
    applyNameFrame(resolveNameTagId())
    refreshNameTagUi()
    log("NameTag", "SetLabel " .. resolveNameTagId() .. " " .. nameTagRowName(resolveNameTagId()))
end

function M.SetTitleId(id)
    M.TITLE_ID = tonumber(id) or 0
    M.TITLE_LABEL = ""
    applyTitle(resolveTitleId())
    applyIngameAlias()
    refreshTitleUi()
    log("Title", "SetId " .. resolveTitleId())
end

function M.SetTitleLabel(label)
    M.TITLE_LABEL = tostring(label or "")
    M.TITLE_ID = 0
    applyTitle(resolveTitleId())
    applyIngameAlias()
    refreshTitleUi()
    log("Title", "SetLabel " .. resolveTitleId() .. " " .. aliasDisplayTitle(resolveTitleId()))
end

function M.Reload()
    applyAll()
    refreshAll()
    log("ProfileSwap", "reload NT=" .. resolveNameTagId() .. " TL=" .. resolveTitleId())
end

function M.Dump()
    log("ProfileSwap", "cfg NT id=" .. cfgId("NAME_TAG_ID") .. " label=" .. tostring(cfg().TARGET_LABEL))
    log("ProfileSwap", "cfg TL id=" .. cfgId("TITLE_ID") .. " label=" .. tostring(cfg().TITLE_LABEL))
    log("NameTag", "resolved=" .. resolveNameTagId() .. " " .. nameTagRowName(resolveNameTagId()))
    log("NameTag", "equipped=" .. detectEquippedNameTag() .. " " .. nameTagRowName(detectEquippedNameTag()))
    log("Title", "resolved=" .. resolveTitleId() .. " " .. aliasDisplayTitle(resolveTitleId()))
    log("Title", "equipped=" .. detectEquippedTitle() .. " " .. aliasDisplayTitle(detectEquippedTitle()))
    pcall(function()
        local GameplayData = require("GameLua.GameCore.Data.GameplayData")
        local ps = GameplayData.GetPlayerState and GameplayData.GetPlayerState()
        if ps and slua.isValid(ps) then
            log("InGame", "PlayerState UID=" .. tostring(ps.UID) .. " aliasID=" .. tostring(ps.AliasInfo and ps.AliasInfo.aliasID))
        else
            log("InGame", "PlayerState not available (lobby?)")
        end
    end)
end

function M.DumpNameTags(filter)
    filter = tostring(filter or ""):upper()
    local ok, tbl = pcall(function() return CDataTable.GetTable("NameFrame") end)
    if not ok or not tbl then log("NameTag", "no NameFrame table"); return end
    for id, row in pairs(tbl) do
        if row then
            local text = nameTagRowName(id):upper()
            if filter == "" or text:find(filter, 1, true) then
                log("NameTag", "ID=" .. tostring(id) .. " | " .. nameTagRowName(id))
            end
        end
    end
end

function M.DumpTitles(filter)
    filter = normLabel(filter)
    local ok, tbl = pcall(function() return CDataTable.GetTable("AliasCfg") end)
    if not ok or not tbl then log("Title", "no AliasCfg table"); return end
    for id, row in pairs(tbl) do
        if row then
            local show = aliasDisplayTitle(id, row)
            local hit = filter == ""
            if not hit then
                for key in pairs(aliasSearchKeys(id, row)) do
                    if key:find(filter, 1, true) then hit = true; break end
                end
                if normLabel(show):find(filter, 1, true) then hit = true end
            end
            if hit then
                log("Title", "ID=" .. tostring(id) .. " | " .. tostring(show))
            end
        end
    end
end

-- ==================== 自定义名牌框和称号（只刷新一次） ====================

local _lastNameTagId = nil
local _lastTitleId = nil

-- 设置名牌框（通过ID）- 只在ID变化时应用一次
function M.SetNameTagById(id)
    id = tonumber(id) or 0
    if id <= 0 then
        log("NameTag", "Invalid ID: " .. tostring(id))
        return false
    end
    if _lastNameTagId ~= id then
        _lastNameTagId = id
        M.SetNameTagId(id)
        if _G.YDMH_Config and _G.YDMH_Config.Set then
            _G.YDMH_Config.Set("NAME_TAG_ID", id)
        end
        log("NameTag", "Set by ID: " .. tostring(id))
        return true
    end
    return false
end

-- 设置称号（通过ID）- 只在ID变化时应用一次
function M.SetTitleById(id)
    id = tonumber(id) or 0
    if id <= 0 then
        log("Title", "Invalid ID: " .. tostring(id))
        return false
    end
    if _lastTitleId ~= id then
        _lastTitleId = id
        M.SetTitleId(id)
        if _G.YDMH_Config and _G.YDMH_Config.Set then
            _G.YDMH_Config.Set("TITLE_ID", id)
        end
        log("Title", "Set by ID: " .. tostring(id))
        return true
    end
    return false
end

-- 从配置文件加载 - 只在ID变化时应用一次
function M.LoadFromConfig()
    if not _G.YDMH_Config then
        log("ProfileSwap", "YDMH_Config not found")
        return
    end
    
    local config = _G.YDMH_Config.Load and _G.YDMH_Config.Load() or {}
    local changed = false
    
    local nameTagId = config["NAME_TAG_ID"]
    if nameTagId and tonumber(nameTagId) > 0 then
        if _lastNameTagId ~= tonumber(nameTagId) then
            _lastNameTagId = tonumber(nameTagId)
            M.SetNameTagId(_lastNameTagId)
            log("NameTag", "Loaded from config: " .. tostring(_lastNameTagId))
            changed = true
        end
    end
    
    local titleId = config["TITLE_ID"]
    if titleId and tonumber(titleId) > 0 then
        if _lastTitleId ~= tonumber(titleId) then
            _lastTitleId = tonumber(titleId)
            M.SetTitleId(_lastTitleId)
            log("Title", "Loaded from config: " .. tostring(_lastTitleId))
            changed = true
        end
    end
    
    -- 只在变化时刷新UI一次
    if changed then
        refreshAll()
        log("ProfileSwap", "Config changed, UI refreshed once")
    end
end

-- 初始化加载
if _G.Mytimer_ticker then
    -- 延迟2秒加载一次，之后不再重复
    _G.Mytimer_ticker.AddTimer(2, function()
        pcall(M.LoadFromConfig)
        pcall(M.Reload)
    end)
end

-- backward compat with old script globals
_G.__NAME_TAG_SWAP_CFG = M
function M.SetId(id) M.SetNameTagId(id) end
function M.SetLabel(label) M.SetNameTagLabel(label) end
function M.DumpAll() M.DumpNameTags("Creator") end

return M