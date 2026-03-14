-- ================================================================
-- MOONMANGO HUB v1.0
-- Universal UI Module untuk Roblox — dark minimalist style
-- Terinspirasi dari ZiaanHub
-- ================================================================
-- CARA PAKAI (dari script apapun):
--
--   local Hub = loadstring(game:HttpGet("URL_RAW_KAMU"))()
--   Hub:Init("MOONMANGO", "Sub-title di sini")
--
--   local main = Hub:AddTab("Main", "⚡")
--   Hub:AddSection(main, "Gameplay")
--   Hub:AddToggle(main, "Fitur", "Deskripsi", true, function(v) end)
--   Hub:AddSlider(main, "Speed", "Desc", 1, 900, 250, function(v) end)
--   Hub:AddDropdown(main, "Mode", "Desc", {"A","B"}, "A", function(v) end)
--   Hub:AddInput(main, "Input", "Desc", "placeholder...", function(t,enter) end)
--   Hub:AddButton(main, "Aksi", "Desc", "Klik", function() end)
-- ================================================================

local MoonMango = {}
MoonMango.__index = MoonMango

-- ================================================================
-- [1] SERVICES
-- ================================================================
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local Players          = game:GetService("Players")
local CoreGui          = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- ================================================================
-- [2] THEME — edit warna di sini untuk kustomisasi
-- ================================================================
local T = {
    -- Backgrounds
    BG          = Color3.fromRGB(11, 11, 15),
    SIDEBAR     = Color3.fromRGB(16, 16, 21),
    TOPBAR      = Color3.fromRGB(16, 16, 21),
    CARD        = Color3.fromRGB(21, 21, 28),
    CARD_HOVER  = Color3.fromRGB(27, 27, 36),
    CARD_STROKE = Color3.fromRGB(40, 40, 55),
    INPUT_BG    = Color3.fromRGB(14, 14, 20),
    SEARCH_BG   = Color3.fromRGB(20, 20, 27),
    TAB_ACTIVE  = Color3.fromRGB(28, 28, 38),
    TAB_HOVER   = Color3.fromRGB(22, 22, 32),
    CTRL_BTN    = Color3.fromRGB(30, 30, 42),

    -- Text
    TEXT        = Color3.fromRGB(235, 235, 245),
    TEXT_SUB    = Color3.fromRGB(165, 165, 185),
    TEXT_DIM    = Color3.fromRGB(100, 100, 125),
    TEXT_MUTED  = Color3.fromRGB(58, 58, 78),

    -- Dividers
    DIVIDER     = Color3.fromRGB(30, 30, 42),
    BORDER      = Color3.fromRGB(38, 38, 52),

    -- Controls
    TOGGLE_ON   = Color3.fromRGB(220, 220, 240),
    TOGGLE_OFF  = Color3.fromRGB(42, 42, 58),
    SLIDER_FILL = Color3.fromRGB(195, 195, 220),
    SLIDER_BG   = Color3.fromRGB(36, 36, 50),

    -- Accents
    ACCENT      = Color3.fromRGB(205, 205, 228),
    CLOSE_RED   = Color3.fromRGB(255, 72, 72),
    LOGO_BG     = Color3.fromRGB(215, 215, 235),
}

-- ================================================================
-- [3] LAYOUT CONSTANTS
-- ================================================================
local W          = 830
local H          = 525
local TOPBAR_H   = 52
local SIDEBAR_W  = 258
local CARD_PAD   = 14
local CARD_GAP   = 8

-- ================================================================
-- [4] HELPERS
-- ================================================================
local function tw(obj, props, t, style, dir)
    TweenService:Create(
        obj,
        TweenInfo.new(t or 0.2, style or Enum.EasingStyle.Quart, dir or Enum.EasingDirection.Out),
        props
    ):Play()
end

local function corner(parent, r)
    local c = Instance.new("UICorner")
    c.CornerRadius = UDim.new(0, r or 10)
    c.Parent = parent
    return c
end

local function mkStroke(parent, col, thick, transp)
    local s = Instance.new("UIStroke")
    s.Color           = col or T.BORDER
    s.Thickness       = thick or 1
    s.Transparency    = transp or 0
    s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    s.Parent          = parent
    return s
end

local function mkLabel(parent, text, size, color, font, xalign, yalign)
    local l = Instance.new("TextLabel")
    l.BackgroundTransparency = 1
    l.Text             = text or ""
    l.TextSize         = size or 13
    l.TextColor3       = color or T.TEXT
    l.Font             = font or Enum.Font.GothamMedium
    l.TextXAlignment   = xalign or Enum.TextXAlignment.Left
    l.TextYAlignment   = yalign or Enum.TextYAlignment.Center
    l.Parent           = parent
    return l
end

local function mkFrame(parent, size, pos, col, transp)
    local f = Instance.new("Frame")
    f.Size               = size
    f.Position           = pos or UDim2.new(0,0,0,0)
    f.BackgroundColor3   = col or T.BG
    f.BackgroundTransparency = transp or 0
    f.BorderSizePixel    = 0
    f.Parent             = parent
    return f
end

