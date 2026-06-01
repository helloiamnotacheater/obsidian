-- ============================================================
-- DrawObsidian - Obsidian-style UI built on Matcha Drawing API
-- Part 1: window shell, sidebar, tab switching
-- ============================================================

local Library = {}
Library.__index = Library

-- palette, matches the obsidian dark look
local Theme = {
    WindowBg     = "#101012",
    SidebarBg    = "#0c0c0e",
    TopBarBg     = "#161618",
    ContentBg    = "#101012",
    TabIdle      = "#0c0c0e",
    TabHover     = "#1a1a1d",
    TabActive    = "#161618",
    Accent       = "#7c5cff",
    Border       = "#2a2a2e",
    BorderLight  = "#3a3a40",
    TextPrimary  = "#ffffff",
    TextDim      = "#8a8a92",
    TextDisabled = "#55555c",
}

local Z = {
    Bg      = 10,
    Panel   = 20,
    Border  = 25,
    Tab     = 30,
    TabText = 35,
    Widget  = 40,
    WidgetText = 45,
    Popup   = 80,
    PopupText = 85,
}

-- ============================================================
-- small drawing helpers
-- ============================================================
local function rect(z, hex, filled)
    local d = Drawing.new("Square")
    d.Visible = false
    d.Transparency = 1
    d.ZIndex = z
    d.Color = Color3.fromHex(hex)
    d.Filled = filled ~= false
    return d
end

local function label(z, hex, size, text, bold)
    local d = Drawing.new("Text")
    d.Visible = false
    d.Transparency = 1
    d.ZIndex = z
    d.Color = Color3.fromHex(hex)
    d.Size = size
    d.Text = text or ""
    d.Outline = true
    d.Font = bold and Drawing.Fonts.SystemBold or Drawing.Fonts.UI
    return d
end

local function pointIn(pos, rPos, rSize)
    return pos.X >= rPos.X and pos.X <= rPos.X + rSize.X
       and pos.Y >= rPos.Y and pos.Y <= rPos.Y + rSize.Y
end

-- mouse position helper, cache GetMouse once then reuse
local _cachedMouse = nil
local function getMousePos()
    if getmouseposition then
        local p = getmouseposition()
        if p then return Vector2.new(p.X or p[1] or 0, p.Y or p[2] or 0) end
    end
    if not _cachedMouse then
        local lp = game:GetService("Players").LocalPlayer
        if lp then _cachedMouse = lp:GetMouse() end
    end
    if _cachedMouse and _cachedMouse.X then
        return Vector2.new(_cachedMouse.X, _cachedMouse.Y)
    end
    return Vector2.new(0, 0)
end

-- ============================================================
-- Window
-- ============================================================
function Library.CreateWindow(opts)
    opts = opts or {}
    local self = setmetatable({}, Library)

    self.Title    = opts.Title or "Obsidian"
    self.Pos      = Vector2.new(opts.X or 120, opts.Y or 90)
    self.Size     = Vector2.new(opts.Width or 720, opts.Height or 540)
    self.SidebarW = opts.SidebarWidth or 170
    self.TopBarH  = 0

    self.Tabs = {}
    self.ActiveTab = nil
    self.Visible = true
    self.ToggleKey = opts.ToggleKey or 0x2D
    self.Debug = opts.Debug or false

    self.Objects = {}
    self._dragging = false
    self._dragStart = nil
    self._startPos = nil
    self._lastMouse1 = false
    self._lastToggle = false

    self.Bg = rect(Z.Bg, Theme.WindowBg)
    self.Bg.Size = self.Size
    self.Bg.Corner = 6
    table.insert(self.Objects, { obj = self.Bg, off = Vector2.new(0, 0) })

    self.BgBorder = rect(Z.Border, Theme.Border, false)
    self.BgBorder.Size = self.Size
    self.BgBorder.Thickness = 1
    self.BgBorder.Corner = 6
    table.insert(self.Objects, { obj = self.BgBorder, off = Vector2.new(0, 0) })

    self.Sidebar = rect(Z.Panel, Theme.SidebarBg)
    self.Sidebar.Size = Vector2.new(self.SidebarW, self.Size.Y)
    self.Sidebar.Corner = 6
    table.insert(self.Objects, { obj = self.Sidebar, off = Vector2.new(0, 0) })

    self.SidebarDivider = rect(Z.Border, Theme.Border)
    self.SidebarDivider.Size = Vector2.new(1, self.Size.Y)
    table.insert(self.Objects, { obj = self.SidebarDivider, off = Vector2.new(self.SidebarW, 0) })

    self.TitleText = label(Z.TabText, Theme.TextPrimary, 20, self.Title, true)
    table.insert(self.Objects, { obj = self.TitleText, off = Vector2.new(48, 22) })

    self.Logo = rect(Z.Tab, Theme.Accent)
    self.Logo.Size = Vector2.new(22, 22)
    self.Logo.Corner = 5
    table.insert(self.Objects, { obj = self.Logo, off = Vector2.new(18, 21) })

    self.Content = rect(Z.Panel, Theme.ContentBg)
    self.Content.Size = Vector2.new(self.Size.X - self.SidebarW - 1, self.Size.Y)
    table.insert(self.Objects, { obj = self.Content, off = Vector2.new(self.SidebarW + 1, 0) })

    self.Footer = label(Z.TabText, Theme.TextDim, 11, "version: drawobsidian")
    table.insert(self.Objects, { obj = self.Footer, off = Vector2.new(18, self.Size.Y - 22) })

    self:_applyPositions()
    return self
