local LogoInject = {}
LogoInject._installed = false
LogoInject._frameTimer = nil
LogoInject._hookedLogoRoots = setmetatable({}, {__mode = "k"})
LogoInject._savedUpdateUI = setmetatable({}, {__mode = "k"})
LogoInject._appliedUrl = setmetatable({}, {__mode = "k"})
LogoInject._initializedRoots = setmetatable({}, {__mode = "k"})
LogoInject._downloading = setmetatable({}, {__mode = "k"})

LogoInject.CONFIG = {
  enabled = true,
  imageUrl = "https://i.postimg.cc/ZKw0RwV7/hplogo.png",
  onlyInGame = true,
  includeSocialIsland = true,
  blockGameUpdateUI = true,
  debugLog = true
}

local IMAGE_NAMES = {"ImageLogo", "Image_Logo", "Image_logo"}
local VISIBLE = UEnums.ESlateVisibility.SelfHitTestInvisible
local HIDDEN = UEnums.ESlateVisibility.Collapsed

function LogoInject.Log(msg)
  if LogoInject.CONFIG.debugLog then
    print(bWriteLog and "[LogoInject] " .. tostring(msg))
  end
end

function LogoInject.IsActive()
  local cfg = LogoInject.CONFIG
  return cfg.enabled and cfg.imageUrl ~= nil and cfg.imageUrl ~= ""
end

function LogoInject.IsInGameContext()
  if not LogoInject.CONFIG.onlyInGame then
    return true
  end
  if GameStatus then
    if GameStatus.IsInFightingStatus and GameStatus.IsInFightingStatus() then
      return true
    end
    if GameStatus.IsInFightingNotMainCity and GameStatus.IsInFightingNotMainCity() then
      return true
    end
    if GameStatus.GetGameStatus and GameStatus.GetGameStatus() == GameStatus.Fighting then
      return true
    end
  end
  if UIManager and UIManager.UI_Config_InGame then
    local cfg = UIManager.UI_Config_InGame.Common_Logo_UIBP
    if cfg and UIManager.GetUI(cfg) then
      return true
    end
  end
  local ok, InGameUITools = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
  if ok and InGameUITools then
    local baseUI = InGameUITools.GetMainControlBaseUI()
    if baseUI and slua.isValid(baseUI) then
      return true
    end
  end
  return false
end

function LogoInject.GetSwitcher(logoRoot)
  if not logoRoot then
    return nil
  end
  return logoRoot.WidgetSwitcher_0 or logoRoot.WidgetSwitcher_Logo
end

function LogoInject.GetSwitcherChild(switcher, index)
  if not switcher then
    return nil
  end
  if switcher.GetWidgetAtIndex then
    return switcher:GetWidgetAtIndex(index)
  end
  if switcher.GetWidgetAt then
    return switcher:GetWidgetAt(index)
  end
  if switcher.GetChildAt then
    return switcher:GetChildAt(index)
  end
  return nil
end

function LogoInject.FindImageWidgets(logoRoot)
  local list = {}
  local seen = {}
  local function addWidget(widget)
    if widget and slua.isValid(widget) and not seen[widget] then
      seen[widget] = true
      table.insert(list, widget)
    end
  end
  local function scanNode(node)
    if not node or not slua.isValid(node) then
      return
    end
    for _, name in ipairs(IMAGE_NAMES) do
      addWidget(node[name])
    end
  end
  scanNode(logoRoot)
  local switcher = LogoInject.GetSwitcher(logoRoot)
  if switcher then
    local count = switcher.GetNumWidgets and switcher:GetNumWidgets() or 3
    for i = 0, count - 1 do
      scanNode(LogoInject.GetSwitcherChild(switcher, i))
    end
  end
  return list
end

function LogoInject.PrepareLogoRootOnce(logoRoot, primaryWidget)
  if LogoInject._initializedRoots[logoRoot] then
    return
  end
  local switcher = LogoInject.GetSwitcher(logoRoot)
  if switcher then
    switcher:SetActiveWidgetIndex(0)
    local count = switcher.GetNumWidgets and switcher:GetNumWidgets() or 3
    for i = 0, count - 1 do
      local child = LogoInject.GetSwitcherChild(switcher, i)
      if child and slua.isValid(child) then
        if i == 0 then
          child:SetWidgetVisibility(VISIBLE)
        else
          child:SetWidgetVisibility(HIDDEN)
        end
      end
    end
  end
  local images = LogoInject.FindImageWidgets(logoRoot)
  for _, img in ipairs(images) do
    if img ~= primaryWidget then
      img:SetWidgetVisibility(HIDDEN)
    end
  end
  logoRoot:SetWidgetVisibility(VISIBLE)
  LogoInject._initializedRoots[logoRoot] = true
  LogoInject.Log("prepared logo root once")
