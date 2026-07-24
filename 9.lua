local FloatConfig = {
    CONFIG_FILE = "/storage/emulated/0/Android/data/com.pubg.imobile/files/ZOULEMOD.ini",
    HEADER_FILE = "/storage/emulated/0/Android/data/com.pubg.imobile/files/MenuConfig.h", -- Path for the .h toggle file
    defaults = {
        ktyBSia = true, -- Changed to true so menu works by default
        kFloatPosX = 0,
        kFloatPosY = 0,
        k9K3WqPBJ1 = 1,
    },
    current = {},
    Load = function(self)
        self:CheckHeaderToggle() -- Check the .h file first
        local content = self:ReadConfigFile()
        if content and content ~= "" then
            self:ParseConfig(content)
        else
            for key, value in pairs(self.defaults) do
                if self.current[key] == nil then
                    self.current[key] = value
                end
            end
        end
    end,
    CheckHeaderToggle = function(self)
        local success, result = pcall(function()
            local file = io.open(self.HEADER_FILE, "r")
            if file then
                local content = file:read("*a"):lower()
                file:close()
                if content:find("on") then
                    self.current["ktyBSia"] = true
                elseif content:find("off") then
                    self.current["ktyBSia"] = false
                end
            end
        end)
    end,
    ReadConfigFile = function(self)
        local success, result = pcall(function()
            if Client and Client.LoadFileToString then
                return Client.LoadFileToString(self.CONFIG_FILE)
            end
        end)
        if success and result then return result end
        success, result = pcall(function()
            local file = io.open(self.CONFIG_FILE, "r")
            if file then
                local content = file:read("*a")
                file:close()
                return content
            end
        end)
        if success and result then return result end
        return nil
    end,
    ParseConfig = function(self, content)
        for line in string.gmatch(content, "[^\r\n]+") do
            line = line:gsub("^%s+", ""):gsub("%s+$", "")
            if line ~= "" and line:sub(1, 1) ~= "#" then
                local key, val = line:match("^([^=]+)=(.+)$")
                if key and val then
                    key = key:gsub("^%s+", ""):gsub("%s+$", "")
                    val = val:gsub("^%s+", ""):gsub("%s+$", "")
                    if val == "true" or val == "1" then
                        self.current[key] = true
                    elseif val == "false" or val == "0" then
                        self.current[key] = false
                    else
                        local num = tonumber(val)
                        if num then
                            self.current[key] = num
                        else
                            self.current[key] = val
                        end
                    end
                end
            end
        end
    end,
    Save = function(self)
        local lines = {}
        table.insert(lines, "# ZOULE_MOD")
        table.insert(lines, "ver=1")
        for key, value in pairs(self.current) do
            if type(value) == "boolean" then
                table.insert(lines, key .. "=" .. (value and "1" or "0"))
            else
                table.insert(lines, key .. "=" .. tostring(value))
            end
        end
        local content = table.concat(lines, "\n")
        self:WriteConfigFile(content)
    end,
    WriteConfigFile = function(self, content)
        pcall(function()
            if Client and Client.SaveStringToFile then
                Client.SaveStringToFile(content, self.CONFIG_FILE)
                return
            end
        end)
        pcall(function()
            local file = io.open(self.CONFIG_FILE, "w")
            if file then
                file:write(content)
                file:close()
            end
        end)
    end,
    Get = function(self, key)
        if self.current[key] ~= nil then
            return self.current[key]
        end
        return self.defaults[key]
    end,
    Set = function(self, key, value)
        self.current[key] = value
    end,
    IsEnabled = function(self, key)
        return self:Get(key) == true
    end,
}

local FloatMenu = {
    isOpen = false,
    floatBtn = nil,
    floatSlot = nil,
    panelRoot = nil,
    panelCanvas = nil,
    dragState = nil,
    isDragging = false,
    dragMoved = false,
    settingsPage = nil,
    menuWidget = nil,
    closeBtn = nil,
    loadedButtons = {},
    currentTab = 1,
    _toggleGuard = false,
    _eventsBound = false,
}

function FloatMenu:Initialize()
    FloatConfig:Load()
    self:RestorePosition()
    if FloatConfig:IsEnabled("ktyBSia") then
        self:EnsureTrigger()
    else
        self:DestroyFloatButton()
    end
end

function FloatMenu:EnsureTrigger()
    if self.floatBtn and self:IsValidWidget(self.floatBtn) then
        return
    end
    self:CreateFloatButton()
end

function FloatMenu:IsValidWidget(widget)
    if not widget then return false end
    local success, result = pcall(function()
        return slua and slua.isValid and slua.isValid(widget)
    end)
    if success and result then return true end
    return widget ~= nil
end

function FloatMenu:CreateFloatButton()
    self:DestroyFloatButton()
    local btn = self:LoadWidget("/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP")
    if not btn then return end
    if not self:IsValidWidget(btn) then return end
    btn:SetWidgetVisibility(self:GetVisibility("Visible"))
    btn:SetRenderOpacity(1)
    local text = btn.RichText_Content or btn.Text
    if text and self:IsValidWidget(text) then
        text:SetText("ZOULE MOD")
        self:ApplyTextStyle(text, 18)
    end
    local bg = btn.Image_Bg or btn.Image_BtnBg
    if bg and self:IsValidWidget(bg) then
        bg:SetBrushFromPathAsync("/Game/UMG/Texture/Atlas/Common/Common_Image_White.Common_Image_White", false)
        bg:SetBrushColor(FLinearColor(0.03, 0.03, 0.06, 1))
        bg:SetRenderOpacity(1)
        bg:SetWidgetVisibility(self:GetVisibility("SelfHitTestInvisible"))
    end
    local icon = btn.Image_Icon
    if icon and self:IsValidWidget(icon) then
        icon:SetBrushFromPathAsync("/Game/UMG/Texture/Atlas/Common_Atlas/Frames/lobby_download_btn_drag_icon.lobby_download_btn_drag_icon", false)
        icon:SetBrushColor(FLinearColor(1, 1, 1, 0.7))
        icon:SetRenderOpacity(1)
        icon:SetWidgetVisibility(self:GetVisibility("SelfHitTestInvisible"))
    end
    self:AddToViewport(btn)
    local posX, posY = self:GetSavedPosition()
    self:SetButtonPosition(btn, posX, posY)
    self.floatBtn = btn
    self.floatSlot = self:GetCanvasSlot(btn)
    self:BindDragEvents()
    self:BindClickEvent()
    self:BindBallEvents()
