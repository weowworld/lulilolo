-- ================================================================
-- FIXED 2.lua - All Errors Handled
-- ================================================================

local LOG_PATH = "/storage/emulated/0/Android/data/com.pubg.imobile/files/WeowLogs.txt"

-- Safe log function (pcall wrapped)
local function SafeWriteLog(content)
    pcall(function()
        local f = io.open(LOG_PATH, "a")
        if f then
            f:write(content .. "\n")
            f:close()
        end
    end)
end

-- Mark 2.lua as loaded FIRST THING
pcall(function()
    SafeWriteLog("\n[2.lua] 🔄 LOADING STARTED at " .. os.date("%H:%M:%S"))
end)

-- ================================================================
-- SAFE IMPORTS (with fallbacks)
-- ================================================================
local ENetRole, EPawnState, GameplayData, KismetMathLibrary, GameplayStatics
local importSuccess = true

pcall(function()
    ENetRole = import("ENetRole")
end)
pcall(function()
    EPawnState = import("EPawnState")
end)
pcall(function()
    GameplayData = require("GameLua.GameCore.Data.GameplayData")
end)
pcall(function()
    KismetMathLibrary = import("KismetMathLibrary")
end)
pcall(function()
    GameplayStatics = import("GameplayStatics")
end)

SafeWriteLog("[2.lua] ✅ Imports Done")

-- ================================================================
-- SAFE NOP FUNCTIONS
-- ================================================================
local function nop() end
local function retTrue() return true end
local function retFalse() return false end
local function retZero() return 0 end

