-- ============================================================
-- DrawObsidian - Obsidian-style UI built on Matcha Drawing API
-- Part 2.1: tighter spacing + smaller fonts
-- ============================================================

local Library = {}
Library.__index = Library

local Theme = {
    WindowBg     = "#0f0f12",
    SidebarBg    = "#0a0a0d",
    ContentBg    = "#0f0f12",
    TabIdle      = "#0a0a0d",
    TabHover     = "#16161a",
    TabActive    = "#16161a",
    Accent       = "#7c5cff",
    Border       = "#23232a",
    BorderLight  = "#33333c",
    GroupboxBg   = "#131318",
    TextPrimary  = "#ffffff",
    TextDim      = "#7a7a82",
    TextDisabled = "#4a4a52",
}

local Z = {
    Bg         = 10,
    Panel      = 20,
    Border     = 25,
    Tab        = 30,
    TabText    = 35,
    Groupbox   = 40,
    GroupboxBorder = 42,
    GroupboxText   = 45,
    Widget     = 50,
    WidgetText = 55,
    Popup      = 80,
    PopupText  = 85,
}

-- ============================================================
-- drawing helpers
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

-- ============================================================
-- Window
-- ============================================================
function Library.CreateWindow(opts)
    opts = opts or {}
    local self = setmetatable({}, Library)

    self.Title    = opts.Title or "Obsidian"
    self.Pos      = Vector2.new(opts.X or 120, opts.Y or 90)
    self.Size     = Vector2.new(opts.Width or 580, opts.Height or 420)
    self.SidebarW = opts.SidebarWidth or 140

    self.Tabs = {}
    self.ActiveTab = nil
    self.Visible = true
    self.ToggleKey = opts.ToggleKey or 0x2D

    self.Objects = {}
    self._dragging = false
    self._dragStart = nil
    self._startPos = nil
    self._lastMouse1 = false
    self._lastToggle = false

    -- main background
    self.Bg = rect(Z.Bg, Theme.WindowBg)
    self.Bg.Size = self.Size
    self.Bg.Corner = 4
    table.insert(self.Objects, { obj = self.Bg, off = Vector2.new(0, 0) })

    self.BgBorder = rect(Z.Border, Theme.Border, false)
    self.BgBorder.Size = self.Size
    self.BgBorder.Thickness = 1
    self.BgBorder.Corner = 4
    table.insert(self.Objects, { obj = self.BgBorder, off = Vector2.new(0, 0) })

    self.Sidebar = rect(Z.Panel, Theme.SidebarBg)
    self.Sidebar.Size = Vector2.new(self.SidebarW, self.Size.Y)
    self.Sidebar.Corner = 4
    table.insert(self.Objects, { obj = self.Sidebar, off = Vector2.new(0, 0) })

    self.SidebarDivider = rect(Z.Border, Theme.Border)
    self.SidebarDivider.Size = Vector2.new(1, self.Size.Y)
    table.insert(self.Objects, { obj = self.SidebarDivider, off = Vector2.new(self.SidebarW, 0) })

    -- header title (no fake logo, cleaner)
    self.TitleText = label(Z.TabText, Theme.TextPrimary, 16, self.Title, true)
    table.insert(self.Objects, { obj = self.TitleText, off = Vector2.new(14, 16) })

    self.Content = rect(Z.Panel, Theme.ContentBg)
    self.Content.Size = Vector2.new(self.Size.X - self.SidebarW - 1, self.Size.Y)
    table.insert(self.Objects, { obj = self.Content, off = Vector2.new(self.SidebarW + 1, 0) })

    self.Footer = label(Z.TabText, Theme.TextDim, 10, "version: drawobsidian")
    table.insert(self.Objects, { obj = self.Footer, off = Vector2.new(14, self.Size.Y - 16) })

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
        tab.Text.Position   = tab.BG.Position + Vector2.new(10, 6)
        tab.Accent.Position = tab.BG.Position
        for _, gb in ipairs(tab.Groupboxes) do
            self:_repositionGroupbox(gb)
        end
    end
end

function Library:_repositionGroupbox(gb)
    gb.BG.Position     = self.Pos + gb.Off
    gb.Border.Position = gb.BG.Position
    gb.Title.Position  = gb.BG.Position + Vector2.new(10, -7)
    gb.TitleBg.Position = gb.BG.Position + Vector2.new(8, -8)
end

