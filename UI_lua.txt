-- ========================================================================
-- AUTO TYPE V33 — UI (GLASS DARK PREMIUM EDITION)
-- ========================================================================
-- Berisi: semua tampilan (Panel Config, Suffix, Kata, Word List).
-- TIDAK ADA logika game di sini (tidak ada FireServer, scoring, dll).
--
-- Fungsi yang diexport ke getgenv() untuk dipakai LOGIC.lua:
--   getgenv()._updateStatus(msg, col)   → update status bar
--   getgenv()._renderProfiles()         → render ulang daftar profil
--   getgenv()._refreshChips()           → refresh chip suffix + trap meter
--   getgenv()._genTurn(prefix)          → generate rekomendasi kata
--   getgenv()._hideAllBtns()            → sembunyikan semua tombol kata
--   getgenv()._setCWTotal(text)         → update label counter kata di Panel 3
-- ========================================================================

-- ========================================================================
-- [1] SERVICES & SHORTCUTS
-- ========================================================================
local TweenService     = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CoreGui          = game:GetService("CoreGui")
local SoundService     = game:GetService("SoundService")

local lower, sub, random = string.lower, string.sub, math.random

local App = getgenv().App

local function addWord(w,s)    return getgenv()._addWord(w,s) end
local function flushWords()    return getgenv()._flushWords() end
local function typeWord(w,btn) return getgenv()._typeWord(w,btn) end
local function optionCount(p)  return getgenv()._optionCount(p) end
local function scoreWord(w,m)  return getgenv()._scoreWord(w,m) end
local function stage()         return getgenv()._stage() end

-- ========================================================================
-- [2] SOUND HELPER
-- ========================================================================
local function playClick()
    local snd = Instance.new("Sound")
    snd.SoundId  = "rbxassetid://113399975987915"
    snd.Volume   = 0.6
    snd.RollOffMaxDistance = 0
    snd.Parent   = SoundService
    snd:Play()
    game:GetService("Debris"):AddItem(snd, 3)
end

-- ========================================================================
-- [3] CLEANUP & SCREENGUI
-- ========================================================================
local uiName = "AutoType_V33"
local pGui   = (gethui and gethui()) or CoreGui
for _,n in ipairs({
    uiName,"AutoType_V32","AutoType_V31","AutoType_V30",
    "AutoType_V29","AutoType_V28_Final","AutoType_V28_Tab",
    "AutoType_V28_Ultimate","AutoType_V27_Ultimate"
}) do
    if pGui:FindFirstChild(n) then pGui[n]:Destroy() end
end

local SG = Instance.new("ScreenGui")
SG.Name          = uiName
SG.ResetOnSpawn  = false
SG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
SG.Parent        = pGui

-- ========================================================================
-- [4] THEME
-- ========================================================================
local T = {
    BG        = Color3.fromRGB(6,  8,  18),
    Glass     = Color3.fromRGB(14, 18, 36),
    GlassLite = Color3.fromRGB(22, 28, 56),
    Border    = Color3.fromRGB(65, 90, 200),
    BorderDim = Color3.fromRGB(35, 45, 100),
    AccentA   = Color3.fromRGB(90, 145, 255),
    AccentB   = Color3.fromRGB(130, 85, 255),
    Success   = Color3.fromRGB(50, 210, 125),
    Warn      = Color3.fromRGB(255, 185, 55),
    Danger    = Color3.fromRGB(255, 72, 72),
    Orange    = Color3.fromRGB(255, 135, 55),
    TextPri   = Color3.fromRGB(215, 228, 255),
    TextSec   = Color3.fromRGB(128, 145, 195),
    TextDim   = Color3.fromRGB(68,  80,  128),
}

-- ========================================================================
-- [5] MAIN FRAME
-- ========================================================================
local W      = 198
local H      = 290
local TOP_H  = 36
local LP_W   = 172

local MF = Instance.new("Frame")
MF.Name                 = "MainFrame"
MF.AnchorPoint          = Vector2.new(0.5, 0.5)
MF.Size                 = UDim2.new(0, W, 0, H)
MF.Position             = UDim2.new(0.5, 0, 0.5, 0)
MF.BackgroundColor3     = T.BG
MF.BackgroundTransparency = 0.20
MF.ClipsDescendants     = true
MF.Parent               = SG
Instance.new("UICorner", MF).CornerRadius = UDim.new(0, 18)

local mStk = Instance.new("UIStroke", MF)
mStk.Color       = T.Border
mStk.Transparency = 0.55
mStk.Thickness   = 1

-- Subtle inner glow overlay
local glassSheen = Instance.new("Frame")
glassSheen.Size                 = UDim2.new(1, 0, 0.45, 0)
glassSheen.BackgroundColor3     = Color3.fromRGB(255, 255, 255)
glassSheen.BackgroundTransparency = 0.97
glassSheen.BorderSizePixel      = 0
glassSheen.ZIndex               = 0
glassSheen.Parent               = MF
Instance.new("UICorner", glassSheen).CornerRadius = UDim.new(0, 18)

-- Entrance spring animation
local USc = Instance.new("UIScale", MF)
USc.Scale = 0.72
TweenService:Create(USc, TweenInfo.new(0.52, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {Scale = 1}):Play()

-- ========================================================================
-- [6] TOPBAR
-- ========================================================================
local TB = Instance.new("Frame")
TB.Size                 = UDim2.new(1, 0, 0, TOP_H)
TB.BackgroundColor3     = T.GlassLite
TB.BackgroundTransparency = 0.22
TB.Active               = true
TB.ZIndex               = 3
TB.Parent               = MF
Instance.new("UICorner", TB).CornerRadius = UDim.new(0, 18)

local tbGrad = Instance.new("UIGradient", TB)
tbGrad.Color    = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(28, 42, 110)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(10, 13, 38)),
})
tbGrad.Rotation = 120

-- Topbar bottom separator
local tbLine = Instance.new("Frame")
tbLine.Size             = UDim2.new(1, -20, 0, 1)
tbLine.Position         = UDim2.new(0, 10, 1, -1)
tbLine.BackgroundColor3 = T.Border
tbLine.BackgroundTransparency = 0.60
tbLine.BorderSizePixel  = 0
tbLine.Parent           = TB

-- Title & subtitle
local TitleL = Instance.new("TextLabel")
TitleL.Size                 = UDim2.new(0, 100, 0, 18)
TitleL.Position             = UDim2.new(0, 14, 0, 6)
TitleL.BackgroundTransparency = 1
TitleL.Text                 = "AUTO TYPE"
TitleL.TextColor3           = T.TextPri
TitleL.Font                 = Enum.Font.GothamBlack
TitleL.TextSize             = 12
TitleL.TextXAlignment       = Enum.TextXAlignment.Left
TitleL.Parent               = TB

local VerBadge = Instance.new("TextLabel")
VerBadge.Size               = UDim2.new(0, 28, 0, 14)
VerBadge.Position           = UDim2.new(0, 14, 0, TOP_H - 18)
VerBadge.BackgroundColor3   = T.AccentA
VerBadge.BackgroundTransparency = 0.55
VerBadge.Text               = "V33"
VerBadge.TextColor3         = Color3.fromRGB(200, 225, 255)
VerBadge.Font               = Enum.Font.GothamBold
VerBadge.TextSize           = 7
VerBadge.Parent             = TB
Instance.new("UICorner", VerBadge).CornerRadius = UDim.new(0, 4)

-- ── DRAG ──────────────────────────────────────────────────────────────────
local drag, dInp, dStart, dPos
TB.InputBegan:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseButton1 or
       i.UserInputType == Enum.UserInputType.Touch then
        drag = true; dStart = i.Position; dPos = MF.Position
        i.Changed:Connect(function()
            if i.UserInputState == Enum.UserInputState.End then drag = false end
        end)
    end
end)
TB.InputChanged:Connect(function(i)
    if i.UserInputType == Enum.UserInputType.MouseMovement or
       i.UserInputType == Enum.UserInputType.Touch then dInp = i end
end)
UserInputService.InputChanged:Connect(function(i)
    if i == dInp and drag then
        local d = i.Position - dStart
        MF.Position = UDim2.new(dPos.X.Scale, dPos.X.Offset + d.X,
                                dPos.Y.Scale, dPos.Y.Offset + d.Y)
    end
end)