-- ================================================================
-- WALLHACK BYPASS (All layers with error handling)
-- ================================================================
local function InstallUltimateWallhackBypass()
    if _G.__ULTIMATE_WH_BYPASS_LOADED then 
        SafeWriteLog("[2.lua] ⏭️ Wallhack Bypass already loaded")
        return 
    end

    local function isBypassActive()
        return _G._WHA_BYPASS_ACTIVE and not _G._MOD_EXPIRED
    end

    -- LAYER 1: PrimitiveSceneProxy
    pcall(function()
        local FPSP = import("PrimitiveSceneProxy")
        if FPSP then
            local origGetViewRelevance = FPSP.GetViewRelevance
            FPSP.GetViewRelevance = function(self, View)
                local VR = origGetViewRelevance and origGetViewRelevance(self, View)
                if isBypassActive() and VR then
                    VR.bRenderCustomDepth = false
                    VR.bUsesSceneDepth = false
                end
                return VR or {}
            end
            local origDepthPriority = FPSP.GetDepthPriorityGroup
            FPSP.GetDepthPriorityGroup = function(self)
                if not isBypassActive() then 
                    return origDepthPriority and origDepthPriority(self) or 0 
                end
                return 0
            end
            SafeWriteLog("[2.lua] ✅ PrimitiveSceneProxy Hooked")
        else
            SafeWriteLog("[2.lua] ⚠️ PrimitiveSceneProxy not found")
        end
    end)

    -- LAYER 2: MeshComponent
    pcall(function()
        local UMesh = import("MeshComponent")
        if UMesh then
            UMesh.GetRenderCustomDepth = function(self)
                if not isBypassActive() then 
                    return UMesh.__origGRCD and UMesh.__origGRCD(self) or false 
                end 
                return false 
            end
            UMesh.__origGRCD = UMesh.GetRenderCustomDepth
            UMesh.IsRenderedOnCustomDepth = function(self)
                if not isBypassActive() then 
                    return UMesh.__origIRCD and UMesh.__origIRCD(self) or false 
                end 
                return false 
            end
            UMesh.__origIRCD = UMesh.IsRenderedOnCustomDepth
            UMesh.GetCustomDepthStencilValue = function(self)
                if not isBypassActive() then 
                    return UMesh.__origGCDSV and UMesh.__origGCDSV(self) or 0 
                end 
                return 0 
            end
            UMesh.__origGCDSV = UMesh.GetCustomDepthStencilValue
            UMesh.ShouldRender = function(self)
                if not isBypassActive() then 
                    return UMesh.__origSR and UMesh.__origSR(self) or true 
                end 
                return true 
            end
            UMesh.__origSR = UMesh.ShouldRender
            UMesh.IsVisible = function(self)
                if not isBypassActive() then 
                    return UMesh.__origIV and UMesh.__origIV(self) or true 
                end 
                return true 
            end
            UMesh.__origIV = UMesh.IsVisible
            SafeWriteLog("[2.lua] ✅ MeshComponent Hooked")
        end
    end)

    -- LAYER 3: PrimitiveComponent
    pcall(function()
        local UPrim = import("PrimitiveComponent")
        if UPrim then
            local funcs = {"IsRenderedOnCustomDepth","GetRenderCustomDepth","GetCustomDepthStencilValue","GetCustomDepthStencilWriteMask","GetVisibleFlag"}
            for _, fn in ipairs(funcs) do
                local orig = UPrim[fn]
                if orig then
                    UPrim["__orig_"..fn] = orig
                    UPrim[fn] = function(self, ...)
                        if not isBypassActive() then 
                            return orig(self, ...) 
                        end
                        if fn == "GetVisibleFlag" then return true end
                        if fn == "GetCustomDepthStencilValue" then return 0 end
                        return false
                    end
                end
            end
            SafeWriteLog("[2.lua] ✅ PrimitiveComponent Hooked")
        end
    end)

    -- LAYER 4: RHI
    pcall(function()
        local FRHI = import("RHICommandList")
        if FRHI and FRHI.SetDepthState then
            local origSetDepth = FRHI.SetDepthState
            FRHI.SetDepthState = function(self, State)
                if isBypassActive() and type(State) == "table" then
                    State.DepthEnable = true
                end
                return origSetDepth(self, State)
            end
            SafeWriteLog("[2.lua] ✅ RHI Depth State Hooked")
        end
    end)

    -- LAYER 5: GameViewportClient
    pcall(function()
        local UGVC = import("GameViewportClient")
        if UGVC and UGVC.Draw then
            local origDraw = UGVC.Draw
            UGVC.Draw = function(self, ...)
                if origDraw then origDraw(self, ...) end
                if isBypassActive() and _G.AK_DrawWallhackOverlay then
                    pcall(_G.AK_DrawWallhackOverlay)
                end
            end
            SafeWriteLog("[2.lua] ✅ GameViewportClient Hooked")
        end
    end)

    -- LAYER 6: Material
    pcall(function()
        local UMat = import("Material")
        local UMatInst = import("MaterialInstance")
        local UMatDyn = import("MaterialInstanceDynamic")

        if UMat then
            UMat.GetDisableDepthTest = function(self)
                if not isBypassActive() then 
                    return UMat.__origDDT and UMat.__origDDT(self) or false 
                end 
                return false 
            end
            UMat.__origDDT = UMat.GetDisableDepthTest
            UMat.GetBlendMode = function(self)
                if not isBypassActive() then 
                    return UMat.__origBM and UMat.__origBM(self) or 0 
                end 
                return 0 
            end
            UMat.__origBM = UMat.GetBlendMode
            UMat.GetMaterialHash = function(self)
                if not isBypassActive() then 
                    return UMat.__origHash and UMat.__origHash(self) or "FAKE_HASH" 
                end 
                return "FAKE_HASH" 
            end
            UMat.__origHash = UMat.GetMaterialHash
            UMat.VerifyMaterial = function(self)
                if not isBypassActive() then 
                    return UMat.__origVM and UMat.__origVM(self) or true 
                end 
                return true 
            end
            UMat.__origVM = UMat.VerifyMaterial
            SafeWriteLog("[2.lua] ✅ Material Hooked")
        end
        if UMatInst then
            UMatInst.GetDisableDepthTest = function(self)
                if not isBypassActive() then 
                    return UMatInst.__origDDT and UMatInst.__origDDT(self) or false 
                end 
                return false 
            end
            UMatInst.__origDDT = UMatInst.GetDisableDepthTest
            UMatInst.GetBlendMode = function(self)
                if not isBypassActive() then 
                    return UMatInst.__origBM and UMatInst.__origBM(self) or 0 
                end 
                return 0 
            end
            UMatInst.__origBM = UMatInst.GetBlendMode
            UMatInst.GetBaseMaterial = function(self)
                if not isBypassActive() then 
                    return UMatInst.__origBM2 and UMatInst.__origBM2(self) or nil 
                end 
                return nil 
            end
            UMatInst.__origBM2 = UMatInst.GetBaseMaterial
            SafeWriteLog("[2.lua] ✅ MaterialInstance Hooked")
        end
        if UMatDyn then
            local oldGetVec = UMatDyn.K2_GetVectorParameterValue
            UMatDyn.K2_GetVectorParameterValue = function(self, name)
                if not isBypassActive() then 
                    return oldGetVec and oldGetVec(self, name) or {R=255,G=255,B=255,A=255} 
                end
                local n = tostring(name or "")
                if n:find("Color") or n:find("Emissive") or n:find("Tint") then
                    return {R=255,G=255,B=255,A=255}
                end
                return oldGetVec(self, name)
            end
            local oldGetScal = UMatDyn.K2_GetScalarParameterValue
            UMatDyn.K2_GetScalarParameterValue = function(self, name)
                if not isBypassActive() then 
                    return oldGetScal and oldGetScal(self, name) or 0 
                end
                if tostring(name):find("Emissive") then return 0.0 end
                return oldGetScal(self, name)
            end
            SafeWriteLog("[2.lua] ✅ MaterialInstanceDynamic Hooked")
        end
    end)

    -- LAYER 7: Object Scanner
    pcall(function()
        local UObj = import("Object")
        if UObj and UObj.GetObjectsOfClass then
            local oldGet = UObj.GetObjectsOfClass
            UObj.GetObjectsOfClass = function(Class, IncludeDerived)
                if isBypassActive() and Class and tostring(Class):find("MaterialInstanceDynamic") then
                    return {}
                end
                return oldGet(Class, IncludeDerived)
            end
            SafeWriteLog("[2.lua] ✅ Object Scanner Hooked")
        end
    end)

    -- LAYER 8: Kernel & Memory
    pcall(function()
        local SubMgr = pcall(require, "GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local kc = SubMgr:Get("ClientKernelCheckSubsystem")
            if kc and not kc.__akhooked then
                local origIKC = kc.IsKernelClean
                kc.IsKernelClean = function(self)
                    if not isBypassActive() then 
                        return origIKC and origIKC(self) or true, { code = 0, message = "clean" }
                    end
                    return true, { code = 0, message = "clean" }
                end
                local origGKV = kc.GetKernelVersion
                kc.GetKernelVersion = function(self)
                    if not isBypassActive() then 
                        return origGKV and origGKV(self) or "5.4.0-generic"
                    end
                    return "5.4.0-generic"
                end
                kc.__akhooked = true
                SafeWriteLog("[2.lua] ✅ KernelCheck Spoofed")
            end
            
            local mg = SubMgr:Get("ClientMemoryGuardSubsystem")
            if mg and not mg.__akhooked then
                local origIMC = mg.IsMemoryClean
                mg.IsMemoryClean = function(self)
                    if not isBypassActive() then 
                        return origIMC and origIMC(self) or true, {code=0}
                    end
                    return true, {code=0}
                end
                local origSR = mg.ScanResult
                mg.ScanResult = function(self)
                    if not isBypassActive() then 
                        return origSR and origSR(self) or "clean"
                    end
                    return "clean"
                end
                mg.__akhooked = true
                SafeWriteLog("[2.lua] ✅ MemoryGuard Spoofed")
            end
        else
            SafeWriteLog("[2.lua] ⚠️ SubsystemMgr not found")
        end
    end)

    _G.__ULTIMATE_WH_BYPASS_LOADED = true
    SafeWriteLog("[2.lua] ✅ Ultimate Wallhack Bypass Installed")
end

-- ================================================================
-- MATERIAL EVASION
-- ================================================================
local function activate_material_evasion()
    if _G._MATERIAL_GETTERS_HOOKED then return end
    
    pcall(function()
        local UMaterial = import("Material")
        local UMaterialInstance = import("MaterialInstance")
        local UMaterialInstanceDynamic = import("MaterialInstanceDynamic")
        local UPrimitiveComponent = import("PrimitiveComponent")
        local UMeshComponent = import("MeshComponent")

        if UMaterial then
            UMaterial.GetDisableDepthTest = function() return false end
            UMaterial.GetBlendMode = function() return 0 end
            UMaterial.GetMaterialHash = function() return "FAKE_HASH" end
            UMaterial.VerifyMaterial = function() return true end
            SafeWriteLog("[2.lua] ✅ Material Evasion - Material")
        end
        if UMaterialInstance then
            UMaterialInstance.GetDisableDepthTest = function() return false end
            UMaterialInstance.GetBlendMode = function() return 0 end
            UMaterialInstance.GetBaseMaterial = function() return nil end
            SafeWriteLog("[2.lua] ✅ Material Evasion - MaterialInstance")
        end
        if UMaterialInstanceDynamic then
            local oldVec = UMaterialInstanceDynamic.K2_GetVectorParameterValue
            UMaterialInstanceDynamic.K2_GetVectorParameterValue = function(self, name)
                local n = tostring(name or "")
                if n:find("Color") or n:find("Emissive") then 
                    return {R=255,G=255,B=255,A=255} 
                end
                return oldVec and oldVec(self, name) or {R=255,G=255,B=255,A=255}
            end
            local oldScal = UMaterialInstanceDynamic.K2_GetScalarParameterValue
            UMaterialInstanceDynamic.K2_GetScalarParameterValue = function(self, name)
                if tostring(name or ""):find("Emissive") then return 0.0 end
                return oldScal and oldScal(self, name) or 0
            end
            UMaterialInstanceDynamic.GetFullName = function() return "DefaultMaterial" end
            SafeWriteLog("[2.lua] ✅ Material Evasion - MaterialInstanceDynamic")
        end
        if UPrimitiveComponent then
            UPrimitiveComponent.IsRenderedOnCustomDepth = function() return false end
            UPrimitiveComponent.GetRenderCustomDepth = function() return false end
            UPrimitiveComponent.GetCustomDepthStencilValue = function() return 0 end
            UPrimitiveComponent.GetCustomDepthStencilWriteMask = function() return 0 end
            UPrimitiveComponent.GetVisibleFlag = function() return true end
            SafeWriteLog("[2.lua] ✅ Material Evasion - PrimitiveComponent")
        end
        if UMeshComponent then
            UMeshComponent.ShouldRender = function() return true end
            UMeshComponent.GetShouldRender = function() return true end
            UMeshComponent.IsVisible = function() return true end
            SafeWriteLog("[2.lua] ✅ Material Evasion - MeshComponent")
        end

        local UObject = import("Object")
        if UObject and UObject.GetObjectsOfClass then
            local oldGet = UObject.GetObjectsOfClass
            UObject.GetObjectsOfClass = function(Class, IncludeDerived)
                if Class and tostring(Class):find("MaterialInstanceDynamic") then 
                    return {} 
                end
                return oldGet(Class, IncludeDerived)
            end
            SafeWriteLog("[2.lua] ✅ Material Evasion - Object Scanner")
        end
    end)
    _G._MATERIAL_GETTERS_HOOKED = true
end

-- ================================================================
-- WALLHACK ACTIVE SYSTEM (DrawDyeing + IdeaOutline)
-- ================================================================
local LinearColor = pcall(import, "LinearColor") and import("LinearColor") or nil

local CONSOLE_READY = false
local PROCESSED_PAWNS = {}
local TICK_COUNT = 0
local WH_TIMER = nil
local TICK_INTERVAL = 0.3
local MAX_PAWNS_PER_TICK = 20
local RESET_PROCESSED_EVERY = 6
local AVATAR_SLOTS = {0,1,2,3,4,5,6,7}

local colors = nil
if LinearColor then
    colors = {
        vis = LinearColor(100, 100, 5, 100),
        occ = LinearColor(100, 0, 100, 100),
        bVis = LinearColor(49, 48, 0, 100),
        bOcc = LinearColor(9, 1.5, 45, 100)
    }
end

local function SetupConsole()
    if CONSOLE_READY then return end
    pcall(function()
        local KismetSystemLibrary = import("KismetSystemLibrary")
        local world = pcall(slua.getWorld) and slua.getWorld() or nil
        if KismetSystemLibrary and world then
            KismetSystemLibrary.ExecuteConsoleCommand(world, "r.EnableDrawDyeingColor 1")
            KismetSystemLibrary.ExecuteConsoleCommand(world, "r.CustomDepth 3")
            KismetSystemLibrary.ExecuteConsoleCommand(world, "r.IdeaOutline.Enable 1")
            KismetSystemLibrary.ExecuteConsoleCommand(world, "r.Highlight.Enable 1")
            CONSOLE_READY = true
            SafeWriteLog("[2.lua] ✅ Wallhack Console Commands Applied")
        end
    end)
end

local function ApplyToMesh(mesh, visColor, occColor)
    if not mesh or not pcall(slua.isValid, mesh) then return end
    pcall(function()
        mesh:SetDrawDyeing(true)
        mesh:SetDrawDyeingMode(1)
        mesh:SetVisibleDyeingColor(visColor)
        mesh:SetOccludedDyeingColor(occColor)
        mesh:SetDyeingColorFadeDistance(99999.0)
        mesh:SetDyeingColorMinMaxDistance(0.0, 99999.0)
        mesh:SetDrawHighlight(true)
        mesh:OverrideHighlightColor(visColor)
        mesh:SetHighlightCanBeOccluded(false)
        mesh:SetDrawIdeaOutline(true)
        mesh:SetIdeaOutlineNew(true)
        mesh:SetIdeaOutlineOcclusionHighlight(true)
        mesh:OverrideIdeaOutlineColor(visColor)
        mesh:SetIdeaOutlineOcclusionColor(occColor)
        mesh:OverrideIdeaOutlineThickness(20.0)
        mesh:SetIdeaOverrideOutlineAndOcclusion(true)
        mesh:SetRenderCustomDepth(true)
        mesh:SetCustomDepthStencilValue(255)
    end)
end

local function IsPawnAlive(pawn)
    if not pcall(slua.isValid, pawn) then return false end
    if pawn.Health and pawn.Health > 0 then return true end
    return false
end

local function PBCtick()
    pcall(function()
        local localPawn = nil
        pcall(function()
            if GameplayData then
                localPawn = GameplayData.GetPlayerCharacter()
            end
        end)
        if not pcall(slua.isValid, localPawn) then return end

        SetupConsole()
        if not colors then return end

        TICK_COUNT = TICK_COUNT + 1
        if TICK_COUNT % RESET_PROCESSED_EVERY == 0 then
            PROCESSED_PAWNS = {}
        end

        local myTeamId = localPawn.TeamID or 0
        local allPawns = {}
        pcall(function()
            if _G.Game and _G.Game.GetAllPlayerPawns then
                allPawns = _G.Game:GetAllPlayerPawns() or {}
            end
        end)
        local processedCount = 0

        for _, pawn in pairs(allPawns) do
            if processedCount >= MAX_PAWNS_PER_TICK then break end
            if not pcall(slua.isValid, pawn) or pawn == localPawn then goto continue end
            if pawn.PlayerKey and PROCESSED_PAWNS[pawn.PlayerKey] then goto continue end

            if IsPawnAlive(pawn) and pawn.TeamID and pawn.TeamID ~= myTeamId then
                local isAI = false
                pcall(function()
                    if _G.Game and _G.Game.IsAI then
                        isAI = _G.Game.IsAI(pawn)
                    end
                end)
                local vis = isAI and colors.bVis or colors.vis
                local occ = isAI and colors.bOcc or colors.occ

                pcall(function()
                    if pcall(slua.isValid, pawn.Mesh) then
                        ApplyToMesh(pawn.Mesh, vis, occ)
                    end
                    local avatarComp = pawn.CharacterAvatarComp2_BP or pawn:getAvatarComponent2()
                    if avatarComp and avatarComp.GetMeshCompBySlot then
                        for _, slot in ipairs(AVATAR_SLOTS) do
                            local mesh = avatarComp:GetMeshCompBySlot(slot)
                            if pcall(slua.isValid, mesh) then
                                ApplyToMesh(mesh, vis, occ)
                            end
                        end
                    end
                    pcall(function()
                        local SkeletalMeshComponent = import("SkeletalMeshComponent")
                        if SkeletalMeshComponent then
                            local skComps = pawn:GetComponentsByClass(SkeletalMeshComponent)
                            if skComps then
                                for i = 0, skComps:Num() - 1 do
                                    local comp = skComps:Get(i)
                                    if pcall(slua.isValid, comp) and comp ~= pawn.Mesh then
                                        ApplyToMesh(comp, vis, occ)
                                    end
                                end
                            end
                        end
                    end)
                    pcall(function()
                        local StaticMeshComponent = import("StaticMeshComponent")
                        if StaticMeshComponent then
                            local stComps = pawn:GetComponentsByClass(StaticMeshComponent)
                            if stComps then
                                for i = 0, stComps:Num() - 1 do
                                    local comp = stComps:Get(i)
                                    if pcall(slua.isValid, comp) then
                                        ApplyToMesh(comp, vis, occ)
                                    end
                                end
                            end
                        end
                    end)
                    local weapon = pawn:GetCurrentWeapon()
                    if pcall(slua.isValid, weapon) and pcall(slua.isValid, weapon.Mesh) then
                        ApplyToMesh(weapon.Mesh, vis, occ)
                    end
                end)

                if pawn.PlayerKey then PROCESSED_PAWNS[pawn.PlayerKey] = true end
                processedCount = processedCount + 1
            end
            ::continue::
        end
    end)
end

local function StartPBC()
    SetupConsole()
    if not colors then
        SafeWriteLog("[2.lua] ⚠️ Wallhack Colors not initialized")
        return false
    end

    if WH_TIMER then
        pcall(function()
            if _G.Game and _G.Game.RemoveGameTimer then
                _G.Game:RemoveGameTimer(WH_TIMER)
            end
        end)
        WH_TIMER = nil
    end

    local started = false
    pcall(function()
        if _G.Game and _G.Game.AddGameTimer then
            WH_TIMER = _G.Game:AddGameTimer(TICK_INTERVAL, true, PBCtick)
            started = true
            SafeWriteLog("[2.lua] ✅ Wallhack Active (Game timer)")
        end
    end)

    if not started then
        pcall(function()
            local pc = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
            if pcall(slua.isValid, pc) and pc.AddGameTimer then
                WH_TIMER = pc:AddGameTimer(TICK_INTERVAL, true, PBCtick)
                started = true
                SafeWriteLog("[2.lua] ✅ Wallhack Active (PC timer)")
            end
        end)
    end

    if not started then
        SafeWriteLog("[2.lua] ⚠️ Wallhack could not start - no timer")
    end
    return started
end

function _G.StartNewWallhack()
    if WH_TIMER then return end
    pcall(StartPBC)
end

-- ================================================================
-- DEVICE ID / BAN BYPASS
-- ================================================================
local function InstallDeviceBanBypass()
    if _G.__DEVICE_BAN_BYPASS_LOADED then return end

    local function isBypassActive()
        return _G._WHA_BYPASS_ACTIVE and not _G._MOD_EXPIRED
    end

    local function generateFakeId(length)
        local chars = "0123456789ABCDEF"
        local id = ""
        for i = 1, length do
            id = id .. chars:sub(math.random(1, #chars), math.random(1, #chars))
        end
        return id
    end
    local fakeDeviceID = generateFakeId(32)
    local fakeAndroidID = generateFakeId(16)
    local fakeMac = string.format("%02X:%02X:%02X:%02X:%02X:%02X",
        math.random(0,255), math.random(0,255), math.random(0,255),
        math.random(0,255), math.random(0,255), math.random(0,255))
    local fakeIMEI = "35" .. math.random(100000, 999999) .. math.random(100000, 999999)

    pcall(function()
        local SystemInfo = import("SystemInfo")
        if SystemInfo then
            if SystemInfo.GetDeviceID then
                local orig = SystemInfo.GetDeviceID
                SystemInfo.GetDeviceID = function()
                    if isBypassActive() then return fakeDeviceID end
                    return orig()
                end
                SafeWriteLog("[2.lua] ✅ DeviceID Spoof")
            end
            if SystemInfo.GetMacAddress then
                local orig = SystemInfo.GetMacAddress
                SystemInfo.GetMacAddress = function()
                    if isBypassActive() then return fakeMac end
                    return orig()
                end
                SafeWriteLog("[2.lua] ✅ MacAddress Spoof")
            end
            if SystemInfo.GetAndroidId then
                local orig = SystemInfo.GetAndroidId
                SystemInfo.GetAndroidId = function()
                    if isBypassActive() then return fakeAndroidID end
                    return orig()
                end
                SafeWriteLog("[2.lua] ✅ AndroidID Spoof")
            end
            if SystemInfo.GetIMEI then
                local orig = SystemInfo.GetIMEI
                SystemInfo.GetIMEI = function()
                    if isBypassActive() then return fakeIMEI end
                    return orig()
                end
                SafeWriteLog("[2.lua] ✅ IMEI Spoof")
            end
        end
    end)

    pcall(function()
        local Build = import("Build")
        if Build then
            local props = {"Fingerprint", "Serial", "Hardware", "Brand", "Model", "Manufacturer", "Product", "Device", "Board"}
            for _, prop in ipairs(props) do
                local orig = Build[prop]
                if orig then
                    Build[prop] = function()
                        if isBypassActive() then
                            if prop == "Fingerprint" then return "google/oriole/oriole:13/TQ1A.221205.011/2022120500:user/release-keys" end
                            if prop == "Serial" then return "R5CT1234567" end
                            if prop == "Hardware" then return "oriole" end
                            if prop == "Brand" then return "google" end
                            if prop == "Model" then return "Pixel 6" end
                            if prop == "Manufacturer" then return "Google" end
                            if prop == "Product" then return "oriole" end
                            if prop == "Device" then return "oriole" end
                            if prop == "Board" then return "gs101" end
                        end
                        return orig()
                    end
                end
            end
            SafeWriteLog("[2.lua] ✅ Build Properties Spoof")
        end
    end)

    _G.__DEVICE_BAN_BYPASS_LOADED = true
end

-- ================================================================
-- MD5 BYPASS
-- ================================================================
local function InstallMD5Bypass()
    local FAKE_MD5 = "7b1c7b5608da3083097816106fc331f9"
    local function returnFakeMD5() return FAKE_MD5 end
    local function returnTrue() return true end

    pcall(function()
        local CreativeModeLib = import("CreativeModeBlueprintLibrary")
        if CreativeModeLib then
            CreativeModeLib.MD5HashByteArray = function() return "BYPASSED_MD5" end
            CreativeModeLib.GetContentDiffData = function() return true, "BYPASSED" end
            SafeWriteLog("[2.lua] ✅ CreativeMode MD5 Bypass")
        end
    end)

    pcall(function()
        local TssSdk = _G.TssSdk
        if TssSdk then
            TssSdk.GetFileMD5 = returnFakeMD5
            TssSdk.VerifyFileSignature = returnTrue
            SafeWriteLog("[2.lua] ✅ TssSdk MD5 Bypass")
        end
    end)

    pcall(function()
        if NetUtil and NetUtil.SendPacket then
            local origSend = NetUtil.SendPacket
            NetUtil.SendPacket = function(packetName, ...)
                if packetName and tostring(packetName):lower():match("md5") then 
                    SafeWriteLog("[2.lua] 🚫 Blocked MD5 packet: " .. tostring(packetName))
                    return nil 
                end
                return origSend(packetName, ...)
            end
            SafeWriteLog("[2.lua] ✅ NetUtil MD5 Packet Block")
        end
    end)

    pcall(function()
        if _G.SendRPC then
            local origRPC = _G.SendRPC
            _G.SendRPC = function(rpcName, ...)
                if rpcName and tostring(rpcName):lower():match("md5") then return end
                return origRPC(rpcName, ...)
            end
            SafeWriteLog("[2.lua] ✅ SendRPC MD5 Block")
        end
    end)
end

-- ================================================================
-- HIGGS BOSON ANNIHILATOR
-- ================================================================
local function InstallHiggsBypass()
    pcall(function()
        local Higgs = pcall(require, "GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            local origInit = Higgs.Initialize or Higgs.ctor
            if origInit then
                Higgs.Initialize = function(self, ...)
                    self.bMHActive = false
                    self.bCallPreReplication = false
                    if origInit then origInit(self, ...) end
                end
            else
                rawset(Higgs, "bMHActive", false)
                rawset(Higgs, "bCallPreReplication", false)
            end
            SafeWriteLog("[2.lua] ✅ HiggsBoson Patched")
        end
    end)

    pcall(function()
        _G.BlackList = {}
        SafeWriteLog("[2.lua] ✅ BlackList Cleaned")
    end)
end

-- ================================================================
-- BRPlayerCharacterBase
-- ================================================================
local BRPlayerCharacterBase = {
    ServerRPC = {},
    ClientRPC = {},
    MulticastRPC = {}
}

BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = { Reliable = true, Params = {} }
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = { Reliable = true, Params = { UEnums.EPropertyClass.Object } }
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = { Reliable = true, Params = { UEnums.EPropertyClass.Int } }
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = { Reliable = true, Params = { UEnums.EPropertyClass.Bool } }
BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = { Reliable = true, Params = { UEnums.EPropertyClass.UInt32, UEnums.EPropertyClass.UInt32 } }

function BRPlayerCharacterBase:ctor()
    self.bHasShownDevNotice = false
    self._newWallhackStarted = false
end

function BRPlayerCharacterBase:_PostConstruct()
    if BRPlayerCharacterBase.__super and BRPlayerCharacterBase.__super._PostConstruct then
        BRPlayerCharacterBase.__super._PostConstruct(self)
    end
    pcall(function() self:InitAddSpecialMoveInfo() end)
    self.bCanNearDeathGiveup = true
    pcall(function() self:StartBypassSystems() end)
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
    if BRPlayerCharacterBase.__super and BRPlayerCharacterBase.__super.ReceiveBeginPlay then
        BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
    end
    pcall(function()
        self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
        if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
            local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
            if pcall(slua.isValid, CheckFallingDistanceComponent_C) and not pcall(slua.isValid, self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
                Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
            end
        end
        if pcall(slua.isValid, self.STCharacterMovement) then
            self.STCharacterMovement.bPositiveBlowUp = true
        end
        if self.Role == ENetRole.ROLE_AutonomousProxy then
            self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
            self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
            self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", { AttrName = { "bCanSelfRescue" } }, self.CharacterAttrChangeEvent, self)
        end
        if Client then
            GameplayData.AddCharacter(self.Object)
        else
            self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, { [1] = "FinishedState" }, self.HandleFinishedState, self)
        end
        EventSystem:postEvent(EVENTTYPE_SINGLETRAINING, EVENTID_CHARACTER_BEGINPLAY, self.Object)
    end)
end

function BRPlayerCharacterBase:ReceiveEndPlay(endPlayReason)
    if BRPlayerCharacterBase.__super and BRPlayerCharacterBase.__super.ReceiveEndPlay then
        BRPlayerCharacterBase.__super.ReceiveEndPlay(self, endPlayReason)
    end
    if Client and GameplayData.RemoveCharacter then 
        GameplayData.RemoveCharacter(self.Object) 
    end
end

function BRPlayerCharacterBase:StartBypassSystems()
    if not Client then return end
    
    local localPlayer = nil
    pcall(function()
        if GameplayData then
            localPlayer = GameplayData.GetPlayerCharacter()
        end
    end)
    
    if pcall(slua.isValid, localPlayer) and localPlayer.Object == self.Object then
        if not localPlayer._bypassActive then
            localPlayer._bypassActive = true
            pcall(function()
                if _G.WHABypass and _G.WHABypass.Init then
                    _G.WHABypass.Init()
                    _G._WHA_BYPASS_ACTIVE = true
                end
            end)
            SafeWriteLog("[2.lua] ✅ WHABypass Init Called")
        end

        if not localPlayer._monitorsSetup then
            localPlayer._monitorsSetup = true
            pcall(function()
                localPlayer:AddGameTimer(0.5, true, function()
                    if not _G._WHA_BYPASS_ACTIVE then
                        pcall(function()
                            if _G.WHABypass and _G.WHABypass.Init then
                                _G.WHABypass.Init()
                                _G._WHA_BYPASS_ACTIVE = true
                            end
                        end)
                    end
                end)
            end)
            pcall(function()
                localPlayer:AddGameTimer(10.0, true, function()
                    pcall(function()
                        if _G.WHABypass and _G.WHABypass.Init then
                            _G.WHABypass.Init()
                            _G._WHA_BYPASS_ACTIVE = true
                        end
                    end)
                end)
            end)
            SafeWriteLog("[2.lua] ✅ Bypass Monitors Setup")
        end

        if not self._newWallhackStarted then
            self._newWallhackStarted = true
            pcall(function()
                if _G.StartNewWallhack then 
                    _G.StartNewWallhack() 
                end
            end)
            SafeWriteLog("[2.lua] ✅ Wallhack Started from BRPlayerCharacterBase")
        end
    end
end

-- ================================================================
-- INSTALL ALL FEATURES
-- ================================================================
pcall(function()
    SafeWriteLog("[2.lua] 🔄 Installing Features...")
    
    InstallUltimateWallhackBypass()
    activate_material_evasion()
    InstallDeviceBanBypass()
    InstallMD5Bypass()
    InstallHiggsBypass()
    
    SafeWriteLog("[2.lua] ✅ ALL FEATURES INSTALLED SUCCESSFULLY")
end)

-- ================================================================
-- FINAL CLASS REGISTRATION
-- ================================================================
local class, CharacterBase
pcall(function()
    class = require("class")
end)
pcall(function()
    CharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
end)

if class and CharacterBase then
    local BRCharacterClass = class(CharacterBase, nil, BRPlayerCharacterBase)
    pcall(function()
        return require("combine_class").DeclareFeature(BRCharacterClass, {
            { SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature" },
            { CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature" },
            { SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature" },
            { TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature" },
            { LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature" },
            { FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature" },
            { CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature" },
            { BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature" },
            { CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature" },
            { ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature" }
        }, "BRPlayerCharacterBase")
    end)
    SafeWriteLog("[2.lua] ✅ BRCharacterClass Registered")
end

-- ================================================================
-- FINAL LOG
-- ================================================================
SafeWriteLog("[2.lua] ✅ 2.lua LOADED SUCCESSFULLY at " .. os.date("%H:%M:%S"))
SafeWriteLog("==================== 2.lua DONE ====================\n")

print("[2.lua] ✅ Loaded Successfully!")