-- ================================================================
-- [5] INIT — build GUI utama
-- ================================================================
function MoonMango:Init(title, subtitle)
    self._tabs      = {}
    self._allCards  = {}
    self._activeTab = nil
    self._tabCount  = 0

    -- Cleanup existing
    local pGui = (gethui and gethui()) or CoreGui
    if pGui:FindFirstChild("MoonMangoHub") then
        pGui.MoonMangoHub:Destroy()
    end

    -- ScreenGui
    local SG = Instance.new("ScreenGui")
    SG.Name           = "MoonMangoHub"
    SG.ResetOnSpawn   = false
    SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    SG.Parent         = pGui
    self._sg          = SG

    -- ──────────────────────────────────────────────────────────
    -- MAIN FRAME
    -- ──────────────────────────────────────────────────────────
    local MF = mkFrame(SG, UDim2.new(0,W,0,H), UDim2.new(0.5,-W/2,0.5,-H/2), T.BG)
    MF.Name               = "MainFrame"
    MF.ClipsDescendants   = true
    MF.BackgroundTransparency = 1
    corner(MF, 14)
    mkStroke(MF, T.BORDER, 1, 0.4)
    self._mf = MF

    -- Scale + fade-in open animation
    local usc = Instance.new("UIScale", MF)
    usc.Scale = 0.9
    tw(usc, {Scale=1},                 0.38, Enum.EasingStyle.Quart)
    tw(MF,  {BackgroundTransparency=0},0.28)

    -- ──────────────────────────────────────────────────────────
    -- TOPBAR
    -- ──────────────────────────────────────────────────────────
    local TB = mkFrame(MF, UDim2.new(1,0,0,TOPBAR_H), UDim2.new(0,0,0,0), T.TOPBAR)
    TB.Name = "TopBar"
    TB.ZIndex = 5
    -- Bottom divider
    local tbDiv = mkFrame(MF, UDim2.new(1,0,0,1), UDim2.new(0,0,0,TOPBAR_H-1), T.DIVIDER)
    tbDiv.ZIndex = 4

    -- Logo box
    local logoF = mkFrame(TB, UDim2.new(0,34,0,34), UDim2.new(0,12,0.5,-17), T.LOGO_BG)
    logoF.ZIndex = 6
    corner(logoF, 8)
    local logoL = mkLabel(logoF, "M", 17, T.BG, Enum.Font.GothamBlack, Enum.TextXAlignment.Center)
    logoL.Size = UDim2.new(1,0,1,0)
    logoL.ZIndex = 7

    -- Title
    local titleL = mkLabel(TB, title or "MOONMANGO", 14, T.TEXT, Enum.Font.GothamBlack)
    titleL.Size = UDim2.new(0,200,0,18); titleL.Position = UDim2.new(0,54,0,8); titleL.ZIndex=6
    -- Subtitle
    local subL = mkLabel(TB, subtitle or "", 11, T.TEXT_DIM, Enum.Font.Gotham)
    subL.Size = UDim2.new(0,350,0,15); subL.Position = UDim2.new(0,54,0,28); subL.ZIndex=6

    -- ─ Window control buttons ─
    local _mini = false
    local function mkCtrlBtn(icon, xOff, hoverCol, action)
        local b = Instance.new("TextButton")
        b.Size               = UDim2.new(0,28,0,28)
        b.Position           = UDim2.new(1,xOff,0.5,-14)
        b.BackgroundColor3   = T.CTRL_BTN
        b.BackgroundTransparency = 0.55
        b.AutoButtonColor    = false
        b.Text               = icon
        b.TextColor3         = T.TEXT_DIM
        b.Font               = Enum.Font.GothamBold
        b.TextSize           = 12
        b.ZIndex             = 6
        b.Parent             = TB
        corner(b, 7)
        b.MouseEnter:Connect(function() tw(b,{BackgroundTransparency=0.05,TextColor3=hoverCol},0.15) end)
        b.MouseLeave:Connect(function() tw(b,{BackgroundTransparency=0.55,TextColor3=T.TEXT_DIM},0.15) end)
        b.MouseButton1Click:Connect(action)
        return b
    end

    -- Close
    mkCtrlBtn("✕", -10, T.CLOSE_RED, function()
        local s = MF:FindFirstChildOfClass("UIScale")
        tw(MF, {BackgroundTransparency=1}, 0.22)
        if s then tw(s, {Scale=0.9}, 0.22) end
        task.wait(0.25); SG:Destroy()
    end)
    -- Minimize
    local minBtn = mkCtrlBtn("—", -46, T.TEXT, function()
        _mini = not _mini
        tw(MF, {Size=UDim2.new(0,W,0,_mini and TOPBAR_H or H)}, 0.32)
    end)

    -- ─ Drag support ─
    local _dAct, _dStart, _dPos = false, nil, nil
    TB.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            _dAct=true; _dStart=i.Position; _dPos=MF.Position
            i.Changed:Connect(function()
                if i.UserInputState==Enum.UserInputState.End then _dAct=false end
            end)
        end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if _dAct and (i.UserInputType==Enum.UserInputType.MouseMovement
        or i.UserInputType==Enum.UserInputType.Touch) then
            local d=i.Position-_dStart
            MF.Position=UDim2.new(_dPos.X.Scale,_dPos.X.Offset+d.X,_dPos.Y.Scale,_dPos.Y.Offset+d.Y)
        end
    end)

    -- ──────────────────────────────────────────────────────────
    -- SIDEBAR
    -- ──────────────────────────────────────────────────────────
    local SB = mkFrame(MF,
        UDim2.new(0,SIDEBAR_W,1,-TOPBAR_H),
        UDim2.new(0,0,0,TOPBAR_H),
        T.SIDEBAR
    )
    SB.Name = "Sidebar"
    -- Sidebar right divider
    mkFrame(MF,
        UDim2.new(0,1,1,-TOPBAR_H),
        UDim2.new(0,SIDEBAR_W,0,TOPBAR_H),
        T.DIVIDER
    )

    -- Search bar
    local searchF = mkFrame(SB, UDim2.new(1,-20,0,36), UDim2.new(0,10,0,12), T.SEARCH_BG)
    corner(searchF, 10)
    mkStroke(searchF, T.BORDER, 1, 0.45)
    mkLabel(searchF, "⌕", 15, T.TEXT_MUTED, Enum.Font.GothamBold, Enum.TextXAlignment.Center).Size=UDim2.new(0,32,1,0)

    local SearchBox = Instance.new("TextBox")
    SearchBox.Size              = UDim2.new(1,-36,1,-4)
    SearchBox.Position          = UDim2.new(0,32,0,2)
    SearchBox.BackgroundTransparency = 1
    SearchBox.Text              = ""
    SearchBox.PlaceholderText   = "Search..."
    SearchBox.TextColor3        = T.TEXT
    SearchBox.PlaceholderColor3 = T.TEXT_MUTED
    SearchBox.Font              = Enum.Font.Gotham
    SearchBox.TextSize          = 13
    SearchBox.TextXAlignment    = Enum.TextXAlignment.Left
    SearchBox.ClearTextOnFocus  = false
    SearchBox.Parent            = searchF

    -- Tab scroll list
    local TabSF = Instance.new("ScrollingFrame")
    TabSF.Size               = UDim2.new(1,-8,1,-126)
    TabSF.Position           = UDim2.new(0,4,0,56)
    TabSF.BackgroundTransparency = 1
    TabSF.ScrollBarThickness = 0
    TabSF.CanvasSize         = UDim2.new(0,0,0,0)
    TabSF.Parent             = SB
    self._tabSF              = TabSF

    local tabLL = Instance.new("UIListLayout")
    tabLL.SortOrder = Enum.SortOrder.LayoutOrder
    tabLL.Padding   = UDim.new(0,3)
    tabLL.Parent    = TabSF
    tabLL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        TabSF.CanvasSize = UDim2.new(0,0,0,tabLL.AbsoluteContentSize.Y+8)
    end)
    local tabPad = Instance.new("UIPadding",TabSF)
    tabPad.PaddingTop   = UDim.new(0,4)
    tabPad.PaddingLeft  = UDim.new(0,4)
    tabPad.PaddingRight = UDim.new(0,4)

    -- User info card
    local userF = mkFrame(SB, UDim2.new(1,-20,0,58), UDim2.new(0,10,1,-66), T.CARD)
    corner(userF, 10)
    mkStroke(userF, T.BORDER, 1, 0.5)
    -- Avatar
    local avatarF = mkFrame(userF, UDim2.new(0,38,0,38), UDim2.new(0,10,0.5,-19), T.BORDER)
    corner(avatarF, 19)
    task.spawn(function()
        local ok, url = pcall(function()
            return Players:GetUserThumbnailAsync(
                LocalPlayer.UserId,
                Enum.ThumbnailType.HeadShot,
                Enum.ThumbnailSize.Size48x48
            )
        end)
        if ok and url then
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.new(1,0,1,0)
            img.BackgroundTransparency = 1
            img.Image = url
            img.Parent = avatarF
            corner(img, 19)
        end
    end)
    -- Name labels
    local dNameL = mkLabel(userF, LocalPlayer.DisplayName, 13, T.TEXT, Enum.Font.GothamBold)
    dNameL.Size = UDim2.new(1,-56,0,17); dNameL.Position = UDim2.new(0,54,0,9)
    local uNameL = mkLabel(userF, "@"..LocalPlayer.Name, 11, T.TEXT_DIM)
    uNameL.Size = UDim2.new(1,-56,0,15); uNameL.Position = UDim2.new(0,54,0,28)

    -- ──────────────────────────────────────────────────────────
    -- CONTENT PANEL
    -- ──────────────────────────────────────────────────────────
    local CP = Instance.new("Frame")
    CP.Name               = "ContentPanel"
    CP.Size               = UDim2.new(1,-SIDEBAR_W-1,1,-TOPBAR_H)
    CP.Position           = UDim2.new(0,SIDEBAR_W+1,0,TOPBAR_H)
    CP.BackgroundTransparency = 1
    CP.ClipsDescendants   = false
    CP.Parent             = MF
    self._cp              = CP

    -- Content title (updates when tab changes)
    local ctTitle = mkLabel(CP, "", 14, T.TEXT, Enum.Font.GothamBlack)
    ctTitle.Size     = UDim2.new(1,-24,0,36)
    ctTitle.Position = UDim2.new(0,16,0,5)
    self._ctTitle    = ctTitle

    -- Thin divider below title
    mkFrame(CP, UDim2.new(1,-16,0,1), UDim2.new(0,8,0,44), T.DIVIDER)

    -- Card scroll
    local CS = Instance.new("ScrollingFrame")
    CS.Name              = "CardScroll"
    CS.Size              = UDim2.new(1,0,1,-50)
    CS.Position          = UDim2.new(0,0,0,50)
    CS.BackgroundTransparency = 1
    CS.ScrollBarThickness = 3
    CS.ScrollBarImageColor3 = T.BORDER
    CS.CanvasSize        = UDim2.new(0,0,0,0)
    CS.Parent            = CP
    self._cs             = CS

    local csLL = Instance.new("UIListLayout")
    csLL.SortOrder = Enum.SortOrder.LayoutOrder
    csLL.Padding   = UDim.new(0,CARD_GAP)
    csLL.Parent    = CS
    csLL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        CS.CanvasSize = UDim2.new(0,0,0,csLL.AbsoluteContentSize.Y+16)
    end)
    local csPad = Instance.new("UIPadding",CS)
    csPad.PaddingTop    = UDim.new(0,8)
    csPad.PaddingLeft   = UDim.new(0,12)
    csPad.PaddingRight  = UDim.new(0,12)
    csPad.PaddingBottom = UDim.new(0,12)

    -- Search filter
    SearchBox:GetPropertyChangedSignal("Text"):Connect(function()
        local q = SearchBox.Text:lower()
        for _, cd in ipairs(self._allCards) do
            if q == "" then
                cd.frame.Visible = (self._activeTab == cd.tab)
            else
                local match = cd.name:lower():find(q,1,true)
                    or (cd.desc or ""):lower():find(q,1,true)
                cd.frame.Visible = (match ~= nil)
            end
        end
    end)

    return self