-- ── TOP BUTTONS ───────────────────────────────────────────────────────────
local function mkTopBtn(icon, offX, col, hovCol)
    local b = Instance.new("TextButton")
    b.Size                  = UDim2.new(0, 26, 0, 26)
    b.Position              = UDim2.new(1, offX, 0.5, -13)
    b.AnchorPoint           = Vector2.new(1, 0)
    b.BackgroundColor3      = Color3.fromRGB(255, 255, 255)
    b.BackgroundTransparency = 0.92
    b.Text                  = icon
    b.TextColor3            = col
    b.Font                  = Enum.Font.GothamBold
    b.TextSize              = 11
    b.AutoButtonColor       = false
    b.ZIndex                = 4
    b.Parent                = TB
    Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)

    b.MouseEnter:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 0.68, TextColor3 = hovCol
        }):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            BackgroundTransparency = 0.92, TextColor3 = col
        }):Play()
    end)
    b.MouseButton1Down:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.07), {BackgroundTransparency = 0.45}):Play()
    end)
    b.MouseButton1Up:Connect(function()
        TweenService:Create(b, TweenInfo.new(0.15), {BackgroundTransparency = 0.92}):Play()
    end)
    return b
end

local CloseB = mkTopBtn("✕",  -6,  Color3.fromRGB(255, 90, 90),  Color3.fromRGB(255, 40, 40))
local MinB   = mkTopBtn("—",  -36, T.TextSec,                    T.TextPri)
local BookB  = mkTopBtn("≡",  -66, T.AccentA,                    Color3.fromRGB(190, 225, 255))

-- ========================================================================
-- [7] STATUS BAR
-- ========================================================================
local statBar = Instance.new("Frame")
statBar.Size                = UDim2.new(1, -16, 0, 24)
statBar.Position            = UDim2.new(0, 8, 0, TOP_H + 5)
statBar.BackgroundColor3    = T.Glass
statBar.BackgroundTransparency = 0.38
statBar.Parent              = MF
Instance.new("UICorner", statBar).CornerRadius = UDim.new(0, 9)
local statStk = Instance.new("UIStroke", statBar)
statStk.Color       = T.Border
statStk.Transparency = 0.70
statStk.Thickness   = 0.8

local statDot = Instance.new("Frame")
statDot.Size            = UDim2.new(0, 7, 0, 7)
statDot.Position        = UDim2.new(0, 9, 0.5, -3)
statDot.BackgroundColor3 = T.Success
statDot.Parent          = statBar
Instance.new("UICorner", statDot).CornerRadius = UDim.new(1, 0)

local SL = Instance.new("TextLabel")
SL.Size                 = UDim2.new(1, -24, 1, 0)
SL.Position             = UDim2.new(0, 21, 0, 0)
SL.BackgroundTransparency = 1
SL.Text                 = "⏳ Loading..."
SL.TextColor3           = T.TextSec
SL.Font                 = Enum.Font.GothamSemibold
SL.TextSize             = 9
SL.TextXAlignment       = Enum.TextXAlignment.Left
SL.Parent               = statBar

local function updateStatus(msg, col)
    if msg then
        SL.Text           = msg
        SL.TextColor3     = col or T.TextPri
        statDot.BackgroundColor3 = col or T.Success
        return
    end
    if App.State.IsMyTurn then
        SL.Text           = "▸  Awalan: " .. App.State.ServerLetter:upper()
        SL.TextColor3     = T.Success
        statDot.BackgroundColor3 = T.Success
    else
        SL.Text           = "Menunggu giliran..."
        SL.TextColor3     = T.TextSec
        statDot.BackgroundColor3 = T.TextDim
    end
end
getgenv()._updateStatus = updateStatus

-- ========================================================================
-- [8] TAB SYSTEM
-- ========================================================================
local CTRL_Y  = TOP_H + 35
local CTRL_H  = H - CTRL_Y - 8

local RP = Instance.new("Frame")
RP.Size                 = UDim2.new(1, -12, 0, CTRL_H)
RP.Position             = UDim2.new(0, 6, 0, CTRL_Y)
RP.BackgroundTransparency = 1
RP.Parent               = MF

-- Tabbar pill
local TabBar = Instance.new("Frame")
TabBar.Size                 = UDim2.new(1, 0, 0, 30)
TabBar.BackgroundColor3     = T.Glass
TabBar.BackgroundTransparency = 0.30
TabBar.Parent               = RP
Instance.new("UICorner", TabBar).CornerRadius = UDim.new(0, 11)
local tbStk2 = Instance.new("UIStroke", TabBar)
tbStk2.Color       = T.Border
tbStk2.Transparency = 0.68
tbStk2.Thickness   = 0.8

local tabInnerPad = Instance.new("UIPadding", TabBar)
tabInnerPad.PaddingLeft   = UDim.new(0, 3)
tabInnerPad.PaddingRight  = UDim.new(0, 3)
tabInnerPad.PaddingTop    = UDim.new(0, 3)
tabInnerPad.PaddingBottom = UDim.new(0, 3)

local tabLL = Instance.new("UIListLayout", TabBar)
tabLL.FillDirection       = Enum.FillDirection.Horizontal
tabLL.SortOrder           = Enum.SortOrder.LayoutOrder
tabLL.Padding             = UDim.new(0, 3)
tabLL.VerticalAlignment   = Enum.VerticalAlignment.Center
tabLL.HorizontalAlignment = Enum.HorizontalAlignment.Center

local TABS       = {"⚙", "🎯", "✏"}
local TAB_LABELS = {"Config", "Suffix", "Kata"}
local TAB_COLORS = {
    Color3.fromRGB(70, 135, 255),
    Color3.fromRGB(255, 135, 55),
    Color3.fromRGB(55, 205, 130),
}
local tabBtns   = {}
local tabPanels = {}
local activeTab = 1

for i, icon in ipairs(TABS) do
    local btn = Instance.new("TextButton")
    btn.Size                 = UDim2.new(1/3, -3, 1, 0)
    btn.BackgroundColor3     = i == 1 and TAB_COLORS[i] or T.Glass
    btn.BackgroundTransparency = i == 1 and 0.28 or 0.88
    btn.Text                 = icon .. "  " .. TAB_LABELS[i]
    btn.TextColor3           = i == 1 and Color3.fromRGB(255, 255, 255) or T.TextDim
    btn.Font                 = Enum.Font.GothamBold
    btn.TextSize             = 8
    btn.AutoButtonColor      = false
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 8)
    btn.Parent               = TabBar
    tabBtns[i]               = btn
end

local PANEL_Y = 36
local PANEL_H = CTRL_H - PANEL_Y - 2

local function mkPanel()
    local f = Instance.new("Frame")
    f.Size                 = UDim2.new(1, 0, 0, PANEL_H)
    f.Position             = UDim2.new(0, 0, 0, PANEL_Y)
    f.BackgroundTransparency = 1
    f.Visible              = false
    f.Parent               = RP
    return f
end

local P1 = mkPanel(); P1.Visible = true
local P2 = mkPanel()
local P3 = mkPanel()
tabPanels = {P1, P2, P3}

local P1L = Instance.new("UIListLayout"); P1L.SortOrder = Enum.SortOrder.LayoutOrder; P1L.Padding = UDim.new(0, 5);  P1L.Parent = P1
local P2L = Instance.new("UIListLayout"); P2L.SortOrder = Enum.SortOrder.LayoutOrder; P2L.Padding = UDim.new(0, 5);  P2L.Parent = P2
local P3L = Instance.new("UIListLayout"); P3L.SortOrder = Enum.SortOrder.LayoutOrder; P3L.Padding = UDim.new(0, 5);  P3L.Parent = P3

local function switchTab(idx)
    activeTab = idx
    playClick()
    for i, p in ipairs(tabPanels) do
        p.Visible = (i == idx)
        TweenService:Create(tabBtns[i], TweenInfo.new(0.22, Enum.EasingStyle.Quart), {
            BackgroundTransparency = i == idx and 0.28 or 0.88,
            BackgroundColor3       = i == idx and TAB_COLORS[i] or T.Glass,
            TextColor3             = i == idx and Color3.fromRGB(255, 255, 255) or T.TextDim,
        }):Play()
    end
end
for i, b in ipairs(tabBtns) do
    b.MouseButton1Click:Connect(function() switchTab(i) end)
end

-- ========================================================================
-- [9] GLASS CARD HELPER
-- ========================================================================
local function mkCard(par, h, alpha)
    local c = Instance.new("Frame")
    c.Size                 = UDim2.new(1, 0, 0, h)
    c.BackgroundColor3     = T.Glass
    c.BackgroundTransparency = alpha or 0.40
    c.Parent               = par
    Instance.new("UICorner", c).CornerRadius = UDim.new(0, 10)
    local sk = Instance.new("UIStroke", c)
    sk.Color       = T.Border
    sk.Transparency = 0.72
    sk.Thickness   = 0.8
    return c, sk