end

function FloatMenu:DestroyFloatButton()
    if self.floatBtn then
        pcall(function()
            if self:IsValidWidget(self.floatBtn) then
                self.floatBtn:RemoveFromParent()
            end
        end)
        self.floatBtn = nil
        self.floatSlot = nil
    end
end

function FloatMenu:LoadWidget(path)
    local success, widget = pcall(function()
        if slua and slua.loadUI then
            return slua.loadUI(path)
        end
    end)
    if success and widget then return widget end
    success, widget = pcall(function()
        local lib = import("STExtraBlueprintFunctionLibrary")
        if lib and lib.CreateWidgetByPathName then
            return lib.CreateWidgetByPathName(path, self:GetGameInstance())
        end
    end)
    if success and widget then return widget end
    return nil
end

function FloatMenu:GetGameInstance()
    local success, result = pcall(function()
        if slua_GameFrontendHUD then
            return slua_GameFrontendHUD:GetGameInstance()
        end
    end)
    if success and result and self:IsValidWidget(result) then return result end
    success, result = pcall(function()
        local util = require("client.common.ui_util")
        if util and util.GetGameInstance then
            return util.GetGameInstance()
        end
    end)
    if success and result and self:IsValidWidget(result) then return result end
    return nil
end

function FloatMenu:GetVisibility(mode)
    local vis = {
        Collapsed = 0,
        Visible = 1,
        SelfHitTestInvisible = 2,
        HitTestInvisible = 3,
    }
    if UEnums and UEnums.ESlateVisibility then
        return UEnums.ESlateVisibility[mode] or 1
    end
    return vis[mode] or 1
end

function FloatMenu:GetScreenSize()
    local w, h = 1920, 1080
    pcall(function()
        local pc = self:GetPlayerController()
        if pc and self:IsValidWidget(pc) then
            local success, sw, sh = pcall(function()
                return pc:GetViewportSize(0, 0)
            end)
            if success and sw and sw > 0 then
                w, h = sw, sh
            end
        end
    end)
    pcall(function()
        local lib = import("WidgetLayoutLibrary")
        if lib and self.floatBtn and self:IsValidWidget(self.floatBtn) then
            local size = lib:GetViewportSize(self.floatBtn)
            if size and size.X and size.X > 0 then
                w, h = size.X, size.Y
            end
        end
    end)
    return w, h
end

function FloatMenu:GetPlayerController()
    local success, result = pcall(function()
        if slua_GameFrontendHUD then
            return slua_GameFrontendHUD:GetPlayerController()
        end
    end)
    if success and result and self:IsValidWidget(result) then return result end
    success, result = pcall(function()
        local lib = import("GameplayStatics")
        if lib and lib.GetPlayerController then
            local world = slua_GameFrontendHUD and slua_GameFrontendHUD:GetWorld()
            if world then
                return lib.GetPlayerController(world, 0)
            end
        end
    end)
    if success and result and self:IsValidWidget(result) then return result end
    return nil
end

function FloatMenu:AddToViewport(widget)
    pcall(function()
        local success = false
        pcall(function()
            local util = require("game_frontend_hud")
            if util and util.AddToContainer then
                util.AddToContainer(UIContainers.Top, widget, 9300)
                success = true
            end
        end)
        if not success then
            pcall(function()
                widget:AddToViewport(9300)
            end)
        end
    end)
end

function FloatMenu:GetCanvasSlot(widget)
    local success, result = pcall(function()
        local lib = import("WidgetLayoutLibrary")
        if lib and lib.SlotAsCanvasSlot then
            return lib.SlotAsCanvasSlot(widget)
        end
    end)
    if success and result then return result end
    return nil
end

function FloatMenu:SetButtonPosition(widget, x, y)
    local slot = self:GetCanvasSlot(widget)
    if slot then
        pcall(function()
            slot:SetAnchors(FAnchors(0, 0, 0, 0))
            slot:SetAlignment(FVector2D(0, 0))
            slot:SetPosition(FVector2D(x, y))
            slot:SetSize(FVector2D(118, 34))
            slot:SetZOrder(9300)
        end)
    end
end

function FloatMenu:GetSavedPosition()
    local x = FloatConfig:Get("kFloatPosX")
    local y = FloatConfig:Get("kFloatPosY")
    if x and y and x ~= 0 and y ~= 0 then
        return x, y
    end
    local sw, sh = self:GetScreenSize()
    return sw - 150, sh - 80
end

function FloatMenu:RestorePosition()
    local x = FloatConfig:Get("kFloatPosX")
    local y = FloatConfig:Get("kFloatPosY")
    if not x or not y or x == 0 and y == 0 then
        local sw, sh = self:GetScreenSize()
        FloatConfig:Set("kFloatPosX", sw - 150)
        FloatConfig:Set("kFloatPosY", sh - 80)
        FloatConfig:Save()
    end
end

function FloatMenu:SavePosition(x, y)
    FloatConfig:Set("kFloatPosX", math.floor(x))
    FloatConfig:Set("kFloatPosY", math.floor(y))
    FloatConfig:Save()
end

function FloatMenu:ClampPosition(x, y)
    local sw, sh = self:GetScreenSize()
    x = math.max(6, math.min(x, sw - 6))
    y = math.max(6, math.min(y, sh - 6))
    return x, y
end

function FloatMenu:GetMousePosition(event)
    local mx, my = 0, 0
    pcall(function()
        local lib = import("KismetInputLibrary")
        if lib and lib.PointerEvent_GetScreenSpacePosition then
            local pos = lib.PointerEvent_GetScreenSpacePosition(event)
            if pos then
                mx, my = pos.X or 0, pos.Y or 0
            end
        end
    end)
    if mx == 0 and my == 0 then
        pcall(function()
            if event and event.GetScreenSpacePosition then
                local pos = event:GetScreenSpacePosition()
                if pos then
                    mx, my = pos.X or 0, pos.Y or 0
                end
            end
        end)
    end
    return mx, my
