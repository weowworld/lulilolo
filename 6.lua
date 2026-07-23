local CONFIG = {
    ENABLED = 1,
    SCREEN_PERCENT = 100,
}

-- ================================================================
-- LOG SYSTEM
-- ================================================================
local LOG_PATH = "/storage/emulated/0/Android/data/com.pubg.imobile/files/WeowLogs.txt"
local logData = {
    file1_loaded = false,
    file2_loaded = false,
    features = {},
    failed = {},
    timestamp = os.date("%Y-%m-%d %H:%M:%S")
}

local function WriteLog()
    pcall(function()
        local f = io.open(LOG_PATH, "w")
        if f then
            f:write("==================== WEOV LOG ====================\n")
            f:write("Timestamp: " .. logData.timestamp .. "\n\n")
            f:write("[FILE STATUS]\n")
            f:write("1.lua: " .. (logData.file1_loaded and "✅ LOADED" or "❌ FAILED") .. "\n")
            f:write("2.lua: " .. (logData.file2_loaded and "✅ LOADED" or "❌ FAILED") .. "\n\n")
            
            f:write("[FEATURES ACTIVATED]\n")
            if #logData.features == 0 then
                f:write("  None\n")
            else
                for i, feat in ipairs(logData.features) do
                    f:write("  ✅ " .. feat .. "\n")
                end
            end
            
            f:write("\n[FAILED FEATURES]\n")
            if #logData.failed == 0 then
                f:write("  None\n")
            else
                for i, fail in ipairs(logData.failed) do
                    f:write("  ❌ " .. fail .. "\n")
                end
            end
            
            f:write("\n==================== END LOG ====================\n")
            f:close()
        end
    end)
end

local function AddFeature(name)
    table.insert(logData.features, name)
    WriteLog()
end

local function AddFailed(name, reason)
    table.insert(logData.failed, name .. " - " .. (reason or "Unknown reason"))
    WriteLog()
end

-- ================================================================
-- Helper Functions
-- ================================================================
local function nop() end
local function retTrue() return true end
local function retFalse() return false end
local function retZero() return 0 end
local function retEmpty() return {} end
local function retEmptyStr() return "" end

local function SafeRequire(path)
    local ok, mod = pcall(require, path)
    if ok and mod then return mod end
    return nil
end