end

-- ================================================================
-- [6] ADD TAB
-- ================================================================
function MoonMango:AddTab(name, icon)
    self._tabCount = (self._tabCount or 0) + 1

    local tab = {
        name   = name,
        icon   = icon or "·",
        cards  = {},
        _order = self._tabCount,
    }

    -- Tab button
    local btn = Instance.new("TextButton")
    btn.Size               = UDim2.new(1,0,0,42)
    btn.BackgroundColor3   = T.SIDEBAR
    btn.BackgroundTransparency = 1
    btn.Text               = ""
    btn.AutoButtonColor    = false
    btn.LayoutOrder        = self._tabCount
    btn.Parent             = self._tabSF
    corner(btn, 9)

    -- Active left bar
    local bar = mkFrame(btn, UDim2.new(0,3,0,22), UDim2.new(0,0,0.5,-11), T.ACCENT)
    bar.BackgroundTransparency = 1
    corner(bar, 2)

    -- Icon label
    local iconL = mkLabel(btn, icon or "·", 15, T.TEXT_DIM, Enum.Font.GothamBold, Enum.TextXAlignment.Center)
    iconL.Size = UDim2.new(0,38,1,0); iconL.Position = UDim2.new(0,8,0,0)

    -- Name label
    local nameL = mkLabel(btn, name, 13, T.TEXT_DIM, Enum.Font.GothamMedium)
    nameL.Size = UDim2.new(1,-52,1,0); nameL.Position = UDim2.new(0,48,0,0)

    -- Hover
    btn.MouseEnter:Connect(function()
        if self._activeTab ~= tab then
            tw(btn,  {BackgroundTransparency=0.8,BackgroundColor3=T.TAB_HOVER}, 0.15)
            tw(iconL,{TextColor3=T.TEXT_SUB}, 0.15)
            tw(nameL,{TextColor3=T.TEXT_SUB}, 0.15)
        end
    end)
    btn.MouseLeave:Connect(function()
        if self._activeTab ~= tab then
            tw(btn,  {BackgroundTransparency=1},    0.15)
            tw(iconL,{TextColor3=T.TEXT_DIM},       0.15)
            tw(nameL,{TextColor3=T.TEXT_DIM},       0.15)
        end
    end)
    btn.MouseButton1Click:Connect(function() self:_switchTab(tab) end)

    tab.btn   = btn
    tab.bar   = bar
    tab.iconL = iconL
    tab.nameL = nameL

    table.insert(self._tabs, tab)
    if #self._tabs == 1 then self:_switchTab(tab) end

    return tab