end

function FloatMenu:GetWidgetScreenPosition(widget)
    local x, y = 0, 0
    pcall(function()
        local util = require("client.common.ui_util")
        if util and util.GetWidgetViewportPos then
            local pos = util.GetWidgetViewportPos(widget)
            if pos then
                x, y = pos.X or 0, pos.Y or 0
            end
        end
    end)
    return x, y
end

function FloatMenu:ApplyTextStyle(widget, size)
    if not widget or not self:IsValidWidget(widget) then return end
    pcall(function()
        local font = widget.Font
        if font then
            font.Size = size or 18
            font.IsBold = true
            widget:SetFont(font)
        end
    end)
    pcall(function()
        widget:SetColorAndOpacity(FSlateColor(FLinearColor(1, 1, 1, 1)))
    end)
end

function FloatMenu:BindDragEvents()
    local btn = self.floatBtn
    if not btn or not self:IsValidWidget(btn) then return end
    local trigger = btn.Button_Temp or btn
    self.dragState = nil
    self:AddControlEvent(trigger, "OnMouseButtonDownEvent", function(event)
        local mx, my = self:GetMousePosition(event)
        local bx, by = self:GetButtonCurrentPosition()
        self.dragState = {
            active = true,
            startX = mx,
            startY = my,
            startBX = bx or 0,
            startBY = by or 0,
            moved = false,
            _ticks = 0,
        }
    end)
    self:AddControlEvent(trigger, "OnMouseMoveEvent", function(event)
        if not self.dragState or not self.dragState.active then return end
        local mx, my = self:GetMousePosition(event)
        local dx = mx - self.dragState.startX
        local dy = my - self.dragState.startY
        if math.abs(dx) > 6 or math.abs(dy) > 6 then
            self.dragState.moved = true
            self.isDragging = true
            local newX = self.dragState.startBX + dx
            local newY = self.dragState.startBY + dy
            newX, newY = self:ClampPosition(newX, newY)
            self:SetButtonPosition(self.floatBtn, newX, newY)
            self:SavePosition(newX, newY)
        end
    end)
    self:AddControlEvent(trigger, "OnMouseButtonUpEvent", function()
        if self.dragState and self.dragState.moved then
            self.isDragging = false
            self.dragMoved = true
            self:AddTimer(0.35, function()
                self.dragMoved = false
            end)
        end
        self.dragState = nil
    end)
    self:AddControlEvent(trigger, "OnTouchStartedImplementation", function(event)
        local mx, my = self:GetMousePosition(event)
        local bx, by = self:GetButtonCurrentPosition()
        self.dragState = {
            active = true,
            startX = mx,
            startY = my,
            startBX = bx or 0,
            startBY = by or 0,
            moved = false,
            _ticks = 0,
        }
    end)
    self:AddControlEvent(trigger, "OnTouchMovedImplementation", function(event)
        if not self.dragState or not self.dragState.active then return end
        local mx, my = self:GetMousePosition(event)
        local dx = mx - self.dragState.startX
        local dy = my - self.dragState.startY
        if math.abs(dx) > 6 or math.abs(dy) > 6 then
            self.dragState.moved = true
            self.isDragging = true
            local newX = self.dragState.startBX + dx
            local newY = self.dragState.startBY + dy
            newX, newY = self:ClampPosition(newX, newY)
            self:SetButtonPosition(self.floatBtn, newX, newY)
            self:SavePosition(newX, newY)
        end
    end)
    self:AddControlEvent(trigger, "OnTouchEndedImplementation", function()
        if self.dragState and self.dragState.moved then
            self.isDragging = false
            self.dragMoved = true
            self:AddTimer(0.35, function()
                self.dragMoved = false
            end)
        end
        self.dragState = nil
    end)
end

function FloatMenu:GetButtonCurrentPosition()
    local slot = self:GetCanvasSlot(self.floatBtn)
    if slot then
        local success, pos = pcall(function()
            return slot:GetPosition()
        end)
        if success and pos then
            return pos.X or 0, pos.Y or 0
        end
    end
    return 0, 0
end

function FloatMenu:AddControlEvent(widget, eventName, callback)
    if not widget or not self:IsValidWidget(widget) then return end
    pcall(function()
        local delegate = self:GetDelegateContainer()
        if delegate then
            delegate:AddControlEvent(widget, eventName, callback)
            return
        end
    end)
    pcall(function()
        local evt = widget[eventName]
        if evt then
            if evt.Bind then
                evt:Bind(callback)
            elseif evt.Add then
                evt:Add(callback)
            end
        end
    end)
end

function FloatMenu:GetDelegateContainer()
    local success, result = pcall(function()
        local module = require("client.slua_ui_framework.delegate_container")
        if module then
            return module()
        end
    end)
    if success and result then return result end
    return nil
end

function FloatMenu:BindClickEvent()
    local btn = self.floatBtn
    if not btn or not self:IsValidWidget(btn) then return end
    local trigger = btn.Button_Temp or btn
    self:AddControlEvent(trigger, "OnClicked", function()
        if self.dragMoved then return end
        self:Toggle()
    end)
end

function FloatMenu:BindBallEvents()
    if not self.floatBtn or not self:IsValidWidget(self.floatBtn) then return end
    if self._eventsBound then return end
    local trigger = self.floatBtn.Button_Temp or self.floatBtn
    self:AddControlEvent(trigger, "OnClicked", function()
        if self.dragMoved then return end
        self:Toggle()
    end)
    self._eventsBound = true
end

function FloatMenu:AddTimer(delay, callback)
    pcall(function()
        local ticker = _G.Mytimer_ticker
        if not ticker then
            ticker = require("common.time_ticker")
            _G.Mytimer_ticker = ticker
        end
        if ticker and ticker.AddTimer then
            ticker:AddTimer(delay, callback)
            return
        end
    end)
    pcall(function()
        local pc = self:GetPlayerController()
        if pc and self:IsValidWidget(pc) and pc.AddGameTimer then
            pc:AddGameTimer(delay, false, callback)
        end
    end)