end

function LogoInject.DownloadAndApply(widget, url)
  if not widget or not slua.isValid(widget) or not url or url == "" then
    return false
  end
  if LogoInject._appliedUrl[widget] == url then
    widget:SetWidgetVisibility(VISIBLE)
    return true
  end
  if LogoInject._downloading[widget] == url then
    return true
  end
  local ui_util = require("client.slua_ui_framework.util")
  if ui_util.IsOnlineImageUrl(url) then
    local image_download_mgr = ModuleManager.GetModule(ModuleManager.CommonModuleConfig.image_download_mgr)
    if image_download_mgr then
      local cached = image_download_mgr:GetLocalImageCache(url)
      if cached and slua.isValid(cached) then
        widget:SetBrushFromTexture(cached, false)
        widget:SetWidgetVisibility(VISIBLE)
        LogoInject._appliedUrl[widget] = url
        LogoInject.Log("used cached image")
        return true
      end
    end
    LogoInject._downloading[widget] = url
    widget:SetWidgetVisibility(VISIBLE)
    local function onSuccess(texture)
      LogoInject._downloading[widget] = nil
      if not slua.isValid(widget) or not texture or not slua.isValid(texture) then
        LogoInject.Log("download success but invalid texture/widget")
        return
      end
      widget:SetBrushFromTexture(texture, false)
      widget:SetWidgetVisibility(VISIBLE)
      LogoInject._appliedUrl[widget] = url
      LogoInject.Log("download OK — custom logo visible")
    end
    local function onFail()
      LogoInject._downloading[widget] = nil
      LogoInject.Log("download FAILED — try imgur/direct png, not Discord")
    end
    if image_download_mgr and image_download_mgr.DownloadImageByHttpWrapper then
      image_download_mgr:DownloadImageByHttpWrapper(url, onSuccess, onFail)
    else
      ui_util.NewLoadImage({
        widget = widget,
        sImgUrl = url,
        bIsHideInBeginning = false,
        successCallFunc = function()
          LogoInject._downloading[widget] = nil
          LogoInject._appliedUrl[widget] = url
          LogoInject.Log("NewLoadImage OK")
        end
      })
    end
    return true
  end
  ui_util.SetTexture(widget, url, {sync = false, defaultIcon = ""})
  widget:SetWidgetVisibility(VISIBLE)
  LogoInject._appliedUrl[widget] = url
  LogoInject.Log("applied local path")
  return true
end

function LogoInject.ApplyCustomLogo(logoRoot)
  if not logoRoot or not slua.isValid(logoRoot) or not LogoInject.IsActive() then
    return false
  end
  local images = LogoInject.FindImageWidgets(logoRoot)
  if #images == 0 then
    LogoInject.Log("no ImageLogo widget found on this root")
    return false
  end
  local primary = images[1]
  LogoInject.PrepareLogoRootOnce(logoRoot, primary)
  return LogoInject.DownloadAndApply(primary, LogoInject.CONFIG.imageUrl)
end

function LogoInject.HijackUpdateUI(logoRoot)
  if not logoRoot or not logoRoot.UpdateUI or LogoInject._hookedLogoRoots[logoRoot] then
    return
  end
  LogoInject._savedUpdateUI[logoRoot] = logoRoot.UpdateUI
  logoRoot.UpdateUI = function(self, ...)
    if LogoInject.IsActive() and LogoInject.CONFIG.blockGameUpdateUI then
      LogoInject.ApplyCustomLogo(self)
      return
    end
    local orig = LogoInject._savedUpdateUI[self]
    if orig then
      return orig(self, ...)
    end
  end
  LogoInject._hookedLogoRoots[logoRoot] = true
end

function LogoInject.RestoreLogoRoot(logoRoot)
  if not logoRoot or not slua.isValid(logoRoot) then
    return
  end
  local saved = LogoInject._savedUpdateUI[logoRoot]
  if saved then
    logoRoot.UpdateUI = saved
    LogoInject._savedUpdateUI[logoRoot] = nil
    LogoInject._hookedLogoRoots[logoRoot] = nil
  end
  LogoInject._initializedRoots[logoRoot] = nil
  pcall(function()
    logoRoot:UpdateUI(false)
  end)
end

