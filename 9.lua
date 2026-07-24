local FloatConfig = {
    CONFIG_FILE = "/storage/emulated/0/Android/data/com.pubg.imobile/files/ZOULEMOD.ini",
    HEADER_FILE = "/storage/emulated/0/Android/data/com.pubg.imobile/files/MenuConfig.h",
    defaults = {
        ktyBSia = true,
        kFloatPosX = 0,
        kFloatPosY = 0,
        k9K3WqPBJ1 = 1,
    },
    current = {},
    Load = function(self)
        self:CheckHeaderToggle()
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
        pcall(function()
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
            local file = io.open(self.HEADER_FILE, "w") -- Keep header file updated if possible
            if file then
                file:write("// ZOULE MOD MENU CONFIG\n// Set to \"on\" to enable menu, \"off\" to disable\n#define MENU_STATUS \"" .. (self.current["ktyBSia"] and "on" or "off") .. "\"\n")
                file:close()
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
    menuWidget = nil,
    closeBtn = nil,
    currentTab = 1,
    _toggleGuard = false,
    _eventsBound = false,
}

function FloatMenu:Initialize()
    FloatConfig:Load()
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

function FloatMenu:GetGameInstance()
    local success, result = pcall(function()
        local ui_util = require("client.common.ui_util")
        if ui_util and ui_util.GetGameInstance then
            return ui_util.GetGameInstance()
        end
    end)
    if success and result then return result end
    
    local success, result = pcall(function()
        if slua_GameFrontendHUD then
            return slua_GameFrontendHUD:GetGameInstance()
        end
    end)
    if success and result then return result end
    
    local success, result = pcall(function()
        local GameInstClass = import("STExtraGameInstance")
        return GameInstClass.GetInstance()
    end)
    if success and result then return result end
    return nil
end

function FloatMenu:LoadWidget(path)
    local success, widget = pcall(function()
        local lib = import("STExtraBlueprintFunctionLibrary")
        if lib and lib.CreateWidgetByPathName then
            return lib.CreateWidgetByPathName(path, self:GetGameInstance() or slua_GameFrontendHUD)
        end
    end)
    if success and widget then return widget end
    
    success, widget = pcall(function()
        if slua and slua.loadUI then
            return slua.loadUI(path)
        end
    end)
    if success and widget then return widget end
    return nil
end

function FloatMenu:CreateFloatButton()
    self:DestroyFloatButton()
    local btn = self:LoadWidget("/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP")
    if not btn then return end
    
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
    
    self:AddToViewport(btn)
    local posX, posY = self:GetSavedPosition()
    self:SetButtonPosition(btn, posX, posY)
    self.floatBtn = btn
    self.floatSlot = self:GetCanvasSlot(btn)
    self:BindDragEvents()
    self:BindClickEvent()
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

function FloatMenu:GetVisibility(mode)
    if UEnums and UEnums.ESlateVisibility then
        return UEnums.ESlateVisibility[mode] or 1
    end
    local vis = { Collapsed = 0, Visible = 1, SelfHitTestInvisible = 2, HitTestInvisible = 3, Hidden = 4 }
    return vis[mode] or 1
end

function FloatMenu:AddToViewport(widget)
    pcall(function()
        local game_frontend_hud = require("game_frontend_hud")
        if game_frontend_hud and game_frontend_hud.AddToContainer then
            game_frontend_hud.AddToContainer("Top", widget, 9300)
            return
        end
    end)
    
    pcall(function()
        widget:AddToViewport(9300)
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
    return 1700, 1000 -- Default bottom right
end

function FloatMenu:SavePosition(x, y)
    FloatConfig:Set("kFloatPosX", math.floor(x))
    FloatConfig:Set("kFloatPosY", math.floor(y))
    FloatConfig:Save()
end

function FloatMenu:GetMousePosition(event)
    local mx, my = 0, 0
    pcall(function()
        local lib = import("KismetInputLibrary")
        if lib and lib.PointerEvent_GetScreenSpacePosition then
            local pos = lib.PointerEvent_GetScreenSpacePosition(event)
            if pos then mx, my = pos.X or 0, pos.Y or 0 end
        end
    end)
    return mx, my
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
    
    self:AddControlEvent(trigger, "OnMouseButtonDownEvent", function(event)
        local mx, my = self:GetMousePosition(event)
        local slot = self:GetCanvasSlot(self.floatBtn)
        local bx, by = 0, 0
        if slot then
            local pos = slot:GetPosition()
            bx, by = pos.X, pos.Y
        end
        self.dragState = {
            active = true,
            startX = mx,
            startY = my,
            startBX = bx,
            startBY = by,
            moved = false
        }
    end)
    
    self:AddControlEvent(trigger, "OnMouseMoveEvent", function(event)
        if not self.dragState or not self.dragState.active then return end
        local mx, my = self:GetMousePosition(event)
        local dx = mx - self.dragState.startX
        local dy = my - self.dragState.startY
        if math.abs(dx) > 5 or math.abs(dy) > 5 then
            self.dragState.moved = true
            self.isDragging = true
            local newX = self.dragState.startBX + dx
            local newY = self.dragState.startBY + dy
            self:SetButtonPosition(self.floatBtn, newX, newY)
            self:SavePosition(newX, newY)
        end
    end)
    
    self:AddControlEvent(trigger, "OnMouseButtonUpEvent", function()
        if self.dragState and self.dragState.moved then
            self.isDragging = false
            self.dragMoved = true
            self:AddTimer(0.3, function() self.dragMoved = false end)
        end
        self.dragState = nil
    end)
end

function FloatMenu:AddControlEvent(widget, eventName, callback)
    if not widget or not self:IsValidWidget(widget) then return end
    pcall(function()
        local evt = widget[eventName]
        if evt then
            if evt.Bind then evt:Bind(callback)
            elseif evt.Add then evt:Add(callback) end
        end
    end)
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

function FloatMenu:AddTimer(delay, callback)
    pcall(function()
        local ticker = _G.Mytimer_ticker or require("common.time_ticker")
        _G.Mytimer_ticker = ticker
        if ticker and ticker.AddTimer then
            ticker:AddTimer(delay, callback)
        end
    end)
end

function FloatMenu:Toggle()
    if self._toggleGuard then return end
    self._toggleGuard = true
    self:AddTimer(0.3, function() self._toggleGuard = false end)
    if self.isOpen then self:Close() else self:Open() end
end

function FloatMenu:Open()
    if self.isOpen then return end
    if not FloatConfig:IsEnabled("ktyBSia") then return end
    
    local panel = self:LoadWidget("/Game/UMG/UI_BP/Common/Common_Mask_UIBP")
    if not panel then return end
    
    panel:SetWidgetVisibility(self:GetVisibility("Visible"))
    panel:SetRenderOpacity(1)
    
    local canvas = self:LoadWidget("/Script/UMG.CanvasPanel")
    if canvas then
        panel:SetContent(canvas)
        self.panelCanvas = canvas
        self:BuildMenuOptions(canvas)
        self:AddCloseButton(canvas)
        self:AddTitle(canvas)
    end
    
    self:AddToViewport(panel)
    self.menuWidget = panel
    self.isOpen = true
end

function FloatMenu:Close()
    if not self.isOpen then return end
    if self.menuWidget then
        pcall(function() self.menuWidget:RemoveFromParent() end)
        self.menuWidget = nil
    end
    self.isOpen = false
    FloatConfig:Save()
end

function FloatMenu:AddTitle(parent)
    local title = self:LoadWidget("/Script/UMG.TextBlock")
    if title then
        title:SetText("ZOULE MOD V4.5")
        self:ApplyTextStyle(title, 22)
        local slot = parent:AddChildToCanvas(title)
        if slot then
            slot:SetAnchors(FAnchors(0.05, 0.05, 0.5, 0.1))
            slot:SetPosition(FVector2D(20, 20))
        end
    end
end

function FloatMenu:AddCloseButton(parent)
    local btn = self:LoadWidget("/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP")
    if btn then
        local text = btn.RichText_Content or btn.Text
        if text then text:SetText("X") end
        local slot = parent:AddChildToCanvas(btn)
        if slot then
            slot:SetAnchors(FAnchors(0.9, 0.05, 0.95, 0.1))
            slot:SetPosition(FVector2D(-20, 20))
            slot:SetSize(FVector2D(50, 50))
        end
        self:AddControlEvent(btn.Button_Temp or btn, "OnClicked", function() self:Close() end)
    end
end

function FloatMenu:BuildMenuOptions(parent)
    local items = self:GetTabItems(FloatConfig:Get("k9K3WqPBJ1") or 1)
    for i, item in ipairs(items) do
        local widget = self:CreateMenuItem(item)
        if widget then
            local slot = parent:AddChildToCanvas(widget)
            if slot then
                slot:SetAnchors(FAnchors(0.5, 0, 0.5, 0))
                slot:SetAlignment(FVector2D(0.5, 0))
                slot:SetPosition(FVector2D(0, 100 + (i-1) * 60))
                slot:SetSize(FVector2D(400, 50))
            end
        end
    end
end

function FloatMenu:GetTabItems(tabIndex)
    local items = {
        [1] = {
            {key = "kXGORqUEis", label = "Wallhack", kind = "toggle"},
            {key = "kOCoNsC", label = "No Recoil", kind = "toggle"},
            {key = "kR8wVJdV", label = "Speed Hack", kind = "toggle"},
            {key = "kgiOsFCb", label = "165 FPS", kind = "toggle"},
        }
    }
    return items[tabIndex] or items[1]
end

function FloatMenu:CreateMenuItem(item)
    local widget = self:LoadWidget("/Game/UMG/UI_BP/Common/BaseComponent/CommonBaseComponent_TextButton_UIBP")
    if not widget then return nil end
    local val = FloatConfig:Get(item.key)
    local txt = widget.RichText_Content or widget.Text
    if txt then
        txt:SetText(item.label .. (val and " [ON]" or " [OFF]"))
        self:ApplyTextStyle(txt, 18)
    end
    self:AddControlEvent(widget.Button_Temp or widget, "OnClicked", function()
        FloatConfig:Set(item.key, not val)
        FloatConfig:Save()
        self:RefreshMenu()
    end)
    return widget
end

function FloatMenu:RefreshMenu()
    if self.isOpen and self.panelCanvas then
        pcall(function() self.panelCanvas:ClearChildren() end)
        self:BuildMenuOptions(self.panelCanvas)
        self:AddCloseButton(self.panelCanvas)
        self:AddTitle(self.panelCanvas)
    end
end

_G.ZOULE_MOD_Toggle = function() FloatMenu:Toggle() end

local function InitLoop()
    FloatConfig:Load()
    if FloatConfig:IsEnabled("ktyBSia") then
        if not FloatMenu.floatBtn or not FloatMenu:IsValidWidget(FloatMenu.floatBtn) then
            FloatMenu:Initialize()
        end
    else
        FloatMenu:Close()
        FloatMenu:DestroyFloatButton()
    end
end

pcall(function()
    local ticker = _G.Mytimer_ticker or require("common.time_ticker")
    if ticker and ticker.AddTimerLoop then
        ticker:AddTimerLoop(2, InitLoop, -1, 2)
    end
end)

FloatMenu:Initialize()