end

-- ========================================================================
-- [10] PANEL 1 — CONFIG
-- ========================================================================
local function mkToggle(par, text, def, cb)
    local card = mkCard(par, 36)

    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(0.68, 0, 1, 0)
    lbl.Position             = UDim2.new(0, 13, 0, 0)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = text
    lbl.TextColor3           = T.TextPri
    lbl.Font                 = Enum.Font.GothamSemibold
    lbl.TextSize             = 10
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
    lbl.Parent               = card

    -- Track
    local track = Instance.new("TextButton")
    track.Size                 = UDim2.new(0, 42, 0, 22)
    track.Position             = UDim2.new(1, -54, 0.5, -11)
    track.BackgroundColor3     = def and T.Success or T.GlassLite
    track.BackgroundTransparency = def and 0 or 0.15
    track.Text                 = ""
    track.AutoButtonColor      = false
    track.Parent               = card
    Instance.new("UICorner", track).CornerRadius = UDim.new(1, 0)
    local trkStk = Instance.new("UIStroke", track)
    trkStk.Color       = def and T.Success or T.Border
    trkStk.Transparency = 0.42
    trkStk.Thickness   = 0.9

    -- Knob
    local knob = Instance.new("Frame")
    knob.Size            = UDim2.new(0, 16, 0, 16)
    knob.Position        = def and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
    knob.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    knob.Parent          = track
    Instance.new("UICorner", knob).CornerRadius = UDim.new(1, 0)
    local knStk = Instance.new("UIStroke", knob)
    knStk.Color       = def and T.Success or T.TextDim
    knStk.Transparency = 0.40
    knStk.Thickness   = 0.8

    local st = def
    track.MouseButton1Click:Connect(function()
        st = not st
        cb(st)
        playClick()

        TweenService:Create(knob,  TweenInfo.new(0.30, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Position = st and UDim2.new(1, -19, 0.5, -8) or UDim2.new(0, 3, 0.5, -8)
        }):Play()
        TweenService:Create(track, TweenInfo.new(0.25, Enum.EasingStyle.Quart), {
            BackgroundColor3     = st and T.Success or T.GlassLite,
            BackgroundTransparency = st and 0 or 0.15,
        }):Play()
        TweenService:Create(trkStk, TweenInfo.new(0.25), { Color = st and T.Success or T.Border }):Play()
        TweenService:Create(knStk,  TweenInfo.new(0.25), { Color = st and T.Success or T.TextDim }):Play()
    end)
end

local function mkSlider(par, text, mn, mx, def, cb)
    local card = mkCard(par, 46)

    local lbl = Instance.new("TextLabel")
    lbl.Size                 = UDim2.new(0.62, 0, 0, 16)
    lbl.Position             = UDim2.new(0, 13, 0, 7)
    lbl.BackgroundTransparency = 1
    lbl.Text                 = text
    lbl.TextColor3           = T.TextSec
    lbl.Font                 = Enum.Font.GothamSemibold
    lbl.TextSize             = 9
    lbl.TextXAlignment       = Enum.TextXAlignment.Left
    lbl.Parent               = card

    local valL = Instance.new("TextLabel")
    valL.Size                 = UDim2.new(0.37, -6, 0, 16)
    valL.Position             = UDim2.new(0.62, 0, 0, 7)
    valL.BackgroundTransparency = 1
    valL.Text                 = def .. "ms"
    valL.TextColor3           = T.AccentA
    valL.Font                 = Enum.Font.GothamBold
    valL.TextSize             = 9
    valL.TextXAlignment       = Enum.TextXAlignment.Right
    valL.Parent               = card
    Instance.new("UIPadding", valL).PaddingRight = UDim.new(0, 12)

    -- Track background
    local trBg = Instance.new("Frame")
    trBg.Size                 = UDim2.new(1, -26, 0, 7)
    trBg.Position             = UDim2.new(0, 13, 0, 30)
    trBg.BackgroundColor3     = T.GlassLite
    trBg.BackgroundTransparency = 0.10
    trBg.Active               = true
    trBg.Parent               = card
    Instance.new("UICorner", trBg).CornerRadius = UDim.new(1, 0)

    local fi = Instance.new("Frame")
    fi.Size             = UDim2.new((def-mn)/(mx-mn), 0, 1, 0)
    fi.BackgroundColor3 = T.AccentA
    fi.Parent           = trBg
    Instance.new("UICorner", fi).CornerRadius = UDim.new(1, 0)

    local fiGrad = Instance.new("UIGradient", fi)
    fiGrad.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(110, 175, 255)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 100, 225)),
    })

    local kn = Instance.new("Frame")
    kn.Size             = UDim2.new(0, 15, 0, 15)
    kn.Position         = UDim2.new(1, -8, 0.5, -8)
    kn.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
    kn.Parent           = fi
    Instance.new("UICorner", kn).CornerRadius = UDim.new(1, 0)
    local knStk2 = Instance.new("UIStroke", kn)
    knStk2.Color       = T.AccentA
    knStk2.Transparency = 0.30
    knStk2.Thickness   = 1

    local isd = false
    local function upd(i)
        local p = math.clamp((i.Position.X - trBg.AbsolutePosition.X) / trBg.AbsoluteSize.X, 0, 1)
        local v = math.floor(mn + (mx - mn) * p)
        fi.Size  = UDim2.new(p, 0, 1, 0)
        valL.Text = v .. "ms"
        cb(v)
    end
    trBg.InputBegan:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or
           i.UserInputType == Enum.UserInputType.Touch then isd = true; upd(i) end
    end)
    UserInputService.InputEnded:Connect(function(i)
        if i.UserInputType == Enum.UserInputType.MouseButton1 or
           i.UserInputType == Enum.UserInputType.Touch then isd = false end
    end)
    UserInputService.InputChanged:Connect(function(i)
        if isd and (i.UserInputType == Enum.UserInputType.MouseMovement or
                    i.UserInputType == Enum.UserInputType.Touch) then upd(i) end
    end)
end

mkToggle(P1, "🤖  Auto Play",     App.Config.AutoPlay, function(v) App.Config.AutoPlay = v end)
mkToggle(P1, "👤  AI Humanizer",  App.Config.Humanize, function(v) App.Config.Humanize = v end)
mkToggle(P1, "🚀  Auto Join",     App.Config.AutoJoin,  function(v) App.Config.AutoJoin  = v end)
mkSlider(P1, "⚡  Kecepatan",     1, 900, App.Config.TypingDelayMS, function(v) App.Config.TypingDelayMS = v end)

-- Mode card
local modeCard = mkCard(P1, 36)
local modeLabel = Instance.new("TextLabel")
modeLabel.Size                 = UDim2.new(0.42, 0, 1, 0)
modeLabel.Position             = UDim2.new(0, 13, 0, 0)
modeLabel.BackgroundTransparency = 1
modeLabel.Text                 = "Mode"
modeLabel.TextColor3           = T.TextSec
modeLabel.Font                 = Enum.Font.GothamSemibold
modeLabel.TextSize             = 10
modeLabel.TextXAlignment       = Enum.TextXAlignment.Left
modeLabel.Parent               = modeCard

local ModeB = Instance.new("TextButton")
ModeB.Size                 = UDim2.new(0.52, -6, 0, 24)
ModeB.Position             = UDim2.new(0.48, 0, 0.5, -12)
ModeB.BackgroundColor3     = T.AccentA
ModeB.BackgroundTransparency = 0.55
ModeB.Text                 = App.Config.Playstyle
ModeB.TextColor3           = Color3.fromRGB(185, 215, 255)
ModeB.Font                 = Enum.Font.GothamBold
ModeB.TextSize             = 8
ModeB.AutoButtonColor      = false
ModeB.Parent               = modeCard
Instance.new("UICorner", ModeB).CornerRadius = UDim.new(0, 8)
local modeBStk = Instance.new("UIStroke", ModeB)
modeBStk.Color       = T.AccentA
modeBStk.Transparency = 0.45
modeBStk.Thickness   = 0.8