function LogoInject.CollectLogoRoots(outList, seen)
  outList = outList or {}
  seen = seen or {}
  local function add(root)
    if root and slua.isValid(root) and not seen[root] then
      seen[root] = true
      table.insert(outList, root)
    end
  end
  if not UIManager or not UIManager.UI_Config_InGame then
    return outList
  end
  local cfg = UIManager.UI_Config_InGame.Common_Logo_UIBP
  if cfg then
    local logoUI = UIManager.GetUI(cfg)
    if logoUI and logoUI.UIRoot then
      add(logoUI.UIRoot)
    end
  end
  local ok, InGameUITools = pcall(require, "GameLua.Mod.BaseMod.Common.UI.InGameUITools")
  if ok and InGameUITools then
    local baseUI = InGameUITools.GetMainControlBaseUI()
    if baseUI and slua.isValid(baseUI) and baseUI.CanvasPanel_42 then
      add(baseUI.CanvasPanel_42.Common_Logo_UIBP)
    end
  end
  if LogoInject.CONFIG.includeSocialIsland then
    local mainCfg = UIManager.UI_Config_InGame.Social_Island_Main_UIBP
    if mainCfg then
      local main = UIManager.GetUI(mainCfg)
      if main and main.Social_Island_Main_LT and main.Social_Island_Main_LT.UIRoot then
        add(main.Social_Island_Main_LT.UIRoot.Common_Logo_UIBP)
      end
    end
    local ltCfg = UIManager.UI_Config_InGame.Social_Island_Main_LT
    if ltCfg then
      local lt = UIManager.GetUI(ltCfg)
      if lt and lt.UIRoot then
        add(lt.UIRoot.Common_Logo_UIBP)
      end
    end
  end
  return outList
end

function LogoInject.RestoreAll()
  LogoInject._appliedUrl = setmetatable({}, {__mode = "k"})
  LogoInject._downloading = setmetatable({}, {__mode = "k"})
  LogoInject._initializedRoots = setmetatable({}, {__mode = "k"})
  for _, logoRoot in ipairs(LogoInject.CollectLogoRoots({}, {})) do
    LogoInject.RestoreLogoRoot(logoRoot)
  end
end

function LogoInject.StopFrameLock()
  if LogoInject._frameTimer and type(LogoInject._frameTimer) == "number" then
    local time_ticker = require("common.time_ticker")
    if time_ticker.RemoveTimer then
      time_ticker.RemoveTimer(LogoInject._frameTimer)
    end
  end
  LogoInject._frameTimer = nil
end

function LogoInject.ApplyAll()
  if not LogoInject.IsActive() or not LogoInject.IsInGameContext() then
    return
  end
  for _, logoRoot in ipairs(LogoInject.CollectLogoRoots({}, {})) do
    LogoInject.HijackUpdateUI(logoRoot)
    local images = LogoInject.FindImageWidgets(logoRoot)
    local primary = images[1]
    if primary and LogoInject._appliedUrl[primary] == LogoInject.CONFIG.imageUrl then
      primary:SetWidgetVisibility(VISIBLE)
    else
      LogoInject.ApplyCustomLogo(logoRoot)
    end
  end
end

function LogoInject.StartFrameLock()
  if LogoInject._frameTimer or not LogoInject.IsActive() then
    return
  end
  local time_ticker = require("common.time_ticker")
  LogoInject._frameTimer = time_ticker.AddTimerLoop(0.5, function()
    if not LogoInject.IsActive() then
      LogoInject.StopFrameLock()
      LogoInject.RestoreAll()
      return
    end
    LogoInject.ApplyAll()
  end, TIMER_INFINITE, 0.5)
  LogoInject.Log("lock timer 0.5s")
end

function LogoInject.Reinstall()
  LogoInject.StopFrameLock()
  LogoInject._appliedUrl = setmetatable({}, {__mode = "k"})
  LogoInject._downloading = setmetatable({}, {__mode = "k"})
  LogoInject._initializedRoots = setmetatable({}, {__mode = "k"})
  if LogoInject.IsActive() then
    LogoInject.ApplyAll()
    LogoInject.StartFrameLock()
    LogoInject.Log("active url=" .. tostring(LogoInject.CONFIG.imageUrl))
  else
    LogoInject.RestoreAll()
  end
  LogoInject._installed = true
end

function LogoInject.Install()
  LogoInject.Reinstall()
  return LogoInject
end

function LogoInject.Uninstall()
  LogoInject.CONFIG.enabled = false
  LogoInject.StopFrameLock()
  LogoInject.RestoreAll()
  LogoInject._installed = false
  return LogoInject
end

function LogoInject.SetImageUrl(url)
  LogoInject.CONFIG.enabled = true
  LogoInject.CONFIG.imageUrl = url or ""
  LogoInject.Reinstall()
end

function LogoInject.Clear()
  LogoInject.CONFIG.imageUrl = ""
  LogoInject.CONFIG.enabled = true
  LogoInject.Reinstall()
end

_G.LogoInject = LogoInject
LogoInject.Install()


return LogoInject