end

-- ================================================================
-- [7] SWITCH TAB (internal)
-- ================================================================
function MoonMango:_switchTab(newTab)
    if self._activeTab then
        local old = self._activeTab
        tw(old.btn,  {BackgroundTransparency=1},         0.2)
        tw(old.bar,  {BackgroundTransparency=1},         0.2)
        tw(old.iconL,{TextColor3=T.TEXT_DIM},            0.2)
        tw(old.nameL,{TextColor3=T.TEXT_DIM},            0.2)
        for _, cd in ipairs(old.cards) do cd.frame.Visible=false end
    end

    self._activeTab = newTab
    tw(newTab.btn,  {BackgroundTransparency=0.78, BackgroundColor3=T.TAB_ACTIVE}, 0.2)
    tw(newTab.bar,  {BackgroundTransparency=0},   0.25, Enum.EasingStyle.Back)
    tw(newTab.iconL,{TextColor3=T.TEXT},          0.2)
    tw(newTab.nameL,{TextColor3=T.TEXT},          0.2)
    for _, cd in ipairs(newTab.cards) do cd.frame.Visible=true end
    self._ctTitle.Text = newTab.name
    self._cs.CanvasPosition = Vector2.new(0,0)
end

-- ================================================================
-- [8] BASE CARD BUILDER (internal)
-- ================================================================
function MoonMango:_baseCard(tab, name, desc, h)
    local f = Instance.new("Frame")
    f.Name             = "Card"
    f.Size             = UDim2.new(1,0,0,h or 72)
    f.BackgroundColor3 = T.CARD
    f.BorderSizePixel  = 0
    f.Visible          = (self._activeTab == tab)
    f.LayoutOrder      = #tab.cards + 1
    f.Parent           = self._cs
    corner(f, 10)
    mkStroke(f, T.CARD_STROKE, 1, 0.5)

    -- Card title
    local titleL = mkLabel(f, name, 14, T.TEXT, Enum.Font.GothamBold)
    titleL.Size     = UDim2.new(0.58, 0, 0, 20)
    titleL.Position = UDim2.new(0, CARD_PAD, 0, 14)

    -- Card description
    local descL = mkLabel(f, desc or "", 12, T.TEXT_DIM, Enum.Font.Gotham)
    descL.Size           = UDim2.new(0.65, 0, 0, 30)
    descL.Position       = UDim2.new(0, CARD_PAD, 0, 35)
    descL.TextWrapped    = true
    descL.TextYAlignment = Enum.TextYAlignment.Top

    -- Hover effect
    f.MouseEnter:Connect(function() tw(f,{BackgroundColor3=T.CARD_HOVER},0.15) end)
    f.MouseLeave:Connect(function() tw(f,{BackgroundColor3=T.CARD},0.15) end)

    local cd = {frame=f, name=name, desc=desc, tab=tab}
    table.insert(tab.cards,  cd)
    table.insert(self._allCards, cd)

    return f, titleL, descL
