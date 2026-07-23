-- ==================== 载具皮肤特效（7303001）- 仅在比赛对局中工作 ====================

-- 比赛检测函数
local function IsInMatchForVehicle()
    -- 在大厅中返回false
    local ok, isLobby = pcall(function()
        return GameStatus and GameStatus.IsInLobbyOrMainCity and GameStatus.IsInLobbyOrMainCity()
    end)
    if ok and isLobby then
        return false
    end
    
    -- 检查是否在战斗状态
    local ok2, isFighting = pcall(function()
        return GameStatus and GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus()
    end)
    if ok2 then
        return isFighting == true
    end
    
    -- 回退：检查是否有有效的游戏角色
    local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not pc then return false end
    local uCharacter = pc:GetPlayerCharacterSafety()
    return uCharacter and slua.isValid(uCharacter)
end

local VehicleAvatarComponent = require("GameLua.GameCore.Module.Vehicle.Component.VehicleAvatarComponent")

VehicleAvatarComponent.__inner_impl.CheckCanPlaySkinSwitchEffect = function(self, curVehicleId, lastVehicleId)
    if not IsInMatchForVehicle() then
        return false
    end
    return true
end

VehicleAvatarComponent.__inner_impl.ShowVehicleSwitchEffect = function(self)
    if not IsInMatchForVehicle() then
        return false
    end
    
    if not self.curSwitchEffectId or self.curSwitchEffectId <= 0 then
        self.curSwitchEffectId = 7303001
    end
    local vehicleActor = self:GetOwner()
    if not slua.isValid(vehicleActor) then return false end
    if self.uSwitchEffectActor then
        self:StopSkinSwitchEffect()
        self.uSwitchEffectActor:K2_DestroyActor()
        self.uSwitchEffectActor = nil
    end
    if not self.lastEquipedAvatarId or self.lastEquipedAvatarId <= 0 then
        self.lastEquipedAvatarId = vehicleActor.ClientUsedAvatarID or vehicleActor:GetDefaultAvatarID() or 0
    end
    local currentAvatarID = vehicleActor.ClientUsedAvatarID or self.lastEquipedAvatarId or 0
    local bIsLobbyActor = self:IsLobbyActor()
    local world = slua_GameFrontendHUD:GetWorld()
    -- Use the module-level VehiclePlateLicenseUtil (pre-required at load time, not every call)
    local SkinSwitchEffectActorPath = VehiclePlateLicenseUtil and VehiclePlateLicenseUtil.GetSwitchEffectActorPath and VehiclePlateLicenseUtil.GetSwitchEffectActorPath()
    local BP_DissolveVehicleClass = import(SkinSwitchEffectActorPath)
    self.uSwitchEffectActor = world:SpawnActor(BP_DissolveVehicleClass, nil, nil, nil)
    if not slua.isValid(self.uSwitchEffectActor) then
        self.uSwitchEffectActor = nil
        return false
    end
    self.uSwitchEffectActor:K2_AttachToActor(vehicleActor, "None", 1, 1, 1, false)
    self.uSwitchEffectActor:K2_SetActorRelativeLocation(FVector(0, 0, 0), false, nil, false)
    self.uSwitchEffectActor:K2_SetActorRelativeRotation(FRotator(0, 0, 0), false, nil, false)
    self:ChangeFakeSwitchVehicleAvatar(self.uSwitchEffectActor.Mesh, self.lastEquipedAvatarId)
    self.uSwitchEffectActor:SetAnimInsAndAnimState(self.uOldVehicleMeshAnimClass, vehicleActor)
    self.uSwitchEffectActor:StartVehicleSwitchEffect(vehicleActor, self.curSwitchEffectId, self.lastEquipedAvatarId, currentAvatarID, bIsLobbyActor)
    self.uOldVehicleMeshAnimClass = nil
    return true
end

local O_ReceiveBeginPlay = VehicleAvatarComponent.__inner_impl.ReceiveBeginPlay
VehicleAvatarComponent.__inner_impl.ReceiveBeginPlay = function(self)
    O_ReceiveBeginPlay(self)
    if IsInMatchForVehicle() and self.ResetAnimationState then
        self:ResetAnimationState()
    end