end

function FloatMenu:Toggle()
    if self._toggleGuard then return end
    self._toggleGuard = true
    self:AddTimer(0.35, function()
        self._toggleGuard = false
    end)
    if self.isOpen then
        self:Close()
    else
        self:Open()
    end
end

function FloatMenu:Open()
    if self.isOpen then return end
    if FloatConfig:IsEnabled("ktyBSia") == false then
        return
    end
    self:EnsureTrigger()
    if not self.floatBtn or not self:IsValidWidget(self.floatBtn) then return end
    local panel, canvas = self:CreateMenuPanel()
    if not panel or not canvas then return end
    self.menuWidget = panel
    self.panelRoot = panel
    self.panelCanvas = canvas
    self.isOpen = true
    self:BuildMenuOptions(canvas)
    self:AddCloseButton(canvas)
    self:AddTitle(canvas)
end

function FloatMenu:Close()
    if not self.isOpen then return end
    if self.settingsPage then
        pcall(function()
            if self.settingsPage.Close then
                self.settingsPage:Close()
            end
        end)
        self.settingsPage = nil
    end
    if self.menuWidget then
        pcall(function()
            if self:IsValidWidget(self.menuWidget) then
                self.menuWidget:RemoveFromParent()
            end
        end)
        self.menuWidget = nil
    end
    self.panelRoot = nil
    self.panelCanvas = nil
    self.closeBtn = nil
    self.isOpen = false
    FloatConfig:Save()
end

function FloatMenu:CreateMenuPanel()
    local panel = self:LoadWidget("/Game/UMG/UI_BP/Common/Common_Mask_UIBP")
    if not panel or not self:IsValidWidget(panel) then return nil, nil end
    panel:SetWidgetVisibility(self:GetVisibility("Visible"))
    panel:SetRenderOpacity(1)
    local bg = panel.Image_Bg or panel.Image_Mask
    if bg and self:IsValidWidget(bg) then
        bg:SetBrushFromPathAsync("/Game/UMG/Texture/Atlas/Common/Common_Image_White.Common_Image_White", false)
        bg:SetBrushColor(FLinearColor(0, 0, 0, 0.7))
        bg:SetRenderOpacity(1)
        bg:SetWidgetVisibility(self:GetVisibility("SelfHitTestInvisible"))
    end
    self:AddToViewport(panel)
    local canvas = self:CreateCanvasPanel()
    if canvas and self:IsValidWidget(canvas) then
        panel:SetContent(canvas)
        canvas:SetWidgetVisibility(self:GetVisibility("Visible"))
        canvas:SetRenderOpacity(1)
    end
    return panel, canvas
end

function FloatMenu:CreateCanvasPanel()
    local success, result = pcall(function()
        local lib = import("STExtraBlueprintFunctionLibrary")
        if lib and lib.CreateWidgetByPathName then
            return lib.CreateWidgetByPathName("/Script/UMG.CanvasPanel", self:GetGameInstance())
        end
    end)
    if success and result and self:IsValidWidget(result) then return result end
    success, result = pcall(function()
        return slua.loadUI("/Script/UMG.CanvasPanel")
    end)
    if success and result and self:IsValidWidget(result) then return result end
    return nil
end

function FloatMenu:AddTitle(parent)
    if not parent or not self:IsValidWidget(parent) then return end
    local title = self:CreateTextBlock()
    if not title then return end
    title:SetText("ZOULE MOD " .. "V4.5")
    title:SetWidgetVisibility(self:GetVisibility("SelfHitTestInvisible"))
    title:SetRenderOpacity(1)
    local slot = parent:AddChildToCanvas(title)
    if slot then
        slot:SetAnchors(FAnchors(0.04, 0.02, 0.82, 0.1))
        slot:SetZOrder(5)
    end
end

function FloatMenu:CreateTextBlock()
    local success, result = pcall(function()
        local lib = import("STExtraBlueprintFunctionLibrary")
        if lib and lib.CreateWidgetByPathName then
            return lib.CreateWidgetByPathName("/Script/UMG.TextBlock", self:GetGameInstance())
        end
    end)
    if success and result and self:IsValidWidget(result) then return result end
    success, result = pcall(function()
        return slua.loadUI("/Script/UMG.TextBlock")
    end)
    if success and result and self:IsValidWidget(result) then return result end
    return nil
end

function FloatMenu:AddCloseButton(parent)
    if not parent or not self:IsValidWidget(parent) then return end
    local btn = self:LoadWidget("/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP")
    if not btn or not self:IsValidWidget(btn) then return end
    btn:SetWidgetVisibility(self:GetVisibility("Visible"))
    btn:SetRenderOpacity(1)
    local text = btn.RichText_Content or btn.Text
    if text and self:IsValidWidget(text) then
        text:SetText("X")
        text:SetColorAndOpacity(FSlateColor(FLinearColor(1, 1, 1, 1)))
        self:ApplyTextStyle(text, 24)
    end
    local bg = btn.Image_Bg or btn.Image_BtnBg
    if bg and self:IsValidWidget(bg) then
        bg:SetBrushFromPathAsync("/Game/UMG/Texture/Atlas/Common/Common_Image_White.Common_Image_White", false)
        bg:SetBrushColor(FLinearColor(0.35, 0.08, 0.08, 0.95))
        bg:SetRenderOpacity(1)
        bg:SetWidgetVisibility(self:GetVisibility("SelfHitTestInvisible"))
    end
    local trigger = btn.Button_Temp or btn
    local slot = parent:AddChildToCanvas(btn)
    if slot then
        slot:SetAnchors(FAnchors(0.88, 0.01, 0.99, 0.09))
        slot:SetZOrder(500)
    end
    self:AddControlEvent(trigger, "OnClicked", function()
        self:Close()
    end)
    self.closeBtn = btn
end