end

-- ================================================================
-- [9] SECTION HEADER
-- ================================================================
function MoonMango:AddSection(tab, title)
    local f = Instance.new("Frame")
    f.Size               = UDim2.new(1,0,0,28)
    f.BackgroundTransparency = 1
    f.Visible            = (self._activeTab == tab)
    f.LayoutOrder        = #tab.cards + 1
    f.Parent             = self._cs

    -- Horizontal rule
    mkFrame(f, UDim2.new(1,-12,0,1), UDim2.new(0,6,0.5,0), T.DIVIDER)

    -- Label (with bg to "erase" line behind text)
    local sL = mkLabel(f, "  "..title:upper().."  ", 10, T.TEXT_MUTED, Enum.Font.GothamBold)
    sL.Size             = UDim2.new(0,0,1,0)
    sL.AutomaticSize    = Enum.AutomaticSize.X
    sL.Position         = UDim2.new(0,6,0,0)
    sL.BackgroundColor3 = T.BG
    sL.BackgroundTransparency = 0

    table.insert(tab.cards, {frame=f, name=title, desc="", tab=tab})
    return f
end

-- ================================================================
-- [10] TOGGLE
-- ================================================================
function MoonMango:AddToggle(tab, name, desc, default, callback)
    local f = self:_baseCard(tab, name, desc, 72)

    local TW, TH = 46, 26
    local track = mkFrame(f, UDim2.new(0,TW,0,TH), UDim2.new(1,-(TW+14),0.5,-TH/2),
        default and T.TOGGLE_ON or T.TOGGLE_OFF)
    corner(track, TH/2)

    local KS = TH - 6
    local knob = mkFrame(track, UDim2.new(0,KS,0,KS), UDim2.new(0,0,0,0), Color3.fromRGB(255,255,255))
    knob.ZIndex = 2
    corner(knob, KS/2)
    mkStroke(knob, Color3.fromRGB(0,0,0), 1, 0.75)
    knob.Position = default
        and UDim2.new(1,-(KS+3),0.5,-KS/2)
        or  UDim2.new(0,3,      0.5,-KS/2)

    local state = default

    local function applyToggle(val, animate)
        state = val
        local t = animate and 0.22 or 0
        tw(track, {BackgroundColor3 = val and T.TOGGLE_ON or T.TOGGLE_OFF}, t)
        tw(knob,  {Position = val
            and UDim2.new(1,-(KS+3),0.5,-KS/2)
            or  UDim2.new(0,3,      0.5,-KS/2)
        }, t, Enum.EasingStyle.Quart)
        if callback then task.spawn(function() pcall(callback, val) end) end
    end

    -- Whole card is clickable for toggle
    local clickArea = Instance.new("TextButton")
    clickArea.Size               = UDim2.new(1,0,1,0)
    clickArea.BackgroundTransparency = 1
    clickArea.Text               = ""
    clickArea.Parent             = f
    clickArea.MouseButton1Click:Connect(function() applyToggle(not state, true) end)

    return {
        Set = function(v) applyToggle(v, true) end,
        Get = function() return state end,
    }