ModeB.MouseButton1Click:Connect(function()
    App.State.StyleIndex     = (App.State.StyleIndex % #App.Config.Styles) + 1
    App.Config.Playstyle     = App.Config.Styles[App.State.StyleIndex]
    ModeB.Text               = App.Config.Playstyle
    playClick()
    TweenService:Create(ModeB, TweenInfo.new(0.10, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
        BackgroundTransparency = 0.15
    }):Play()
    task.wait(0.16)
    TweenService:Create(ModeB, TweenInfo.new(0.18), {BackgroundTransparency = 0.55}):Play()
end)

-- ========================================================================
-- [11] PANEL 2 — SUFFIX  (premium rewrite)
-- ========================================================================
local function rarityLabel(cnt)
    if cnt == 0     then return "☠  DEAD END",       T.Success
    elseif cnt <= 3   then return "🔥 SANGAT LANGKA",  T.Warn
    elseif cnt <= 10  then return "⚡ LANGKA",          T.Orange
    elseif cnt <= 30  then return "~  AGAK SULIT",      Color3.fromRGB(175, 200, 255)
    else              return "·  UMUM",                 T.TextDim end
end

-- Header card
local p2Hdr, _ = mkCard(P2, 38, 0.28)
local p2HdrGrad = Instance.new("UIGradient", p2Hdr)
p2HdrGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(175, 85, 15)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(55, 28, 8)),
})
p2HdrGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.42), NumberSequenceKeypoint.new(1, 0.65)
})
p2HdrGrad.Rotation = 130

local p2IconL = Instance.new("TextLabel")
p2IconL.Size = UDim2.new(0, 30, 1, 0); p2IconL.Position = UDim2.new(0, 8, 0, 0)
p2IconL.BackgroundTransparency = 1; p2IconL.Text = "🎯"; p2IconL.TextSize = 17
p2IconL.Font = Enum.Font.GothamBold; p2IconL.Parent = p2Hdr

local p2TitleL = Instance.new("TextLabel")
p2TitleL.Size = UDim2.new(0.5, 0, 0.52, 0); p2TitleL.Position = UDim2.new(0, 42, 0, 5)
p2TitleL.BackgroundTransparency = 1; p2TitleL.Text = "TARGET AKHIRAN"
p2TitleL.TextColor3 = T.Orange; p2TitleL.Font = Enum.Font.GothamBlack
p2TitleL.TextSize = 9; p2TitleL.TextXAlignment = Enum.TextXAlignment.Left; p2TitleL.Parent = p2Hdr

local SfxCntL = Instance.new("TextLabel")
SfxCntL.Size = UDim2.new(0.45, -8, 1, 0); SfxCntL.Position = UDim2.new(0.55, 0, 0, 0)
SfxCntL.BackgroundTransparency = 1; SfxCntL.Text = "0 aktif"
SfxCntL.TextColor3 = T.Warn; SfxCntL.Font = Enum.Font.GothamBold
SfxCntL.TextSize = 9; SfxCntL.TextXAlignment = Enum.TextXAlignment.Right
Instance.new("UIPadding", SfxCntL).PaddingRight = UDim.new(0, 10)
SfxCntL.Parent = p2Hdr

-- Trap meter card
local trapCard = mkCard(P2, 26, 0.55)
local trapBg = Instance.new("Frame")
trapBg.Size = UDim2.new(1, -20, 0, 7); trapBg.Position = UDim2.new(0, 10, 0.5, -4)
trapBg.BackgroundColor3 = T.GlassLite; trapBg.BackgroundTransparency = 0.12
Instance.new("UICorner", trapBg).CornerRadius = UDim.new(1, 0); trapBg.Parent = trapCard

local trapMeterFill = Instance.new("Frame")
trapMeterFill.Size = UDim2.new(0, 0, 1, 0); trapMeterFill.BackgroundColor3 = T.Success
trapMeterFill.BackgroundTransparency = 0.15
Instance.new("UICorner", trapMeterFill).CornerRadius = UDim.new(1, 0)
trapMeterFill.Parent = trapBg

local trapMeterLabel = Instance.new("TextLabel")
trapMeterLabel.Size = UDim2.new(1, -20, 1, 0); trapMeterLabel.Position = UDim2.new(0, 10, 0, 0)
trapMeterLabel.BackgroundTransparency = 1; trapMeterLabel.Text = "Pilih suffix dulu"
trapMeterLabel.TextColor3 = T.TextDim; trapMeterLabel.Font = Enum.Font.GothamSemibold
trapMeterLabel.TextSize = 8; trapMeterLabel.Parent = trapCard

-- Chips scroll card
local chipCard = mkCard(P2, 32, 0.55)
chipCard.ClipsDescendants = true

local ChipSF = Instance.new("ScrollingFrame")
ChipSF.Size = UDim2.new(1, -8, 1, -8); ChipSF.Position = UDim2.new(0, 4, 0, 4)
ChipSF.BackgroundTransparency = 1; ChipSF.ScrollBarThickness = 0
ChipSF.CanvasSize = UDim2.new(0, 0, 0, 0)
ChipSF.ScrollingDirection = Enum.ScrollingDirection.X; ChipSF.Parent = chipCard

local ChipL = Instance.new("UIListLayout")
ChipL.FillDirection = Enum.FillDirection.Horizontal; ChipL.SortOrder = Enum.SortOrder.LayoutOrder
ChipL.Padding = UDim.new(0, 4); ChipL.VerticalAlignment = Enum.VerticalAlignment.Center; ChipL.Parent = ChipSF

local TAG_C = {
    Color3.fromRGB(70,140,255), Color3.fromRGB(255,120,40),
    Color3.fromRGB(190,70,255), Color3.fromRGB(255,65,110),
    Color3.fromRGB(40,200,200), Color3.fromRGB(70,210,120),
}

-- Input card
local sfxInputCard = mkCard(P2, 34, 0.55)

local SfxIn = Instance.new("TextBox")
SfxIn.Size = UDim2.new(0.73, -4, 0, 24); SfxIn.Position = UDim2.new(0, 6, 0.5, -12)
SfxIn.BackgroundColor3 = T.GlassLite; SfxIn.BackgroundTransparency = 0.22
SfxIn.Text = App.Config.TargetSuffixRaw; SfxIn.PlaceholderText = "tt, ly, cy, ox..."
SfxIn.TextColor3 = T.Warn; SfxIn.PlaceholderColor3 = T.TextDim
SfxIn.Font = Enum.Font.GothamBold; SfxIn.TextSize = 9; SfxIn.ClearTextOnFocus = false
Instance.new("UICorner", SfxIn).CornerRadius = UDim.new(0, 8)
local sIs = Instance.new("UIStroke", SfxIn); sIs.Color = T.Orange; sIs.Transparency = 0.40; sIs.Thickness = 0.9
SfxIn.Parent = sfxInputCard

local SfxClr = Instance.new("TextButton")
SfxClr.Size = UDim2.new(0.26, -2, 0, 24); SfxClr.Position = UDim2.new(0.74, 0, 0.5, -12)
SfxClr.BackgroundColor3 = T.Danger; SfxClr.BackgroundTransparency = 0.30
SfxClr.Text = "CLR"; SfxClr.TextColor3 = Color3.fromRGB(255, 255, 255)
SfxClr.Font = Enum.Font.GothamBold; SfxClr.TextSize = 9; SfxClr.AutoButtonColor = false
Instance.new("UICorner", SfxClr).CornerRadius = UDim.new(0, 8); SfxClr.Parent = sfxInputCard
SfxClr.MouseButton1Down:Connect(function() TweenService:Create(SfxClr, TweenInfo.new(0.07), {BackgroundTransparency = 0.05}):Play() end)
SfxClr.MouseButton1Up:Connect(function() TweenService:Create(SfxClr, TweenInfo.new(0.15), {BackgroundTransparency = 0.30}):Play() end)

-- Rarity info card
local rarCard = mkCard(P2, 24, 0.60)
local TrapInfoL = Instance.new("TextLabel")
TrapInfoL.Size = UDim2.new(1, -16, 1, 0); TrapInfoL.Position = UDim2.new(0, 8, 0, 0)
TrapInfoL.BackgroundTransparency = 1; TrapInfoL.Text = "—"
TrapInfoL.TextColor3 = T.Warn; TrapInfoL.Font = Enum.Font.GothamSemibold
TrapInfoL.TextSize = 8; TrapInfoL.TextXAlignment = Enum.TextXAlignment.Left; TrapInfoL.Parent = rarCard

-- Divider
local Div2 = Instance.new("Frame")
Div2.Size = UDim2.new(1, 0, 0, 1); Div2.BackgroundColor3 = T.Border
Div2.BackgroundTransparency = 0.75; Div2.BorderSizePixel = 0; Div2.Parent = P2