end



-- ==================== 载具皮肤系统 ====================

local ENABLED = true
local DEBUG_NOTICE = false
local REAPPLY_INTERVAL = 5.0

-- ========== 动态载具皮肤加载 (Dynamic Loader) ==========
local SKIN_IDS = {}
local function LoadAllVehicleSkinsDynamically()
    local loadedCount = 0
    pcall(function()
        local ItemTable = CDataTable.GetTable("Item")
        if ItemTable then
            for id, cfg in pairs(ItemTable) do
                -- All vehicle skins in PUBG Mobile are in the 1900000 - 1999999 range
                if type(id) == "number" and id >= 1900000 and id <= 1999999 then
                    table.insert(SKIN_IDS, id)
                    loadedCount = loadedCount + 1
                end
            end
        end
    end)
    -- Fallback in case CDataTable iteration fails
    if loadedCount == 0 then
        SKIN_IDS = {
            1901047, 1903206, 1915026, 1961152, 1916006, 1908055, 1907072
        }
    end
end
LoadAllVehicleSkinsDynamically()

-- itemSubType لـ Coupe RB (من AvatarDataUtil)
local COUPE_SUBTYPE = 961

_G.TestVehicleSkin = _G.TestVehicleSkin or {}
local M = _G.TestVehicleSkin

M._enabled = ENABLED
M._skinIds = SKIN_IDS
M._hooks = M._hooks or {}
M._installed = M._installed or false
M._timerIndex = M._timerIndex or nil
M._lastApply = 0

if M._timerIndex then
  pcall(function() require("common.time_ticker").RemoveTimer(M._timerIndex) end)
  M._timerIndex = nil
end

local timeTicker = require("common.time_ticker")
local TableUtil = require("common.table_util")
local UAvatarUtils = import("AvatarUtils")
-- Pre-require modules that are used in hot paths so they are never required mid-frame.
local VehiclePlateLicenseUtil = nil
pcall(function()
    VehiclePlateLicenseUtil = require("GameLua.Activity.Commercialize.GamePlay.Vehicle.VehiclePlateLicenseUtil")
end)

local function logMsg(msg)
  pcall(function() print("[TestVehicleSkin] " .. tostring(msg)) end)
end

local function notify(msg)
  if DEBUG_NOTICE then
    pcall(function() if ShowNotice then ShowNotice(tostring(msg)) end end)
  end
  logMsg(msg)
end

-- ==================== NEW: Real Asset Downloader ====================
local function realDownloadAsset(id)
    pcall(function()
        local pufferManager = require('client.slua.logic.download.puffer.puffer_manager')
        local pufferConst   = require('client.slua.logic.download.puffer_const')
        if pufferManager and pufferConst then
            local currentState = pufferManager.GetState(pufferConst.ENUM_DownloadType.ODPAK, {id})
            if currentState ~= pufferConst.ENUM_DownloadState.Done then
                pufferManager.Download(pufferConst.ENUM_DownloadType.ODPAK, {id})
                logMsg("Triggered asset download for " .. tostring(id))
            end
        end
    end)
end
-- ===================================================================

local function getPC()
  if slua_GameFrontendHUD then
    local pc = slua_GameFrontendHUD:GetPlayerController()
    if slua.isValid(pc) then return pc end
  end
  local ok, gd = pcall(require, "GameLua.GameCore.Data.GameplayData")
  if ok and gd then
    local pc = gd.GetPlayerController()
    if slua.isValid(pc) then return pc end
  end
  return nil
end