end

-- ================================================================
-- [11] SLIDER
-- ================================================================
function MoonMango:AddSlider(tab, name, desc, min, max, default, callback)
    local f = self:_baseCard(tab, name, desc, 80)

    -- Value display (top-right area)
    local valL = mkLabel(f, tostring(default), 13, T.TEXT, Enum.Font.GothamBold, Enum.TextXAlignment.Right)
    valL.Size = UDim2.new(0,55,0,20); valL.Position = UDim2.new(1,-69,0,14)

    -- Track bg
    local trackF = mkFrame(f,
        UDim2.new(1,-(CARD_PAD*2),0,6),
        UDim2.new(0,CARD_PAD,1,-20),
        T.SLIDER_BG
    )
    corner(trackF, 3)

    -- Fill
    local iPct = math.clamp((default-min)/math.max(max-min,1),0,1)
    local fillF = mkFrame(trackF, UDim2.new(iPct,0,1,0), UDim2.new(0,0,0,0), T.SLIDER_FILL)
    corner(fillF, 3)

    -- Knob
    local KD = 16
    local knobF = mkFrame(trackF, UDim2.new(0,KD,0,KD), UDim2.new(iPct,-KD/2,0.5,-KD/2), Color3.fromRGB(255,255,255))
    knobF.ZIndex = 2
    corner(knobF, KD/2)
    mkStroke(knobF, T.DIVIDER, 1, 0.4)

    local value   = default
    local sliding = false

    local function updateSlider(inputX)
        local rel = math.clamp(inputX - trackF.AbsolutePosition.X, 0, trackF.AbsoluteSize.X)
        local pct = rel / math.max(trackF.AbsoluteSize.X, 1)
        value          = math.floor(min + (max-min)*pct + 0.5)
        fillF.Size     = UDim2.new(pct,0,1,0)
        knobF.Position = UDim2.new(pct,-KD/2,0.5,-KD/2)
        valL.Text      = tostring(value)
        if callback then task.spawn(function() pcall(callback, value) end) end
    end

    trackF.InputBegan:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then
            sliding=true; updateSlider(i.Position.X)
        end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType==Enum.UserInputType.MouseButton1
        or i.UserInputType==Enum.UserInputType.Touch then sliding=false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if sliding and (i.UserInputType==Enum.UserInputType.MouseMovement
        or i.UserInputType==Enum.UserInputType.Touch) then
            updateSlider(i.Position.X)
        end
    end)

    return {
        Set = function(v)
            value = math.clamp(v,min,max)
            local pct = (value-min)/math.max(max-min,1)
            fillF.Size     = UDim2.new(pct,0,1,0)
            knobF.Position = UDim2.new(pct,-KD/2,0.5,-KD/2)
            valL.Text      = tostring(value)
        end,
        Get = function() return value end,
    }
end