-- Save card
local saveCard = mkCard(P2, 34, 0.55)
local PNIn = Instance.new("TextBox")
PNIn.Size = UDim2.new(0.56, -4, 0, 24); PNIn.Position = UDim2.new(0, 6, 0.5, -12)
PNIn.BackgroundColor3 = T.GlassLite; PNIn.BackgroundTransparency = 0.28
PNIn.Text = ""; PNIn.PlaceholderText = "Nama profil..."
PNIn.TextColor3 = T.TextPri; PNIn.PlaceholderColor3 = T.TextDim
PNIn.Font = Enum.Font.GothamSemibold; PNIn.TextSize = 9; PNIn.ClearTextOnFocus = false
Instance.new("UICorner", PNIn).CornerRadius = UDim.new(0, 8)
local pnStk = Instance.new("UIStroke", PNIn); pnStk.Color = T.Border; pnStk.Transparency = 0.52; pnStk.Thickness = 0.8
PNIn.Parent = saveCard

local SaveB = Instance.new("TextButton")
SaveB.Size = UDim2.new(0.43, -2, 0, 24); SaveB.Position = UDim2.new(0.57, 0, 0.5, -12)
SaveB.BackgroundColor3 = T.Success; SaveB.BackgroundTransparency = 0.22
SaveB.Text = "💾  Simpan"; SaveB.TextColor3 = Color3.fromRGB(215, 255, 230)
SaveB.Font = Enum.Font.GothamBold; SaveB.TextSize = 9; SaveB.AutoButtonColor = false
Instance.new("UICorner", SaveB).CornerRadius = UDim.new(0, 8)
local saveBStk = Instance.new("UIStroke", SaveB); saveBStk.Color = T.Success; saveBStk.Transparency = 0.48; saveBStk.Thickness = 0.8
SaveB.Parent = saveCard
SaveB.MouseButton1Down:Connect(function() TweenService:Create(SaveB, TweenInfo.new(0.07), {BackgroundTransparency = 0.05}):Play() end)
SaveB.MouseButton1Up:Connect(function() TweenService:Create(SaveB, TweenInfo.new(0.15), {BackgroundTransparency = 0.22}):Play() end)

-- Profile header row
local phRow = Instance.new("Frame"); phRow.Size = UDim2.new(1, 0, 0, 14); phRow.BackgroundTransparency = 1; phRow.Parent = P2
local PHdr2 = Instance.new("TextLabel"); PHdr2.Size = UDim2.new(1, 0, 1, 0); PHdr2.BackgroundTransparency = 1
PHdr2.Text = "PROFIL TERSIMPAN"; PHdr2.TextColor3 = T.Orange; PHdr2.Font = Enum.Font.GothamBold
PHdr2.TextSize = 8; PHdr2.TextXAlignment = Enum.TextXAlignment.Left; PHdr2.Parent = phRow

-- Profile scroll
local PSF = Instance.new("ScrollingFrame")
PSF.Size = UDim2.new(1, 0, 0, 52); PSF.BackgroundColor3 = T.Glass; PSF.BackgroundTransparency = 0.38
PSF.ScrollBarThickness = 2; PSF.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", PSF).CornerRadius = UDim.new(0, 9)
local psStk = Instance.new("UIStroke", PSF); psStk.Color = T.Orange; psStk.Transparency = 0.70; psStk.Thickness = 0.8
PSF.Parent = P2
local PLL = Instance.new("UIListLayout"); PLL.SortOrder = Enum.SortOrder.LayoutOrder; PLL.Padding = UDim.new(0, 2); PLL.Parent = PSF
local PPad = Instance.new("UIPadding", PSF); PPad.PaddingTop = UDim.new(0, 4); PPad.PaddingLeft = UDim.new(0, 4); PPad.PaddingRight = UDim.new(0, 4)
PLL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function() PSF.CanvasSize = UDim2.new(0, 0, 0, PLL.AbsoluteContentSize.Y + 8) end)

