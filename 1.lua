local BRPlayerCharacterBase = {
  ServerRPC = {},
  ClientRPC = {},
  MulticastRPC = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_NearDeathGiveupRescue = {
  Reliable = true,
  Params = {}
}
BRPlayerCharacterBase.ServerRPC.ServerRPC_CarryDeadBox = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Object
  }
}
BRPlayerCharacterBase.ServerRPC.RPC_Server_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.MulticastRPC.MulticastRPC_GmPlayAction = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Int
  }
}
BRPlayerCharacterBase.ClientRPC.RPC_Client_SetShouldCheckPassWall = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.Bool
  }
}
local ENetRole = import("ENetRole")
local EPawnState = import("EPawnState")
local GameplayData = require("GameLua.GameCore.Data.GameplayData")
local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")

function BRPlayerCharacterBase:ctor()
end

function BRPlayerCharacterBase:_PostConstruct()
  BRPlayerCharacterBase.__super._PostConstruct(self)
  self:InitAddSpecialMoveInfo()
  self.bCanNearDeathGiveup = true
  print(bWriteLog and "BRPlayerCharacterBase:_PostConstruct bCanNearDeathGiveup true")
end

function BRPlayerCharacterBase:ReceiveBeginPlay()
  BRPlayerCharacterBase.__super.ReceiveBeginPlay(self)
  self:AddControlEvent(self, "MovementModeChangedDelegate", self.HandleOnMovementModeChangedNew, self)
  if self:HasAuthority() and self:CheckAddCheckFallingDistanceComponent() then
    local CheckFallingDistanceComponent_C = import("CheckFallingDistanceComponent")
    if slua.isValid(CheckFallingDistanceComponent_C) and not slua.isValid(self:GetComponentByClass(CheckFallingDistanceComponent_C)) then
      print(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay Add CheckFallingDistanceComponent")
      Game:AddComponent(CheckFallingDistanceComponent_C, self, "CheckFallingDistanceComponent")
    end
  end
  if slua.isValid(self.STCharacterMovement) then
    self.STCharacterMovement.bPositiveBlowUp = true
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy then
    self:AddControlEvent(self, "OnPawnStateDisabled", self.OnPawnStateChange, self)
    self:AddControlEvent(self, "OnPawnStateEnabled", self.OnPawnStateChange, self)
    self:AddControlEventConditionOnly(self, "OnAttrChangeEventDelegate", {
      AttrName = {
        "bCanSelfRescue"
      }
    }, self.CharacterAttrChangeEvent, self)
  end
  if Client then
    printf(bWriteLog and "BRPlayerCharacterBase:ReceiveBeginPlay, PlayerKey:%u ", self.PlayerKey)
    GameplayData.AddCharacter(self.Object)
    self:AddControlEvent(self, "OnAttachedToVehicle", self.HandleOnAttachedToVehicle, self)
    self:AddControlEvent(self, "OnDetachedFromVehicle", self.HandleOnDetachedFromVehicle, self)
  else
    self:AddCommonEventWithConditions(EVENTTYPE_INGAME_NORMAL, EVENTID_GAME_MODE_STATE_CHANGE, {
      [1] = "FinishedState"
    }, self.HandleFinishedState, self)
  end
end

function BRPlayerCharacterBase:HandleOnAttachedToVehicle(uVehicle)
  if not slua.isValid(uVehicle) then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:HandleOnAttachedToVehicle", Game:GetObjName(uVehicle)))
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
    self.nUpdatePlayerAttachToVehicleTimer = self:AddGameTimer(5, true, 
function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:UpdatePlayerAttachToVehicle(uVehicle)
      end
    end)
    self.nFixMeshContainerTimer = self:AddGameTimer(3, true, 
function()
      if slua.isValid(self.Object) and slua.isValid(uVehicle) then
        self:FixMeshContainerOffsetIfNeeded(uVehicle)
      end
    end)
  end
end

function BRPlayerCharacterBase:HandleOnDetachedFromVehicle(uLastVehicle)
  if not slua.isValid(uLastVehicle) then
    return
  end
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnDetachedFromVehicle", uLastVehicle)
  if self.Role == ENetRole.ROLE_SimulatedProxy then
    self:ClearAttachToVehicleTimer()
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:UpdatePlayerAttachToVehicle(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.CapsuleComponent) or not slua.isValid(self.Mesh) or not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  if not self.nUpdatePlayerAttachToVehicleCount then
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  local ESTEPoseState = import("ESTEPoseState")
  local bStand = self.PoseState == ESTEPoseState.Stand
  local uActorRelativeLocation = self.CapsuleComponent:GetRelativeTransform():GetLocation()
  local uMeshRelativeLocation = self.Mesh:GetRelativeTransform():GetLocation()
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  local nCapsuleRadius = self.CapsuleComponent:GetScaledCapsuleRadius()
  local nCapsuleHalfHeight = self.CapsuleComponent:GetScaledCapsuleHalfHeight()
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local nExpectedCapsuleRadius = self.StandRadius
  local nExpectedCapsuleHalfHeight = self.StandHalfHeight
  local uMeshExpectedRL = FVector(0, 0, 0)
  local uActorExpectedRL = FVector(0, 0, self.StandHalfHeight)
  local nTolerance = 1.0
  local bCapsuleRLCorrect = uActorRelativeLocation:Equals(uActorExpectedRL, nTolerance)
  local bMeshRLCorrect = uMeshRelativeLocation:Equals(uMeshExpectedRL, nTolerance)
  local bMeshContainerRLCorrect = nTolerance > math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ)
  local bCapsuleRadiusCorrect = nTolerance > math.abs(nCapsuleRadius - nExpectedCapsuleRadius)
  local bCapsuleHalfHeightCorrect = nTolerance > math.abs(nCapsuleHalfHeight - nExpectedCapsuleHalfHeight)
  local bAllCorrect = bStand and bCapsuleRLCorrect and bMeshRLCorrect and bMeshContainerRLCorrect and bCapsuleRadiusCorrect and bCapsuleHalfHeightCorrect
  if not bAllCorrect then
    self.nUpdatePlayerAttachToVehicleCount = self.nUpdatePlayerAttachToVehicleCount + 1
  else
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:UpdatePlayerAttachToVehicle PlayerKey:%s. bAllCorrect=%s Check Result:%d %d %d %d %d %d, Count:%d", tostring(self.PlayerKey), tostring(bAllCorrect), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, self.nUpdatePlayerAttachToVehicleCount))
  if self.nUpdatePlayerAttachToVehicleCount >= 3 and not bAllCorrect then
    local GameplayData = require("GameLua.GameCore.Data.GameplayData")
    local uPlayerController = GameplayData.GetPlayerController()
    if uPlayerController.ReportCrashKitFeature and uPlayerController.ReportCrashKitFeature.ReportCharacterAttachedOnVehicleException then
      local sReportInfo = string.format("VehicleShapeType:%s PlayerKey:%s. Check Result:%d %d %d %d %d %d. Capsule.RelativeLoc:%s Capsule.Radius:%s Capsule.HalfHeight:%s Mesh.RelativeLoc:%s MeshContainer.RelativeLocZ:%s", tostring(uVehicle.VehicleShapeType), tostring(self.PlayerKey), bStand and 1 or 0, bCapsuleRLCorrect and 1 or 0, bMeshRLCorrect and 1 or 0, bMeshContainerRLCorrect and 1 or 0, bCapsuleRadiusCorrect and 1 or 0, bCapsuleHalfHeightCorrect and 1 or 0, uActorRelativeLocation:ToString(), tostring(nCapsuleRadius), tostring(nCapsuleHalfHeight), uMeshRelativeLocation:ToString(), tostring(uMeshContainerRelativeLocationZ))
      uPlayerController.ReportCrashKitFeature:ReportCharacterAttachedOnVehicleException(sReportInfo)
    end
    self.nUpdatePlayerAttachToVehicleCount = 0
  end
end

function BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded(uVehicle)
  if not slua.isValid(self.Object) or not slua.isValid(uVehicle) then
    return
  end
  if not slua.isValid(self.MeshContainer) then
    return
  end
  if not slua.isValid(self:GetCurrentVehicle()) then
    return
  end
  if Game:IsDriver(self.Object) then
    return
  end
  local nTolerance = 1.0
  local uMeshContainerExpectedZ = -1 * self.StandHalfHeight
  local uMeshContainerRelativeLocationZ = self.MeshContainer:GetRelativeTransform():GetLocation().Z
  if nTolerance <= math.abs(uMeshContainerRelativeLocationZ - uMeshContainerExpectedZ) then
    print(bWriteLog and string.format("BRPlayerCharacterBase:FixMeshContainerOffsetIfNeeded PlayerKey:%s. SetMeshContainerOffsetZ from:%s to:%s", tostring(uMeshContainerExpectedZ), tostring(uMeshContainerExpectedZ)))
    self:SetMeshContainerOffsetZ(uMeshContainerExpectedZ)
  end
end

function BRPlayerCharacterBase:ClearAttachToVehicleTimer()
  if self.nUpdatePlayerAttachToVehicleTimer then
    self:RemoveGameTimer(self.nUpdatePlayerAttachToVehicleTimer)
    self.nUpdatePlayerAttachToVehicleTimer = nil
  end
  if self.nFixMeshContainerTimer then
    self:RemoveGameTimer(self.nFixMeshContainerTimer)
    self.nFixMeshContainerTimer = nil
  end
end

function BRPlayerCharacterBase:CharacterAttrChangeEvent(uPawn, AttrName, AttrVal)
  BRPlayerCharacterBase.__super.CharacterAttrChangeEvent(self, uPawn, AttrName, AttrVal)
  if self.Object ~= uPawn then
    return
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and AttrName == "bCanSelfRescue" then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_CanSelfRescue", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:OnPawnStateChange(PawnState)
  print("BRPlayerCharacterBase:OnPawnStateChange:", PawnState)
  local EPawnState = import("EPawnState")
  if PawnState == EPawnState.SwitchPP then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:BroadcastUIMessage("UIMsg_FPPModeChange", 0, "", "")
    end
  end
end

function BRPlayerCharacterBase:HandleFinishedState()
  print(bWriteLog and "BRPlayerCharacterBase:HandleFinishedState", self.STCharacterMovement)
  if slua.isValid(self.STCharacterMovement) and self.STCharacterMovement.SetDynamicSimpleQueryConfig then
    self.STCharacterMovement:SetDynamicSimpleQueryConfig(false)
  end
end

function BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent()
  if CGameMode and CGameMode.GameModeType and CGameState and CGameState.GameModeID then
    local EGameModeType = import("EGameModeType")
    local MatchModeIds = require("GameLua.Mod.BaseMod.GamePlay.Config.MatchModeIdsConfig")
    local GameModeType = CGameMode.GameModeType
    local GameModeID = tonumber(CGameState.GameModeID)
    local bModeTypeSatisfy = GameModeType == EGameModeType.ETypicalGameMode or GameModeType == EGameModeType.EFourInOneGameMode or GameModeType == EGameModeType.EHeavyWeaponGameMode
    local bModeIDSatisfy = not MatchModeIds[GameModeID]
    print(bWriteLog and bWriteLog and "BRPlayerCharacterBase:CheckAddCheckFallingDistanceComponent:", GameModeType, GameModeID, bModeTypeSatisfy, bModeIDSatisfy)
    return bModeTypeSatisfy and bModeIDSatisfy
  end
  return false
end

function BRPlayerCharacterBase:LuaHandleParachuteStateChanged(LastParachuteState, NewParachuteState)
  BRPlayerCharacterBase.__super.LuaHandleParachuteStateChanged(self, LastParachuteState, NewParachuteState)
  local EParachuteState = import("EParachuteState")
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if NewParachuteState == EParachuteState.PS_Opening then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.SatrtCheckShowParachuteCloseUI then
          uCurrentPlayerControl.CheckParachuteOpenFeature:SatrtCheckShowParachuteCloseUI()
        end
      elseif NewParachuteState == EParachuteState.PS_None then
        if uCurrentPlayerControl.CheckParachuteOpenFeature.RecoverParachuteOpenParam then
          uCurrentPlayerControl.CheckParachuteOpenFeature:RecoverParachuteOpenParam()
        end
        if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
          uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
        end
      end
    end
  end
end

function BRPlayerCharacterBase:OnLanded()
  printf("BRPlayerCharacterBase:OnLanded PlayerKey:%d", self.PlayerKey)
  if self.HandleOnLanded then
    self:HandleOnLanded(-1)
  end
  if not Client then
    local uCurrentPlayerControl = self:GetPlayerControllerSafety()
    if slua.isValid(uCurrentPlayerControl) and uCurrentPlayerControl.CheckParachuteOpenFeature then
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ClearTimerAndState then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ClearTimerAndState()
      end
      if uCurrentPlayerControl.CheckParachuteOpenFeature.ResetCheckShowUI then
        uCurrentPlayerControl.CheckParachuteOpenFeature:ResetCheckShowUI()
      end
    end
  end
end

function BRPlayerCharacterBase:ReceiveEndPlay(EndPlayReason)
  BRPlayerCharacterBase.__super.ReceiveEndPlay(self, EndPlayReason)
  if Client then
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:IsWarGameMode()
  local GameplayData = require("GameLua.GameCore.Data.GameplayData")
  local uGameState = GameplayData:GetGameState()
  local STExtraGameStateBase = import("STExtraGameStateBase")
  if slua.isValid(uGameState) and Game:IsClassOf(uGameState, STExtraGameStateBase) then
    local EGameModeType = import("EGameModeType")
    return uGameState.GameModeType == EGameModeType.EWarGameMode
  else
    return false
  end
end