-- ================================================================
-- [12] DROPDOWN
-- ================================================================
function MoonMango:AddDropdown(tab, name, desc, options, default, callback)
    local selected = default or options[1]
    local baseH    = 72
    local itemH    = 36
    local isOpen   = false

    local f = self:_baseCard(tab, name, desc, baseH)

    -- Selector button
    local selW = 148
    local selBtn = Instance.new("TextButton")
    selBtn.Size               = UDim2.new(0,selW,0,30)
    selBtn.Position           = UDim2.new(1,-(selW+12),0.5,-15)
    selBtn.BackgroundColor3   = T.INPUT_BG
    selBtn.AutoButtonColor    = false
    selBtn.Text               = ""
    selBtn.Parent             = f
    corner(selBtn, 8)
    mkStroke(selBtn, T.BORDER, 1, 0.38)

    local selL = mkLabel(selBtn, selected, 12, T.TEXT, Enum.Font.GothamMedium)
    selL.Size         = UDim2.new(1,-26,1,0)
    selL.Position     = UDim2.new(0,10,0,0)
    selL.TextTruncate = Enum.TextTruncate.AtEnd

    local chevL = mkLabel(selBtn,"▾",11,T.TEXT_DIM,Enum.Font.GothamBold,Enum.TextXAlignment.Center)
    chevL.Size=UDim2.new(0,20,1,0); chevL.Position=UDim2.new(1,-22,0,0)

    -- Dropdown list (appears below selector, inside card which expands)
    local dropF = mkFrame(f, UDim2.new(0,selW,0,0), UDim2.new(1,-(selW+12),1,4), T.CARD_HOVER)
    dropF.Visible          = false
    dropF.ZIndex           = 10
    dropF.ClipsDescendants = true
    corner(dropF, 8)
    mkStroke(dropF, T.BORDER, 1, 0.3)

    local dropLL = Instance.new("UIListLayout")
    dropLL.SortOrder = Enum.SortOrder.LayoutOrder
    dropLL.Parent    = dropF

    for idx, opt in ipairs(options) do
        local ob = Instance.new("TextButton")
        ob.Size               = UDim2.new(1,0,0,itemH)
        ob.BackgroundColor3   = T.CARD_HOVER
        ob.BackgroundTransparency = 1
        ob.Text               = ""
        ob.AutoButtonColor    = false
        ob.ZIndex             = 11
        ob.LayoutOrder        = idx
        ob.Parent             = dropF

        local oL = mkLabel(ob, opt, 12, opt==selected and T.TEXT or T.TEXT_DIM, Enum.Font.GothamMedium)
        oL.Size=UDim2.new(1,-12,1,0); oL.Position=UDim2.new(0,10,0,0); oL.ZIndex=12

        -- Separator between items
        if idx < #options then
            local sep = mkFrame(ob, UDim2.new(1,-16,0,1), UDim2.new(0,8,1,-1), T.DIVIDER, 0)
            sep.ZIndex=11
        end

        ob.MouseEnter:Connect(function()
            tw(ob,{BackgroundTransparency=0.78,BackgroundColor3=T.TAB_ACTIVE},0.1)
            tw(oL,{TextColor3=T.TEXT},0.1)
        end)
        ob.MouseLeave:Connect(function()
            tw(ob,{BackgroundTransparency=1},0.1)
            tw(oL,{TextColor3=opt==selected and T.TEXT or T.TEXT_DIM},0.1)
        end)
        ob.MouseButton1Click:Connect(function()
            selected = opt; selL.Text = opt
            isOpen = false
            tw(dropF,{Size=UDim2.new(0,selW,0,0)},  0.18, Enum.EasingStyle.Quart)
            tw(f,     {Size=UDim2.new(1,0,0,baseH)},0.2,  Enum.EasingStyle.Quart)
            tw(chevL, {Rotation=0}, 0.18)
            task.wait(0.2); dropF.Visible=false
            if callback then task.spawn(function() pcall(callback, opt) end) end
        end)
    end

    local totalH = #options * itemH

    selBtn.MouseButton1Click:Connect(function()
        isOpen = not isOpen
        if isOpen then
            dropF.Visible=true; dropF.Size=UDim2.new(0,selW,0,0)
            tw(dropF,{Size=UDim2.new(0,selW,0,totalH)},         0.22,Enum.EasingStyle.Quart)
            tw(f,    {Size=UDim2.new(1,0,0,baseH+totalH+8)},    0.22,Enum.EasingStyle.Quart)
            tw(chevL,{Rotation=180},0.18)
        else
            tw(dropF,{Size=UDim2.new(0,selW,0,0)},  0.18,Enum.EasingStyle.Quart)
            tw(f,    {Size=UDim2.new(1,0,0,baseH)},0.2, Enum.EasingStyle.Quart)
            tw(chevL,{Rotation=0},0.18)
            task.wait(0.2); dropF.Visible=false
        end
    end)

    return {
        Set = function(v) selected=v; selL.Text=v end,
        Get = function() return selected end,
    }
end

-- ================================================================
-- [13] TEXT INPUT
-- ================================================================
function MoonMango:AddInput(tab, name, desc, placeholder, callback)
    local f = self:_baseCard(tab, name, desc, 84)

    local inputF = mkFrame(f,
        UDim2.new(1,-(CARD_PAD*2),0,30),
        UDim2.new(0,CARD_PAD,1,-40),
        T.INPUT_BG
    )
    corner(inputF, 8)
    local iStroke = mkStroke(inputF, T.BORDER, 1, 0.42)

    local inputBox = Instance.new("TextBox")
    inputBox.Size              = UDim2.new(1,-16,1,-4)
    inputBox.Position          = UDim2.new(0,8,0,2)
    inputBox.BackgroundTransparency = 1
    inputBox.Text              = ""
    inputBox.PlaceholderText   = placeholder or "Ketik di sini..."
    inputBox.TextColor3        = T.TEXT
    inputBox.PlaceholderColor3 = T.TEXT_MUTED
    inputBox.Font              = Enum.Font.Gotham
    inputBox.TextSize          = 12
    inputBox.TextXAlignment    = Enum.TextXAlignment.Left
    inputBox.ClearTextOnFocus  = false
    inputBox.Parent            = inputF

    inputBox.Focused:Connect(function()
        tw(iStroke, {Transparency=0.1, Color=T.ACCENT}, 0.15)
        tw(inputF,  {BackgroundColor3=Color3.fromRGB(18,18,26)}, 0.15)
    end)
    inputBox.FocusLost:Connect(function(enter)
        tw(iStroke, {Transparency=0.42, Color=T.BORDER}, 0.15)
        tw(inputF,  {BackgroundColor3=T.INPUT_BG}, 0.15)
        if callback then task.spawn(function() pcall(callback, inputBox.Text, enter) end) end
    end)

    return {
        Set   = function(v) inputBox.Text = v end,
        Get   = function() return inputBox.Text end,
        Clear = function() inputBox.Text = "" end,
    }