function FloatMenu:BuildMenuOptions(parent)
    if not parent or not self:IsValidWidget(parent) then return end
    local tabData = self:GetTabData()
    local currentTab = FloatConfig:Get("k9K3WqPBJ1") or 1
    local items = self:GetTabItems(currentTab)
    local yOffset = 60
    local rowHeight = 52
    local itemSpacing = 10
    for i, item in ipairs(items) do
        local widget = self:CreateMenuItem(item)
        if widget and self:IsValidWidget(widget) then
            local slot = parent:AddChildToCanvas(widget)
            if slot then
                slot:SetAnchors(FAnchors(0.5, 0, 0.5, 0))
                slot:SetAlignment(FVector2D(0.5, 0))
                slot:SetPosition(FVector2D(0, yOffset + (i - 1) * (rowHeight + itemSpacing)))
                slot:SetSize(FVector2D(420, rowHeight))
                slot:SetZOrder(1)
            end
        end
    end
    self:BuildTabs(parent, tabData, currentTab)
end

function FloatMenu:GetTabData()
    return {
        "ESP",
        "战斗",
        "武器修改",
        "自瞄",
        "移动",
        "其他",
    }
end

function FloatMenu:GetTabItems(tabIndex)
    local items = {
        [1] = {
            {key = "kXGORqUEis", label = "方框绘制", kind = "toggle"},
            {key = "kwjFS1", label = "显示距离", kind = "toggle"},
            {key = "krmUO9H0V", label = "显示名字", kind = "toggle"},
            {key = "kaU1fvv3tY", label = "显示血量", kind = "toggle"},
            {key = "kEspDistOn", label = "ESP距离开关", kind = "toggle"},
            {key = "kEspDistVal", label = "ESP距离", kind = "slider", min = 100, max = 800, default = 300},
            {key = "kEspCountOn", label = "显示总数", kind = "toggle"},
            {key = "kmqnRgO", label = "忽略机器人", kind = "toggle"},
        },
        [2] = {
            {key = "kgiOsFCb", label = "165 FPS", kind = "toggle"},
            {key = "k3TQGQ", label = "iPad视野", kind = "toggle"},
            {key = "kwQzYrr", label = "FOV 80-150", kind = "slider", min = 80, max = 150, default = 90},
            {key = "k9P61lm5", label = "去除雾效", kind = "toggle"},
            {key = "kRm7Grass", label = "移除草地", kind = "toggle"},
            {key = "kSkyColOn", label = "黑色天空", kind = "toggle"},
        },
        [3] = {
            {key = "kOCoNsC", label = "无后坐力", kind = "toggle"},
            {key = "kyBrFAnp", label = "无散布", kind = "toggle"},
            {key = "k8OKXKT8m", label = "移除抖动", kind = "toggle"},
            {key = "kUIS4Zh", label = "快速切枪", kind = "toggle"},
            {key = "kFastAimOn", label = "快速开镜", kind = "toggle"},
            {key = "kMUeXST", label = "命中特效", kind = "toggle"},
            {key = "kHitEffectVal", label = "特效值 1-200", kind = "slider", min = 1, max = 200, default = 2},
            {key = "kFastReloadOn", label = "快速换弹", kind = "toggle"},
        },
        [4] = {
            {key = "kB9PfO", label = "旧自瞄系统", kind = "toggle"},
            {key = "kNewAimOn", label = "新自瞄系统", kind = "toggle"},
            {key = "kNewAimPart", label = "瞄准部位 0-2", kind = "slider", min = 0, max = 2, default = 1},
            {key = "kNewAimSpd", label = "瞄准速度", kind = "slider", min = 0, max = 500, default = 20},
            {key = "kNewAimDist", label = "瞄准距离", kind = "slider", min = 10, max = 800, default = 500},
            {key = "kNewAimFov", label = "瞄准FOV", kind = "slider", min = 5, max = 180, default = 50},
            {key = "kNewAimRecoil", label = "后坐力补偿", kind = "slider", min = 0, max = 50, default = 50},
            {key = "kNewAimPred", label = "预判强度", kind = "slider", min = 0, max = 100, default = 100},
            {key = "kNewAimIgnDown", label = "跳过倒地", kind = "toggle"},
            {key = "kNewAimIgnBot", label = "跳过机器人", kind = "toggle"},
            {key = "kNewAimPrior", label = "瞄准优先级 0-1", kind = "slider", min = 0, max = 1, default = 0},
            {key = "kAimHead", label = "始终瞄准头部", kind = "toggle"},
        },
        [5] = {
            {key = "kR8wVJdV", label = "加速", kind = "toggle"},
            {key = "k2NelPpM", label = "加速倍率 100-250%", kind = "slider", min = 100, max = 250, default = 135},
            {key = "kcWjWY6", label = "超级跳跃", kind = "toggle"},
            {key = "kBcrCRI", label = "跳跃倍率 100-1000%", kind = "slider", min = 100, max = 1000, default = 200},
            {key = "kLNzXG", label = "超级跳远", kind = "toggle"},
            {key = "k6U1WxRpZ", label = "跳远倍率 100-1000%", kind = "slider", min = 100, max = 1000, default = 200},
        },
        [6] = {
            {key = "k3yxyFCez", label = "墙透", kind = "toggle"},
            {key = "kWe1Vjn6E", label = "隐藏颜色", kind = "slider", min = 1, max = 9, default = 7},
            {key = "kcHOHW", label = "可见颜色", kind = "slider", min = 1, max = 9, default = 5},
            {key = "kKrVngZh", label = "中文语言", kind = "toggle"},
            {key = "kCharScaleOn", label = "角色缩放", kind = "toggle"},
            {key = "kCharScaleVal", label = "角色大小 50-200", kind = "slider", min = 50, max = 200, default = 100},
            {key = "kWpnScaleOn", label = "武器缩放", kind = "toggle"},
            {key = "kWpnScaleVal", label = "武器大小 50-200", kind = "slider", min = 50, max = 200, default = 100},
            {key = "kSpinOn", label = "自动旋转", kind = "toggle"},
            {key = "kSpinSpd", label = "旋转速度 30-1800", kind = "slider", min = 30, max = 1800, default = 360},
            {key = "kWpnOrbitOn", label = "武器轨道", kind = "toggle"},
            {key = "kWpnOrbitSpd", label = "轨道速度 30-720", kind = "slider", min = 30, max = 720, default = 180},
            {key = "kSB7Ihy", label = "上帝模式", kind = "toggle"},
            {key = "kwywn8vIL", label = "子弹体积增大", kind = "toggle"},
            {key = "kMagicBulletHeadVal", label = "头部体积 0-500", kind = "slider", min = 0, max = 500, default = 150},
            {key = "kMagicBulletBodyVal", label = "身体体积 0-500", kind = "slider", min = 0, max = 500, default = 50},
            {key = "kMagicBulletLegVal", label = "腿部体积 0-500", kind = "slider", min = 0, max = 500, default = 50},
            {key = "kMagicBulletArmVal", label = "手臂体积 0-500", kind = "slider", min = 0, max = 500, default = 50},
        },
    }
    return items[tabIndex] or {}