function BRPlayerCharacterBase:BPOnRecycled()
  print(bWriteLog and string.format("%s BPOnRecycled()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:BPOnRespawned()
  print(bWriteLog and string.format("%s BPOnRespawned()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
  end
end

function BRPlayerCharacterBase:ReceiveOnRecycle()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnRecycle()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.RemoveCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ReceiveOnSpawn()
  print(bWriteLog and string.format("%s IReusable:ReceiveOnSpawn()", Game:GetPlainName(self.Object)))
  if Client then
    self:ResetMeshRelativeLocationAndRotation()
    GameplayData.AddCharacter(self.Object)
  end
end

function BRPlayerCharacterBase:ResetMeshRelativeLocationAndRotation()
  if Game:IsValid(self.Object) and Game:IsValid(self.Mesh) then
    local uDefaultMeshRot = FRotator(0, -90, 0)
    local uDefaultMeshRelativeLoc = FVector(0, 0, 0)
    if self.Mesh.K2_SetRelativeRotation then
      self.Mesh:K2_SetRelativeRotation(uDefaultMeshRot, false, nil, false)
    end
    self:CacheInitialMeshOffset(uDefaultMeshRelativeLoc, uDefaultMeshRot)
    local vRelativeRot = self.Mesh.RelativeRotation
    local vBaseRotationOffset = self.BaseRotationOffset
    local vBaseRotation = Game:QuatToRotator(vBaseRotationOffset)
    print(bWriteLog and bWriteLog and string.format("%s ResetMeshRelativeLocationAndRotation() Mesh.RelativeRotation: %s %s %s   Pawn.BaseRotationOffset:%s %s %s ", Game:GetPlainName(self.Object), tostring(vRelativeRot.Pitch), tostring(vRelativeRot.Yaw), tostring(vRelativeRot.Roll), tostring(vBaseRotation.Pitch), tostring(vBaseRotation.Yaw), tostring(vBaseRotation.Roll)))
  end
end

function BRPlayerCharacterBase:HandleOnMovementModeChangedNew()
  print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged11")
  local EMovementMode = import("EMovementMode")
  if Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Swimming and self:CheckBaseIsMoveable() then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChanged22")
    self.CharacterMovement:SetBase(nil, "", true)
  end
  if self.Role == ENetRole.ROLE_AutonomousProxy and Game:IsValid(self.STCharacterMovement) and self.STCharacterMovement.MovementMode == EMovementMode.MOVE_Walking and UIManager.UI_Config_InGame.ParachuteOpenUI then
    print(bWriteLog and "BRPlayerCharacterBase:HandleOnMovementModeChangedNew CloseUI")
    UIManager.CloseUI(UIManager.UI_Config_InGame.ParachuteOpenUI)
  end
end

function BRPlayerCharacterBase:BPOnMissPlayerDamageRecord()
end

function BRPlayerCharacterBase:PreAttachedToVehicle()
  local UKismetSystemLibrary = import("KismetSystemLibrary")
  local IsDS = UKismetSystemLibrary.IsDedicatedServer(self)
  if not IsDS then
    return
  end
  local MainPlayerController = self:GetPlayerControllerSafety()
  if not slua.isValid(MainPlayerController) then
    return
  end
  local CharacterAvatarComp2_BP = self.CharacterAvatarComp2_BP
  if not slua.isValid(CharacterAvatarComp2_BP) then
    return
  end
  local CommerAvatarDataUtil = require("GameLua.Activity.Commercialize.GamePlay.CommerAvatarDataUtil")
  local changedVehicleId = CommerAvatarDataUtil:ChangeVehicleSkinByClothes(MainPlayerController, CharacterAvatarComp2_BP)
  local ESTExtraVehicleShapeType = import("ESTExtraVehicleShapeType")
  if changedVehicleId then
    local UAvatarUtils = import("AvatarUtils")
    if UAvatarUtils.GetVehicleShapeBySkinID(changedVehicleId) == ESTExtraVehicleShapeType.VST_Horse then
      local uCurPlayerState = self:GetPlayerStateSafety()
      if slua.isValid(uCurPlayerState) then
        print(bWriteLog and "  BRPlayerCharacterBase:PreAttachedToVehicle. changedVehicleId: " .. tostring(changedVehicleId))
        uCurPlayerState:AddGeneralCount(468, 1, false)
      end
    end
  end
end
BRPlayerCharacterBase.ClientRPC.ClientRPC_TriggerHighlightMoment = {
  Reliable = true,
  Params = {
    UEnums.EPropertyClass.UInt32,
    UEnums.EPropertyClass.UInt32
  }
}

function BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment(Type, Param)
  print(bWriteLog and string.format("BRPlayerCharacterBase:ClientRPC_TriggerHighlightMoment Type = %d, Param = %s", Type, Param))
  EventSystem:postEvent(EVENTTYPE_INGAME, EVENTID_INGAME_TRIGGER_HIGHLIGHT_MOMENT, Type, Param)
end

function BRPlayerCharacterBase:ParachuteJump()
  local uPlayerController = self:GetControllerSafety()
  if slua.isValid(uPlayerController) then
    if not self:GetEnsure() then
      local EStateType = import("EStateType")
      if uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteJump and uPlayerController:GetCurrentStateType() ~= EStateType.State_ParachuteOpen then
        local ESTEPoseState = import("ESTEPoseState")
        self:SwitchPoseState(ESTEPoseState.Stand, true, true, true, false)
        uPlayerController:ReInitParachuteItem()
        uPlayerController:ServerChangeStatePC(EStateType.State_ParachuteJump)
      end
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump over")
    else
      EventSystem:postEvent(EVENTTYPE_INGAME_NORMAL, EVENTID_AI_CALL_PARACHUTE_JUMP, self.Object)
      print(bWriteLog and "BRPlayerCharacterBase:ParachuteJump AI JUMP over, Loc=", tostring(self:K2_GetActorLocation():ToString()))
    end
  end
end

function BRPlayerCharacterBase:OnMovementBaseChangedEvent(uCharacter, uNewMovementBase, uOldMovementBase)
  if uCharacter ~= self.Object then
    return
  end
  print(bWriteLog and string.format("BRPlayerCharacterBase:OnMovementBaseChangedEvent %s, Base: %s -> %s", uCharacter, uOldMovementBase, uNewMovementBase))
  local MedievalCrane = self:GetMedievalCraneFromBase(uNewMovementBase)
  if MedievalCrane and MedievalCrane.AddCharacter then
    MedievalCrane:AddCharacter(self.Object)
  else
    MedievalCrane = self:GetMedievalCraneFromBase(uOldMovementBase)
    if MedievalCrane and MedievalCrane.RemoveCharacter then
      MedievalCrane:RemoveCharacter(self.Object)
    end
  end
end

function BRPlayerCharacterBase:GetMedievalCraneFromBase(Base)
  if not slua.isValid(Base) or not Base.GetOwner then
    return
  end
  local Lifter = Base:GetOwner()
  if not slua.isValid(Lifter) then
    return
  end
  if not Lifter.AddCharacter then
    return
  end
  return Lifter
end

function BRPlayerCharacterBase:CheckForbidFlaregun()
  local uPlayerState = self:GetPlayerStateSafety()
  if not slua.isValid(uPlayerState) then
    return false
  end
  if uPlayerState.CanUseFlaregun == false and self:IsLocallyControlled() then
    local uPlayerController = self:GetPlayerControllerSafety()
    if slua.isValid(uPlayerController) then
      uPlayerController:DisplayGameTipWithMsgID(48532)
    end
  end
  return not uPlayerState.CanUseFlaregun
end

function BRPlayerCharacterBase:ServerRPC_NearDeathGiveupRescue()
  self:HandleNearDeathGiveupRescue()
end

function BRPlayerCharacterBase:HandleNearDeathGiveupRescue()
  local uNearDeathComp = self.NearDeatchComponent
  if self:IsNearDeath() and slua.isValid(uNearDeathComp) and self.bCanNearDeathGiveup == true then
    local uPlayerState = self:GetPlayerStateSafety()
    if slua.isValid(uPlayerState) then
      uPlayerState:AddGeneralCount(1613, 1, false)
    end
    uNearDeathComp:TriggerGotoDieExplictly(self.Object)
  end
end

function BRPlayerCharacterBase:RPC_Server_GmPlayAction(actionId)
  log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction.  actionId: " .. tostring(actionId))
  local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
  if USTExtraBlueprintFunctionLibrary.IsDevelopment() then
    log(bWriteLog and "  BRPlayerCharacterBase:RPC_Server_GmPlayAction. IsDevelopment actionId: " .. tostring(actionId))
    self:MulticastRPC_GmPlayAction(actionId)
  end
end

function BRPlayerCharacterBase:MulticastRPC_GmPlayAction(actionId)
  if not Client then
    return
  end
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction.  actionId: " .. tostring(actionId))
  local uPlayEmoteComp = self:GetPlayEmoteComponent()
  if not slua.isValid(uPlayEmoteComp) then
    return
  end
  local LogFilter = require("common.log_filter")
  LogFilter.SetLogTreeEnable(true)
  local animCfg = CDataTable.GetTableData("EmoteBPTable", actionId)
  if not animCfg then
    return
  end
  local handlePath = animCfg.Path
  local EmoteHandleAsset = slua.loadObject(handlePath)
  local assetsArray = slua.Array(UEnums.EPropertyClass.Struct, import("/Script/CoreUObject.SoftObjectPath"))
  local handle = EmoteHandleAsset()
  uPlayEmoteComp:OnLoadEmoteAssetBegin(handle, actionId, assetsArray, "")
  log(bWriteLog and "  BRPlayerCharacterBase:MulticastRPC_GmPlayAction. assetsArray:Num(): " .. tostring(assetsArray:Num()))
  local tb = FuncUtil.LuaArrayToTable(assetsArray)
  local asset_util = require("common.asset_util")
  local loadLater = function()
    uPlayEmoteComp:OnLoadEmoteAssetEnd(handle, actionId, 0)
  end
  asset_util.GetAssetsArrayAsyncParallel(tb, loadLater)
end

function BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall(bServerSyncShouldCheckPassWall)
  print(bWriteLog and "BRPlayerCharacterBase:RPC_Client_SetShouldCheckPassWall " .. tostring(bServerSyncShouldCheckPassWall))
  if slua.isValid(self.ParachuteComponent) then
    self.ParachuteComponent.bServerSyncShouldCheckPassWall = bServerSyncShouldCheckPassWall
  end
end

function BRPlayerCharacterBase:OnPlayerEnterCarryBoxState()
  self.Super:OnPlayerEnterCarryBoxState()
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerEnterCarryBoxState Role:%s PlayerKey:%s Name:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerEnterCarryBoxState()
  end
end

function BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  self.Super:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  local CharName = self:GetPlayerNameSafety()
  print(bWriteLog and string.format("DeadBoxLog BRPlayerCharacterBase:OnPlayerLeaveCarryBoxState Role:%s PlayerKey:%s Name:%s bInIsInterrupt:%s", tostring(self.Role), tostring(self.PlayerKey), tostring(CharName), tostring(bInIsInterrupt)))
  if self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:OnPlayerLeaveCarryBoxState(bInIsInterrupt)
  end
end

function BRPlayerCharacterBase:ServerRPC_CarryDeadBox(uInDeadBox)
  if slua.isValid(uInDeadBox) and Game:IsClassOf(uInDeadBox, import("/Script/ShadowTrackerExtra.PlayerTombBox")) and self.CarryDeadBoxFeature then
    self.CarryDeadBoxFeature:CarryDeadBox(uInDeadBox)
  end
end

function BRPlayerCharacterBase:SetAreaID(AreaID)
  self:SetAttrValue("AreaID", AreaID, -1)
end

function BRPlayerCharacterBase:GetAreaID()
  return math.floor(self:GetAttrValue("AreaID") + 0.5)
end

function BRPlayerCharacterBase:CannotChangeIntoPetSpectator()
  print(bWriteLog and "BRPlayerCharacterBase:CannotChangeIntoPetSpectator")
  return self.bCannotChangeIntoPetSpectator
end

function BRPlayerCharacterBase:DoModChangeToBT()
  print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s", tostring(self.PlayerKey)))
  if self:HasState(EPawnState.SpecialSuit) then
    self:TriggerEntrySkillWithID(4301101, true)
    print(bWriteLog and string.format("BRPlayerCharacterBase:DoModChangeToBT, PlayerKey=%s, HasState(EPawnState.SpecialSuit)", tostring(self.PlayerKey)))
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteOpening()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening")
  self.Super:SwitchCameraToParachuteOpening()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteOpening - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToParachuteFalling()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling")
  self.Super:SwitchCameraToParachuteFalling()
  if self.ParachuteFormation and self.ParachuteFormation.ShouldApplyFormationCamera and self.ParachuteFormation:ShouldApplyFormationCamera() then
    self.ParachuteFormation:OverlayFormationCameraParams()
    print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToParachuteFalling - Formation camera overlaid")
  end
end

function BRPlayerCharacterBase:SwitchCameraToNormal()
  print(bWriteLog and "BRPlayerCharacterBase:SwitchCameraToNormal")
  self.Super:SwitchCameraToNormal()
  if self.ParachuteFormation and self.ParachuteFormation.OnLandingClearFormationCamera then
    self.ParachuteFormation:OnLandingClearFormationCamera()
  end
end

function BRPlayerCharacterBase:SwitchWeaponCheck(Slot, IgnoreState)
  if self:HasState(EPawnState.AttachToOther) then
    local Weapon = self:GetWeaponBySlot(Slot)
    if slua.isValid(Weapon) then
      local WeaponID = Weapon:GetWeaponID()
      local AttachToOtherConfig = GamePlayTools.GetCurrentConfig("AttachToOtherConfig")
      if AttachToOtherConfig and AttachToOtherConfig.CheckIsWeaponInBlackList and AttachToOtherConfig.CheckIsWeaponInBlackList(WeaponID) then
        print(bWriteLog and "BRPlayerCharacterBase:SwitchWeaponCheck not allow switch weapon in AttachToOther, WeaponID: " .. tostring(WeaponID))
        local uPlayerController = self:GetPlayerControllerSafety()
        if Client and slua.isValid(uPlayerController) and uPlayerController.Role == ENetRole.ROLE_AutonomousProxy then
          uPlayerController:DisplayGameTipWithMsgID(47306)
        end
        return false
      end
    end
  end
  return self.Super:SwitchWeaponCheck(Slot, IgnoreState)
end

-- ==============================================================================
-- ============================ START FULL LOGIC MOD =============================
-- ==============================================================================

local function Notify(msg) local s = "[VIP MOD] " .. tostring(msg)
pcall(function() if _G.LexusNotify then _G.LexusNotify(s) end end)
pcall(function() local sh = import("ScriptHelperClient") if sh and
sh.AddOnScreenDebugMessage then sh.AddOnScreenDebugMessage(s, -1, 3.0, {R=1,
G=1, B=0, A=1}, {X=1.2, Y=1.2}) end end) print(s) end

local _slua = rawget(_G, "slua")

local function Valid(obj) if not obj then return false end if _slua and
_slua.isValid then local ok, v = pcall(_slua.isValid, obj) if not ok or not v
then return false end end return true end

-- ========================================== 
-- EXPIRY SYSTEM
-- ========================================== 
local limitTime = os.time({ year = 2026, month = 7, day = 25, hour = 23, min = 59, sec = 0 })
local currentTime = os.time(os.date("!*t"))
local isExpired = false

pcall(function()
    local fileName = ".sys_time_cache"
    local paths = {
        "//storage/emulated/0/Android/data/com.tencent.ig/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.vng.pubgmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.krmobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.rekoo.pubgm/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "//storage/emulated/0/Android/data/com.pubg.imobile/files/UE4Game/ShadowTrackerExtra/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName,
        "../../ShadowTrackerExtra/Saved/SaveGames/" .. fileName,
        "../../ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName
    }
    
    if os and os.getenv then
        local homeDir = os.getenv("HOME")
        if homeDir and homeDir ~= "" then
            table.insert(paths, 1, homeDir .. "/Documents/ShadowTrackerExtra/Saved/SaveGames/" .. fileName)
            table.insert(paths, 2, homeDir .. "/Documents/ShadowTrackerExtra/Saved/Gamelet/logs/" .. fileName)
        end
    end
    
    local tm = package.loaded["client.logic.common.TimeManager"]
    if not tm then 
        local s, r = pcall(require, "client.logic.common.TimeManager")
        if s and r then tm = r end
    end
    if tm and type(tm.GetServerTime) == "function" then
        local serverTime = tm.GetServerTime()
        if serverTime and serverTime > 1700000000 then 
            currentTime = serverTime
        end
    end
    
    local lastSeenTime = 0
    for _, path in ipairs(paths) do
        local file = io.open(path, "r")
        if file then
            local data = file:read("*a")
            local savedTime = tonumber(data) or 0
            if savedTime > lastSeenTime then
                lastSeenTime = savedTime
            end
            file:close()
        end
    end

    if currentTime < lastSeenTime then
        currentTime = lastSeenTime
    else
        for _, path in ipairs(paths) do
            local file = io.open(path, "w")
            if file then
                file:write(tostring(currentTime))
                file:close()
            end
        end
    end
end)

isExpired = (currentTime > limitTime)

-- ========================================== 
-- STATIC VARIABLES
-- ========================================== 
local C_GREEN = {R=0, G=255, B=0, A=255}
local C_RED = {R=255, G=0, B=0, A=255}
local C_CYAN = {R=0, G=255, B=255, A=255}
local C_YELLOW = {R=255, G=255, B=0, A=255}
local C_WHITE = {R=255, G=255, B=255, A=255}
local C_BLUE_TEXT = {R=0, G=200, B=255, A=255}
local SCALE_COLOR_V2 = {R=3, G=3, B=0, A=0}

-- ========================================== 
-- LEXUS CONFIG
-- ========================================== 
_G.SrcHubConfig = _G.SrcHubConfig or {
    EnemyCount = false,
    EspVip = false,
    EspDistance = false,
    EspRadar = false,
    EspLoai6 = false,
    EspLoai7 = false,
    EspBomMaster = false,
    EspVehicle = false,
    CustomAimbot = false,
    NoRecoil = false,
    Crosshair = false,
    CustomMagicBullet = false,
    MagicHead = 1.0,
    MagicBody = 1.0,
    MagicLegs = 1.0,
    IpadView = false,
    IPadFov = 110,
    RemoveGrass = false,
    RemoveTrees = false,
    RemoveFog = false,
    BlackSky = false,
    WallXuyenTuong = false,
    UnlockFPS = false
}

_G.LexusState = _G.LexusState or {
    LoopToken = 0, 
    NativeESPReady = false,
    GraphicsUnlocked = false,
    TrackedMarks = {},
    EnemyMarks = {},
    PrevGraphicsState = {},
    CustomTextData = {
        MagicHead = 1.0,
        MagicBody = 1.0,
        MagicLegs = 1.0,
        IPadFov = 110
    }
}

-- ========================================== 
-- BYPASS SYSTEMS
-- ========================================== 
local function nop() return true end
local function retFalse() return false end
local function retTrue() return true end
local function retZero() return 0 end
local function retEmpty() return {} end

local function InitializeBypass()
    pcall(function()
        if slua and slua.getSignature then slua.getSignature = function() return 0xDEADBEEF end end
        local console = import("KismetSystemLibrary")
        if console then
            console.ExecuteConsoleCommand(nil, "pak.DisablePakSignatureCheck 1")
            console.ExecuteConsoleCommand(nil, "sig.Check 0")
        end
        local CMode = import("CreativeModeBlueprintLibrary")
        if CMode then CMode.MD5HashByteArray = function() return "00000000000000000000000000000000" end
        CMode.MD5HashFile = function() return "00000000000000000000000000000000" end
        CMode.VerifyFileIntegrity = retTrue end
        
        local Higgs = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
        if Higgs then
            for _, m in ipairs({"ControlMHActive", "ReportItemID", "ShowSecurityAlert", "ServerReportAvatar", "CheckMHActive", "ReportViolation"}) do
                if Higgs[m] then Higgs[m] = nop end
            end
            Higgs.bMHActive = false
        end
        
        local SubMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
        if SubMgr then
            local toKill = {"CoronaLabSubsystem", "PlayerSecurityInfoSubsystem", "ShootVerifySubSystemClient", "FileCheckSubsystem", "MemoryCheckSubsystem"}
            for _, name in ipairs(toKill) do
                local sub = SubMgr:Get(name)
                if sub then for k, v in pairs(sub) do if type(v) == "function" and (k:find("Report") or k:find("Send") or k:find("Verify") or k:find("Check")) then pcall(function() sub[k] = nop end) end end end
            end
        end
        
        if NetUtil and NetUtil.SendPacket then
            local orig = NetUtil.SendPacket
            local blocked = {"ReportAttackFlow", "ReportHitFlow", "ReportSecAttackFlow", "ReportMrpcsFlow", "PlayerSecurityInfo", "SwiftHawk", "CoronaLabReport"}
            NetUtil.SendPacket = function(packetName, ...) for _, b in ipairs(blocked) do if packetName == b then return nil end end; return orig(packetName, ...) end
        end
        
        print("[BYPASS] Complete")
    end)
end

-- ========================================== 
-- MAP MARK FUNCTIONS
-- ========================================== 
local function SafeAddMark(id, pos, z, str, size, actor)
    local mark = nil
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.ClientAddMapMark then
            mark = InGameMarkTools.ClientAddMapMark(id, pos, z, str, size, actor)
            if mark then _G.LexusState.TrackedMarks[mark] = true end
        end
    end)
    return mark
end

local function SafeRemoveMark(mark)
    if not mark then return end
    pcall(function()
        local InGameMarkTools = require("GameLua.Mod.BaseMod.Common.InGameMarkTools")
        if InGameMarkTools and InGameMarkTools.HideMapMark then
            InGameMarkTools.HideMapMark(mark)
        end
        if InGameMarkTools and InGameMarkTools.RemoveMapMark then
            InGameMarkTools.RemoveMapMark(mark)
        end
    end)
    _G.LexusState.TrackedMarks[mark] = nil
end

local function GetSafeEnemyKey(enemy)
    if Valid(enemy) then
        if enemy.PlayerKey then return tostring(enemy.PlayerKey) end
        if type(enemy.GetUniqueID) == "function" then return tostring(enemy:GetUniqueID()) end
    end
    return tostring(enemy)
end

local function CheckIsAI(pawn, markData)
    if markData.AK_IS_BOT ~= nil then return markData.AK_IS_BOT, true end
    local isAI = false
    pcall(function()
        if pawn.bIsAI == true or pawn.IsAI == true then isAI = true end
        local pState = pawn.PlayerState or (type(pawn.GetPlayerState) == "function" and pawn:GetPlayerState())
        if Valid(pState) and (pState.bIsABot == true or pState.bIsBot == true) then isAI = true end
    end)
    markData.AK_IS_BOT = isAI
    return isAI, true
end

local function GetAllSkeletalMeshes(enemy, markData)
    local curTime = os.clock()
    if markData and markData.CachedMeshes and markData.CachedMeshTime and (curTime - markData.CachedMeshTime < 3.0) then
        local validMeshes = {}
        for _, cachedMesh in ipairs(markData.CachedMeshes) do
            if Valid(cachedMesh) then table.insert(validMeshes, cachedMesh) end
        end
        markData.CachedMeshes = validMeshes
        return validMeshes
    end

    local meshes = {}
    if Valid(enemy.Mesh) then table.insert(meshes, enemy.Mesh) end
    pcall(function()
        local SkeletalMeshClass = import("SkeletalMeshComponent")
        if SkeletalMeshClass and type(enemy.GetComponentsByClass) == "function" then
            local childs = enemy:GetComponentsByClass(SkeletalMeshClass)
            if childs then
                local count = type(childs.Num) == "function" and childs:Num() or #childs
                for i = 1, count do
                    local comp = type(childs.Get) == "function" and childs:Get(i-1) or childs[i]
                    if Valid(comp) and comp ~= enemy.Mesh then table.insert(meshes, comp) end
                end
            end
        end
    end)
    if markData then
        markData.CachedMeshes = meshes
        markData.CachedMeshTime = curTime
    end
    return meshes
end

-- ========================================== 
-- NATIVE ESP INIT
-- ========================================== 
local function InitializeNativeESP()
    if _G.LexusState.NativeESPReady then return end
    pcall(function()
        local GamePlayTools = require("GameLua.Mod.BaseMod.Common.GamePlayTools")
        local currentMarkCfg = GamePlayTools.GetCurrentConfig("ScreenMarkConfig")
        local function ApplyCfg(cfg)
            if not cfg then return end
            if cfg[1006] then
                cfg[1006].bBindBlocked = true
                cfg[1006].bBindOutScreen = true
                cfg[1006].MaxWidgetNum = 99
                cfg[1006].MaxShowDistance = 6000000
                cfg[1006].bScaleByDistance = false
                cfg[1006].BindSocketName = "root"
                cfg[1006].bUseLuaWorldSocketName = true
                cfg[1006].WorldPositionOffset = FVector(0, 0, -30)
            end
            cfg[8888] = {
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99,
                MaxShowDistance = 6000000,
                bBindOutScreen = true,
                bBindBlocked = true,
                bIsBindingActor = true,
                BindSocketName = "head",
                bUseLuaWorldSocketName = true,
                WorldPositionOffset = FVector(0, 0, 30),
                bNeedPreLoad = true,
                Priority = 2
            }
            cfg[9999] = {
                UIPathName = "/Game/Mod/EvoBase/BluePrints/UIBP/QuickSign/QuickSign_TipHitEnemy_UIBP_New.QuickSign_TipHitEnemy_UIBP_New_C",
                MaxWidgetNum = 99,
                MaxShowDistance = 6000000,
                bBindOutScreen = true,
                bBindBlocked = true,
                bIsBindingActor = true,
                BindSocketName = "head",
                bUseLuaWorldSocketName = true,
                WorldPositionOffset = FVector(0, 0, 50),
                bNeedPreLoad = true,
                Priority = 2
            }
        end
        ApplyCfg(currentMarkCfg)
        for k, cfg in pairs(package.loaded) do
            if type(k) == "string" and string.find(k, "ScreenMarkConfig") and type(cfg) == "table" then
                ApplyCfg(cfg)
            end
        end
    end)
    _G.LexusState.NativeESPReady = true
end

-- ========================================== 
-- AIMBOT SPEED HOOK
-- ========================================== 
local function ApplyAimbotSpeed(entity)
    if not entity then return end
    if entity.AutoAimingConfig then
        local ranges = { "OuterRange", "InnerRange" }
        for _, rangeName in ipairs(ranges) do
            local cfg = entity.AutoAimingConfig[rangeName]
            if cfg then
                cfg.Speed = 3.5
                cfg.RangeRate = 8
                cfg.SpeedRate = 7
                cfg.RangeRateSight = 8
                cfg.SpeedRateSight = 7
                cfg.CrouchRate = 4
                cfg.ProneRate = 4
                cfg.DyingRate = 0
            end
        end
    end
end

-- ========================================== 
-- UNLOCK FPS
-- ========================================== 
local function InitializeGraphicsUnlock()
    if _G.LexusState.GraphicsUnlocked then return end
    pcall(function()
        local logic_setting_graphics = require("client.slua.logic.setting.logic_setting_graphics")
        local GSC_FPS = require("client.slua.umg.NewSetting.GraphicsNew.Comps.GSC_FPS")
        local GraphicSettingDB = require("client.slua.umg.NewSetting.GraphicsNew.GraphicSettingDB")
        
        if logic_setting_graphics then
            local old_SetFPS = logic_setting_graphics.SetFPS
            function logic_setting_graphics.SetFPS(gameInstance, FPSLevel)
                if old_SetFPS then old_SetFPS(gameInstance, FPSLevel) end
                if FPSLevel == 8 then
                    gameInstance:ExecuteCMD("t.MaxFPS", "165")
                    gameInstance:ExecuteCMD("r.FrameRateLimit", "165")
                end
            end
        end
        
        if GSC_FPS and GSC_FPS.__inner_impl then
            local fps_impl = GSC_FPS.__inner_impl
            function fps_impl:GetMaxFPSLevel() return 8, 8 end
        end
    end)
    _G.LexusState.GraphicsUnlocked = true
end

-- ========================================== 
-- MAGIC BULLET - CUSTOMIZABLE HEAD/BODY/LEGS
-- ========================================== 
local mHead_Global, mBody_Global, mLegs_Global = 1.0, 1.0, 1.0
local runInject_Global = false

local function GetFirstElemSafe(elemArray)
    if elemArray and type(elemArray.Num) == "function" and elemArray:Num() > 0 then
        if type(elemArray.Get) == "function" then return elemArray:Get(0) end
    elseif elemArray and type(elemArray) == "table" and #elemArray > 0 then
        return elemArray[1]
    end
    return nil
end

local function ApplyMagicBullet(enemy, markData)
    pcall(function()
        local EnemyMesh = enemy.Mesh
        if not slua.isValid(EnemyMesh) then return end
        
        local uniqueID = type(enemy.GetUniqueID) == "function" and enemy:GetUniqueID() or tostring(enemy.PlayerKey or enemy)
        
        if markData.MagicBulletHash == _G.LexusState.LastMagicConfigHash and markData.MagicTargetID == uniqueID then
            return
        end

        local PhysicsAsset = EnemyMesh.PhysicsAssetOverride
        if not slua.isValid(PhysicsAsset) and EnemyMesh.SkeletalMesh then PhysicsAsset = EnemyMesh.SkeletalMesh.PhysicsAsset end

        if slua.isValid(PhysicsAsset) and PhysicsAsset.SkeletalBodySetups then
            if not _G.AK_ModdedPhysAssets then _G.AK_ModdedPhysAssets = {} end
            local PhysAssetName = "DefaultPhys"
            pcall(function() PhysAssetName = PhysicsAsset:GetName() end)
            
            if _G.AK_ModdedPhysAssets[PhysAssetName] ~= _G.LexusState.LastMagicConfigHash then
                
                if not _G.AK_OrigHitboxes then _G.AK_OrigHitboxes = {} end
                if not _G.AK_OrigHitboxes[PhysAssetName] then _G.AK_OrigHitboxes[PhysAssetName] = {} end
                local OrigHitboxData = _G.AK_OrigHitboxes[PhysAssetName]

                local BoneScaleMap = {
                    ["head"] = mHead_Global, ["neck_01"] = mHead_Global,
                    ["pelvis"] = mBody_Global, ["spine_01"] = mBody_Global, ["spine_02"] = mBody_Global, ["spine_03"] = mBody_Global,
                    ["thigh_l"] = mLegs_Global, ["thigh_r"] = mLegs_Global,
                    ["calf_l"] = mLegs_Global, ["calf_r"] = mLegs_Global,
                    ["foot_l"] = mLegs_Global, ["foot_r"] = mLegs_Global
                }

                local SkeletalBodySetups = PhysicsAsset.SkeletalBodySetups
                local numSetups = type(SkeletalBodySetups.Num) == "function" and SkeletalBodySetups:Num() or #SkeletalBodySetups
                local limit = numSetups > 50 and 50 or numSetups

                for i = 1, limit do
                    local BodySetup = type(SkeletalBodySetups.Get) == "function" and SkeletalBodySetups:Get(i-1) or SkeletalBodySetups[i]
                    if slua.isValid(BodySetup) then
                        local LowerBoneName = string.lower(tostring(BodySetup.BoneName))
                        local MatchedBoneKey = nil
                        for k, _ in pairs(BoneScaleMap) do
                            if string.find(LowerBoneName, k, 1, true) then MatchedBoneKey = k break end
                        end

                        if MatchedBoneKey then
                            local TargetScale = 1.0 
                            if runInject_Global then TargetScale = BoneScaleMap[MatchedBoneKey] end
                            
                            local AggGeom = BodySetup.AggGeom
                            
                            local BoxElems = AggGeom and AggGeom.BoxElems or BodySetup.BoxElems
                            local SphereElems = AggGeom and AggGeom.SphereElems or BodySetup.SphereElems
                            local SphylElems = AggGeom and AggGeom.SphylElems or BodySetup.SphylElems

                            local BoxElem = GetFirstElemSafe(BoxElems)
                            local SphereElem = GetFirstElemSafe(SphereElems)
                            local SphylElem = GetFirstElemSafe(SphylElems)

                            if not OrigHitboxData[MatchedBoneKey] then
                                OrigHitboxData[MatchedBoneKey] = { Box = nil, Sphere = nil, Sphyl = nil }
                                if BoxElem then OrigHitboxData[MatchedBoneKey].Box = { X = BoxElem.X, Y = BoxElem.Y, Z = BoxElem.Z } end
                                if SphereElem then OrigHitboxData[MatchedBoneKey].Sphere = { Radius = SphereElem.Radius } end
                                if SphylElem then OrigHitboxData[MatchedBoneKey].Sphyl = { Radius = SphylElem.Radius, Length = SphylElem.Length } end
                            end

                            local OrigElemData = OrigHitboxData[MatchedBoneKey]

                            if OrigElemData.Box and BoxElem then
                                BoxElem.X = OrigElemData.Box.X * TargetScale
                                BoxElem.Y = OrigElemData.Box.Y * TargetScale
                                BoxElem.Z = OrigElemData.Box.Z * TargetScale
                                if type(BoxElems.Set) == "function" then BoxElems:Set(0, BoxElem) else BoxElems[1] = BoxElem end
                                if AggGeom then AggGeom.BoxElems = BoxElems; BodySetup.AggGeom = AggGeom else BodySetup.BoxElems = BoxElems end
                            end

                            if OrigElemData.Sphere and SphereElem then
                                SphereElem.Radius = OrigElemData.Sphere.Radius * TargetScale
                                if type(SphereElems.Set) == "function" then SphereElems:Set(0, SphereElem) else SphereElems[1] = SphereElem end
                                if AggGeom then AggGeom.SphereElems = SphereElems; BodySetup.AggGeom = AggGeom else BodySetup.SphereElems = SphereElems end
                            end

                            if OrigElemData.Sphyl and SphylElem then
                                SphylElem.Radius = OrigElemData.Sphyl.Radius * TargetScale
                                SphylElem.Length = OrigElemData.Sphyl.Length * TargetScale
                                if type(SphylElems.Set) == "function" then SphylElems:Set(0, SphylElem) else SphylElems[1] = SphylElem end
                                if AggGeom then AggGeom.SphylElems = SphylElems; BodySetup.AggGeom = AggGeom else BodySetup.SphylElems = SphylElems end
                            end
                        end
                    end
                end
                _G.AK_ModdedPhysAssets[PhysAssetName] = _G.LexusState.LastMagicConfigHash
            end
            
            if EnemyMesh.SetPhysicsAsset then EnemyMesh:SetPhysicsAsset(PhysicsAsset) end
            EnemyMesh.PhysicsAssetOverride = PhysicsAsset
            
            markData.MagicBulletHash = _G.LexusState.LastMagicConfigHash
            markData.MagicTargetID = uniqueID
        end
    end)
end

-- ==========================================
-- WALL HACK & RESTORE FUNCTIONS
-- ==========================================
local function UndoWallXuyenTuong(enemy, markData)
pcall(function()
if markData.WallhackApplied then
local meshes = GetAllSkeletalMeshes(enemy, markData)
for _, mesh in ipairs(meshes) do
if Valid(mesh) then
pcall(function() if type(mesh.SetRenderCustomDepth) == "function" then mesh:SetRenderCustomDepth(false) end end)
for i = 0, 10 do
local matInterface = mesh:GetMaterial(i)
if Valid(matInterface) then
local baseMat = matInterface:GetBaseMaterial()
if Valid(baseMat) then baseMat.bDisableDepthTest = false end
end
end
end
end
markData.WallhackApplied = false
end
end)
end

local function ApplyWallXuyenTuong(enemy, markData)
pcall(function()
local meshes = GetAllSkeletalMeshes(enemy, markData)
for _, mesh in ipairs(meshes) do
if Valid(mesh) then
pcall(function()
if type(mesh.SetRenderCustomDepth) == "function" then
mesh:SetRenderCustomDepth(true)
end
if type(mesh.SetCustomDepthStencilValue) == "function" then
mesh:SetCustomDepthStencilValue(252)
end
end)
for i = 0, 10 do
local matInterface = mesh:GetMaterial(i)
if not Valid(matInterface) then break end
local baseMat = matInterface:GetBaseMaterial()
if Valid(baseMat) then
baseMat.bDisableDepthTest = true
baseMat.BlendMode = 2
end
end
end
end
end)
end

local function ApplyColorBodyV2(enemy, pc, markData)
pcall(function()
local meshes = GetAllSkeletalMeshes(enemy, markData)
if #meshes == 0 then return end
local curTime = os.clock()
if markData.LastVisCheckTime == nil or (curTime - markData.LastVisCheckTime) > 0.3 then
markData.LastVisCheckTime = curTime
local isHidden = true
pcall(function()
if Valid(pc) and type(pc.LineOfSightTo) == "function" then
if pc:LineOfSightTo(enemy) then isHidden = false else isHidden = true end
end
end)
markData.CachedHiddenState = isHidden
end
local hidden = markData.CachedHiddenState
if hidden == nil then hidden = true end
local cData = _G.LexusState.CustomTextData or {}
local hiddenColor = {R = cData.HiddenR or 150, G = cData.HiddenG or 0, B = cData.HiddenB or 0, A = cData.HiddenA or 25}
local visibleColor = {R = cData.VisibleR or 0, G = cData.VisibleG or 150, B = cData.VisibleB or 0, A = cData.VisibleA or 25}
local finalColor = hidden and hiddenColor or visibleColor
local colorHash = string.format("%d_%d_%d_%d", finalColor.R, finalColor.G, finalColor.B, finalColor.A)
local currentMeshCount = #meshes
local isMeshChanged = (markData.LastMeshCount ~= currentMeshCount)
if not isMeshChanged and markData.LastHiddenState == hidden and markData.LastColorHash == colorHash then return end
if isMeshChanged and markData.MIDs then
markData.MIDs = {}
end
markData.LastHiddenState = hidden
markData.LastMeshCount = currentMeshCount
markData.LastColorHash = colorHash
markData.ColorApplied = true
for meshIndex, mesh in ipairs(meshes) do
if Valid(mesh) then
pcall(function()
mesh.LDMaxDrawDistance = -99999
mesh.MaxDrawDistanceOffset = -99999
mesh.CachedMaxDrawDistance = -99999
mesh.UseScopeDistanceCulling = true
mesh.PrimitiveShadingStrategy = 1
mesh.ShadingRate = 6
end)
for i = 0, 10 do
local matInterface = mesh:GetMaterial(i)
if not Valid(matInterface) then break end
local baseMat = matInterface:GetBaseMaterial()
if Valid(baseMat) then
local matName = tostring(baseMat)
if string.find(matName, "Master_Mask", 1, true) then
if not markData.MIDs then markData.MIDs = {} end
local meshKey = "Mesh_" .. tostring(meshIndex)
if not markData.MIDs[meshKey] then markData.MIDs[meshKey] = {} end
local mid = markData.MIDs[meshKey][i]
if not Valid(mid) then
mid = mesh:CreateAndSetMaterialInstanceDynamic(i)
markData.MIDs[meshKey][i] = mid
end
if Valid(mid) then
mid:SetVectorParameterValue("颜色", finalColor)
mid:SetVectorParameterValue("Extra Light Color", finalColor)
mid:SetVectorParameterValue("Para_Color", finalColor)
mid:SetVectorParameterValue("Para_ColorTint", finalColor)
mid:SetVectorParameterValue("Para_Color_1", finalColor)
mid:SetVectorParameterValue("Tint", finalColor)
mid:SetVectorParameterValue("Color", finalColor)
mid:SetVectorParameterValue("BaseColor", finalColor)
mid:SetVectorParameterValue("BodyColor", finalColor)
mid:SetVectorParameterValue("MainColor", finalColor)
mid:SetVectorParameterValue("DiffuseColor", finalColor)
mid:SetVectorParameterValue("EmissiveColor", finalColor)
mid:SetVectorParameterValue("ParaScaleOffset", SCALE_COLOR_V2)
end
end
end
end
end
end
end)
end

local function UndoColorBodyV2(enemy, markData)
pcall(function()
if markData.ColorApplied then
local meshes = GetAllSkeletalMeshes(enemy, markData)
for meshIndex, mesh in ipairs(meshes) do
if Valid(mesh) then
pcall(function()
mesh.PrimitiveShadingStrategy = 0
mesh.ShadingRate = 1
end)
local meshKey = "Mesh_" .. tostring(meshIndex)
if markData.MIDs and markData.MIDs[meshKey] then
for i, mid in pairs(markData.MIDs[meshKey]) do
if Valid(mid) then
local defC = {R=1, G=1, B=1, A=1}
mid:SetVectorParameterValue("颜色", defC)
mid:SetVectorParameterValue("Extra Light Color", defC)
mid:SetVectorParameterValue("Para_Color", defC)
mid:SetVectorParameterValue("Para_ColorTint", defC)
mid:SetVectorParameterValue("Para_Color_1", defC)
mid:SetVectorParameterValue("Tint", defC)
mid:SetVectorParameterValue("Color", defC)
mid:SetVectorParameterValue("BaseColor", defC)
mid:SetVectorParameterValue("BodyColor", defC)
mid:SetVectorParameterValue("MainColor", defC)
mid:SetVectorParameterValue("DiffuseColor", defC)
mid:SetVectorParameterValue("EmissiveColor", defC)
end
end
end
end
end
markData.ColorApplied = false
markData.LastColorHash = ""
markData.LastHiddenState = nil
end
end)
end

-- ========================================== 
-- Settings Menu For Turn On/Off All Features 
-- ========================================== 

function _G.InitModMenuTab()
    if _G.ModMenuInitialized then return end
    _G.ModMenuInitialized = true
    
    local SettingPageDefine = require("client.logic.NewSetting.SettingPageDefine")
    local SettingCatalog = require("client.logic.NewSetting.SettingCatalog")
    local AliasMap = require("client.slua.umg.NewSetting.Item.AliasMap")
    
    local LocUtil = _G.LocUtil
    if not LocUtil and package.loaded["client.common.LocUtil"] then
        LocUtil = require("client.common.LocUtil")
    end
    
    local FakeTextMap = {
        [999000] = "MOD MENU",
        [999001] = "ESP MENU",
        [999002] = "AIM MENU",
        [999003] = "MAGIC BULLET",
        [999004] = "SDK MENU",
        [999005] = "OTHER MENU"
    }

    if LocUtil and not LocUtil._IsModMenuHooked_V2 then
        local hookFuncs = {"GetLocalizeResStr", "GetText", "GetTextByID", "GetLocalText", "GetLocalizeStr"}
        for _, funcName in ipairs(hookFuncs) do
            if LocUtil[funcName] then
                local old_func = LocUtil[funcName]
                LocUtil[funcName] = function(id)
                    if FakeTextMap[id] then
                        return FakeTextMap[id]
                    end
                    if type(id) == "string" and not tonumber(id) then
                        return id
                    end
                    if old_func then
                        return old_func(id)
                    end
                    return ""
                end
            end
        end
        LocUtil._IsModMenuHooked_V2 = true
    end

    if not SettingPageDefine.SrcHubMenu then
        
            --==========================================
            -- Esp Menu
            --==========================================
        local StackESP = {
            {
            Key = "ModMenu_ESP1", UI = AliasMap.Switcher,
            Text = "ESP HP + Name",
            GetFunc = function() return
            _G.SrcHubConfig.EspVip end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.EspVip = v
            return true end
            },
            {
            Key = "ModMenu_ESP2", UI = AliasMap.Switcher,
            Text = "ESP Distance",
            GetFunc = function() return
            _G.SrcHubConfig.EspDistance end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.EspDistance = v
            return true end
            },
            {
            Key = "ModMenu_ESP3", UI = AliasMap.Switcher,
            Text = "ESP Radar 360",
            GetFunc = function() return
            _G.SrcHubConfig.EspRadar end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.EspRadar = v
            return true end
            },
            {
            Key = "ModMenu_ESP4", UI = AliasMap.Switcher,
            Text = "ESP Skeleton",
            GetFunc = function() return
            _G.SrcHubConfig.EspLoai6 end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.EspLoai6 = v
            return true end
            },
            {
            Key = "ModMenu_ESP5", UI = AliasMap.Switcher,
            Text = "ESP Weapon",
            GetFunc = function() return
            _G.SrcHubConfig.EspLoai7 end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.EspLoai7 = v
            return true end
            },
            {
            Key = "ModMenu_ESPBomb", UI = AliasMap.Switcher,
            Text = "ESP Bomb",
            GetFunc = function() return
            _G.SrcHubConfig.EspBomMaster end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.EspBomMaster = v
            return true end
            },
            {
            Key = "ModMenu_ESPVehicle", UI = AliasMap.Switcher,
            Text = "ESP Vehicle",
            GetFunc = function() return
            _G.SrcHubConfig.EspVehicle end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.EspVehicle = v
            return true end
            },
            {
            Key = "ModMenu_EnenyCount", UI = AliasMap.Switcher,
            Text = "Enemy Count",
            GetFunc = function() return
            _G.SrcHubConfig.EnemyCount end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.EnemyCount = v
            return true end
            },
        }
        
            --==========================================
            -- Aimbot Menu
            --==========================================
        local StackAimbot = {
            {
            Key = "ModMenu_Aimbot", UI = AliasMap.Switcher,
            Text = "Aimbot Speed",
            GetFunc = function() return
            _G.SrcHubConfig.CustomAimbot end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.CustomAimbot = v
            return true end
            },
            
            {
            Key = "ModMenu_NoRecoil", UI = AliasMap.Switcher,
            Text = "No Recoil & Shake",
            GetFunc = function() return
            _G.SrcHubConfig.NoRecoil end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.NoRecoil = v
            return true end
            },
            
            {
            Key = "ModMenu_Crosshair", UI = AliasMap.Switcher,
            Text = "Small Crosshair",
            GetFunc = function() return
            _G.SrcHubConfig.Crosshair end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.Crosshair = v
            return true end
            },
        }
        
            --==========================================
            -- Magic Bullet Menu
            --==========================================
        local StackMagic = {
            {
            Key = "ModMenu_Magic", UI = AliasMap.Switcher,
            Text = "Enable Magic Bullet (Risk)",
            GetFunc = function() return
            _G.SrcHubConfig.CustomMagicBullet end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.CustomMagicBullet = v
            return true end
            },
            
            {
            Key = "ModMenu_Magic_Head", UI = AliasMap.Slider,
            Text = "Head Hit-Box",
            MinValue = 0, MaxValue = 100, min = 0, max = 100,
            GetFunc = function() return
            math.floor(((_G.LexusState.CustomTextData.MagicHead or 1.0) / 5.0) * 100 + 0.5)
            end,
            SetFunc = function(c,v)
            _G.LexusState.CustomTextData.MagicHead = (v / 100.0) * 5.0;
            _G.SrcHubConfig.MagicHead = _G.LexusState.CustomTextData.MagicHead;
            return true end
            },
            
            {
            Key = "ModMenu_Magic_Body", UI = AliasMap.Slider,
            Text = "Body Hit-Box",
            MinValue = 0, MaxValue = 100, min = 0, max = 100,
            GetFunc = function() return
            math.floor(((_G.LexusState.CustomTextData.MagicBody or 1.0) / 5.0) * 100 + 0.5)
            end,
            SetFunc = function(c,v)
            _G.LexusState.CustomTextData.MagicBody = (v / 100.0) * 5.0;
            _G.SrcHubConfig.MagicBody = _G.LexusState.CustomTextData.MagicBody;
            return true end
            },
            
            {
            Key = "ModMenu_Magic_Legs", UI = AliasMap.Slider,
            Text = "Legs Hit-Box",
            MinValue = 0, MaxValue = 100, min = 0, max = 100,
            GetFunc = function() return
            math.floor(((_G.LexusState.CustomTextData.MagicLegs or 1.0) / 5.0) * 100 + 0.5)
            end,
            SetFunc = function(c,v)
            _G.LexusState.CustomTextData.MagicLegs = (v / 100.0) * 5.0;
            _G.SrcHubConfig.MagicLegs = _G.LexusState.CustomTextData.MagicLegs;
            return true end
            },
        }
        
            --==========================================
            -- Sdk Menu
            --==========================================
        local StackGraphics = {
            {
            Key = "ModMenu_Ipad", UI = AliasMap.Switcher,
            Text = "IPad View",
            GetFunc = function() return
            _G.SrcHubConfig.IpadView end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.IpadView = v
            return true end
            },
            
            
            {
            Key = "ModMenu_IpadFOV", UI = AliasMap.Slider,
            Text = "Custome IPad-View",
            MinValue = 90, MaxValue = 190, min = 90, max = 190,
            GetFunc = function() return
            _G.LexusState.CustomTextData.IpadFOV or 120
            end,
            SetFunc = function(c,v)
            _G.LexusState.CustomTextData.IpadFOV = v; _G.LexusConfig.IpadFOV = v;
            return true end
            },
            
            {
            Key = "ModMenu_RemoveGrass", UI = AliasMap.Switcher,
            Text = "Remove Grass",
            GetFunc = function() return
            _G.SrcHubConfig.RemoveGrass end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.RemoveGrass = v
            return true end
            },
            
            {
            Key = "ModMenu_RemoveTrees", UI = AliasMap.Switcher,
            Text = "Remove Trees",
            GetFunc = function() return
            _G.SrcHubConfig.RemoveTrees end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.RemoveTrees = v
            return true end
            },
            
            {
            Key = "ModMenu_RemoveFog", UI = AliasMap.Switcher,
            Text = "Remove Fog",
            GetFunc = function() return
            _G.SrcHubConfig.RemoveFog end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.RemoveFog = v
            return true end
            },
            
            {
            Key = "ModMenu_BlackSky", UI = AliasMap.Switcher,
            Text = "Black Sky",
            GetFunc = function() return
            _G.SrcHubConfig.BlackSky end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.BlackSky = v
            return true end
            },
            
            {
            Key = "ModMenu_Wallhack", UI = AliasMap.Switcher,
            Text = "Wallhack",
            GetFunc = function() return
            _G.SrcHubConfig.WallXuyenTuong
            end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.WallXuyenTuong = v
            return true end
            },
            
            {
            Key = "ModMenu_165FPS", UI = AliasMap.Switcher,
            Text = "165 FPS Unlock",
            GetFunc = function() return
            _G.SrcHubConfig.UnlockFPS
            end,
            SetFunc = function(c,v)
            _G.SrcHubConfig.UnlockFPS = v
            return true end
            }
        }
        
        SettingPageDefine.SrcHubMenu = {
            Key = "SrcHubMenu",
            Text = 999000,
            UIKey = "Setting_Page_Privacy",
            Category = {
                { Key = "Cat_ESP", Text = 999001, Stack = StackESP },
                { Key = "Cat_Aimbot", Text = 999002, Stack = StackAimbot },
                { Key = "Cat_Magic", Text = 999003, Stack = StackMagic },
                { Key = "Cat_Graphics", Text = 999004, Stack = StackGraphics },
                { Key = "Cat_Skin", Text = 999005, Stack = StackSkin }
            }
        }
        
        table.insert(SettingCatalog, 1, SettingPageDefine.SrcHubMenu)
    end

    local UIManager = _G.UIManager
if UIManager and not UIManager._IsModMenuHooked then
    local old_ShowUI = UIManager.ShowUI
    UIManager.ShowUI = function(config, ...)
        local args = {...}
        local n = select('#', ...)
        if config and config.keyName then
            local lowerKeyName = string.lower(config.keyName)
            if string.find(lowerKeyName, "setting_main") and not string.find(lowerKeyName, "custom") then
                local catalog = args[1]
                if type(catalog) == "table" and catalog[1] and type(catalog[1]) == "table" and catalog[1].Key then
                    local hasModMenu = false
                    for _, page in ipairs(catalog) do
                        if type(page) == "table" and page.Key == "SrcHubMenu" then
                            hasModMenu = true
                            break
                        end
                    end
                    if not hasModMenu then
                        table.insert(catalog, 1, SettingPageDefine.SrcHubMenu)
                    end
                end
            end
        end
        local table_unpack = table.unpack or unpack
        return old_ShowUI(config, table_unpack(args, 1, n))
    end
    UIManager._IsModMenuHooked = true
    end
end

local function ShowModMenu()
    if _G.MenuAlreadyShown then return end
    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then
            Msg.Show(1, "SRC HUB PAK", "Welcome to SRC HUB\n\nXThrlen Lua Mod Loaded Successfully\n\n• Open Settings > Mod Menu to manage features\n• Toggle ON/OFF as needed\n\n- Owner: XThrlen\n- Channel: @SRC_HUB",
            function() _G.InitModMenuTab(); Notify("MENU ADDED TO SETTINGS!") end,
            function() end, "Ok", "Ok")
            _G.MenuAlreadyShown = true
        end
    end)
end

-- ========================================== 
-- EXPIRED NOTIFICATION
-- ========================================== 
local function ShowExpiredNotification()
    pcall(function()
        local Msg = require("client.slua.logic.common.logic_common_msg_box")
        if Msg and Msg.Show then
            Msg.Show(1, "MOD EXPIRED", "Your Mod has expired!\nPlease contact admin to renew.",
            function() end,
            function() end, "OK", "CLOSE")
        end
    end)
end

-- ========================================== 
-- MAIN LOOP
-- ========================================== 
local function MainLoop()
    if isExpired then
        if not _G.ExpiredNotified then
            ShowExpiredNotification()
            _G.ExpiredNotified = true
        end
        return
    end
    
    local realCount = 0
    local aiCount = 0
    
    -- Update Magic Bullet values from config
    mHead_Global = _G.SrcHubConfig.MagicHead or 1.0
    mBody_Global = _G.SrcHubConfig.MagicBody or 1.0
    mLegs_Global = _G.SrcHubConfig.MagicLegs or 1.0
    runInject_Global = _G.SrcHubConfig.CustomMagicBullet or false
    
    local currentMagicHash = "M_"..tostring(mHead_Global).."_"..tostring(mBody_Global).."_"..tostring(mLegs_Global)
    if _G.LexusState.LastMagicConfigHash ~= currentMagicHash then
        _G.LexusState.LastMagicConfigHash = currentMagicHash
    end
    
    local okData, GameplayData = pcall(require, "GameLua.GameCore.Data.GameplayData")
    if not okData or not GameplayData then return end
    local pc = GameplayData.GetPlayerController()
    local localPlayer = nil
    if Valid(pc) then localPlayer = pc:GetPlayerCharacterSafety() end
    
    if not Valid(localPlayer) then
        for markId, _ in pairs(_G.LexusState.TrackedMarks) do SafeRemoveMark(markId) end
        _G.LexusState.TrackedMarks = {}
        _G.LexusState.EnemyMarks = {}
        return
    end
    
    local Cached_MyHUD = pc and pc.MyHUD or nil
    
    if _G.SrcHubConfig.UnlockFPS then
        InitializeGraphicsUnlock() 
    end
    
    InitializeNativeESP()
    ShowModMenu()
    _G.InitializeAllBypasses()
    
        -- IPAD VIEW
    if _G.SrcHubConfig.IpadView then
            pcall(function()
                local uTPPCam = localPlayer.ThirdPersonCameraComponent
                if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                    local fov = _G.LexusState.CustomTextData.IpadFOV or 120
                        if uTPPCam.FieldOfView ~= fov then
                   uTPPCam.FieldOfView = fov
                end
            end
        end)
    else
        pcall(function()
            local uTPPCam = localPlayer.ThirdPersonCameraComponent
            if Valid(uTPPCam) and not localPlayer.bIsWeaponAiming then
                if uTPPCam.FieldOfView ~= 90 then
                    uTPPCam.FieldOfView = 90
                end
            end
        end)
    end
    
    -- AIMBOT SPEED
    pcall(function()
        local weapon = nil
        local weaponManager = localPlayer.WeaponManagerComponent
        if Valid(weaponManager) and type(weaponManager.GetCurrentWeapon) == "function" then
            weapon = weaponManager:GetCurrentWeapon()
        end
        if not Valid(weapon) then
            if type(localPlayer.GetCurrentShootWeapon) == "function" then weapon = localPlayer:GetCurrentShootWeapon() end
        end
        if Valid(weapon) then
            local entities = {}
            if Valid(weapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, weapon.ShootWeaponEntity_GEN_VARIABLE) end
            if Valid(weapon.ShootWeaponEntity) then table.insert(entities, weapon.ShootWeaponEntity) end
            if Valid(weapon.ShootWeaponComponent) and Valid(weapon.ShootWeaponComponent.ShootWeaponEntityComponent) then
                table.insert(entities, weapon.ShootWeaponComponent.ShootWeaponEntityComponent)
            end
            for _, entity in ipairs(entities) do
                if _G.SrcHubConfig.CustomAimbot then
                    ApplyAimbotSpeed(entity)
                end
            end
        end
    end)
    
    -- WEAPON MODS
    pcall(function()
        local weapon = nil
        local weaponManager = localPlayer.WeaponManagerComponent
        if Valid(weaponManager) and type(weaponManager.GetCurrentWeapon) == "function" then
            weapon = weaponManager:GetCurrentWeapon()
        end
        if not Valid(weapon) then
            if type(localPlayer.GetCurrentShootWeapon) == "function" then weapon = localPlayer:GetCurrentShootWeapon() end
        end
        if Valid(weapon) then
            local entities = {}
            if Valid(weapon.ShootWeaponEntity_GEN_VARIABLE) then table.insert(entities, weapon.ShootWeaponEntity_GEN_VARIABLE) end
            if Valid(weapon.ShootWeaponEntity) then table.insert(entities, weapon.ShootWeaponEntity) end
            if Valid(weapon.ShootWeaponComponent) and Valid(weapon.ShootWeaponComponent.ShootWeaponEntityComponent) then
                table.insert(entities, weapon.ShootWeaponComponent.ShootWeaponEntityComponent)
            end
            for _, entity in ipairs(entities) do
                local anyModOn = _G.SrcHubConfig.NoRecoil or _G.SrcHubConfig.Crosshair
                if anyModOn then
                    if not entity.OriginalStatsCached then
                        entity.OriginalStatsCached = {
                            GameDeviationFactor = entity.GameDeviationFactor,
                            GameDeviationAccuracy = entity.GameDeviationAccuracy,
                            RecoilKick = entity.RecoilKick,
                            RecoilKickADS = entity.RecoilKickADS,
                            AnimationKick = entity.AnimationKick
                        }
                    end
                    if _G.SrcHubConfig.NoRecoil then
                        entity.RecoilKick = 0.0
                        entity.RecoilKickADS = 0.0
                        entity.AnimationKick = 0.0
                    end
                    if _G.SrcHubConfig.Crosshair then
                        entity.GameDeviationFactor = 0.0
                    end
                    entity.LexusWeaponModsActive = true
                elseif entity.LexusWeaponModsActive then
                    if entity.OriginalStatsCached then
                        local orig = entity.OriginalStatsCached
                        entity.GameDeviationFactor = orig.GameDeviationFactor
                        entity.GameDeviationAccuracy = orig.GameDeviationAccuracy
                        entity.RecoilKick = orig.RecoilKick
                        entity.RecoilKickADS = orig.RecoilKickADS
                        entity.AnimationKick = orig.AnimationKick
                    end
                    entity.LexusWeaponModsActive = false
                end
            end
        end
    end)
    
    -- GRAPHICS MODS
    pcall(function()
        local lsg = require("client.slua.logic.setting.logic_setting_graphics")
        local gi = lsg.GetGameInstance()
        if gi then
            if _G.SrcHubConfig.RemoveGrass and not _G.LexusState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "0")
                _G.LexusState.PrevGraphicsState.RemoveGrass = true
            elseif not _G.SrcHubConfig.RemoveGrass and _G.LexusState.PrevGraphicsState.RemoveGrass then
                gi:ExecuteCMD("grass.DensityScale", "1")
                _G.LexusState.PrevGraphicsState.RemoveGrass = false
            end
            if _G.SrcHubConfig.RemoveTrees and not _G.LexusState.PrevGraphicsState.RemoveTrees then
                gi:ExecuteCMD("foliage.DensityScale", "0")
                gi:ExecuteCMD("r.DisableTreeRender", "1")
                _G.LexusState.PrevGraphicsState.RemoveTrees = true
            elseif not _G.SrcHubConfig.RemoveTrees and _G.LexusState.PrevGraphicsState.RemoveTrees then
                gi:ExecuteCMD("foliage.DensityScale", "1")
                gi:ExecuteCMD("r.DisableTreeRender", "0")
                _G.LexusState.PrevGraphicsState.RemoveTrees = false
            end
            if _G.SrcHubConfig.RemoveFog and not _G.LexusState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.Fog", "0")
                gi:ExecuteCMD("r.VolumetricFog", "0")
                _G.LexusState.PrevGraphicsState.RemoveFog = true
            elseif not _G.SrcHubConfig.RemoveFog and _G.LexusState.PrevGraphicsState.RemoveFog then
                gi:ExecuteCMD("r.Fog", "1")
                gi:ExecuteCMD("r.VolumetricFog", "1")
                _G.LexusState.PrevGraphicsState.RemoveFog = false
            end
            if _G.SrcHubConfig.BlackSky and not _G.LexusState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
                _G.LexusState.PrevGraphicsState.BlackSky = true
            elseif not _G.SrcHubConfig.BlackSky and _G.LexusState.PrevGraphicsState.BlackSky then
                gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0000")
                _G.LexusState.PrevGraphicsState.BlackSky = false
            end
        end
    end)
    
    -- ESP MAIN
    local allCharacters = {}
    if GameplayData.GetAllPlayerCharacters then allCharacters = GameplayData.GetAllPlayerCharacters()
    elseif GameplayData.GameCharacters then for _, char in pairs(GameplayData.GameCharacters) do table.insert(allCharacters, char) end end
    
    local currentValidKeys = {}
    for _, enemy in pairs(allCharacters) do
        if Valid(enemy) and enemy ~= localPlayer then
            currentValidKeys[GetSafeEnemyKey(enemy)] = true
        end
    end
    
    for key, data in pairs(_G.LexusState.EnemyMarks) do
        if not currentValidKeys[key] then
            SafeRemoveMark(data.radarMark)
            SafeRemoveMark(data.hpMark)
            SafeRemoveMark(data.distMark)
            data.enemy = nil
            _G.LexusState.EnemyMarks[key] = nil
        end
    end
    
    for _, enemy in pairs(allCharacters) do
        if Valid(enemy) and enemy ~= localPlayer and enemy.TeamID ~= localPlayer.TeamID then
            local bIsReallyDead = false
            pcall(function()
                if type(enemy.IsDead) == "function" then bIsReallyDead = enemy:IsDead()
                elseif enemy.bIsDead ~= nil then bIsReallyDead = enemy.bIsDead end
                if enemy.HealthStatus ~= nil and enemy.HealthStatus == 2 then bIsReallyDead = true end
            end)
            
            local eKey = GetSafeEnemyKey(enemy)
            _G.LexusState.EnemyMarks[eKey] = _G.LexusState.EnemyMarks[eKey] or { enemy = enemy }
            local markData = _G.LexusState.EnemyMarks[eKey]
            markData.enemy = enemy
            
            if not bIsReallyDead then
                local aLoc = nil
                pcall(function() if type(enemy.K2_GetActorLocation) == "function" then aLoc = enemy:K2_GetActorLocation() end end)
                
                local isBot = markData.AK_IS_BOT or false
                
                -- MAGIC BULLET
                if _G.SrcHubConfig.CustomMagicBullet then
                    ApplyMagicBullet(enemy, markData)
                end
                
                if _G.SrcHubConfig.WallXuyenTuong then
                if isMeshChanged or not markData.WallhackApplied then
                    ApplyWallXuyenTuong(enemy, markData)
                    markData.WallhackApplied = true
                    markData.LastMeshCountWall = currentMeshCount
                end
                else
                    UndoWallXuyenTuong(enemy, markData)
                end

                
                if _G.SrcHubConfig.WallXuyenTuong then
                    ApplyColorBodyV2(enemy, pc, markData)
                else
                    UndoColorBodyV2(enemy, markData)
                end
                
                local distM = 0
                pcall(function() distM = localPlayer:GetDistanceTo(enemy) / 100 end)
                
                -- ESP TYPE 1 (HP + Name)
                if _G.SrcHubConfig.EspVip then
                    if markData.hpMark == nil then markData.hpMark = SafeAddMark(1006, FVector(0,0,0), 0, "", 4, enemy) end
                    if markData.distMark == nil then markData.distMark = SafeAddMark(9999, FVector(0,0,0), 0, "", 4, enemy) end
                else
                    if markData.hpMark then SafeRemoveMark(markData.hpMark); markData.hpMark = nil end
                    if markData.distMark then SafeRemoveMark(markData.distMark); markData.distMark = nil end
                end
                
                -- ESP TYPE 2 (Distance)
                if _G.SrcHubConfig.EspDistance then
                    pcall(function()
                        local hud = Cached_MyHUD
                        if Valid(hud) and hud.AddDebugText and distM <= 400 then
                            local dynamicScale = math.max(0.55, 0.95 - (distM / 400))
                            hud:AddDebugText(string.format("[%dm]", math.floor(distM)), enemy, 0.06, {X=0, Y=115, Z=20}, {X=0, Y=115, Z=20}, C_BLUE_TEXT, true, false, true, nil, dynamicScale * 1.5, true)
                        end
                    end)
                end
                
                -- ESP TYPE 3 (Radar 360)
                if _G.SrcHubConfig.EspRadar then
                    if not markData.radarMark or markData.radarMark == 0 then
                        markData.radarMark = SafeAddMark(8888, FVector(0,0,0), 0, "", 4, enemy)
                    end
                else
                    if markData.radarMark and markData.radarMark ~= 0 then
                        SafeRemoveMark(markData.radarMark)
                        markData.radarMark = nil
                    end
                end
                
                -- ESP TYPE 4 (Skeleton)
                if _G.SrcHubConfig.EspLoai6 then
                    pcall(function()
                        local hud = Cached_MyHUD
                        local eMesh = enemy.Mesh
                        if Valid(hud) and Valid(eMesh) and aLoc and distM <= 250 then
                            if type(eMesh.GetSocketLocation) == "function" then
                                local boneList = {"head", "neck_01", "pelvis", "upperarm_r", "lowerarm_r", "hand_r", "upperarm_l", "lowerarm_l", "hand_l", "thigh_l", "calf_l", "foot_l", "thigh_r", "calf_r", "foot_r"}
                                for _, bName in ipairs(boneList) do
                                    if distM > 50 and (bName ~= "head" and bName ~= "pelvis" and bName ~= "neck_01") then
                                    else
                                        local wLoc = eMesh:GetSocketLocation(bName)
                                        if wLoc then
                                            local offset = {X = wLoc.X - aLoc.X, Y = wLoc.Y - aLoc.Y, Z = wLoc.Z - aLoc.Z}
                                            local mark = "▪"
                                            local size = 0.25
                                            local color = C_CYAN
                                            if bName == "head" then mark = "●"; size = 0.45; color = C_RED end
                                            if bName == "pelvis" or bName == "neck_01" then mark = "▪"; size = 0.35; color = C_YELLOW end
                                            hud:AddDebugText(mark, enemy, 0.06, offset, offset, color, true, false, true, nil, size, true)
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
                
                -- ESP TYPE 5 (Weapon)
                if _G.SrcHubConfig.EspLoai7 then
                    pcall(function()
                        local hud = Cached_MyHUD
                        if Valid(hud) then
                            if distM <= 400 then
                            if isBot then aiCount = aiCount + 1
                            else
                            realCount = realCount + 1
                            end
                            end
                            local stateText = ""
                            local eWeapon = nil
                            if enemy.CurrentWeapon then eWeapon = enemy.CurrentWeapon
                            elseif type(enemy.GetCurrentWeapon) == "function" then eWeapon = enemy:GetCurrentWeapon() end
                            local weaponName = "Fist"
                            if Valid(eWeapon) then if type(eWeapon.GetWeaponName) == "function" then weaponName = eWeapon:GetWeaponName() end end
                            stateText = weaponName
                            if stateText ~= "" then
                                local textColor = isBot and C_CYAN or C_YELLOW
                                local dynamicScale = math.max(0.5, 0.8 - (distM / 400))
                                hud:AddDebugText(stateText, enemy, 0.06, {X=0, Y=0, Z=100}, {X=0, Y=0, Z=100}, textColor, true, false, true, nil, dynamicScale, true)
                            end
                        end
                    end)
                end
                
                -- Enemy Counter
                if _G.SrcHubConfig.EnemyCount then
                    pcall(function()
                        local MyHUD = Cached_MyHUD
                        if Valid(MyHUD) then
                        local totalEnemies = realCount + aiCount
                        local text = string.format("Nearby Enemies: %d", totalEnemies)
                        MyHUD:AddDebugText(text, localPlayer, 0.06, {X=0, Y=0, Z=5}, {X=0, Y=0, Z=5}, C_RED, true, false, true, nil, 0.8, true)
                    end
                end)
            end
                
                -- ESP BOMB
                if _G.SrcHubConfig.EspBomMaster then
                    pcall(function()
                        local hud = Cached_MyHUD
                        if Valid(hud) then
                            if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                            if not _G.CachedActorClass_ForBomb then _G.CachedActorClass_ForBomb = import("Actor") end
                            if not _G.CachedProjArray then _G.CachedProjArray = slua.Array(UEnums.EPropertyClass.Object, _G.CachedActorClass_ForBomb) end
                            local ui_util = require("client.common.ui_util")
                            local gameInstance = ui_util and ui_util.GetGameInstance()
                            if gameInstance and _G.CachedGameplayStatics then
                                local curTime = os.clock()
                                if not _G.LastBombScanTime or (curTime - _G.LastBombScanTime) > 0.5 then
                                    _G.LastBombScanTime = curTime
                                    local allActors = _G.CachedGameplayStatics.GetAllActorsOfClass(gameInstance, _G.CachedActorClass_ForBomb, _G.CachedProjArray)
                                    local activeBombs = {}
                                    if allActors then
                                        for _, actor in pairs(allActors) do
                                            if slua.isValid(actor) and not actor.bHidden then
                                                local nameLower = string.lower(tostring(actor))
                                                if string.find(nameLower, "grenade") or string.find(nameLower, "projectile") or string.find(nameLower, "thrown") then
                                                    table.insert(activeBombs, actor)
                                                end
                                            end
                                        end
                                    end
                                    _G.CachedActiveBombs = activeBombs
                                end
                                if _G.CachedActiveBombs then
                                    for _, bomb in ipairs(_G.CachedActiveBombs) do
                                        if slua.isValid(bomb) then
                                            local distBomb = 0
                                            pcall(function() distBomb = localPlayer:GetDistanceTo(bomb) / 100 end)
                                            if distBomb > 0 and distBomb <= 150 then
                                                local dynamicScale = math.max(0.6, 1.1 - (distBomb / 150))
                                                hud:AddDebugText("● BOMB", bomb, 0.06, {X=0, Y=0, Z=25}, {X=0, Y=0, Z=25}, C_RED, true, false, true, nil, dynamicScale, true)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
                
                
                -- ESP VEHICLE
                if _G.SrcHubConfig.EspVehicle then
                    pcall(function()
                        local hud = Cached_MyHUD
                        if Valid(hud) then
                            if not _G.CachedGameplayStatics then _G.CachedGameplayStatics = import("GameplayStatics") end
                            if not _G.CachedActorClass_ForVehicle then _G.CachedActorClass_ForVehicle = import("STExtraVehicleBase") end
                            if not _G.CachedVehicleArray then _G.CachedVehicleArray = slua.Array(UEnums.EPropertyClass.Object, _G.CachedActorClass_ForVehicle) end
                            local ui_util = require("client.common.ui_util")
                            local gameInstance = ui_util and ui_util.GetGameInstance()
                            if gameInstance and _G.CachedGameplayStatics then
                                local curTime = os.clock()
                                if not _G.LastVehicleScanTime or (curTime - _G.LastVehicleScanTime) > 1.0 then
                                    _G.LastVehicleScanTime = curTime
                                    local allVehicles = _G.CachedGameplayStatics.GetAllActorsOfClass(gameInstance, _G.CachedActorClass_ForVehicle, _G.CachedVehicleArray)
                                    local activeVehicles = {}
                                    if allVehicles then
                                        for _, veh in pairs(allVehicles) do
                                            if slua.isValid(veh) and not veh.bHidden then
                                                local vehName = "Vehicle"
                                                pcall(function() if type(veh.GetVehicleName) == "function" then vehName = veh:GetVehicleName() elseif veh.VehicleName then vehName = veh.VehicleName end end)
                                                local nameLower = string.lower(tostring(vehName))
                                                local displayName = "Vehicle"
                                                if string.find(nameLower, "uaz") then displayName = "UAZ"
                                                elseif string.find(nameLower, "dacia") then displayName = "Dacia"
                                                elseif string.find(nameLower, "buggy") then displayName = "Buggy"
                                                elseif string.find(nameLower, "mirado") then displayName = "Mirado"
                                                elseif string.find(nameLower, "bike") or string.find(nameLower, "motor") then displayName = "Motor"
                                                elseif string.find(nameLower, "coupe") then displayName = "Coupe"
                                                else displayName = "Vehicle" end
                                                table.insert(activeVehicles, {act = veh, name = displayName})
                                            end
                                        end
                                    end
                                    _G.CachedVehicles = activeVehicles
                                end
                                if _G.CachedVehicles then
                                    for _, item in ipairs(_G.CachedVehicles) do
                                        local veh = item.act
                                        if slua.isValid(veh) and not veh.bHidden then
                                            local distVeh = 0
                                            pcall(function() distVeh = localPlayer:GetDistanceTo(veh) / 100 end)
                                            if distVeh > 0 and distVeh <= 300 then
                                                local text = string.format("%s [%dm]", item.name, math.floor(distVeh))
                                                local dynamicScale = math.max(0.6, 1.1 - (distVeh / 300))
                                                hud:AddDebugText(text, veh, 0.06, {X=0, Y=0, Z=50}, {X=0, Y=0, Z=50}, C_GREEN, true, false, true, nil, dynamicScale, true)
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end)
                end
                
            else
                if not markData.IsCleanedUp then
                    SafeRemoveMark(markData.radarMark)
                    markData.radarMark = nil
                    SafeRemoveMark(markData.hpMark)
                    markData.hpMark = nil
                    SafeRemoveMark(markData.distMark)
                    markData.distMark = nil
                    markData.IsCleanedUp = true
                end
            end
        end
    end
end

_G.LexusState.LoopToken = (_G.LexusState.LoopToken or 0) + 1
local myToken = _G.LexusState.LoopToken

local function FastTick()
    if myToken ~= _G.LexusState.LoopToken then return end
    pcall(MainLoop)
    local okTicker, ticker = pcall(require, "common.time_ticker")
    if okTicker and ticker and ticker.AddTimerOnce then
        ticker.AddTimerOnce(0.03, FastTick)
    end
end

if not isExpired then
    FastTick()
    Notify("VIP MOD LOADED - Check Settings for Menu!")
else
    Notify("MOD EXPIRED! Please contact admin to renew.")
    ShowExpiredNotification()
end

-- ========================================== 
-- Credit Text In Game + Lobby ✓
-- ========================================== 

local IngamePhoneStateUI = require("GameLua.Mod.Library.Client.UI.IngamePhoneStateUI") 
local Lobby_Main_Wifi_UIBP = require("client.slua.umg.lobby.Main.Lobby_Main_Wifi_UIBP")

local o_UpdateQuality = Lobby_Main_Wifi_UIBP.__inner_impl.UpdateQuality
Lobby_Main_Wifi_UIBP.__inner_impl.UpdateQuality = function(self)
    self.UIRoot.WidgetSwitcher_Quality:SetActiveWidgetIndex(0)
    self.UIRoot.TextBlock_High:SetText("XThrlen")
    self.UIRoot.TextBlock_High:SetColorAndOpacity(FSlateColor(FLinearColor(1, 0.85, 0.8, 1)))
end

local InGameUITools
local o_UpdateArtQualityUI = IngamePhoneStateUI.__inner_impl.UpdateArtQualityUI
IngamePhoneStateUI.__inner_impl.UpdateArtQualityUI = function(self, _, _)
    self.UIRoot.TextBlock_quality:SetText("XThrlen")
    pcall(function()
        if not InGameUITools then
            InGameUITools = require("GameLua.Mod.BaseMod.Common.UI.InGameUITools")
        end
        local Main = InGameUITools.GetMainControlBaseUI()
        if Main then
            Main.TextBlock_BID:SetText("Telegram: @SRC_HUB")
            Main.TextBlock_BID:SetColorAndOpacity(FSlateColor(FLinearColor(1, 0.75, 0.8, 1)))
            Main.TextBlock_Hour:SetWidgetVisibility(UEnums.ESlateVisibility.Collapsed)
        end
    end)
end

local o_OnInitialize = IngamePhoneStateUI.__inner_impl.OnInitialize
IngamePhoneStateUI.__inner_impl.OnInitialize = function(self)
    o_OnInitialize(self)
    
    if self.UIRoot.TextBlock_quality then
        self.UIRoot.TextBlock_quality:SetColorAndOpacity(FSlateColor(FLinearColor(1, 0.6, 0.2, 1)))
    end
end

-- ========================================== 
-- INIT BYPASS
-- ========================================== 

-- ========================================== 
-- =========== COMPLETE BYPASS SYSTEM ========== 
-- ========================================== 

-- ========================================== 
-- BYPASS 1: CLIENT REPORT SUBSYSTEM
-- ========================================== 
function _G.KASHMIRY_BYPASS_INSTALL()
pcall(function()
local paths = { "GameLua.Mod.BaseMod.Client.Security.ClientReportPlayerSubsystem", "Client.Security.ClientReportPlayerSubsystem" }
local ClientReport = nil
for _, path in ipairs(paths) do
if package.loaded[path] then ClientReport = package.loaded[path] break end
local status, lib = pcall(require, path)
if status and lib then ClientReport = lib break end
end
if ClientReport then
ClientReport.OnInit = function(self) return end
ClientReport._OnPlayerKilledOtherPlayer = function() return end
ClientReport._RecordFatalDamager = function() return end
ClientReport._OnDeathReplayDataWhenFatalDamaged = function() return end
ClientReport._RecordMurdererFromDeathReplayData = function() return end
ClientReport._RecordTeammatePlayerInfo = function() return end
ClientReport._OnBattleResult = function() return end
ClientReport._OnShowQuickReportMutualExclusiveUI = function() return end
ClientReport.GetFatalDamagerMap = function() return {} end
ClientReport.GetCachedTeammateName2InfoMap = function() return {} end
ClientReport.GetTeammateName2InfoMapDuringBattle = function() return {} end
ClientReport.GetCurrentNotInTeamHistoricalTeammateMap = function() return {} end
ClientReport.GetInTeamIndexFromHistoricalTeammateInfo = function() return -1 end
end
end)

pcall(function()
local paths = { "GameLua.Mod.BaseMod.DS.Security.DSReportPlayerSubsystem", "GameLua.Mod.BaseMod.Client.Security.DSReportPlayerSubsystem" }
local DSReport = nil
for _, path in ipairs(paths) do
if package.loaded[path] then DSReport = package.loaded[path] break end
local status, lib = pcall(require, path)
if status and lib then DSReport = lib break end
end
if DSReport then
DSReport.OnInit = function(self) return end
DSReport._OnNearDeathOrRescued = function() return end
DSReport._OnCharacterDied = function() return end
DSReport._OnTeammateDamage = function() return end
DSReport._OnPlayerSettlementStart = function() return end
DSReport._AddKnockDownerToBattleResult = function() return end
DSReport._AddKillerToBattleResult = function() return end
DSReport._AddTeammateMurderToBattleResult = function() return end
DSReport._AddFatalDamagerMapToBattleResult = function() return end
DSReport._AddMLKillerUIDToBattleResult = function() return end
DSReport._SaveHistoricalTeammateInfo = function() return end
DSReport._RecordFatalDamager = function() return end
DSReport._RecordTeammateMurderer = function() return end
end
end)

pcall(function()
local ReportPlayerUtils = require("GameLua.Mod.BaseMod.Common.Security.ReportPlayerUtils")
if ReportPlayerUtils then
ReportPlayerUtils.RecordFatalDamager = function() return end
ReportPlayerUtils.IsUsingHistoricalTeammateInfo = function() return false end
ReportPlayerUtils.IsCharacterDeliverAI = function() return false end
end
end)

pcall(function()
local SecurityCommonUtils = require("GameLua.Mod.BaseMod.Common.Security.SecurityCommonUtils")
if SecurityCommonUtils then
SecurityCommonUtils.ExtractPlayerBasicInfo = function() return {} end
SecurityCommonUtils.LogIf = function() return false end
end
end)

pcall(function()
local QuickReport = require("GameLua.Mod.BaseMod.Client.Security.ClientQuickReportMaliciousTeammate")
if QuickReport then
QuickReport.OnShowMutualExclusiveUI = function() return end
QuickReport.OnHideMutualExclusiveUI = function() return end
end
end)
end

-- ========================================== 
-- BYPASS 2: HIGGS BOSON DISABLE
-- ========================================== 
function _G.DisableHiggsBoson()
local PlayerController = slua_GameFrontendHUD and slua_GameFrontendHUD:GetPlayerController()
if not PlayerController or not slua.isValid(PlayerController) then return end
if PlayerController.HiggsBoson then
PlayerController.HiggsBoson.bMHActive = false
PlayerController.HiggsBoson.bCallPreReplication = false
end
if PlayerController.HiggsBosonComponent then
PlayerController.HiggsBosonComponent.bMHActive = false
PlayerController.HiggsBosonComponent:ControlMHActive(0)
end
end

-- ========================================== 
-- BYPASS 3: HIGGS BOSON HOOKS
-- ========================================== 
function _G.KASHMIRY_BYPASS_HOOK()
pcall(function()
local HiggsBosonComponent = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
if HiggsBosonComponent and HiggsBosonComponent.StaticShowSecurityAlertInDev then
HiggsBosonComponent.StaticShowSecurityAlertInDev = function() end
end
end)

if _G.AvatarCheckCallback then
_G.AvatarCheckCallback.StartAvatarCheck = function(HiggsBosonComponent) end
_G.AvatarCheckCallback.OnReportItemID = function(HiggsBosonComponent) end
_G.AvatarCheckCallback.PostPlayerControllerLoginInit = function(PlayerController)
if slua.isValid(PlayerController) and PlayerController.HiggsBosonComponent then
PlayerController.HiggsBosonComponent:ControlMHActive(0)
PlayerController.HiggsBosonComponent.bMHActive = false
end
end
end

pcall(function()
local SecurityModule = require("GameLua.Mod.BaseMod.Common.Security.HiggsBosonComponent")
if SecurityModule and SecurityModule.BlackList then
for k in pairs(SecurityModule.BlackList) do SecurityModule.BlackList[k] = nil end
end
end)

_G.BlackList = {}

pcall(function()
_G.GlobalPlayerCoronaData = _G.GlobalPlayerCoronaData or {}
_G.GlobalPlayerCheatTimes = _G.GlobalPlayerCheatTimes or {}
local mt = getmetatable(_G.GlobalPlayerCoronaData) or {}
mt.__newindex = function(t, k, v) end
setmetatable(_G.GlobalPlayerCoronaData, mt)
end)

pcall(function()
if _G.GameSafeCallbacks and _G.GameSafeCallbacks.RecordStrategyTimestampInReplay then
_G.GameSafeCallbacks.RecordStrategyTimestampInReplay = function(...) end
_G.GameSafeCallbacks.DoAttackFlowStrategy = function() end
_G.GameSafeCallbacks.GetScriptReportContent = function() return "" end
end
end)

pcall(function()
local USTExtraBlueprintFunctionLibrary = import("STExtraBlueprintFunctionLibrary")
if USTExtraBlueprintFunctionLibrary then
USTExtraBlueprintFunctionLibrary.IsDevelopment = function() return false end
end
end)
end

-- ========================================== 
-- BYPASS 4: GAMEPLAY CALLBACKS ISLAND
-- ========================================== 
function _G.KASHMIRY_BYPASS_ISLAND()
pcall(function()
if not _G.GameplayCallbacks or _G.GameplayCallbacks.IsBypassed then return end

local GC = _G.GameplayCallbacks

local original_OnDSPlayerStateChanged = GC.OnDSPlayerStateChanged
GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
if InPlayerState and string.lower(tostring(InPlayerState)) == "cheatdetected" then return end
if original_OnDSPlayerStateChanged then return original_OnDSPlayerStateChanged(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason) end
end

local function BlockFunc() return end
local function BlockRetEmpty() return {} end
local function BlockRetNil() return nil end

GC.ReportAttackFlow = BlockFunc
GC.ReportSecAttackFlow = BlockFunc
GC.ReportHurtFlow = BlockFunc
GC.ReportFireArms = BlockFunc
GC.ReportVerifyInfoFlow = BlockFunc
GC.ReportMrpcsFlow = BlockFunc
GC.ReportPlayerBehavior = BlockFunc
GC.ReportTeammatHurt = BlockFunc
GC.ReportMisKillByTeammate = BlockFunc
GC.ReportForbitPick = BlockFunc
GC.ReportPlayerMoveRoute = BlockFunc
GC.ReportPlayerPosition = BlockFunc
GC.ReportVehicleMoveFlow = BlockFunc
GC.ReportSecTgameMovingFlow = BlockFunc
GC.ReportParachuteData = BlockFunc
GC.SendTssSdkAntiDataToLobby = BlockFunc
GC.SendDSErrorLogToLobby = BlockFunc
GC.SendDSErrorLogToLobbyOnece = BlockFunc
GC.SendDSHawkEyePatrolLogToLobby = BlockFunc
GC.ReportEquipmentFlow = BlockFunc
GC.ReportAimFlow = BlockFunc
GC.GetWeaponReport = BlockRetEmpty
GC.GetOneWeaponReport = BlockRetEmpty
GC.ReportHeavyWeaponBoxSpawnFlow = BlockFunc
GC.ReportHeavyWeaponBoxActivationFlow = BlockFunc
GC.ReportHeavyWeaponBoxOpenPlayerFlow = BlockFunc
GC.ReportHeavyWeaponBoxItemFlow = BlockFunc
GC.ReportPlayersPing = BlockFunc
GC.ReportPlayerIP = BlockFunc
GC.ReportPlayerFramePingRecord = BlockFunc
GC.OnDSConnectionSaturated = BlockFunc
GC.ReportDSNetSaturation = BlockFunc
GC.ReportNetContinuousSaturate = BlockFunc
GC.ReportDSNetRate = BlockFunc
GC.SendClientStats = BlockFunc
GC.SendServerAvgTickDelta = BlockFunc
GC.ReportCircleFlow = BlockFunc
GC.ReportDSCircleFlow = BlockFunc
GC.ReportJumpFlow = BlockFunc
GC.ReportAIStrategyInfo = BlockFunc
GC.SendAIDeliveryInfo = BlockFunc
GC.ReportDailyTaskInfo = BlockFunc
GC.ReportMatchRoomData = BlockFunc
GC.SendPlayerSpectatingLog = BlockFunc
GC.ReportIDCardProduceFlow = BlockFunc
GC.ReportIDCardPickUpFlow = BlockFunc
GC.ReportIDCardDestroyFlow = BlockFunc
GC.ReportRevivalFlow = BlockFunc
GC.ReportGameSetting = BlockFunc
GC.ReportGameSettingNew = BlockFunc
GC.ReportAntsVoiceTeamCreate = BlockFunc
GC.ReportAntsVoiceTeamQuit = BlockFunc
GC.ReportCommonInfo = BlockFunc
GC.ReportLightweightStat = BlockFunc
GC.SendSecTLog = BlockFunc
GC.SendDataMiningTLog = BlockFunc
GC.SendActivityTLog = BlockFunc
GC.GetGeneralTLogData = BlockRetNil

GC.IsBypassed = true
end)

pcall(function()
if NetUtil and NetUtil.SendPacket and not NetUtil.IsBypassed then
local original_SendPacket = NetUtil.SendPacket
local BlockedPackets = {
["ReportAttackFlow"]=1, ["ReportSecAttackFlow"]=1, ["ReportHurtFlow"]=1,
["ReportFireArms"]=1, ["ReportVerifyInfoFlow"]=1, ["ReportMrpcsFlow"]=1,
["ReportPlayerBehavior"]=1, ["ReportTeammatHurt"]=1, ["ReportTeammateKillConfirmFlow"]=1,
["ReportForbiddenPickupFlow"]=1, ["ReportPlayerMoveRoute"]=1, ["ReportPlayerPosition"]=1,
["ReportSecVehicleMoveFlow"]=1, ["ReportSecTgameMovingFlow"]=1, ["report_parachute_data"]=1,
["report_character_all_drag"]=1, ["report_parachute_all_drag"]=1, ["report_vehicle_move_drag"]=1,
["on_tss_sdk_anti_data"]=1, ["report_unrealnet_exception"]=1, ["ReportPlayerEquipmentInfo"]=1,
["ReportAimFlow"]=1, ["ReportHitFlow"]=1, ["log_shooting_miss"]=1, ["report_heavy_weapon_box_activation_flow"]=1,
["report_heavy_weapon_box_item_flow"]=1, ["ReportCircleFlow"]=1, ["report_ds_player_circle_flow"]=1,
["ReportJumpFlow"]=1, ["ReportGameStartFlow"]=1, ["ReportGameEndFlow"]=1, ["report_players_ping"]=1,
["report_player_ip"]=1, ["report_player_frame_ping_record"]=1, ["report_net_saturate"]=1,
["report_ds_netsaturate"]=1, ["report_ds_net_continuous_saturate"]=1, ["report_ds_netrate"]=1,
["report_unrealnet_clientstats"]=1, ["report_serverstat_avgtickdelta"]=1, ["report_all_players_address"]=1,
["report_ai_strategyinfo"]=1, ["ReportAIActionFlow"]=1, ["ReportGenerateMonsterFlow"]=1,
["report_ds_match_room_data"]=1, ["SendSpectatingLog"]=1, ["ReportIDCardProduceFlow"]=1,
["ReportIDCardPickUpFlow"]=1, ["ReportIDCardDestroyFlow"]=1, ["ReportRevivalFlow"]=1,
["ReportGameSetting"]=1, ["ReportGameSettingNew"]=1, ["ReportAntsVoiceTeamCreate"]=1,
["ReportAntsVoiceTeamQuit"]=1, ["report_common_info"]=1, ["report_common_battle_info"]=1,
["report_client_scan_result"]=1, ["tss_sdk_report"]=1, ["report_memory_exception"]=1,
["report_avatar_exception"]=1, ["report_ui_state"]=1, ["report_hit_reg_fail"]=1,
["report_character_state"]=1, ["report_vehicle_exception"]=1, ["report_camera_exception"]=1,
["ReportPlayerControllerStateChanged"]=1, ["ReportAvatarFlow"]=1
}

NetUtil.SendPacket = function(packetName, ...)
if BlockedPackets[packetName] then return end
return original_SendPacket(packetName, ...)
end
NetUtil.IsBypassed = true
end
end)
end

-- ========================================== 
-- BYPASS 5: CONNECTION GUARD
-- ========================================== 
function _G.KASHMIRY_BYPASS_CONNECTED()
pcall(function()
if _G.ConnectionGuardInitialized or not _G.GameplayCallbacks then return end

local GC = _G.GameplayCallbacks
local original_OnDSPlayerStateChanged = GC.OnDSPlayerStateChanged

GC.OnDSPlayerStateChanged = function(UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
local sState = InPlayerState and string.lower(tostring(InPlayerState)) or ""
local BadStates = {
["cheatdetected"] = true, ["connectionlost"] = true,
["connectiontimeout"] = true, ["connectionexception"] = true,
["netdrivererror"] = true
}
if BadStates[sState] then return end
if original_OnDSPlayerStateChanged then
pcall(original_OnDSPlayerStateChanged, UID, InPlayerState, bPureWatcher, bIsSafeExit, ParamReason)
end
end

GC.OnPlayerNetConnectionClosed = function(GameID, UID, Reason, ErrorMessage) end
GC.OnPlayerActorChannelError = function(GameID, UID, Reason, ErrorMessage) end
GC.OnPlayerRPCValidateFailed = function(GameID, UID, Reason, ErrorMessage) end
GC.OnPlayerSpectateException = function(GameID, UID, Reason, ErrorMessage) end
GC.OnShutdownAfterError = function(GameID) end

_G.ConnectionGuardInitialized = true
end)
end

-- ========================================== 
-- BYPASS 6: BLOCK LOGS & REPORTS
-- ========================================== 
function _G.KASHMIRY_BYPASS_BLOCK()
pcall(function()
local TLog = package.loaded["TLog"] or _G.TLog
if TLog then
TLog.Info = function() end; TLog.Warning = function() end
TLog.Error = function() end; TLog.Debug = function() end; TLog.Report = function() end
end
local CrashSight = package.loaded["CrashSight"] or _G.CrashSight
if CrashSight then
CrashSight.ReportException = function() end
CrashSight.SetCustomData = function() end; CrashSight.Log = function() end
end
local ClientToolsReport = package.loaded["client.slua.logic.report.ClientToolsReport"]
if ClientToolsReport then
ClientToolsReport.SendReport = function() end; ClientToolsReport.SendException = function() end
end
local ClientTLogUtil = package.loaded["GameLua.Mod.BaseMod.Client.ClientTLog.ClientTLogUtil"]
if ClientTLogUtil then
ClientTLogUtil.ReportGeneralCountByBRPhase = function() end
ClientTLogUtil.ReportCommonTLogDataByBRPhase = function() end
end
local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
local GameReportSubsystem = SubsystemMgr and SubsystemMgr:Get("GameReportSubsystem")
if GameReportSubsystem then
GameReportSubsystem.CheckCanBugglyPostException = function() return false end
GameReportSubsystem.BugglyPostExceptionFull = function() return false end
end
end)
end

-- ========================================== 
-- BYPASS 7: SUB SYSTEM LOG BLOCK
-- ========================================== 
function _G.KASHMIRY_BYPASS_LOG()
pcall(function()
local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")
if not SubsystemMgr then return end
local AFKSub = SubsystemMgr:Get("AFKReportorSubsystem")
if AFKSub then 
AFKSub.PlayerHaveAction = function() end; AFKSub.ReportAFK = function() end
end
local AvatarExc = SubsystemMgr:Get("AvatarExceptionSubsystem")
if AvatarExc then
AvatarExc.ReportException = function() end
AvatarExc.BindPlayerCharacter = function() end
AvatarExc.CheckAvatarValid = function() return true end
end

local ShootVerifyClient = SubsystemMgr:Get("ShootVerifySubSystemClient")
if ShootVerifyClient then
ShootVerifyClient.ReportVerifyFail = function() end
ShootVerifyClient.OnVerifyFailed = function() end
end

local TSS = package.loaded["TssSdk"] or _G.TssSdk
if TSS then
TSS.OnRecvData = function() end; TSS.SendReportInfo = function() end
TSS.ScanMemory = function() return true end
end
end)
end

-- ========================================== 
-- BYPASS 8: REPLAY TELEMETRY BLOCK
-- ========================================== 
function _G.KASHMIRY_BYPASS_REPLAY()
pcall(function()
local SubsystemMgr = require("GameLua.GameCore.Module.Subsystem.SubsystemMgr")

local RescueTrace = SubsystemMgr and SubsystemMgr:Get("RescueBtnReplayTraceSubsystem")
if RescueTrace then
RescueTrace.ReportTrace = function() end; RescueTrace.StartTickMonitor = function() end
RescueTrace.TickMonitorCheck = function() end; RescueTrace.ReportTickMonitorHeartbeat = function() end
end

local GameReportUtils = package.loaded["GameLua.Mod.BaseMod.GamePlay.GameReport.GameReportUtils"]
if GameReportUtils then
GameReportUtils.ReplayReportData = function() end
GameReportUtils.ReportGameException = function() end
end

local GameReportSubsystem = SubsystemMgr and SubsystemMgr:Get("GameReportSubsystem")
if GameReportSubsystem then
GameReportSubsystem.ReplayReportData = function() return false end
if GameReportSubsystem.Reporter then
GameReportSubsystem.Reporter.ReportIntArrayData = function() end
GameReportSubsystem.Reporter.ReportUInt8ArrayData = function() end
GameReportSubsystem.Reporter.ReportFloatArrayData = function() end
end
end
end)
end

-- ========================================== 
-- MASTER INIT FUNCTION
-- ========================================== 
function _G.InitializeAllBypasses()
    pcall(function()
        _G.KASHMIRY_BYPASS_INSTALL()
        _G.KASHMIRY_BYPASS_HOOK()
        _G.KASHMIRY_BYPASS_ISLAND()
        _G.KASHMIRY_BYPASS_CONNECTED()
        _G.KASHMIRY_BYPASS_BLOCK()
        _G.KASHMIRY_BYPASS_LOG()
        _G.KASHMIRY_BYPASS_REPLAY()
        _G.DisableHiggsBoson()
        print("[✓ BYPASS] All Bypasses Initialized Successfully!")
    end)
end

pcall(InitializeBypass)
-- ========================================== 
-- =========== END BYPASS SYSTEM ============ 
-- ========================================== 

-- ==============================================================================
-- ================== RETURN SECTION =============================================
-- ==============================================================================
local class = require("class")
local CCharacterBase = require("GameLua.GameCore.Framework.CharacterBase")
local CBRPlayerCharacterBase = class(CCharacterBase, nil, BRPlayerCharacterBase)
return require("combine_class").DeclareFeature(CBRPlayerCharacterBase, {
  {
    SkyTransition = "GameLua.Mod.BaseMod.Gameplay.Feature.SkyControl.PlayerCharacterSkyTransitionFeature"
  },
  {
    CarryDeadBoxFeature = "GameLua.Mod.Library.GamePlay.Feature.CarryDeadBoxFeature"
  },
  {
    SpecialSuitFeature = "GameLua.Mod.Library.GamePlay.Feature.SpecialSuitFeature"
  },
  {
    TeleportPawnFeature = "GameLua.Mod.Library.GamePlay.Feature.TeleportPawnFeature"
  },
  {
    LifterControl = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.CharacterLifterControlFeature"
  },
  {
    FinalKillEffect = "GameLua.Mod.BaseMod.Gameplay.Feature.Player.PlayerCharacterFinalKillEffectFeature"
  },
  {
    CampFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.Camp.PlayerCharacterCampFeature"
  },
  {
    BuildSkateFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.PlayerCharacterBuildVehicleFeature"
  },
  {
    CommonBornlandTransformFeature = "GameLua.Mod.BaseMod.GamePlay.Feature.HeroPropFeature.CommonBornlandTransformFeature"
  },
  {
    ParachuteFormation = "GameLua.Mod.BaseMod.GamePlay.Feature.ParachuteFormationFeature"
  }
}, "BRPlayerCharacterBase")