-- ── CHIP LOGIC ─────────────────────────────────────────────────────────────
local chipObjs = {}
local function refreshChips()
    for _, o in ipairs(chipObjs) do o:Destroy() end; chipObjs = {}
    local sfxCount = #App.Config.TargetSuffixes
    SfxCntL.Text      = sfxCount > 0 and (sfxCount .. " aktif") or "0 aktif"
    SfxCntL.TextColor3 = sfxCount > 0 and T.Warn or T.TextDim
    if sfxCount == 0 then
        local ph = Instance.new("TextLabel"); ph.Size = UDim2.new(0, 175, 1, 0); ph.BackgroundTransparency = 1
        ph.Text = "Ketik akhiran → pisahkan koma"; ph.TextColor3 = T.TextDim
        ph.Font = Enum.Font.GothamSemibold; ph.TextSize = 8; ph.Parent = ChipSF
        table.insert(chipObjs, ph); ChipSF.CanvasSize = UDim2.new(0, 0, 0, 0)
        TrapInfoL.Text = "Belum ada suffix dipilih"; TrapInfoL.TextColor3 = T.TextDim
        TweenService:Create(trapMeterFill, TweenInfo.new(0.4, Enum.EasingStyle.Quart), {Size = UDim2.new(0, 0, 1, 0)}):Play()
        trapMeterLabel.Text = "Pilih suffix dulu"; trapMeterLabel.TextColor3 = T.TextDim
        return
    end
    local tw = 8
    for i, sfx in ipairs(App.Config.TargetSuffixes) do
        local cnt = optionCount(sfx)
        local lbl, lcol = rarityLabel(cnt)
        local col = TAG_C[((i-1) % #TAG_C) + 1]
        local cw = math.max(30, #sfx * 9 + 22)
        local chip = Instance.new("Frame"); chip.Size = UDim2.new(0, cw, 0, 20)
        chip.BackgroundColor3 = col; chip.BackgroundTransparency = 0.48
        Instance.new("UICorner", chip).CornerRadius = UDim.new(0, 7)
        local chStk = Instance.new("UIStroke", chip); chStk.Color = col; chStk.Transparency = 0.28; chStk.Thickness = 0.8
        chip.Parent = ChipSF
        local cl = Instance.new("TextLabel"); cl.Size = UDim2.new(1, 0, 1, 0); cl.BackgroundTransparency = 1
        cl.Text = sfx:upper(); cl.TextColor3 = Color3.fromRGB(255, 255, 255); cl.Font = Enum.Font.GothamBold; cl.TextSize = 9; cl.Parent = chip
        table.insert(chipObjs, chip); tw = tw + cw + 4
    end
    ChipSF.CanvasSize = UDim2.new(0, tw, 0, 0)
    local sfx1 = App.Config.TargetSuffixes[1]
    if sfx1 then
        local cnt = optionCount(sfx1)
        local lbl, lcol = rarityLabel(cnt)
        TrapInfoL.Text      = sfx1:upper() .. "  →  " .. lbl .. (cnt > 0 and ("  (" .. cnt .. " opsi)") or "")
        TrapInfoL.TextColor3 = lcol
        local fr = cnt==0 and 1 or cnt<=3 and 0.86 or cnt<=10 and 0.65 or cnt<=30 and 0.40 or 0.15
        TweenService:Create(trapMeterFill, TweenInfo.new(0.5, Enum.EasingStyle.Quart), {Size = UDim2.new(fr, 0, 1, 0), BackgroundColor3 = lcol}):Play()
        trapMeterLabel.Text       = cnt == 0 and "💀 PASTI MENANG!" or lbl
        trapMeterLabel.TextColor3 = lcol
    end
end
getgenv()._refreshChips = refreshChips

local function parseSfx(raw)
    App.Config.TargetSuffixRaw = raw; App.Config.TargetSuffixes = {}
    for sfx in raw:gmatch("([^,]+)") do
        local c = lower(sfx:match("^%s*(.-)%s*$") or "")
        if c ~= "" then table.insert(App.Config.TargetSuffixes, c) end
    end
    refreshChips()
end
SfxIn.FocusLost:Connect(function() parseSfx(SfxIn.Text) end)
SfxClr.MouseButton1Click:Connect(function()
    SfxIn.Text = ""; parseSfx(""); playClick()
end)

-- ── PROFILES ───────────────────────────────────────────────────────────────
local profObjs = {}; local editIdx = nil
local function renderProfiles()
    for _, o in ipairs(profObjs) do o:Destroy() end; profObjs = {}
    if #App.Profiles == 0 then
        local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, 0, 0, 22); lbl.BackgroundTransparency = 1
        lbl.Text = "Belum ada profil tersimpan"; lbl.TextColor3 = T.TextDim; lbl.Font = Enum.Font.GothamSemibold; lbl.TextSize = 9; lbl.Parent = PSF
        table.insert(profObjs, lbl); return
    end
    for i, prof in ipairs(App.Profiles) do
        local row = Instance.new("Frame"); row.Size = UDim2.new(1, 0, 0, 24)
        row.BackgroundColor3 = editIdx == i and T.GlassLite or T.Glass
        row.BackgroundTransparency = editIdx == i and 0.18 or 0.48
        Instance.new("UICorner", row).CornerRadius = UDim.new(0, 7); row.Parent = PSF
        if editIdx == i then
            local hs = Instance.new("UIStroke", row); hs.Color = T.Orange; hs.Transparency = 0.28; hs.Thickness = 0.9
        end
        table.insert(profObjs, row)

        local nl = Instance.new("TextButton"); nl.Size = UDim2.new(0.53, 0, 1, 0); nl.BackgroundTransparency = 1
        nl.Text = prof.name or ("Profil "..i); nl.TextColor3 = T.Warn
        nl.Font = Enum.Font.GothamSemibold; nl.TextSize = 9; nl.TextXAlignment = Enum.TextXAlignment.Left; nl.TextTruncate = Enum.TextTruncate.AtEnd
        Instance.new("UIPadding", nl).PaddingLeft = UDim.new(0, 7); nl.Parent = row

        local eb = Instance.new("TextButton"); eb.Size = UDim2.new(0.22, 0, 0.72, 0); eb.Position = UDim2.new(0.54, 1, 0.14, 0)
        eb.BackgroundColor3 = T.AccentA; eb.BackgroundTransparency = 0.32; eb.Text = "✏"
        eb.TextColor3 = Color3.fromRGB(255, 255, 255); eb.Font = Enum.Font.GothamBold; eb.TextSize = 11
        Instance.new("UICorner", eb).CornerRadius = UDim.new(0, 5); eb.Parent = row

        local db = Instance.new("TextButton"); db.Size = UDim2.new(0.21, 0, 0.72, 0); db.Position = UDim2.new(0.77, 2, 0.14, 0)
        db.BackgroundColor3 = T.Danger; db.BackgroundTransparency = 0.32; db.Text = "🗑"
        db.TextColor3 = Color3.fromRGB(255, 255, 255); db.Font = Enum.Font.GothamBold; db.TextSize = 11
        Instance.new("UICorner", db).CornerRadius = UDim.new(0, 5); db.Parent = row

        local function loadProf()
            SfxIn.Text = prof.suffixes or ""; parseSfx(prof.suffixes or ""); PNIn.Text = prof.name or ""; editIdx = i; renderProfiles()
        end
        nl.MouseButton1Click:Connect(loadProf)
        eb.MouseButton1Click:Connect(loadProf)
        db.MouseButton1Click:Connect(function()
            table.remove(App.Profiles, i)
            if editIdx == i then editIdx = nil elseif editIdx and editIdx > i then editIdx = editIdx - 1 end
            if getgenv()._saveProfiles then getgenv()._saveProfiles() end
            renderProfiles()
        end)
    end
end
getgenv()._renderProfiles = renderProfiles

SaveB.MouseButton1Click:Connect(function()
    local raw = SfxIn.Text; if raw == "" then return end; parseSfx(raw)
    local nm = PNIn.Text ~= "" and PNIn.Text or ("Profil " .. (#App.Profiles + 1))
    if editIdx and App.Profiles[editIdx] then
        App.Profiles[editIdx].name = nm; App.Profiles[editIdx].suffixes = raw
    else
        table.insert(App.Profiles, {name = nm, suffixes = raw}); editIdx = #App.Profiles
    end
    PNIn.Text = ""
    if getgenv()._saveProfiles then getgenv()._saveProfiles() end
    renderProfiles(); playClick()
    task.spawn(function()
        TweenService:Create(SaveB, TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(25, 235, 110)}):Play()
        task.wait(0.42)
        TweenService:Create(SaveB, TweenInfo.new(0.20), {BackgroundColor3 = T.Success}):Play()
    end)
end)

-- ========================================================================
-- [12] PANEL 3 — TAMBAH KATA CUSTOM  (premium rewrite)
-- ========================================================================

-- Header card
local p3Hdr = mkCard(P3, 38, 0.28)
local p3HdrGrad = Instance.new("UIGradient", p3Hdr)
p3HdrGrad.Color = ColorSequence.new({
    ColorSequenceKeypoint.new(0, Color3.fromRGB(18, 115, 58)),
    ColorSequenceKeypoint.new(1, Color3.fromRGB(7,  38, 22)),
})
p3HdrGrad.Transparency = NumberSequence.new({
    NumberSequenceKeypoint.new(0, 0.40), NumberSequenceKeypoint.new(1, 0.62)
})
p3HdrGrad.Rotation = 130

local p3IconL = Instance.new("TextLabel")
p3IconL.Size = UDim2.new(0, 30, 1, 0); p3IconL.Position = UDim2.new(0, 8, 0, 0)
p3IconL.BackgroundTransparency = 1; p3IconL.Text = "✏"; p3IconL.TextSize = 17
p3IconL.Font = Enum.Font.GothamBold; p3IconL.Parent = p3Hdr

local p3TitleL = Instance.new("TextLabel")
p3TitleL.Size = UDim2.new(0.55, 0, 0.52, 0); p3TitleL.Position = UDim2.new(0, 42, 0, 5)
p3TitleL.BackgroundTransparency = 1; p3TitleL.Text = "TAMBAH KATA"
p3TitleL.TextColor3 = T.Success; p3TitleL.Font = Enum.Font.GothamBlack
p3TitleL.TextSize = 9; p3TitleL.TextXAlignment = Enum.TextXAlignment.Left; p3TitleL.Parent = p3Hdr

local p3SubL = Instance.new("TextLabel")
p3SubL.Size = UDim2.new(0.55, 0, 0.40, 0); p3SubL.Position = UDim2.new(0, 42, 0.55, 0)
p3SubL.BackgroundTransparency = 1; p3SubL.Text = "Manual word bank"
p3SubL.TextColor3 = T.TextDim; p3SubL.Font = Enum.Font.GothamSemibold
p3SubL.TextSize = 7; p3SubL.TextXAlignment = Enum.TextXAlignment.Left; p3SubL.Parent = p3Hdr

local cwTotalBadge = Instance.new("TextLabel")
cwTotalBadge.Size = UDim2.new(0, 58, 0, 20); cwTotalBadge.Position = UDim2.new(1, -65, 0.5, -10)
cwTotalBadge.BackgroundTransparency = 1; cwTotalBadge.Text = "DB: —"
cwTotalBadge.TextColor3 = T.Success; cwTotalBadge.Font = Enum.Font.GothamBold
cwTotalBadge.TextSize = 8; cwTotalBadge.TextXAlignment = Enum.TextXAlignment.Right; cwTotalBadge.Parent = p3Hdr

-- Input card
local cwInputCard = mkCard(P3, 38, 0.52)
local cwIn = Instance.new("TextBox")
cwIn.Size = UDim2.new(0.65, -4, 0, 26); cwIn.Position = UDim2.new(0, 6, 0.5, -13)
cwIn.BackgroundColor3 = T.GlassLite; cwIn.BackgroundTransparency = 0.22
cwIn.Text = ""; cwIn.PlaceholderText = "Ketik kata..."
cwIn.TextColor3 = T.Success; cwIn.PlaceholderColor3 = T.TextDim
cwIn.Font = Enum.Font.GothamBold; cwIn.TextSize = 10; cwIn.ClearTextOnFocus = false
Instance.new("UICorner", cwIn).CornerRadius = UDim.new(0, 8)
local cwInStk = Instance.new("UIStroke", cwIn); cwInStk.Color = T.Success; cwInStk.Transparency = 0.45; cwInStk.Thickness = 0.9
cwIn.Parent = cwInputCard

local cwAddB = Instance.new("TextButton")
cwAddB.Size = UDim2.new(0.34, -2, 0, 26); cwAddB.Position = UDim2.new(0.66, 0, 0.5, -13)
cwAddB.BackgroundColor3 = T.Success; cwAddB.BackgroundTransparency = 0.18
cwAddB.Text = "+ ADD"; cwAddB.TextColor3 = Color3.fromRGB(215, 255, 230)
cwAddB.Font = Enum.Font.GothamBold; cwAddB.TextSize = 10; cwAddB.AutoButtonColor = false
Instance.new("UICorner", cwAddB).CornerRadius = UDim.new(0, 8)
local cwAddStk = Instance.new("UIStroke", cwAddB); cwAddStk.Color = T.Success; cwAddStk.Transparency = 0.42; cwAddStk.Thickness = 0.8
cwAddB.Parent = cwInputCard
cwAddB.MouseButton1Down:Connect(function() TweenService:Create(cwAddB, TweenInfo.new(0.07), {BackgroundTransparency = 0.0}):Play() end)
cwAddB.MouseButton1Up:Connect(function() TweenService:Create(cwAddB, TweenInfo.new(0.15), {BackgroundTransparency = 0.18}):Play() end)

-- Notif card
local cwNotifCard = mkCard(P3, 30, 0.58)
local cwNotifIcon = Instance.new("TextLabel")
cwNotifIcon.Size = UDim2.new(0, 28, 1, 0); cwNotifIcon.BackgroundTransparency = 1
cwNotifIcon.Text = ""; cwNotifIcon.Font = Enum.Font.GothamBold; cwNotifIcon.TextSize = 14; cwNotifIcon.Parent = cwNotifCard

local cwNotifL = Instance.new("TextLabel")
cwNotifL.Size = UDim2.new(1, -30, 1, 0); cwNotifL.Position = UDim2.new(0, 26, 0, 0)
cwNotifL.BackgroundTransparency = 1; cwNotifL.Text = "Siap menambahkan kata"
cwNotifL.TextColor3 = T.TextDim; cwNotifL.Font = Enum.Font.GothamSemibold
cwNotifL.TextSize = 8; cwNotifL.TextXAlignment = Enum.TextXAlignment.Left; cwNotifL.Parent = cwNotifCard

-- Counter row
local cwCounterRow = Instance.new("Frame"); cwCounterRow.Size = UDim2.new(1, 0, 0, 14); cwCounterRow.BackgroundTransparency = 1; cwCounterRow.Parent = P3
local cwTotalL = Instance.new("TextLabel"); cwTotalL.Size = UDim2.new(0.5, 0, 1, 0); cwTotalL.BackgroundTransparency = 1
cwTotalL.Text = "DB: —"; cwTotalL.TextColor3 = T.TextDim; cwTotalL.Font = Enum.Font.GothamSemibold; cwTotalL.TextSize = 8; cwTotalL.TextXAlignment = Enum.TextXAlignment.Left; cwTotalL.Parent = cwCounterRow
local cwSessionL = Instance.new("TextLabel"); cwSessionL.Size = UDim2.new(0.5, 0, 1, 0); cwSessionL.Position = UDim2.new(0.5, 0, 0, 0); cwSessionL.BackgroundTransparency = 1
cwSessionL.Text = "Sesi: 0 ditambah"; cwSessionL.TextColor3 = T.Success; cwSessionL.Font = Enum.Font.GothamSemibold; cwSessionL.TextSize = 8; cwSessionL.TextXAlignment = Enum.TextXAlignment.Right; cwSessionL.Parent = cwCounterRow

getgenv()._setCWTotal = function(text)
    cwTotalL.Text = text; cwTotalBadge.Text = text
end

-- Divider
local cwDiv = Instance.new("Frame"); cwDiv.Size = UDim2.new(1, 0, 0, 1); cwDiv.BackgroundColor3 = T.Success; cwDiv.BackgroundTransparency = 0.72; cwDiv.BorderSizePixel = 0; cwDiv.Parent = P3

-- Recent header
local cwRecHdr = Instance.new("TextLabel"); cwRecHdr.Size = UDim2.new(1, 0, 0, 14); cwRecHdr.BackgroundTransparency = 1
cwRecHdr.Text = "BARU DITAMBAHKAN"; cwRecHdr.TextColor3 = T.Success; cwRecHdr.Font = Enum.Font.GothamBold; cwRecHdr.TextSize = 8; cwRecHdr.TextXAlignment = Enum.TextXAlignment.Left; cwRecHdr.Parent = P3

-- Recent scroll
local cwRecentSF = Instance.new("ScrollingFrame")
cwRecentSF.Size = UDim2.new(1, 0, 0, 58); cwRecentSF.BackgroundColor3 = T.Glass
cwRecentSF.BackgroundTransparency = 0.38; cwRecentSF.ScrollBarThickness = 2; cwRecentSF.CanvasSize = UDim2.new(0, 0, 0, 0)
Instance.new("UICorner", cwRecentSF).CornerRadius = UDim.new(0, 9)
local cwRecStk = Instance.new("UIStroke", cwRecentSF); cwRecStk.Color = T.Success; cwRecStk.Transparency = 0.68; cwRecStk.Thickness = 0.8; cwRecentSF.Parent = P3
local cwRecList = Instance.new("UIListLayout"); cwRecList.SortOrder = Enum.SortOrder.LayoutOrder; cwRecList.Padding = UDim.new(0, 2); cwRecList.Parent = cwRecentSF
local cwRecPad = Instance.new("UIPadding", cwRecentSF); cwRecPad.PaddingLeft = UDim.new(0, 7); cwRecPad.PaddingTop = UDim.new(0, 5)
cwRecList:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    cwRecentSF.CanvasSize = UDim2.new(0, 0, 0, cwRecList.AbsoluteContentSize.Y + 8)
end)

local cwSessionCount = 0
local cwRecentItems  = {}

local function cwNotif(ok, msg)
    local bgCol  = ok and Color3.fromRGB(10, 38, 22) or Color3.fromRGB(42, 10, 10)
    local txtCol = ok and Color3.fromRGB(130, 255, 160) or Color3.fromRGB(255, 130, 130)
    cwNotifIcon.Text      = ok and "✓" or "✕"
    cwNotifIcon.TextColor3 = ok and T.Success or T.Danger
    cwNotifCard.BackgroundColor3 = bgCol
    cwNotifL.Text       = msg; cwNotifL.TextColor3 = txtCol
    TweenService:Create(cwNotifCard, TweenInfo.new(0.18), {BackgroundTransparency = 0.12}):Play()
    task.wait(2.5)
    TweenService:Create(cwNotifCard, TweenInfo.new(0.50), {BackgroundTransparency = 0.58, BackgroundColor3 = T.Glass}):Play()
end

local function cwAddRecent(word)
    local lbl = Instance.new("TextLabel"); lbl.Size = UDim2.new(1, -10, 0, 17); lbl.BackgroundTransparency = 1
    lbl.Text = "✓  " .. word:upper(); lbl.TextColor3 = T.Success; lbl.Font = Enum.Font.GothamSemibold; lbl.TextSize = 9; lbl.TextXAlignment = Enum.TextXAlignment.Left; lbl.LayoutOrder = -cwSessionCount
    lbl.Parent = cwRecentSF; table.insert(cwRecentItems, lbl)
    if #cwRecentItems > 12 then cwRecentItems[1]:Destroy(); table.remove(cwRecentItems, 1) end
end

local cwAddCooldown = false
local function doAddCustomWord()
    if cwAddCooldown then return end
    local raw = cwIn.Text
    local lw  = lower(raw:match("^%s*(%a+)%s*$") or "")
    if lw == "" or #lw < 2 then
        task.spawn(function() cwNotif(false, "Masukkan kata valid (huruf saja)") end); return
    end
    cwAddCooldown = true
    if App.DB.KnownWords[lw] then
        task.spawn(function()
            TweenService:Create(cwInStk, TweenInfo.new(0.15), {Color = T.Danger}):Play()
            cwNotif(false, 'Sudah ada!  "' .. lw:upper() .. '"')
            task.wait(0.5); TweenService:Create(cwInStk, TweenInfo.new(0.30), {Color = T.Success}):Play()
            cwAddCooldown = false
        end); return
    end
    if App.State.PermanentBlacklist[lw] then
        task.spawn(function()
            TweenService:Create(cwInStk, TweenInfo.new(0.15), {Color = T.Danger}):Play()
            cwNotif(false, '"' .. lw:upper() .. '" ada di blacklist')
            task.wait(0.5); TweenService:Create(cwInStk, TweenInfo.new(0.30), {Color = T.Success}):Play()
            cwAddCooldown = false
        end); return
    end
    local added = addWord(lw, true)
    if added then
        flushWords(); cwSessionCount = cwSessionCount + 1; cwIn.Text = ""
        local dbTxt = "DB: " .. App.DB.TotalWords .. " kata"
        cwTotalL.Text = dbTxt; cwTotalBadge.Text = dbTxt
        cwSessionL.Text = "Sesi: +" .. cwSessionCount
        cwAddRecent(lw); playClick()
        task.spawn(function()
            TweenService:Create(cwAddB,  TweenInfo.new(0.12), {BackgroundColor3 = Color3.fromRGB(30, 255, 120)}):Play()
            TweenService:Create(cwInStk, TweenInfo.new(0.15), {Color = Color3.fromRGB(40, 255, 120)}):Play()
            cwNotif(true, '"' .. lw:upper() .. '" berhasil ditambahkan!')
            task.wait(0.45)
            TweenService:Create(cwAddB,  TweenInfo.new(0.22), {BackgroundColor3 = T.Success}):Play()
            task.wait(0.32)
            TweenService:Create(cwInStk, TweenInfo.new(0.40), {Color = T.Success}):Play()
            cwAddCooldown = false
        end)
    else
        task.spawn(function() cwNotif(false, "Gagal menambahkan kata"); cwAddCooldown = false end)
    end
end

cwAddB.MouseButton1Click:Connect(doAddCustomWord)
cwIn.FocusLost:Connect(function(enterPressed) if enterPressed then doAddCustomWord() end end)

-- ========================================================================
-- [13] LEFT PANEL — Word List (Book panel)
-- ========================================================================
local LP = Instance.new("Frame")
LP.Size = UDim2.new(0, LP_W, 1, -TOP_H); LP.Position = UDim2.new(1, -W - LP_W + 4, 0, TOP_H)
LP.BackgroundTransparency = 1; LP.Parent = MF

local WordSF = Instance.new("ScrollingFrame")
WordSF.Size = UDim2.new(1, -8, 1, -8); WordSF.Position = UDim2.new(0, 4, 0, 4)
WordSF.BackgroundTransparency = 1; WordSF.ScrollBarThickness = 2; WordSF.CanvasSize = UDim2.new(0, 0, 0, 0); WordSF.Parent = LP

local GL = Instance.new("UIGridLayout"); GL.CellSize = UDim2.new(0.47, 0, 0, 24); GL.CellPadding = UDim2.new(0.04, 0, 0, 5)
GL.SortOrder = Enum.SortOrder.LayoutOrder; GL.Parent = WordSF
GL:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
    WordSF.CanvasSize = UDim2.new(0, 0, 0, GL.AbsoluteContentSize.Y + 10)
end)

-- ── TOPBAR BUTTON LOGIC ────────────────────────────────────────────────────
local isMini = false; local isBook = false

CloseB.MouseButton1Click:Connect(function()
    TweenService:Create(USc, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.In), {Scale = 0}):Play()
    task.wait(0.28); SG:Destroy()
end)
MinB.MouseButton1Click:Connect(function()
    isMini = not isMini
    local targetH = isMini and TOP_H or H
    TweenService:Create(MF, TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, isBook and W + LP_W or W, 0, targetH)
    }):Play()
    MinB.Text = isMini and "□" or "—"