end

-- ================================================================
-- [14] BUTTON
-- ================================================================
function MoonMango:AddButton(tab, name, desc, btnLabel, callback)
    local f = self:_baseCard(tab, name, desc, 72)

    local bW = 96
    local b = Instance.new("TextButton")
    b.Size               = UDim2.new(0,bW,0,30)
    b.Position           = UDim2.new(1,-(bW+14),0.5,-15)
    b.BackgroundColor3   = Color3.fromRGB(46,46,64)
    b.AutoButtonColor    = false
    b.Text               = btnLabel or "Klik"
    b.TextColor3         = T.TEXT
    b.Font               = Enum.Font.GothamBold
    b.TextSize           = 12
    b.Parent             = f
    corner(b, 8)
    mkStroke(b, T.BORDER, 1, 0.35)

    b.MouseEnter:Connect(function() tw(b,{BackgroundColor3=Color3.fromRGB(60,60,85)},0.15) end)
    b.MouseLeave:Connect(function() tw(b,{BackgroundColor3=Color3.fromRGB(46,46,64)},0.15) end)
    b.MouseButton1Click:Connect(function()
        tw(b,{BackgroundColor3=Color3.fromRGB(80,80,110)},0.07)
        task.wait(0.1)
        tw(b,{BackgroundColor3=Color3.fromRGB(46,46,64)},0.15)
        if callback then task.spawn(function() pcall(callback) end) end
    end)

    return b
end

-- ================================================================
-- [15] RETURN INSTANCE
-- ================================================================
return setmetatable({
    _tabs     = {},
    _allCards = {},
    _tabCount = 0,
}, MoonMango)

--[[
================================================================
CONTOH PENGGUNAAN — AutoType V33 + MoonMango Hub
================================================================
Paste kode ini ke LOADER.lua setelah loadstring Hub selesai:

local Hub = loadstring(game:HttpGet("URL_MOONMANGO"))()
Hub:Init("MOONMANGO", "Auto Type V33")

local App = getgenv().App  -- dari LOGIC.lua

-- ─── TAB MAIN ─────────────────────────────────────────────
local main = Hub:AddTab("Main", "⚡")

Hub:AddSection(main, "Gameplay")
Hub:AddToggle(main, "Auto Play",
    "Bot ketik otomatis saat giliranmu",
    App.Config.AutoPlay,
    function(v) App.Config.AutoPlay = v end)

Hub:AddToggle(main, "AI Humanizer",
    "Simulasi ketik manusia + typo acak",
    App.Config.Humanize,
    function(v) App.Config.Humanize = v end)

Hub:AddToggle(main, "Auto Join",
    "Gabung meja terbaik secara otomatis",
    App.Config.AutoJoin,
    function(v) App.Config.AutoJoin = v end)

Hub:AddSection(main, "Performance")
Hub:AddSlider(main, "Kecepatan Ketik",
    "Delay antar karakter dalam milidetik",
    1, 900, App.Config.TypingDelayMS,
    function(v) App.Config.TypingDelayMS = v end)

Hub:AddDropdown(main, "Playstyle",
    "Mode strategi bot saat bermain",
    App.Config.Styles,
    App.Config.Playstyle,
    function(v) App.Config.Playstyle = v end)

-- ─── TAB SUFFIX ───────────────────────────────────────────
local sfxTab = Hub:AddTab("Suffix", "🎯")

Hub:AddSection(sfxTab, "Target Akhiran")
Hub:AddInput(sfxTab, "Akhiran Kata",
    "Pisah dengan koma. Contoh: tt, ly, rt",
    "tt, rt, ly, cy...",
    function(text)
        -- panggil fungsi parseSfx dari UI.lua kamu
        if getgenv()._parseSfx then getgenv()._parseSfx(text) end
    end)

Hub:AddButton(sfxTab, "Reset Suffix",
    "Hapus semua target akhiran aktif",
    "Reset",
    function()
        if getgenv()._parseSfx then getgenv()._parseSfx("") end
    end)

-- ─── TAB KATA ─────────────────────────────────────────────
local kataTab = Hub:AddTab("Kata", "✏")

Hub:AddSection(kataTab, "Tambah Kata Manual")
local wordInput = Hub:AddInput(kataTab, "Tambah ke Bankword",
    "Masukkan kata yang tidak ada di KBBI",
    "Ketik kata...",
    function(text, enter)
        if enter then
            -- panggil fungsi addWord dari LOGIC.lua kamu
            if getgenv()._addWord then
                getgenv()._addWord(text, true)
                getgenv()._flushWords()
                wordInput.Clear()
            end
        end
    end)

-- ─── TAB DATABASE ─────────────────────────────────────────
local dbTab = Hub:AddTab("Database", "🗄")

Hub:AddSection(dbTab, "Info")
Hub:AddButton(dbTab, "Sync Kata Baru",
    "Ambil kata terbaru dari cloud",
    "Sync",
    function()
        if getgenv()._updateStatus then
            getgenv()._updateStatus("🔄 Syncing...", Color3.fromRGB(150,200,255))
        end
    end)

================================================================
]]