-- ================================================================
-- 1. ANTI-REPORT SYSTEM
-- ================================================================
local function InitAntiReport()
    local success = true
    pcall(function()
        local paths = {
            "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem",
            "Client.Security.ClientReportPlayerSubsystem"
        }
        for _, path in ipairs(paths) do
            local mod = SafeRequire(path)
            if mod then
                mod.OnInit = nop
                mod._OnPlayerKilledOtherPlayer = nop
                mod._RecordFatalDamager = nop
                mod._OnDeathReplayDataWhenFatalDamaged = nop
                mod._RecordMurdererFromDeathReplayData = nop
                mod._RecordTeammatePlayerInfo = nop
                mod._OnBattleResult = nop
                mod._OnShowQuickReportMutualExclusiveUI = nop
                mod.GetFatalDamagerMap = retEmpty
                mod.GetCachedTeammateName2InfoMap = retEmpty
                mod.GetTeammateName2InfoMapDuringBattle = retEmpty
                mod.GetCurrentNotInTeamHistoricalTeammateMap = retEmpty
                mod.GetInTeamIndexFromHistoricalTeammateInfo = function() return -1 end
                mod.bEnableReporting = false
            end
        end
    end)
    if not success then AddFailed("Anti-Report System", "Failed to patch") else AddFeature("Anti-Report System") end

    pcall(function()
        local dsPaths = {
            "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem",
            "GameLua.Mod.BaseMod.Client.Security.DSReportPlayerSubsystem"
        }
        for _, path in ipairs(dsPaths) do
            local mod = SafeRequire(path)
            if mod then
                mod.OnInit = nop
                mod._OnNearDeathOrRescued = nop
                mod._OnCharacterDied = nop
                mod._OnTeammateDamage = nop
                mod._OnPlayerSettlementStart = nop
                mod._AddKnockDownerToBattleResult = nop
                mod._AddKillerToBattleResult = nop
                mod._AddTeammateMurderToBattleResult = nop
                mod._AddFatalDamagerMapToBattleResult = nop
                mod._AddMLKillerUIDToBattleResult = nop
                mod._SaveHistoricalTeammateInfo = nop
                mod._RecordFatalDamager = nop
                mod._RecordTeammateMurderer = nop
                mod.bEnableDSReporting = false
            end
        end
    end)

    pcall(function()
        local mod = SafeRequire("GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils")
        if mod then
            mod.RecordFatalDamager = nop
            mod.IsUsingHistoricalTeammateInfo = retFalse
            mod.IsCharacterDeliverAI = retFalse
        end
    end)

    pcall(function()
        local mod = SafeRequire("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
        if mod then
            mod.ExtractPlayerBasicInfo = retEmpty
            mod.LogIf = retFalse
            mod.IsFunctionCheckPass = retTrue
            mod.IsSecurityCheckPass = retTrue
            mod.DetectAnomaly = retFalse
            mod.IsCheatDetected = retFalse
        end
    end)

    pcall(function()
        local mod = SafeRequire("GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate")
        if mod then
            mod.OnShowMutualExclusiveUI = nop
            mod.OnHideMutualExclusiveUI = nop
        end
    end)
end

-- ================================================================
-- 2. ANTI-CHEAT HOOKS (HiggsBoson, MD5, SHA, etc.)
-- ================================================================
local function InitAntiCheatHooks()
    pcall(function()
        local Higgs = SafeRequire("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            Higgs.StaticShowSecurityAlertInDev = nop
            Higgs.ControlMHActive = nop
            Higgs.MHActiveLogic = nop
            Higgs.TriggerAvatarCheck = nop
            Higgs.ReportItemID = nop
            Higgs.GetNetAvatarItemIDs = retEmpty
            Higgs.GetCurWeaponSkinID = retZero
            Higgs.SendAntiDataFlow = retTrue
            Higgs.SendHitFireBtnFlow = retTrue
            Higgs.SpeedHackDetection = retFalse
            Higgs.TeleportDetection = retFalse
            Higgs.WallhackDetection = retFalse
            Higgs.AimbotDetection = retFalse
            Higgs.MagicBulletDetection = retFalse
            Higgs.bEnableCheck = false
            Higgs.bMHActive = false
            Higgs.bCallPreReplication = false
            if Higgs.BlackList then
                for k in pairs(Higgs.BlackList) do Higgs.BlackList[k] = nil end
            end
            AddFeature("HiggsBoson Disabled")
        else
            AddFailed("HiggsBoson", "Module not found")
        end
    end)

    pcall(function()
        _G.BlackList = {}
        _G.GlobalPlayerCoronaData = _G.GlobalPlayerCoronaData or {}
        _G.GlobalPlayerCheatTimes = _G.GlobalPlayerCheatTimes or {}
        local mt = getmetatable(_G.GlobalPlayerCoronaData) or {}
        mt.__newindex = function(t, k, v) end
        setmetatable(_G.GlobalPlayerCoronaData, mt)
        AddFeature("BlackList/Corona Cleaned")
    end)

    pcall(function()
        local STExtraBPFunc = import("STExtraBlueprintFunctionLibrary")
        if STExtraBPFunc then
            STExtraBPFunc.IsDevelopment = retFalse
            AddFeature("STExtraBPFunc Patched")
        end
    end)
end

-- ================================================================
-- 3. MD5 / SHA HASH SPOOF
-- ================================================================
local function InitHashSpoof()
    pcall(function()
        local md5 = SafeRequire("GameLua.Mod.BaseMod.Common.Security.MD5")
        if not md5 then md5 = SafeRequire("md5") end
        if md5 then
            md5.sumhexa = function(data) return "d41d8cd98f00b204e9800998ecf8427e" end
            md5.sum = function(data) return "d41d8cd98f00b204e9800998ecf8427e" end
            AddFeature("MD5 Spoof")
        else
            AddFailed("MD5 Spoof", "Module not found")
        end
    end)

    pcall(function()
        local sha = SafeRequire("GameLua.Mod.BaseMod.Common.Security.SHA256")
        if not sha then sha = SafeRequire("sha256") end
        if sha then
            sha.hash = function(data) return "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855" end
            sha.digest = sha.hash
            AddFeature("SHA256 Spoof")
        else
            AddFailed("SHA256 Spoof", "Module not found")
        end
    end)

    pcall(function()
        local CreativeModeLib = import("CreativeModeBlueprintLibrary")
        if CreativeModeLib then
            CreativeModeLib.MD5HashByteArray = function() return "BYPASSED_MD5" end
            CreativeModeLib.GetContentDiffData = function() return true, "BYPASSED" end
            AddFeature("CreativeMode MD5 Bypass")
        end
    end)
end

-- ================================================================
-- 4. GAMEPLAY CALLBACKS BYPASS
-- ================================================================
local function InitGameplayBypass()
    pcall(function()
        local GC = _G.GameplayCallbacks or _G.GC
        if not GC then 
            AddFailed("GameplayCallbacks", "GC not found")
            return 
        end

        local blockFuncs = {
            "ReportAttackFlow", "ReportSecAttackFlow", "ReportHurtFlow", "ReportFireArms",
            "ReportVerifyInfoFlow", "ReportMrpcsFlow", "ReportPlayerBehavior", "ReportTeammatHurt",
            "ReportMisKillByTeammate", "ReportForbitPick", "ReportPlayerMoveRoute", "ReportPlayerPosition",
            "ReportVehicleMoveFlow", "ReportSecTgameMovingFlow", "ReportParachuteData",
            "SendTssSdkAntiDataToLobby", "SendDSErrorLogToLobby", "SendDSHawkEyePatrolLogToLobby",
            "ReportEquipmentFlow", "ReportAimFlow", "ReportHeavyWeaponBoxSpawnFlow",
            "ReportHeavyWeaponBoxActivationFlow", "ReportHeavyWeaponBoxOpenPlayerFlow",
            "ReportHeavyWeaponBoxItemFlow", "ReportPlayersPing", "ReportPlayerIP",
            "ReportPlayerFramePingRecord", "ReportDSNetSaturation", "ReportNetContinuousSaturate",
            "ReportDSNetRate", "SendClientStats", "SendServerAvgTickDelta", "ReportCircleFlow",
            "ReportDSCircleFlow", "ReportJumpFlow", "ReportAIStrategyInfo", "SendAIDeliveryInfo",
            "ReportDailyTaskInfo", "ReportMatchRoomData", "SendPlayerSpectatingLog",
            "ReportIDCardProduceFlow", "ReportIDCardPickUpFlow", "ReportIDCardDestroyFlow",
            "ReportRevivalFlow", "ReportGameSetting", "ReportGameSettingNew", "ReportAntsVoiceTeamCreate",
            "ReportAntsVoiceTeamQuit", "ReportCommonInfo", "ReportLightweightStat",
            "SendSecTLog", "SendDataMiningTLog", "SendActivityTLog", "ReportHitFlow"
        }

        for _, funcName in ipairs(blockFuncs) do
            GC[funcName] = nop
        end

        GC.GetWeaponReport = retEmpty
        GC.GetOneWeaponReport = retEmpty
        GC.GetGeneralTLogData = function() return nil end
        GC.IsBypassed = true
        AddFeature("GameplayCallbacks Blocked (" .. #blockFuncs .. " functions)")
    end)
end

-- ================================================================
-- 5. CONNECTION GUARD
-- ================================================================
local function InitConnectionGuard()
    pcall(function()
        local GC = _G.GameplayCallbacks or _G.GC
        if not GC then 
            AddFailed("ConnectionGuard", "GC not found")
            return 
        end

        local original = GC.OnDSPlayerStateChanged
        GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
            local state = InPlayerState and string.lower(tostring(InPlayerState)) or ""
            local blockList = {
                ["cheatdetected"]=1, ["connectionlost"]=1, ["connectiontimeout"]=1,
                ["connectionexception"]=1, ["netdrivererror"]=1, ["ban"]=1, ["kick"]=1,
                ["suspended"]=1, ["violationdetected"]=1, ["integrityfailure"]=1,
                ["securityviolation"]=1
            }
            if blockList[state] then return end
            if original then pcall(original, UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason) end
        end

        GC.OnPlayerNetConnectionClosed = nop
        GC.OnPlayerActorChannelError = nop
        GC.OnPlayerRPCValidateFailed = nop
        GC.OnPlayerSpectateException = nop
        GC.OnShutdownAfterError = nop
        GC.KickPlayer = nop
        GC.BanPlayer = nop
        AddFeature("ConnectionGuard Active")
    end)
end

-- ================================================================
-- 6. LOG BLOCKER (TLog, Crash, Screenshot)
-- ================================================================
local function InitLogBlocker()
    pcall(function()
        local ScreenshotMaker = import("ScreenshotMaker")
        if ScreenshotMaker then
            ScreenshotMaker.MakePicture = retEmptyStr
            ScreenshotMaker.ReMakePicture = retEmptyStr
            ScreenshotMaker.HasCaptured = retTrue
            AddFeature("Screenshot Blocker")
        end
    end)

    pcall(function()
        local TLog = _G.TLog or SafeRequire("TLog")
        if TLog then
            TLog.Info = nop
            TLog.Warning = nop
            TLog.Error = nop
            TLog.Debug = nop
            TLog.Report = nop
            TLog.Send = nop
            TLog.Flush = nop
            AddFeature("TLog Blocker")
        else
            AddFailed("TLog Blocker", "Module not found")
        end
    end)

    pcall(function()
        local CrashSight = _G.CrashSight or SafeRequire("CrashSight")
        if CrashSight then
            CrashSight.ReportException = nop
            CrashSight.SetCustomData = nop
            CrashSight.Log = nop
            CrashSight.SendCrash = nop
            AddFeature("CrashSight Blocker")
        end
    end)

    pcall(function()
        local mod = SafeRequire("GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils")
        if mod then
            mod.BugglyPostExceptionFull = retFalse
            mod.CheckCanBugglyPostException = retFalse
            mod.ReplayReportData = nop
            mod.ReportGameException = nop
            mod.PostException = nop
            AddFeature("GameReportUtils Blocked")
        end
    end)

    pcall(function()
        local mod = SafeRequire("client.slua.logic.report.ClientToolsReport")
        if mod then
            mod.SendReport = nop
            mod.SendException = nop
            mod.UploadLog = nop
            AddFeature("ClientToolsReport Blocked")
        end
    end)

    pcall(function()
        local mod = SafeRequire("client.slua.config.tlog.tlog_report_utils")
        if mod then
            mod.ReportTLogEvent = nop
            mod.FlushEvents = nop
            AddFeature("TLog Report Utils Blocked")
        end
    end)

    pcall(function()
        local mod = SafeRequire("client.slua.logic.ugc.UGCNewTLogReport")
        if mod then
            mod.SendExposeReq = nop
            mod.SendInteractionReq = nop
            mod.TLogReport = nop
            AddFeature("UGC TLog Blocked")
        end
    end)

    pcall(function()
        local mod = SafeRequire("GameLua.Mod.BaseMod.Client.ClientTLog.ClientTLogUtil")
        if mod then
            mod.ReportGeneralCountByBRPhase = nop
            mod.ReportCommonTLogDataByBRPhase = nop
            AddFeature("ClientTLogUtil Blocked")
        end
    end)
end

-- ================================================================
-- 7. SCANNER BLOCKER (Subsystems)
-- ================================================================
local function InitScannerBlocker()
    pcall(function()
        local SubsystemMgr = SafeRequire("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if not SubsystemMgr then
            AddFailed("SubsystemMgr", "Module not found")
            return
        end

        local afk = SubsystemMgr:Get("AFKReportorSubsystem")
        if afk then
            afk.PlayerHaveAction = nop
            afk.ReportAFK = nop
            afk.SetPlayerAFKState = nop
            afk.AddOneAFKInfo = nop
            AddFeature("AFKReportor Blocked")
        end

        local stats = SubsystemMgr:Get("ClientDataStatistcsSubsystem")
        if stats then
            stats.StartToCheck = nop
            stats.DelayCount = 0
            if stats.ReportPingDelayTimer then
                stats:RemoveGameTimer(stats.ReportPingDelayTimer)
                stats.ReportPingDelayTimer = nil
            end
            AddFeature("ClientDataStats Blocked")
        end

        local avatarEx = SubsystemMgr:Get("AvatarExceptionSubsystem")
        if avatarEx then
            avatarEx.ReportException = nop
            avatarEx.BindPlayerCharacter = nop
            avatarEx.CheckAvatarValid = retTrue
            AddFeature("AvatarException Blocked")
        end

        local shootVerify = SubsystemMgr:Get("ShootVerifySubSystemClient")
        if shootVerify then
            shootVerify.ReportVerifyFail = nop
            shootVerify.OnVerifyFailed = nop
            shootVerify.VerifyShot = retTrue
            AddFeature("ShootVerify Blocked")
        end

        local modEx = SubsystemMgr:Get("ModifierExceptionSubsystem")
        if modEx then
            modEx.ReportException = nop
            modEx.CheckModifier = retTrue
            modEx.ValidateModifier = retTrue
            AddFeature("ModifierException Blocked")
        end

        local simChar = SubsystemMgr:Get("SimulateCharacterSubsystem")
        if simChar then
            simChar.ReportLocation = nop
            simChar.SendLocationData = nop
            simChar.VerifyLocation = retTrue
            AddFeature("SimulateCharacter Blocked")
        end

        local behavior = SubsystemMgr:Get("BehaviorScoreSubsystem")
        if behavior then
            behavior.OnHandleBehaviorScore = nop
            behavior.AIPerceptionScore = nop
            behavior.ReportBehavior = nop
            behavior.CalcFinalScore = retZero
            AddFeature("BehaviorScore Blocked")
        end

        local replay = SubsystemMgr:Get("RescueBtnReplayTraceSubsystem")
        if replay then
            replay.ReportTrace = nop
            replay.StartTickMonitor = nop
            replay.TickMonitorCheck = nop
            replay.ReportTickMonitorHeartbeat = nop
            AddFeature("RescueBtnReplayTrace Blocked")
        end

        local gameReport = SubsystemMgr:Get("GameReportSubsystem")
        if gameReport then
            gameReport.ReplayReportData = retFalse
            gameReport.CheckCanBugglyPostException = retFalse
            gameReport.BugglyPostExceptionFull = retFalse
            gameReport.GetClientReplayDataReporter = function() return nil end
            if gameReport.Reporter then
                gameReport.Reporter.ReportIntArrayData = nop
                gameReport.Reporter.ReportUInt8ArrayData = nop
                gameReport.Reporter.ReportFloatArrayData = nop
            end
            AddFeature("GameReportSubsystem Blocked")
        end
    end)

    pcall(function()
        local mod = SafeRequire("GameLua.Mod.Library.GamePlay.Avatar.Exception.AvatarExceptionPlayerInst")
        if mod then
            mod.CheckAvatarException = nop
            mod.CheckAvatarExceptionOnce = nop
            mod.ReportAvatarException = nop
            mod.CheckSlotMeshVisible = retFalse
            mod.CheckPawnVisible = retFalse
            mod.CheckCanBugglyPostException = retFalse
            AddFeature("AvatarExceptionPlayerInst Blocked")
        end
    end)

    pcall(function()
        local mod = SafeRequire("blacklist.slua.logic.lobby_gm.AvatarCheckerModule")
        if mod then
            mod.CheckAvatar = retTrue
            mod.ReportException = nop
            AddFeature("AvatarCheckerModule Blocked")
        end
    end)

    pcall(function()
        local mod = SafeRequire("client.slua.logic.memory_warning.logic_memory_warning")
        if mod then
            mod.OnMemoryWarning = nop
            mod.ReportMemoryWarning = nop
            AddFeature("MemoryWarning Blocked")
        end
    end)

    pcall(function()
        local mod = SafeRequire("client.slua.logic.replay.logic_report_replay")
        if mod then
            mod.ReportReplay = nop
            mod.SendReportReq = nop
            mod.UploadReplay = nop
            AddFeature("ReplayReport Blocked")
        end
    end)

    pcall(function()
        local TssSdk = _G.TssSdk or SafeRequire("TssSdk")
        if TssSdk then
            TssSdk.SendReportInfo = nop
            TssSdk.ScanMemory = retTrue
            TssSdk.IsEmulator = retFalse
            TssSdk.GetTssSdkReportInfo = retEmptyStr
            TssSdk.GetFileMD5 = function() return "d41d8cd98f00b204e9800998ecf8427e" end
            TssSdk.VerifyFileSignature = retTrue
            TssSdk.VerifyModule = retTrue
            TssSdk.CheckIntegrity = retTrue
            AddFeature("TssSdk Blocked")
        else
            AddFailed("TssSdk", "Module not found")
        end
    end)
end

-- ================================================================
-- 8. PACKET BLOCKER
-- ================================================================
local function InitPacketBlocker()
    pcall(function()
        if NetUtil and NetUtil.SendPacket and not NetUtil._HTY_BLOCKED then
            local sendPacket = NetUtil.SendPacket
            local blockedPackets = {
                ["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportHurtFlow"]=1,
                ["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
                ["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportTeammateKillConfirmFlow"]=1,
                ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1, ["ReportSecVehicleMoveFlow"]=1,
                ["ReportSecTgameMovingFlow"]=1, ["report_parachute_data"]=1, ["on_tss_sdk_anti_data"]=1,
                ["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["ReportCircleFlow"]=1, ["ReportJumpFlow"]=1,
                ["report_players_ping"]=1, ["report_player_ip"]=1, ["ReportDSCircleFlow"]=1,
                ["ReportEquipmentFlow"]=1, ["ReportHeavyWeaponBoxSpawnFlow"]=1,
                ["ReportHeavyWeaponBoxActivationFlow"]=1, ["ReportHeavyWeaponBoxOpenPlayerFlow"]=1,
                ["ReportHeavyWeaponBoxItemFlow"]=1, ["ReportPlayerFramePingRecord"]=1,
                ["ReportDSNetSaturation"]=1, ["ReportNetContinuousSaturate"]=1, ["ReportDSNetRate"]=1,
                ["SendClientStats"]=1, ["SendServerAvgTickDelta"]=1, ["SendSecTLog"]=1,
                ["SendDataMiningTLog"]=1, ["SendActivityTLog"]=1, ["SendDSErrorLogToLobby"]=1,
                ["SendDSHawkEyePatrolLogToLobby"]=1, ["SendTssSdkAntiDataToLobby"]=1,
                ["SendAIDeliveryInfo"]=1, ["ReportAIStrategyInfo"]=1, ["ReportDailyTaskInfo"]=1,
                ["ReportMatchRoomData"]=1, ["SendPlayerSpectatingLog"]=1, ["ReportIDCardProduceFlow"]=1,
                ["ReportIDCardPickUpFlow"]=1, ["ReportIDCardDestroyFlow"]=1, ["ReportRevivalFlow"]=1,
                ["ReportGameSetting"]=1, ["ReportGameSettingNew"]=1, ["ReportAntsVoiceTeamCreate"]=1,
                ["ReportAntsVoiceTeamQuit"]=1, ["ReportCommonInfo"]=1, ["ReportLightweightStat"]=1,
                ["GetGeneralTLogData"]=1, ["GetWeaponReport"]=1, ["GetOneWeaponReport"]=1,
                ["report_avatar_exception"]=1, ["report_memory_exception"]=1, ["tss_sdk_report"]=1,
                ["report_client_scan_result"]=1
            }

            NetUtil.SendPacket = function(packetName, ...)
                if blockedPackets[packetName] then return end
                if packetName and string.lower(tostring(packetName)):match("report") then return end
                if packetName and string.lower(tostring(packetName)):match("tlog") then return end
                if packetName and string.lower(tostring(packetName)):match("flow") then return end
                if packetName and string.lower(tostring(packetName)):match("md5") then return end
                if packetName and string.lower(tostring(packetName)):match("hash") then return end
                return sendPacket(packetName, ...)
            end
            NetUtil._HTY_BLOCKED = true
            AddFeature("PacketBlocker Active (" .. #blockedPackets .. " packets blocked)")
        else
            AddFailed("PacketBlocker", "NetUtil not found or already blocked")
        end
    end)

    pcall(function()
        if _G.SendRPC and not _G._HTY_RPC_BLOCKED then
            local origRPC = _G.SendRPC
            _G.SendRPC = function(rpcName, ...)
                if rpcName and string.lower(tostring(rpcName)):match("report") then return end
                if rpcName and string.lower(tostring(rpcName)):match("tlog") then return end
                if rpcName and string.lower(tostring(rpcName)):match("flow") then return end
                return origRPC(rpcName, ...)
            end
            _G._HTY_RPC_BLOCKED = true
            AddFeature("RPC Blocker Active")
        end
    end)
end

-- ================================================================
-- 9. HIGGS BOSON DISABLE (Live)
-- ================================================================
local function DisableHiggsBoson()
    pcall(function()
        local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            if pc.HiggsBoson then
                pc.HiggsBoson.bMHActive = false
                pc.HiggsBoson.bCallPreReplication = false
            end
            if pc.HiggsBosonComponent then
                pc.HiggsBosonComponent.bMHActive = false
                pc.HiggsBosonComponent:ControlMHActive(0)
            end
            AddFeature("HiggsBoson Live Disabled")
        end
    end)
end

-- ================================================================
-- 10. NETWORK OPTIMIZATION
-- ================================================================
local function InitNetworkOpt()
    pcall(function()
        local inst = slua_GameFrontendHUD and slua_GameFrontendHUD:GetGameInstance()
        if not inst then
            AddFailed("NetworkOpt", "GameInstance not found")
            return
        end

        local cmds = {
            {"net.MaxInternetClientRate", "100000"},
            {"net.MaxClientRate", "100000"},
            {"net.MaxServerRate", "100000"},
            {"net.ClientTickRate", "30"},
            {"net.MaxTickRate", "60"},
            {"net.InterpolationDelay", "0.01"},
            {"net.MaxPacketSize", "65536"},
            {"net.Timeout", "30"},
            {"net.HeartbeatInterval", "1"},
            {"net.KeepAliveInterval", "5"},
        }

        for _, cmd in ipairs(cmds) do
            pcall(function() inst:ExecuteCMD(cmd[1], cmd[2]) end)
        end
        AddFeature("Network Optimization Applied")
    end)
end

-- ================================================================
-- 11. RESOLUTION / SCREEN PERCENTAGE
-- ================================================================
local function ApplyResolution()
    pcall(function()
        local inst = slua_GameFrontendHUD and slua_GameFrontendHUD:GetGameInstance()
        if not inst then return end
        local pct = CONFIG.SCREEN_PERCENT or 100
        if pct < 10 then pct = 10 end
        inst:ExecuteCMD("r.ScreenPercentage", tostring(pct))
        AddFeature("ScreenPercentage Applied (" .. pct .. "%)")
    end)
end

-- ================================================================
-- 12. CONFIG LOADER (Optional file)
-- ================================================================
local CONFIG_PATH = nil

local function LoadConfig()
    local gamePackages = {
        "com.tencent.ig", "com.rekoo.pubgm", "com.pubg.krmobile", "com.vng.pubgmobile"
    }
    for _, pkg in ipairs(gamePackages) do
        local path = "/storage/emulated/0/Android/data/" .. pkg .. "/小小优.U5.七夕.h"
        local f = io.open(path, "r")
        if f then
            CONFIG_PATH = path
            f:close()
            break
        end
    end

    if not CONFIG_PATH then return end
    local file = io.open(CONFIG_PATH, "r")
    if not file then return end
    for line in file:lines() do
        if line then
            local trimmed = line:match("^%s*(.-)%s*$")
            if trimmed and trimmed ~= "" and not trimmed:match("^#") then
                local key, value = trimmed:match("^([^=]+)%s*=%s*(.+)$")
                if key and value then
                    key = key:match("^%s*(.-)%s*$")
                    value = value:match("^%s*(.-)%s*$")
                    local numValue = tonumber(value)
                    if key == "分辨率" then
                        CONFIG.SCREEN_PERCENT = numValue or 100
                    end
                end
            end
        end
    end
    file:close()
    AddFeature("Config Loaded")
end

-- ================================================================
-- 13. MAIN INITIALIZER
-- ================================================================
local initialized = false

local function InitAll()
    if initialized then return end
    initialized = true

    print("[HTY] Initializing Ultimate Anti-Cheat Bypass...")
    logData.file1_loaded = true
    AddFeature("1.lua LOADED SUCCESSFULLY")

    LoadConfig()
    InitAntiReport()
    InitAntiCheatHooks()
    InitHashSpoof()
    InitGameplayBypass()
    InitConnectionGuard()
    InitLogBlocker()
    InitScannerBlocker()
    InitPacketBlocker()
    DisableHiggsBoson()
    InitNetworkOpt()
    ApplyResolution()

    print("[HTY] ✅ Ultimate Anti-Cheat Bypass Activated!")
    WriteLog()
end

-- ================================================================
-- 14. TIMER & STARTUP
-- ================================================================
local resTick = 0

local function ResolutionTick()
    local now = os.clock()
    if (now - resTick) < 1 then return end
    resTick = now
    pcall(function()
        LoadConfig()
        ApplyResolution()
    end)
end

pcall(function()
    local tmr = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
    if not slua.isValid(tmr) then
        tmr = import("GameplayStatics").GetPlayerController(slua_GameFrontendHUD:GetWorld(), 0)
    end
    if not slua.isValid(tmr) then return end
    if _G.HTY_ULTIMATE_TIMER == tmr then return end
    _G.HTY_ULTIMATE_TIMER = tmr

    tmr:AddGameTimer(1, false, function()
        local pc = slua_GameFrontendHUD:GetPlayerController()
        if slua.isValid(pc) then
            pc:AddGameTimer(1, false, InitAll)
            pc:AddGameTimer(3, true, ResolutionTick)
            pc:AddGameTimer(5, true, DisableHiggsBoson)
            pc:AddGameTimer(10, true, function()
                pcall(function()
                    if _G.GameplayCallbacks then
                        _G.GameplayCallbacks.IsBypassed = true
                    end
                    if _G.WHABypass and _G.WHABypass.Init then
                        _G.WHABypass.Init()
                        _G._WHA_BYPASS_ACTIVE = true
                    end
                end)
            end)
        end
    end)
end)

print("[HTY] Ultimate Anti-Cheat Bypass Loaded")