end

function FloatMenu:CreateMenuItem(item)
    local widget = self:LoadWidget("/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP")
    if not widget or not self:IsValidWidget(widget) then return nil end
    widget:SetWidgetVisibility(self:GetVisibility("Visible"))
    widget:SetRenderOpacity(1)
    local value = FloatConfig:Get(item.key)
    local displayText = item.label
    if item.kind == "toggle" then
        displayText = displayText .. (value and "  [ON]" or "  [OFF]")
    elseif item.kind == "slider" then
        displayText = displayText .. "  [" .. tostring(value or item.default) .. "]"
    end
    local text = widget.RichText_Content or widget.Text
    if text and self:IsValidWidget(text) then
        text:SetText(displayText)
        self:ApplyTextStyle(text, 18)
    end
    local bg = widget.Image_Bg or widget.Image_BtnBg
    if bg and self:IsValidWidget(bg) then
        bg:SetBrushFromPathAsync("/Game/UMG/Texture/Atlas/Common/Common_Image_White.Common_Image_White", false)
        bg:SetBrushColor(FLinearColor(0.03, 0.03, 0.06, 1))
        bg:SetRenderOpacity(1)
        bg:SetWidgetVisibility(self:GetVisibility("SelfHitTestInvisible"))
    end
    local trigger = widget.Button_Temp or widget
    self:AddControlEvent(trigger, "OnClicked", function()
        self:OnMenuItemClick(item)
    end)
    return widget
end

function FloatMenu:OnMenuItemClick(item)
    local current = FloatConfig:Get(item.key)
    if item.kind == "toggle" then
        local newVal = not current
        FloatConfig:Set(item.key, newVal)
        FloatConfig:Save()
        self:RefreshMenu()
        self:ApplyConfig(item.key, newVal)
    elseif item.kind == "slider" then
        local step = 1
        if item.key == "kNewAimPart" then step = 1 end
        if item.key == "kNewAimPrior" then step = 1 end
        local newVal = (current or item.default) + step
        if newVal > item.max then
            newVal = item.min
        end
        FloatConfig:Set(item.key, newVal)
        FloatConfig:Save()
        self:RefreshMenu()
        self:ApplyConfig(item.key, newVal)
    end
end

function FloatMenu:RefreshMenu()
    if not self.isOpen then return end
    if self.panelCanvas and self:IsValidWidget(self.panelCanvas) then
        pcall(function()
            local count = self.panelCanvas:GetChildrenCount()
            for i = count - 1, 0, -1 do
                local child = self.panelCanvas:GetChildAt(i)
                if child and self:IsValidWidget(child) then
                    self.panelCanvas:RemoveChildAt(i)
                end
            end
        end)
        self:BuildMenuOptions(self.panelCanvas)
        self:AddTitle(self.panelCanvas)
        self:AddCloseButton(self.panelCanvas)
    end
end

function FloatMenu:BuildTabs(parent, tabData, currentTab)
    if not parent or not self:IsValidWidget(parent) then return end
    for i, tabName in ipairs(tabData) do
        local btn = self:CreateTabButton(tabName, i == currentTab)
        if btn and self:IsValidWidget(btn) then
            local slot = parent:AddChildToCanvas(btn)
            if slot then
                local xPos = 0.02 + (i - 1) * 0.16
                slot:SetAnchors(FAnchors(xPos, 0.11, xPos + 0.14, 0.16))
                slot:SetZOrder(2)
            end
            self:AddControlEvent(btn, "OnClicked", function()
                local newTab = i
                if newTab ~= currentTab then
                    FloatConfig:Set("k9K3WqPBJ1", newTab)
                    FloatConfig:Save()
                    self:RefreshMenu()
                end
            end)
        end
    end
end

function FloatMenu:CreateTabButton(text, isSelected)
    local widget = self:LoadWidget("/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP")
    if not widget or not self:IsValidWidget(widget) then return nil end
    widget:SetWidgetVisibility(self:GetVisibility("Visible"))
    widget:SetRenderOpacity(1)
    local txt = widget.RichText_Content or widget.Text
    if txt and self:IsValidWidget(txt) then
        txt:SetText(text)
        self:ApplyTextStyle(txt, 16)
    end
    local bg = widget.Image_Bg or widget.Image_BtnBg
    if bg and self:IsValidWidget(bg) then
        bg:SetBrushFromPathAsync("/Game/UMG/Texture/Atlas/Common/Common_Image_White.Common_Image_White", false)
        if isSelected then
            bg:SetBrushColor(FLinearColor(0.2, 0.45, 0.95, 1))
        else
            bg:SetBrushColor(FLinearColor(0.03, 0.03, 0.06, 0.7))
        end
        bg:SetRenderOpacity(1)
        bg:SetWidgetVisibility(self:GetVisibility("SelfHitTestInvisible"))
    end
    return widget
end

function FloatMenu:ApplyConfig(key, value)
    pcall(function()
        local func = self["_Apply_" .. key]
        if func then
            func(self, value)
        end
    end)
end