local function uniqueIds(ids)
  local out, seen = {}, {}
  for _, id in ipairs(ids or {}) do
    local n = tonumber(id)
    if n and n > 0 and not seen[n] then
      seen[n] = true
      out[#out + 1] = n
    end
  end
  return out
end

-- Cache: computed once from M._skinIds, invalidated when the skin list changes.
-- Avoids rebuilding the deduped array and the CDataTable-based subtype map on every call.
M._cachedSkinIds   = nil   -- deduplicated flat array
M._cachedVst       = nil   -- groupByItemSubType result
M._cachedSkinEpoch = 0     -- bumped whenever M._skinIds is replaced

local function _invalidateSkinCache()
  M._cachedSkinEpoch = M._cachedSkinEpoch + 1
  M._cachedSkinIds   = nil
  M._cachedVst       = nil
end

local function getSkinIds()
  if M._cachedSkinIds then return M._cachedSkinIds end
  M._cachedSkinIds = uniqueIds(M._skinIds or SKIN_IDS)
  return M._cachedSkinIds
end

-- CDataTable lookups are expensive; memoize per skinId across the session.
local _subTypeCache = {}
local function groupByItemSubType(skinIds)
  local bySub = {}
  for _, skinId in ipairs(skinIds) do
    local subType = _subTypeCache[skinId]
    if not subType then
      subType = COUPE_SUBTYPE
      local ok, cfg = pcall(function()
        return CDataTable.GetTableData("Item", skinId)
      end)
      if ok and cfg and cfg.ItemSubType then
        subType = cfg.ItemSubType
      end
      _subTypeCache[skinId] = subType   -- memoize for all future calls
    end
    bySub[subType] = bySub[subType] or {}
    bySub[subType][#bySub[subType] + 1] = skinId
  end

  -- Roadster (9116) borrows skins from Coupe (961) and Mirado (915)
  bySub[9116] = bySub[9116] or {}
  if bySub[961] then
      for _, id in ipairs(bySub[961]) do table.insert(bySub[9116], id) end
  end
  if bySub[915] then
      for _, id in ipairs(bySub[915]) do table.insert(bySub[9116], id) end
  end

  return bySub
end

local function buildVstInBattle(skinIds)
  -- Return the cached result if the skin list has not changed.
  if M._cachedVst then return M._cachedVst end
  M._cachedVst = groupByItemSubType(skinIds)
  return M._cachedVst
end

local function buildInitialLists(vst_in_battle)
  local vehicleSkinList = {}
  local vehicleSkinData = {}
  for _, skinList in pairs(vst_in_battle) do
    local itemArray = {}
    for _, resid in ipairs(skinList) do
      if resid and resid > 0 then
        itemArray[#itemArray + 1] = { ItemTableID = resid, Count = 1 }
        vehicleSkinList[#vehicleSkinList + 1] = { ItemTableID = resid, Count = 1 }
      end
    end
    if #itemArray > 0 then
      vehicleSkinData[#vehicleSkinData + 1] = { Items = itemArray }
    end
  end
  return vehicleSkinList, vehicleSkinData
end

local function mergeVstIntoPlayerInfo(playerInfo, skinIds)
  if not playerInfo then return end
  playerInfo.vst_in_battle = playerInfo.vst_in_battle or {}
  local vst = buildVstInBattle(skinIds)
  for subType, list in pairs(vst) do
    playerInfo.vst_in_battle[subType] = list
  end
end

local function directInjectSkinList(pc, skinIds)
  if not slua.isValid(pc) or not pc.VehicleAvatarSkinList then return end
  for _, skinId in ipairs(skinIds) do
    local shapeType = nil
    pcall(function()
      shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
    end)
    if shapeType and shapeType >= 0 then
      pcall(function() pc.VehicleAvatarList:Add(shapeType, skinId) end)
      local entry = pc.VehicleAvatarSkinList:Get(shapeType)
      if entry and entry.SkinList then
        pcall(function() entry.SkinList:Add(skinId) end)
      end
    end
  end
end

function M.getCurrentVehicle()
  local found = nil
  pcall(function()
    local subs = SubsystemMgr:Get("VehicleControlUISubsystem")
    if subs and subs.GetVehicleUserComponent then
      local uuc = subs:GetVehicleUserComponent()
      if slua.isValid(uuc) and slua.isValid(uuc.Vehicle) then
        found = uuc.Vehicle
      end
    end
  end)
  if slua.isValid(found) then return found end
  local pc = getPC()
  if slua.isValid(pc) and pc.GetPlayerCharacterSafety then
    local char = pc:GetPlayerCharacterSafety()
    if slua.isValid(char) then
      if char.GetCurrentVehicle then
        local v = char:GetCurrentVehicle()
        if slua.isValid(v) then return v end
      end
      if char.CurrentVehicle and slua.isValid(char.CurrentVehicle) then
        return char.CurrentVehicle
      end
    end
  end
  return nil
end

-- ==================== NEW: Save Selected Cars to JSON ====================
local CAR_JSON_PATH = "/storage/emulated/0/Android/data/com.pubg.imobile/files/selected_cars.json"

local function readJSON(path)
    local data = {}
    local f = io.open(path, "r")
    if f then
        local content = f:read("*a")
        f:close()
        for k, v in string.gmatch(content or "", '"(%d+)":%s*(%d+)') do
            data[k] = tonumber(v)
        end
    end
    return data
end

-- PRELOAD the JSON into RAM at startup so we NEVER hit the disk during gameplay
M._CachedCarJSON = readJSON(CAR_JSON_PATH)

-- Dirty flag: set when the in-RAM cache changes; flushed on the next timer tick
-- so disk I/O NEVER happens on the game/skin-apply hot path.
M._jsonDirty = false

local function flushCarJSONIfDirty()
    if not M._jsonDirty then return end
    M._jsonDirty = false
    pcall(function()
        local data = M._CachedCarJSON or {}
        local out = io.open(CAR_JSON_PATH, "w")
        if out then
            local parts = {}
            for k, v in pairs(data) do
                parts[#parts + 1] = '  "' .. tostring(k) .. '": ' .. tostring(v)
            end
            out:write("{\n" .. table.concat(parts, ",\n") .. "\n}")
            out:close()
        end
    end)
end

local function saveCarSelectionToJSON(skinId)
    -- Only update the in-RAM cache here; never touch the disk during gameplay.
    pcall(function()
        local basePrefix = string.sub(tostring(skinId), 1, 4)
        local baseTypeID = tostring(basePrefix .. "001")
        local data = M._CachedCarJSON or {}
        if data[baseTypeID] ~= tonumber(skinId) then   -- skip if already current
            data[baseTypeID] = tonumber(skinId)
            M._CachedCarJSON = data
            M._jsonDirty = true   -- schedule disk flush for next idle tick
        end
    end)
end
-- ========================================================================

function M.serverChangeVehicleAvatar(skinId, pc)
  if not M._enabled then return false end
  skinId = tonumber(skinId)
  if not skinId or skinId <= 0 then return false end

  pc = pc or getPC()
  if not slua.isValid(pc) then
    logMsg("serverChangeVehicleAvatar: no PC")
    return false
  end

  M.applyToPC(pc)

  pcall(function()
    pc.ShowVehicleSkin = skinId
    local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
    if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
      pc.VehicleAvatarList:Add(shapeType, skinId)
    end
    directInjectSkinList(pc, { skinId })
  end)

  local ok = false
  pcall(function()
    if pc.ServerChangeVehicleAvatar then
      pc:ServerChangeVehicleAvatar(skinId)
      ok = true
      if ShowNotice then ShowNotice("Vehicle skin apply successful: " .. tostring(skinId)) end
    end
  end)

  pcall(function()
    if pc.PlayerState and slua.isValid(pc.PlayerState) then
      pc.PlayerState.nVst_skin = skinId
    end
  end)

  pcall(function() pc:ForceNetUpdate() end)
  return ok
end

local function applyClientSkin(skinId, vehicle, pc)
  if not M._enabled then return false end
  skinId = tonumber(skinId)
  if not skinId or skinId <= 0 then return false end

  pc = pc or getPC()
  vehicle = vehicle or M.getCurrentVehicle()
  if not slua.isValid(vehicle) then
    logMsg("applyClientSkin: no vehicle")
    return false
  end

  pcall(function()
    if slua.isValid(pc) then
      pc.ShowVehicleSkin = skinId
      local shapeType = UAvatarUtils.GetVehicleShapeBySkinID(skinId)
      if shapeType and shapeType >= 0 and pc.VehicleAvatarList then
        pc.VehicleAvatarList:Add(shapeType, skinId)
      end
    end
  end)

  local applied = false
  local av = nil
  pcall(function()
    if vehicle.GetAvatarComponent then av = vehicle:GetAvatarComponent() end
    if not slua.isValid(av) then av = vehicle.VehicleAvatarComponent_BP end
  end)

  if slua.isValid(av) then
    pcall(function() if av.bIsLobbyAvatar ~= nil then av.bIsLobbyAvatar = false end end)
    pcall(function() if av.CanChangeAvatar ~= nil then av.CanChangeAvatar = true end end)
    pcall(function()
      if slua.isValid(pc) and av.SetVehicleNetAvatarData then
        av:SetVehicleNetAvatarData(pc)
      end
    end)
    pcall(function()
      if av.ChangeItemAvatar then
        av:ChangeItemAvatar(skinId, false)
        applied = true
      elseif av.PreChangeVehicleAvatar then
        av:PreChangeVehicleAvatar(skinId)
        applied = true
      end
    end)
    pcall(function()
      if av.PostChangeItemAvatar then av:PostChangeItemAvatar(false) end
    end)
  end

  pcall(function()
    local battleCls = import("VehicleAvatarComponentBattleBase")
    local battleAv = vehicle:GetComponentByClass(battleCls)
    if slua.isValid(battleAv) then
      if battleAv.ChangeVehicleAvatar then
        battleAv:ChangeVehicleAvatar(skinId, false)
        applied = true
      end
      pcall(function()
        -- Use module-level VehiclePlateLicenseUtil (pre-required at load time)
        if VehiclePlateLicenseUtil then
          local uid = pc and pc.PlayerUID or 0
          local bTire = VehiclePlateLicenseUtil.NeedOpenHighTire(tonumber(uid), skinId)
          if battleAv.PreChangeHighTireLight then
            battleAv:PreChangeHighTireLight(skinId, bTire)
          end
        end
      end)
    end
  end)

  pcall(function()
    if vehicle.ChangeVehicleAvatar and slua.isValid(pc) then
      vehicle:ChangeVehicleAvatar(pc)
      applied = true
    end
  end)

  pcall(function() vehicle:ForceNetUpdate() end)
  logMsg("applyClientSkin " .. tostring(skinId) .. " applied=" .. tostring(applied))
  return applied
end

function M.applySkin(skinId)
  if not M._enabled then return false end
  skinId = tonumber(skinId)
  if not skinId or skinId <= 0 then return false end

  -- FIXED: Explicitly download the asset first before trying to apply it
  realDownloadAsset(skinId)

  local pc = getPC()
  local vehicle = M.getCurrentVehicle()
  local serverOk = M.serverChangeVehicleAvatar(skinId, pc)
  local clientOk = applyClientSkin(skinId, vehicle, pc)
  logMsg("applySkin " .. skinId .. " server=" .. tostring(serverOk) .. " client=" .. tostring(clientOk))
  
  -- FIXED: Tell OPTISKI (2.lua) to stop reverting our skin!
  pcall(function()
    if _G._ResolvedVehicleSkins then
      local basePrefix = string.sub(tostring(skinId), 1, 4)
      local baseTypeID = tonumber(basePrefix .. "001")
      _G._ResolvedVehicleSkins[baseTypeID] = skinId
      _G.CurrentEquipVehicleID = skinId
    end
  end)

  -- NEW: Save selection to JSON on Android storage
  saveCarSelectionToJSON(skinId)

  return serverOk or clientOk
end

function M.forceApplySkin(skinId, vehicle)
  return M.applySkin(skinId)
end

function M.applyToPC(pc)
  if not M._enabled then return false end
  pc = pc or getPC()
  if not slua.isValid(pc) then return false end

  local skinIds = getSkinIds()
  if #skinIds == 0 then
    notify("No skin IDs configured")
    return false
  end

  local vst = buildVstInBattle(skinIds)
  local avatarList, avatarSkinList = buildInitialLists(vst)

  pc.bEnableFuzzyAvatarOnClient = false
  pc.ShowVehicleSkin = skinIds[1]

  if #avatarList > 0 then
    pc.InitialVehicleAvatarList = avatarList
    pcall(function() pc:InitVehicleAvatarList() end)
  end

  if #avatarSkinList > 0 then
    pc.InitialVehicleAvatarSkinList = avatarSkinList
    pcall(function() pc:InitVehicleAvatarSkinList() end)
  end

  directInjectSkinList(pc, skinIds)

  logMsg("applied " .. #skinIds .. " skins, first=" .. tostring(skinIds[1]))
  return true
end

function M.applyDataMgr()
  if not M._enabled then return end
  pcall(function()
    if not DataMgr then return end
    local vst = buildVstInBattle(getSkinIds())
    DataMgr.VehicleSlotList = DataMgr.VehicleSlotList or {}
    for subType, list in pairs(vst) do
      DataMgr.VehicleSlotList[subType] = list
    end
  end)
end

function M.apply()
  M.applyDataMgr()
  if M.applyToPC() then
    notify("Vehicle skins injected: " .. #getSkinIds())
    return true
  end
  notify("Waiting for PlayerController...")
  return false
end

function M.setSkins(ids)
  if type(ids) ~= "table" then return end
  M._skinIds = uniqueIds(ids)
  _invalidateSkinCache()
  if M._enabled then M.apply() end
  notify("Skin list: " .. #M._skinIds)
end

function M.addSkin(id)
  local n = tonumber(id)
  if not n or n <= 0 then return end
  M._skinIds = M._skinIds or {}
  M._skinIds[#M._skinIds + 1] = n
  M._skinIds = uniqueIds(M._skinIds)
  _invalidateSkinCache()
  if M._enabled then M.apply() end
end

function M.getSkins()
  return getSkinIds()
end

function M.setEnabled(on)
  M._enabled = on == true
  if M._enabled then
    M.installHooks()
    M.apply()
  else
    notify("TestVehicleSkin OFF")
  end
end

function M.toggle()
  M.setEnabled(not M._enabled)
end

local function hookImpl(classMod, name, key, wrapper)
  if not classMod or not classMod.__inner_impl then return false end
  local impl = classMod.__inner_impl
  if not impl[name] or M._hooks[key] then return false end
  local orig = impl[name]
  M._hooks[key] = orig
  impl[name] = wrapper(orig)
  return true
end

function M.installHooks()
  if M._installed then return end

  pcall(function()
    local classMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinItem")
    hookImpl(classMod, "OnClickSkinButton", "clickSkin", function(orig)
      return function(self)
        if M._enabled and self.resID and self.resID > 0 then
          -- FIXED: Actually download the asset when user selects it
          realDownloadAsset(self.resID)
          
          if M.applySkin(self.resID) then
            notify("Skin OK: " .. tostring(self.resID))
            pcall(function()
              if EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL and EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK then
                EventSystem:postEvent(EVENTYPE_INGAME_VEHICLE_CONTROL_PANEL, EVENTID_CHANGE_VEHICLESKIN_BUTTON_CLICK)
              end
            end)
          else
            notify("Skin apply failed")
          end
          return orig(self) -- FIXED: Always pass through to original so UI updates fully
        end
        return orig(self)
      end
    end)
    hookImpl(classMod, "OnRefresh", "refreshSkin", function(orig)
      return function(self, resID, selectIndex)
        orig(self, resID, selectIndex)
        if M._enabled and self.resID and self.resID > 0 then
          local ok, PufferConst = pcall(require, "client.slua.logic.download.puffer_const")
          if ok and PufferConst then
            self.dowloadState = PufferConst.ENUM_DownloadState.Done
          end
          pcall(function()
            self.UIRoot.Image_Download:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
            self:SetWidgetVisible(self.UIRoot.Image_Mask, false)
          end)
        end
      end
    end)
  end)

  pcall(function()
    local PufferOdpakManager = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.puffer_odpak_manager)
    if PufferOdpakManager and PufferOdpakManager.GetStateByItemID and not M._hooks.pufferState then
      local orig = PufferOdpakManager.GetStateByItemID
      M._hooks.pufferState = orig
      PufferOdpakManager.GetStateByItemID = function(mgr, itemId)
        if M._enabled and TableUtil.Find(getSkinIds(), tonumber(itemId)) >= 0 then
          local ok, PufferConst = pcall(require, "client.slua.logic.download.puffer_const")
          if ok then return PufferConst.ENUM_DownloadState.Done end
        end
        return orig(mgr, itemId)
      end
    end
  end)

  pcall(function()
    local mod = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
    if mod._FillVehicleSkinList and not M._hooks.fillVehicle then
      local orig = mod._FillVehicleSkinList
      M._hooks.fillVehicle = orig
      mod._FillVehicleSkinList = function(self, playerInfo, uPlayerController)
        if M._enabled and playerInfo then
          mergeVstIntoPlayerInfo(playerInfo, getSkinIds())
        end
        return orig(self, playerInfo, uPlayerController)
      end
    end
  end)

  pcall(function()
    local classMod = require("GameLua.Mod.BaseMod.Client.InGameUI.VehicleControl.VehicleSkinAndMusicPanel")
    hookImpl(classMod, "InitSkinList", "initSkinList", function(orig)
      return function(self)
        if M._enabled then
          M.applyToPC(getPC())
        end
        return orig(self)
      end
    end)
  end)

  pcall(function()
    -- Use the module-level VehiclePlateLicenseUtil pre-required at load time
    local utilMod = VehiclePlateLicenseUtil
    if utilMod and utilMod.CheckHasUnLockFeature and not M._hooks.vplUnlock then
      local orig = utilMod.CheckHasUnLockFeature
      M._hooks.vplUnlock = orig
      utilMod.CheckHasUnLockFeature = function(ft, uid, itemId)
        if M._enabled and TableUtil.Find(getSkinIds(), tonumber(itemId)) >= 0 then
          return true
        end
        return orig(ft, uid, itemId)
      end
    end
  end)

  M._installed = true
  logMsg("hooks installed")
end

function M.tick()
  if not M._enabled then return end
  local now = os.clock()
  if now - M._lastApply < REAPPLY_INTERVAL then return end
  M._lastApply = now
  M.applyToPC()

  -- Flush any pending JSON write now that we're in an idle timer callback,
  -- not in the middle of a skin-apply hot path.
  flushCarJSONIfDirty()

  pcall(function()
      local vehicle = M.getCurrentVehicle()
      if slua.isValid(vehicle) then
          -- Only do per-vehicle work when we first enter a new vehicle.
          if M._LastVehicleEntity == vehicle then return end

          -- Get the base ID of the current vehicle
          local baseTypeID = 0
          if vehicle.AvatarDefaultCfg then
              baseTypeID = vehicle.AvatarDefaultCfg.TypeSpecificID
          end
          local avatarComp = vehicle.VehicleAvatarComponent_BP or (vehicle.GetAvatarComponent and vehicle:GetAvatarComponent())
          if baseTypeID == 0 and slua.isValid(avatarComp) and avatarComp.VehicleNetAvatarData and avatarComp.VehicleNetAvatarData.ItemDefineID then
              baseTypeID = avatarComp.VehicleNetAvatarData.ItemDefineID.TypeSpecificID
          end

          if baseTypeID and baseTypeID > 0 then
              -- Compute the normalized key once per vehicle entry (not every tick).
              local normalizedBaseID = tostring(string.sub(tostring(baseTypeID), 1, 4)) .. "001"
              local targetSkinID = (M._CachedCarJSON or {})[normalizedBaseID]
              if targetSkinID and targetSkinID > 0 then
                  local pc = getPC()
                  applyClientSkin(targetSkinID, vehicle, pc)
              end
          end

          M._LastVehicleEntity = vehicle
      else
          -- No longer in a vehicle — reset so next entry is detected correctly.
          M._LastVehicleEntity = nil
      end
  end)
end

M.installHooks()
M._timerIndex = timeTicker.AddTimerLoop(2.0, function()
  M.tick()
end, -1, 2.0)

local function tryApply()
    if M.apply() then
        if ShowNotice then ShowNotice("TestVehicleSkin ON | ride car → open car button") end
        return true
    end
    return false
end

timeTicker.AddTimer(1.5, function()
    if not tryApply() then
        timeTicker.AddTimer(2.5, tryApply)
    end
end)