end

function Library:_applyPositions()
    for _, entry in ipairs(self.Objects) do
        entry.obj.Position = self.Pos + entry.off
    end
    for _, tab in ipairs(self.Tabs) do
        tab.BG.Position     = self.Pos + tab.Off
        tab.Border.Position = tab.BG.Position
        tab.Text.Position   = tab.BG.Position + Vector2.new(14, 8)
        tab.Accent.Position = tab.BG.Position
    end
end

-- ============================================================
-- Tabs
-- ============================================================
function Library:AddTab(name)
    local index = #self.Tabs + 1
    local yOff = 64 + (index - 1) * 38

    local tab = {}
    tab.Name = name
    tab.Off = Vector2.new(10, yOff)
    tab.Groupboxes = {}

    tab.BG = rect(Z.Tab, Theme.TabIdle)
    tab.BG.Size = Vector2.new(self.SidebarW - 20, 32)
    tab.BG.Corner = 5

    tab.Border = rect(Z.Border, Theme.TabIdle, false)
    tab.Border.Size = tab.BG.Size
    tab.Border.Thickness = 1
    tab.Border.Corner = 5

    tab.Accent = rect(Z.TabText, Theme.Accent)
    tab.Accent.Size = Vector2.new(3, 32)
    tab.Accent.Corner = 2

    tab.Text = label(Z.TabText, Theme.TextDim, 15, name)

    table.insert(self.Tabs, tab)

    if not self.ActiveTab then
        self:SetActiveTab(tab)
    end

    self:_applyPositions()
    return tab
end

function Library:SetActiveTab(tab)
    self.ActiveTab = tab
    for _, t in ipairs(self.Tabs) do
        local active = (t == tab)
        t.BG.Color = Color3.fromHex(active and Theme.TabActive or Theme.TabIdle)
        t.Border.Color = Color3.fromHex(active and Theme.BorderLight or Theme.TabIdle)
        t.Text.Color = Color3.fromHex(active and Theme.TextPrimary or Theme.TextDim)
        t.Accent.Visible = active and self.Visible
    end
end

-- ============================================================
-- visibility
-- ============================================================
function Library:SetVisible(state)
    self.Visible = state
    for _, entry in ipairs(self.Objects) do
        entry.obj.Visible = state
    end
    for _, tab in ipairs(self.Tabs) do
        tab.BG.Visible = state
        tab.Border.Visible = state
        tab.Text.Visible = state
        tab.Accent.Visible = state and (tab == self.ActiveTab)
    end
end

-- ============================================================
-- input + render
-- ============================================================
function Library:Update()
    local tDown = iskeypressed(self.ToggleKey)
    if tDown and not self._lastToggle then
        self:SetVisible(not self.Visible)
    end
    self._lastToggle = tDown

    if not self.Visible then
        self._lastMouse1 = ismouse1pressed()
        return
    end

    local mPos = getMousePos()
    local mouse1 = ismouse1pressed()
    local clicked = mouse1 and not self._lastMouse1

    if clicked then
        if self.Debug then
            print("[drag] click at", mPos.X, mPos.Y,
                  "| window at", self.Pos.X, self.Pos.Y,
                  "| size", self.Size.X, self.Size.Y)
        end

        local hitTab = false
        for _, tab in ipairs(self.Tabs) do
            if pointIn(mPos, tab.BG.Position, tab.BG.Size) then
                self:SetActiveTab(tab)
                hitTab = true
                break
            end
        end

        -- TEMP: whole window draggable to confirm drag works at all
        if not hitTab then
            if pointIn(mPos, self.Pos, self.Size) then
                self._dragging = true
                self._dragStart = mPos
                self._startPos = self.Pos
                if self.Debug then print("[drag] grabbed") end
            end
        end
    end

    if not mouse1 then
        self._dragging = false
    end

    if self._dragging and mouse1 then
        local delta = mPos - self._dragStart
        self.Pos = self._startPos + delta
        self:_applyPositions()
    end

    self._lastMouse1 = mouse1
end

-- ============================================================
-- exports
-- ============================================================
Library.Theme = Theme
Library.Z = Z
Library._rect = rect
Library._label = label
Library._pointIn = pointIn
Library._getMousePos = getMousePos

return Library