function FloatMenu:_Apply_ktyBSia(value)
    if not value then
        self:Close()
        self:DestroyFloatButton()
    else
        self:EnsureTrigger()
    end
end

function FloatMenu:_Apply_kgiOsFCb(value)
    if value then
        pcall(function()
            local gi = self:GetGameInstance()
            if gi and self:IsValidWidget(gi) then
                gi:ExecuteCMD("t.MaxFPS", "165")
                gi:ExecuteCMD("r.FrameRateLimit", "165")
            end
        end)
    end
end

function FloatMenu:_Apply_k3TQGQ(value)
    if value then
        pcall(function()
            local util = require("client.logic.setting.setting_config")
            if util then
                if util.TpViewValue then util.TpViewValue.max = 150 end
                if util.FpViewValue then util.FpViewValue.max = 150 end
            end
        end)
    end
end

function FloatMenu:_Apply_kwQzYrr(value)
    pcall(function()
        local pc = self:GetPlayerController()
        if pc and self:IsValidWidget(pc) then
            local char = pc:GetPlayerCharacterSafety()
            if char and self:IsValidWidget(char) then
                local cam = char.ThirdPersonCameraComponent
                if cam and self:IsValidWidget(cam) then
                    cam.FieldOfView = value
                end
            end
        end
    end)
end

function FloatMenu:_Apply_kOCoNsC(value)
    pcall(function()
        local pc = self:GetPlayerController()
        if pc and self:IsValidWidget(pc) then
            local char = pc:GetPlayerCharacterSafety()
            if char and self:IsValidWidget(char) then
                if value then
                    char.RecoilKick = 0
                    char.RecoilKickADS = 0
                    char.AnimationKick = 0
                    char.GameDeviationFactor = 0
                    char.GameDeviationAccuracy = 0
                    if char.RecoilInfo then
                        char.RecoilInfo.VerticalRecoilMin = 0
                        char.RecoilInfo.VerticalRecoilMax = 0
                    end
                end
            end
        end
    end)
end

function FloatMenu:_Apply_kFastReloadOn(value)
    pcall(function()
        local pc = self:GetPlayerController()
        if pc and self:IsValidWidget(pc) then
            local char = pc:GetPlayerCharacterSafety()
            if char and self:IsValidWidget(char) then
                local weapon = char:GetCurrentWeapon()
                if weapon and self:IsValidWidget(weapon) then
                    local attr = weapon.AttrModifierCompoment
                    if attr and self:IsValidWidget(attr) then
                        if value then
                            attr:LuaSetValueToAttributeSafety("ReloadRate", 100)
                            attr:LuaSetValueToAttributeSafety("ReloadTime", 0.01)
                            attr:LuaSetValueToAttributeSafety("ReloadTimeTactical", 0.01)
                            attr:LuaSetValueToAttributeSafety("ReloadDurationStart", 0.01)
                            attr:LuaSetValueToAttributeSafety("ReloadDurationLoop", 0.01)
                        end
                    end
                end
            end
        end
    end)
end

function FloatMenu:_Apply_kFastAimOn(value)
    pcall(function()
        local pc = self:GetPlayerController()
        if pc and self:IsValidWidget(pc) then
            local char = pc:GetPlayerCharacterSafety()
            if char and self:IsValidWidget(char) then
                local weapon = char:GetCurrentWeapon()
                if weapon and self:IsValidWidget(weapon) then
                    if value then
                        weapon.WeaponAimInTime = 10
                    end
                end
            end
        end
    end)
end

function FloatMenu:_Apply_kR8wVJdV(value)
    pcall(function()
        local pc = self:GetPlayerController()
        if pc and self:IsValidWidget(pc) then
            local char = pc:GetPlayerCharacterSafety()
            if char and self:IsValidWidget(char) then
                local move = char.STCharacterMovement or char.CharacterMovement
                if move and self:IsValidWidget(move) then
                    if value then
                        local speedPercent = FloatConfig:Get("k2NelPpM") or 135
                        local baseSpeed = 600
                        pcall(function()
                            local attr = char.AttrModifyComp
                            if attr and attr.GetAttributeOrignalValue then
                                baseSpeed = attr:GetAttributeOrignalValue("MaxWalkSpeed") or 600
                            end
                        end)
                        move.MaxWalkSpeed = baseSpeed * (speedPercent / 100)
                    end
                end
            end
        end
    end)
end

function FloatMenu:_Apply_kcWjWY6(value)
    pcall(function()
        local pc = self:GetPlayerController()
        if pc and self:IsValidWidget(pc) then
            local char = pc:GetPlayerCharacterSafety()
            if char and self:IsValidWidget(char) then
                local move = char.STCharacterMovement or char.CharacterMovement
                if move and self:IsValidWidget(move) then
                    if value then
                        local jumpPercent = FloatConfig:Get("kBcrCRI") or 200
                        local baseJump = 443
                        pcall(function()
                            local attr = char.AttrModifyComp
                            if attr and attr.GetAttributeOrignalValue then
                                baseJump = attr:GetAttributeOrignalValue("JumpZVelocity") or 443
                            end
                        end)
                        move.JumpZVelocity = baseJump * (jumpPercent / 100)
                        move:SetGravityScale(0.6)
                    else
                        move:SetGravityScale(1)
                    end
                end
            end
        end
    end)
end

function FloatMenu:_Apply_k3yxyFCez(value)
    if value then
        self:AddTimer(0.1, function()
            pcall(function()
                local allPawns = Game.GetAllPlayerPawns()
                if allPawns then
                    for i = 0, allPawns:Num() - 1 do
                        local pawn = allPawns:Get(i)
                        if pawn and self:IsValidWidget(pawn) then
                            local meshes = self:GetAllMeshComponents(pawn)
                            for _, mesh in ipairs(meshes) do
                                if self:IsValidWidget(mesh) then
                                    mesh.bDisableDepthTest = true
                                    mesh.BlendMode = 2
                                    pcall(function()
                                        mesh:SetRenderCustomDepth(true)
                                    end)
                                end
                            end
                        end
                    end
                end
            end)
        end)
    else
        pcall(function()
            local allPawns = Game.GetAllPlayerPawns()
            if allPawns then
                for i = 0, allPawns:Num() - 1 do
                    local pawn = allPawns:Get(i)
                    if pawn and self:IsValidWidget(pawn) then
                        local meshes = self:GetAllMeshComponents(pawn)
                        for _, mesh in ipairs(meshes) do
                            if self:IsValidWidget(mesh) then
                                mesh.bDisableDepthTest = false
                                mesh.BlendMode = 0
                                pcall(function()
                                    mesh:SetRenderCustomDepth(false)
                                end)
                            end
                        end
                    end
                end
            end
        end)
    end