end)
BookB.MouseButton1Click:Connect(function()
    if isMini then return end
    isBook = not isBook
    TweenService:Create(MF, TweenInfo.new(0.42, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
        Size = UDim2.new(0, isBook and W + LP_W or W, 0, H)
    }):Play()
    TweenService:Create(BookB, TweenInfo.new(0.20), {
        TextColor3 = isBook and Color3.fromRGB(255, 255, 255) or T.AccentA
    }):Play()
end)

-- ========================================================================
-- [14] WORD BUTTON POOL
-- ========================================================================
local Pool = {}
local function getBtn(idx)
    if not Pool[idx] then
        local b = Instance.new("TextButton")
        b.BackgroundColor3     = T.Glass
        b.BackgroundTransparency = 0.38
        b.TextColor3           = T.TextPri
        b.Font                 = Enum.Font.GothamSemibold
        b.TextSize             = 9
        b.TextTruncate         = Enum.TextTruncate.AtEnd
        b.AutoButtonColor      = false
        b.Parent               = WordSF
        Instance.new("UICorner", b).CornerRadius = UDim.new(0, 7)
        local sk = Instance.new("UIStroke", b)
        sk.Color       = T.Border
        sk.Transparency = 0.75
        sk.Thickness   = 0.7
        b.MouseEnter:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                BackgroundTransparency = 0.15, BackgroundColor3 = T.AccentA
            }):Play()
        end)
        b.MouseLeave:Connect(function()
            TweenService:Create(b, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
                BackgroundTransparency = 0.38, BackgroundColor3 = T.Glass
            }):Play()
        end)
        Pool[idx] = {b = b, sk = sk, word = ""}
        b.MouseButton1Click:Connect(function()
            if Pool[idx].word ~= "" then typeWord(Pool[idx].word, b) end
        end)
    end
    local p = Pool[idx]; p.b.Visible = true; p.b.Interactable = true
    p.b.BackgroundColor3 = T.Glass; p.b.BackgroundTransparency = 0.38
    p.b.TextColor3 = T.TextPri; p.sk.Color = T.Border; p.sk.Transparency = 0.75
    return p