-- ============================================================
-- Tabs
-- ============================================================
function Library:AddTab(name)
    local index = #self.Tabs + 1
    local yOff = 50 + (index - 1) * 30   -- tighter row stride

    local tab = {}
    tab.Name = name
    tab.Off = Vector2.new(8, yOff)
    tab.Groupboxes = {}
    tab.LeftCursor = 14
    tab.RightCursor = 14
    tab.Window = self

    tab.BG = rect(Z.Tab, Theme.TabIdle)
    tab.BG.Size = Vector2.new(self.SidebarW - 16, 26)
    tab.BG.Corner = 4

    tab.Border = rect(Z.Border, Theme.TabIdle, false)
    tab.Border.Size = tab.BG.Size
    tab.Border.Thickness = 1
    tab.Border.Corner = 4

    tab.Accent = rect(Z.TabText, Theme.Accent)
    tab.Accent.Size = Vector2.new(2, 26)
    tab.Accent.Corner = 1

    tab.Text = label(Z.TabText, Theme.TextDim, 13, name)

    function tab:AddLeftGroupbox(boxName)
        return self.Window:_createGroupbox(self, "left", boxName)
    end
    function tab:AddRightGroupbox(boxName)
        return self.Window:_createGroupbox(self, "right", boxName)
    end

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
    for _, t in ipairs(self.Tabs) do
        local show = (t == tab) and self.Visible
        for _, gb in ipairs(t.Groupboxes) do
            self:_setGroupboxVisible(gb, show)
        end
    end
end

-- ============================================================
-- Groupboxes
-- ============================================================
function Library:_createGroupbox(tab, side, name)
    local gb = {}
    gb.Name = name
    gb.Side = side
    gb.Tab = tab

    local contentW = self.Size.X - self.SidebarW - 1
    local gutter = 10
    local colW = (contentW - gutter * 3) / 2
    local xOff
    if side == "left" then
        xOff = self.SidebarW + 1 + gutter
    else
        xOff = self.SidebarW + 1 + gutter * 2 + colW
    end

    gb.Width = colW
    gb.Height = 50

    local cursor = (side == "left") and tab.LeftCursor or tab.RightCursor
    gb.Off = Vector2.new(xOff, cursor)

    gb.BG = rect(Z.Groupbox, Theme.GroupboxBg)
    gb.BG.Size = Vector2.new(gb.Width, gb.Height)
    gb.BG.Corner = 4

    gb.Border = rect(Z.GroupboxBorder, Theme.Border, false)
    gb.Border.Size = gb.BG.Size
    gb.Border.Thickness = 1
    gb.Border.Corner = 4

    gb.TitleBg = rect(Z.GroupboxBorder, Theme.WindowBg)
    gb.TitleBg.Size = Vector2.new(8 + #name * 6 + 8, 3)
    gb.TitleBg.Filled = true

    gb.Title = label(Z.GroupboxText, Theme.TextPrimary, 12, name, true)

    gb.InnerCursor = 14
    gb.Widgets = {}

    local newCursor = cursor + gb.Height + 10
    if side == "left" then
        tab.LeftCursor = newCursor
    else
        tab.RightCursor = newCursor
    end

    table.insert(tab.Groupboxes, gb)
    self:_repositionGroupbox(gb)
    self:_setGroupboxVisible(gb, tab == self.ActiveTab and self.Visible)
    return gb
end

function Library:_setGroupboxVisible(gb, state)
    gb.BG.Visible = state
    gb.Border.Visible = state
    gb.Title.Visible = state
    gb.TitleBg.Visible = state
end

function Library:_growGroupbox(gb, addedHeight)
    gb.Height = gb.Height + addedHeight
    gb.BG.Size = Vector2.new(gb.Width, gb.Height)
    gb.Border.Size = gb.BG.Size
    local tab = gb.Tab
    if gb.Side == "left" then
        tab.LeftCursor = tab.LeftCursor + addedHeight
    else
        tab.RightCursor = tab.RightCursor + addedHeight
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
        for _, gb in ipairs(tab.Groupboxes) do
            local show = state and (tab == self.ActiveTab)
            self:_setGroupboxVisible(gb, show)
        end
    end
end

-- ============================================================
-- input + render
-- ============================================================
function Library:Update(Mouse)
    local tDown = iskeypressed(self.ToggleKey)
    if tDown and not self._lastToggle then
        self:SetVisible(not self.Visible)
    end
    self._lastToggle = tDown

    if not self.Visible then
        self._lastMouse1 = ismouse1pressed()
        return
    end

    local mPos = Vector2.new(Mouse.X, Mouse.Y)
    local mouse1 = ismouse1pressed()
    local clicked = mouse1 and not self._lastMouse1

    if clicked then
        local hitTab = false
        for _, tab in ipairs(self.Tabs) do
            if pointIn(mPos, tab.BG.Position, tab.BG.Size) then
                self:SetActiveTab(tab)
                hitTab = true
                break
            end
        end
        if not hitTab and pointIn(mPos, self.Pos, self.Size) then
            self._dragging = true
            self._dragStart = mPos
            self._startPos = self.Pos
        end
    end

    if not mouse1 then self._dragging = false end

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

return Library