end

function FloatMenu:GetAllMeshComponents(actor)
    local meshes = {}
    pcall(function()
        local mesh = actor.Mesh
        if mesh and self:IsValidWidget(mesh) then
            table.insert(meshes, mesh)
        end
    end)
    pcall(function()
        local lib = import("SkeletalMeshComponent")
        if lib then
            local comps = actor:GetComponentsByClass(lib)
            if comps then
                for i = 0, comps:Num() - 1 do
                    local comp = comps:Get(i)
                    if comp and self:IsValidWidget(comp) then
                        table.insert(meshes, comp)
                    end
                end
            end
        end
    end)
    return meshes
end

function FloatMenu:_Apply_kRm7Grass(value)
    pcall(function()
        local gi = self:GetGameInstance()
        if gi and self:IsValidWidget(gi) then
            if value then
                gi:ExecuteCMD("r.DisableGrassRender", "1")
            else
                gi:ExecuteCMD("r.DisableGrassRender", "0")
            end
        end
    end)
end

function FloatMenu:_Apply_kSkyColOn(value)
    pcall(function()
        local pc = self:GetPlayerController()
        if pc and self:IsValidWidget(pc) then
            if value then
                local gi = self:GetGameInstance()
                if gi and self:IsValidWidget(gi) then
                    gi:ExecuteCMD("r.CylinderMaxDrawHeight", "9999")
                end
            else
                local gi = self:GetGameInstance()
                if gi and self:IsValidWidget(gi) then
                    gi:ExecuteCMD("r.CylinderMaxDrawHeight", "0")
                end
            end
        end
    end)
end

function FloatMenu:_Apply_kCharScaleOn(value)
    pcall(function()
        local pc = self:GetPlayerController()
        if pc and self:IsValidWidget(pc) then
            local char = pc:GetPlayerCharacterSafety()
            if char and self:IsValidWidget(char) then
                local mesh = char.Mesh
                if mesh and self:IsValidWidget(mesh) then
                    if value then
                        local scale = FloatConfig:Get("kCharScaleVal") or 100
                        mesh:SetRelativeScale3D(FVector(scale / 100, scale / 100, scale / 100))
                    else
                        mesh:SetRelativeScale3D(FVector(1, 1, 1))
                    end
                end
            end
        end
    end)
end

function FloatMenu:_Apply_kWpnScaleOn(value)
    pcall(function()
        local pc = self:GetPlayerController()
        if pc and self:IsValidWidget(pc) then
            local char = pc:GetPlayerCharacterSafety()
            if char and self:IsValidWidget(char) then
                local weapon = char:GetCurrentWeapon()
                if weapon and self:IsValidWidget(weapon) then
                    if value then
                        local scale = FloatConfig:Get("kWpnScaleVal") or 100
                        local mesh = weapon:GetWeaponMeshComponent()
                        if mesh and self:IsValidWidget(mesh) then
                            mesh:SetRelativeScale3D(FVector(scale / 100, scale / 100, scale / 100))
                        end
                    end
                end
            end
        end
    end)
end

function FloatMenu:_Apply_kSpinOn(value)
    if value then
        self:AddTimer(0.016, function()
            self:SpinLoop()
        end)
    end
end

function FloatMenu:SpinLoop()
    if not FloatConfig:IsEnabled("kSpinOn") then return end
    pcall(function()
        local pc = self:GetPlayerController()
        if pc and self:IsValidWidget(pc) then
            local char = pc:GetPlayerCharacterSafety()
            if char and self:IsValidWidget(char) then
                local mesh = char.Mesh
                if mesh and self:IsValidWidget(mesh) then
                    local rot = mesh:GetRelativeRotation()
                    rot.Yaw = rot.Yaw + (FloatConfig:Get("kSpinSpd") or 360) * 0.016
                    mesh:SetRelativeRotation(rot)
                end
            end
        end
    end)
    self:AddTimer(0.016, function()
        self:SpinLoop()
    end)
end

function FloatMenu:Destroy()
    self:Close()
    self:DestroyFloatButton()
    self._eventsBound = false
    self.dragState = nil
    self.isDragging = false
    self.dragMoved = false
end

_G.ZOULE_MOD_SJes35JTx = FloatMenu
_G.ZOULE_MOD_AsWJmeFkU = function() FloatMenu:Toggle() end
_G.ZOULE_MOD_rsOzAUbtu = function() FloatMenu:Open() end
_G.ZOULE_MOD_bxuVFjp7W = function() FloatMenu:Close() end

local function InitFloatMenu()
    pcall(function()
        FloatMenu:Initialize()
    end)
end

local function InitLoop()
    -- Reload config every loop to check for .h file changes
    FloatConfig:Load()
    
    if FloatConfig:IsEnabled("ktyBSia") then
        if not FloatMenu.floatBtn or not FloatMenu:IsValidWidget(FloatMenu.floatBtn) then
            pcall(function()
                FloatMenu:Initialize()
            end)
        end
    else
        if FloatMenu.floatBtn then
            FloatMenu:DestroyFloatButton()
        end
        if FloatMenu.isOpen then
            FloatMenu:Close()
        end
    end
end

pcall(function()
    local ticker = _G.Mytimer_ticker
    if not ticker then
        ticker = require("common.time_ticker")
        _G.Mytimer_ticker = ticker
    end
    if ticker and ticker.AddTimerLoop then
        ticker:AddTimerLoop(2, InitLoop, -1, 2)
    end
end)

FloatMenu:Initialize()