end
local function hideAllBtns()
    for _, p in ipairs(Pool) do p.b.Visible = false; p.word = "" end
end
getgenv()._hideAllBtns = hideAllBtns

-- ========================================================================
-- [15] GENERATION ENGINE
-- ========================================================================
local function genTurn(prefix)
    hideAllBtns()
    local mode = App.Config.Playstyle
    if not prefix or prefix == "" or App.DB.TotalWords == 0 then return end
    local lp = lower(prefix); local cands = {}; local seen = {}

    local function collectWords(pfx)
        for i = #pfx, 1, -1 do
            local sp = sub(pfx, 1, i)
            for _, di in ipairs(App.DB.PrefixMap[sp] or {}) do
                local w = App.DB.Dictionary[di]
                if w and not seen[w] and not App.State.UsedWords[w]
                   and not App.State.TriedThisTurn[w] and not App.State.PermanentBlacklist[w] then
                    seen[w] = true
                    if sub(w, 1, #pfx) == pfx then table.insert(cands, {word = w, score = scoreWord(w, mode)}) end
                end
            end
        end
    end

    collectWords(lp)
    if #cands == 0 then
        local savedSfx = App.Config.TargetSuffixes; App.Config.TargetSuffixes = {}
        collectWords(lp); App.Config.TargetSuffixes = savedSfx
    end
    if #cands == 0 and #lp > 1 then
        local sp1 = sub(lp, 1, 1)
        for _, di in ipairs(App.DB.PrefixMap[sp1] or {}) do
            local w = App.DB.Dictionary[di]
            if w and not seen[w] and not App.State.UsedWords[w]
               and not App.State.TriedThisTurn[w] and not App.State.PermanentBlacklist[w] then
                seen[w] = true
                if sub(w, 1, 1) == sp1 then table.insert(cands, {word = w, score = scoreWord(w, mode)}) end
            end
        end
    end

    table.sort(cands, function(a, b) return a.score > b.score end)
    local uiB = {}
    for i = 1, math.min(150, #cands) do
        local p = getBtn(i); p.word = cands[i].word
        p.b.Text = p.word:upper() .. " (" .. #p.word .. ")"
        uiB[i] = p.b; p.b.Size = UDim2.new(0.47, 0, 0, 0)
        TweenService:Create(p.b, TweenInfo.new(0.20 + (i * 0.006), Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            Size = UDim2.new(0.47, 0, 0, 24)
        }):Play()
    end
    if App.Config.AutoPlay and #cands > 0 and not App.State.BotExecuting then
        App.State.BotExecuting = true
        task.spawn(function()
            local sg = stage()
            local mn = sg == "early" and 200 or sg == "mid" and 140 or 90
            local mx = sg == "early" and 500 or sg == "mid" and 360 or 250
            task.wait(random(mn, mx) / 1000)
            for i = 1, math.min(100, #cands) do
                if not App.State.IsMyTurn or not App.Config.AutoPlay then break end
                local tw = cands[i].word; updateStatus(tw:upper(), T.AccentA)
                local ok = typeWord(tw, uiB[i])
                if ok then App.State.RoundCount = App.State.RoundCount + 1; break end
                if App.State.IsMyTurn and App.Config.AutoPlay then task.wait(0.1) end
            end
            App.State.BotExecuting = false
        end)
    end
end
getgenv()._genTurn = genTurn

-- ========================================================================
-- [16] EXPORTS
-- ========================================================================
getgenv()._saveProfiles = function()
    if getgenv()._saveProfilesFn then getgenv()._saveProfilesFn() end
end

print("[AutoType] UI.lua loaded! — Glass Dark Premium Edition")
