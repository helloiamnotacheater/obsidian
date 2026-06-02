-- ============================================================
-- DrawObsidian - Matcha Drawing-based Obsidian-style UI
-- Larger default sizing pass
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
    InputBg      = "#0d0d11",
    InputBorder  = "#2a2a32",
    PopupBg      = "#131318",
    HoverBg      = "#1a1a20",
    TextPrimary  = "#ffffff",
    TextDim      = "#7a7a82",
    TextDisabled = "#4a4a52",
    CheckOn      = "#7c5cff",
    ButtonBg     = "#1a1a20",
    SliderFill   = "#7c5cff",
}

local Z = {
    Bg = 10, Panel = 20, Border = 25, Tab = 30, TabText = 35,
    Groupbox = 40, GroupboxBorder = 42, GroupboxText = 45,
    Widget = 50, WidgetBorder = 52, WidgetText = 55, WidgetOver = 58,
    Popup = 80, PopupBorder = 82, PopupText = 85, PopupOver = 88,
}

local function rect(z, hex, filled)
    local d = Drawing.new("Square")
    d.Visible = false; d.Transparency = 1; d.ZIndex = z
    d.Color = Color3.fromHex(hex)
    d.Filled = filled ~= false
    return d
end

local function label(z, hex, size, text, bold)
    local d = Drawing.new("Text")
    d.Visible = false; d.Transparency = 1; d.ZIndex = z
    d.Color = Color3.fromHex(hex)
    d.Size = size; d.Text = text or ""; d.Outline = true
    d.Font = bold and Drawing.Fonts.SystemBold or Drawing.Fonts.UI
    return d
end

local function pointIn(pos, rPos, rSize)
    return pos.X >= rPos.X and pos.X <= rPos.X + rSize.X
       and pos.Y >= rPos.Y and pos.Y <= rPos.Y + rSize.Y
end

local function listTeamNames()
    local out = {}
    local ok, teams = pcall(function() return game:GetService("Teams") end)
    if not ok or not teams then return out end
    local ok2, list = pcall(function() return teams:GetTeams() end)
    if ok2 and type(list) == "table" then
        for _, t in ipairs(list) do table.insert(out, t.Name) end
    else
        for _, c in ipairs(teams:GetChildren()) do
            if c.ClassName == "Team" or (c.IsA and c:IsA("Team")) then
                table.insert(out, c.Name)
            end
        end
    end
    table.sort(out)
    return out
end

local function clamp01(x) if x < 0 then return 0 elseif x > 1 then return 1 else return x end end

local function hsvToRgb(h, s, v)
    if s == 0 then return v, v, v end
    h = (h % 1) * 6
    local i = math.floor(h)
    local f = h - i
    local p = v * (1 - s)
    local q = v * (1 - s * f)
    local t = v * (1 - s * (1 - f))
    if     i == 0 then return v, t, p
    elseif i == 1 then return q, v, p
    elseif i == 2 then return p, v, t
    elseif i == 3 then return p, q, v
    elseif i == 4 then return t, p, v
    else                return v, p, q end
end

local function rgbToHsv(r, g, b)
    local mx = math.max(r, g, b)
    local mn = math.min(r, g, b)
    local d = mx - mn
    local h, s, v = 0, (mx == 0) and 0 or d / mx, mx
    if d ~= 0 then
        if mx == r then h = ((g - b) / d) % 6
        elseif mx == g then h = (b - r) / d + 2
        else h = (r - g) / d + 4 end
        h = h / 6
    end
    return h, s, v
end

local KeyNames = {
    [48]="0",[49]="1",[50]="2",[51]="3",[52]="4",[53]="5",[54]="6",[55]="7",[56]="8",[57]="9",
    [8]="Backspace",[13]="Enter",[16]="Shift",[27]="Esc",[32]="Space",[38]="Up",[40]="Down",
    [65]="A",[66]="B",[67]="C",[68]="D",[69]="E",[70]="F",[71]="G",[72]="H",[73]="I",[74]="J",
    [75]="K",[76]="L",[77]="M",[78]="N",[79]="O",[80]="P",[81]="Q",[82]="R",[83]="S",[84]="T",
    [85]="U",[86]="V",[87]="W",[88]="X",[89]="Y",[90]="Z",
    [112]="F1",[113]="F2",[114]="F3",[115]="F4",[116]="F5",[117]="F6",[118]="F7",[119]="F8",
    [120]="F9",[121]="F10",[122]="F11",[123]="F12",
    [189]="-",
}

local function keyCodeName(kc)
    if KeyNames[kc] then return KeyNames[kc] end
    return "VK" .. tostring(kc)
end

-- ============================================================
-- Window
-- ============================================================
function Library.CreateWindow(opts)
    opts = opts or {}
    local self = setmetatable({}, Library)

    self.Title    = opts.Title or "Obsidian"
    self.Pos      = Vector2.new(opts.X or 100, opts.Y or 70)
    self.Size     = Vector2.new(opts.Width or 720, opts.Height or 560)
    self.SidebarW = opts.SidebarWidth or 160

    self.Tabs = {}
    self.ActiveTab = nil
    self.Visible = true
    self.ToggleKey = opts.ToggleKey or 0x70

    self.Objects = {}
    self._dragging = false
    self._dragStart = nil
    self._startPos = nil
    self._lastMouse1 = false
    self._lastToggle = false
    self._openPopup = nil
    self._focusedText = nil
    self._capturingKeybind = nil
    self._activeSlider = nil
    self._keyState = {}
    self._keyRepeat = {}

    self.Bg = rect(Z.Bg, Theme.WindowBg); self.Bg.Size = self.Size; self.Bg.Corner = 5
    table.insert(self.Objects, { obj = self.Bg, off = Vector2.new(0, 0) })

    self.BgBorder = rect(Z.Border, Theme.Border, false)
    self.BgBorder.Size = self.Size; self.BgBorder.Thickness = 1; self.BgBorder.Corner = 5
    table.insert(self.Objects, { obj = self.BgBorder, off = Vector2.new(0, 0) })

    self.Sidebar = rect(Z.Panel, Theme.SidebarBg)
    self.Sidebar.Size = Vector2.new(self.SidebarW, self.Size.Y); self.Sidebar.Corner = 5
    table.insert(self.Objects, { obj = self.Sidebar, off = Vector2.new(0, 0) })

    self.SidebarDivider = rect(Z.Border, Theme.Border)
    self.SidebarDivider.Size = Vector2.new(1, self.Size.Y)
    table.insert(self.Objects, { obj = self.SidebarDivider, off = Vector2.new(self.SidebarW, 0) })

    self.TitleText = label(Z.TabText, Theme.TextPrimary, 18, self.Title, true)
    table.insert(self.Objects, { obj = self.TitleText, off = Vector2.new(16, 18) })

    self.Content = rect(Z.Panel, Theme.ContentBg)
    self.Content.Size = Vector2.new(self.Size.X - self.SidebarW - 1, self.Size.Y)
    table.insert(self.Objects, { obj = self.Content, off = Vector2.new(self.SidebarW + 1, 0) })

    self.Footer = label(Z.TabText, Theme.TextDim, 11, "version: drawobsidian")
    table.insert(self.Objects, { obj = self.Footer, off = Vector2.new(16, self.Size.Y - 20) })

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
        tab.Text.Position   = tab.BG.Position + Vector2.new(12, 7)
        tab.Accent.Position = tab.BG.Position
        for _, gb in ipairs(tab.Groupboxes) do
            self:_repositionGroupbox(gb)
            for _, w in ipairs(gb.Widgets) do
                if w._reposition then w:_reposition() end
            end
        end
    end
end

function Library:_repositionGroupbox(gb)
    gb.BG.Position      = self.Pos + gb.Off
    gb.Border.Position  = gb.BG.Position
    gb.Title.Position   = gb.BG.Position + Vector2.new(12, -8)
    gb.TitleBg.Position = gb.BG.Position + Vector2.new(10, -9)
end

-- ============================================================
-- Tabs
-- ============================================================
function Library:AddTab(name)
    local index = #self.Tabs + 1
    local yOff = 56 + (index - 1) * 34

    local tab = {}
    tab.Name = name
    tab.Off = Vector2.new(10, yOff)
    tab.Groupboxes = {}
    tab.LeftCursor = 18
    tab.RightCursor = 18
    tab.Window = self

    tab.BG = rect(Z.Tab, Theme.TabIdle)
    tab.BG.Size = Vector2.new(self.SidebarW - 20, 30); tab.BG.Corner = 4

    tab.Border = rect(Z.Border, Theme.TabIdle, false)
    tab.Border.Size = tab.BG.Size; tab.Border.Thickness = 1; tab.Border.Corner = 4

    tab.Accent = rect(Z.TabText, Theme.Accent)
    tab.Accent.Size = Vector2.new(3, 30); tab.Accent.Corner = 1

    tab.Text = label(Z.TabText, Theme.TextDim, 14, name)

    function tab:AddLeftGroupbox(boxName)  return self.Window:_createGroupbox(self, "left",  boxName) end
    function tab:AddRightGroupbox(boxName) return self.Window:_createGroupbox(self, "right", boxName) end

    table.insert(self.Tabs, tab)
    if not self.ActiveTab then self:SetActiveTab(tab) end
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
    if self._openPopup then self._openPopup:_close() end
    self._focusedText = nil
    self._capturingKeybind = nil
    for _, t in ipairs(self.Tabs) do
        local show = (t == tab) and self.Visible
        for _, gb in ipairs(t.Groupboxes) do
            self:_setGroupboxVisible(gb, show)
            for _, w in ipairs(gb.Widgets) do
                if w._setVisible then w:_setVisible(show) end
            end
        end
    end
end

-- ============================================================
-- Groupboxes
-- ============================================================
function Library:_createGroupbox(tab, side, name)
    local gb = {}
    gb.Name = name; gb.Side = side; gb.Tab = tab

    local contentW = self.Size.X - self.SidebarW - 1
    local gutter = 12
    local colW = (contentW - gutter * 3) / 2
    local xOff = (side == "left") and (self.SidebarW + 1 + gutter)
                                   or  (self.SidebarW + 1 + gutter * 2 + colW)

    gb.Width = colW
    gb.Height = 16
    gb.InnerCursor = 16
    gb.Widgets = {}

    local cursor = (side == "left") and tab.LeftCursor or tab.RightCursor
    gb.Off = Vector2.new(xOff, cursor)

    gb.BG = rect(Z.Groupbox, Theme.GroupboxBg)
    gb.BG.Size = Vector2.new(gb.Width, gb.Height); gb.BG.Corner = 4

    gb.Border = rect(Z.GroupboxBorder, Theme.Border, false)
    gb.Border.Size = gb.BG.Size; gb.Border.Thickness = 1; gb.Border.Corner = 4

    gb.TitleBg = rect(Z.GroupboxBorder, Theme.WindowBg)
    gb.TitleBg.Size = Vector2.new(10 + #name * 7 + 10, 4); gb.TitleBg.Filled = true

    gb.Title = label(Z.GroupboxText, Theme.TextPrimary, 13, name, true)

    gb.Window = self
    function gb:AddDropdown(opts)       return self.Window:_addDropdown(self, "single", opts) end
    function gb:AddSearchDropdown(opts) return self.Window:_addDropdown(self, "search", opts) end
    function gb:AddMultiDropdown(opts)  return self.Window:_addDropdown(self, "multi",  opts) end
    function gb:AddPlayerDropdown(opts) return self.Window:_addDropdown(self, "player", opts) end
    function gb:AddTeamDropdown(opts)   return self.Window:_addDropdown(self, "team",   opts) end
    function gb:AddButton(opts)         return self.Window:_addButton(self, opts) end
    function gb:AddToggle(opts)         return self.Window:_addToggle(self, opts) end
    function gb:AddCheckbox(opts)       return self.Window:_addCheckbox(self, opts) end
    function gb:AddLabel(opts)          return self.Window:_addLabel(self, opts) end
    function gb:AddSlider(opts)         return self.Window:_addSlider(self, opts) end
    function gb:AddTextbox(opts)        return self.Window:_addTextbox(self, opts) end
    function gb:AddColor(opts)          return self.Window:_addColor(self, opts) end
    function gb:AddKeybind(opts)        return self.Window:_addKeybind(self, opts) end

    if side == "left" then tab.LeftCursor = cursor + gb.Height + 14
    else tab.RightCursor = cursor + gb.Height + 14 end

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
    if gb.Side == "left" then tab.LeftCursor = tab.LeftCursor + addedHeight
    else tab.RightCursor = tab.RightCursor + addedHeight end
end

-- ============================================================
-- BUTTON
-- ============================================================
function Library:_addButton(gb, opts)
    opts = opts or {}
    local widgetH = 28
    local yIn = gb.InnerCursor

    local b = {
        Gb = gb, Window = self,
        Text = opts.Text or "Button",
        Disabled = opts.Disabled or false,
        Callback = opts.Callback or function() end,
        _yIn = yIn, _height = widgetH,
    }

    b.BG = rect(Z.Widget, Theme.ButtonBg); b.BG.Corner = 3
    b.Border = rect(Z.WidgetBorder, Theme.InputBorder, false)
    b.Border.Thickness = 1; b.Border.Corner = 3
    b.TextDraw = label(Z.WidgetText, Theme.TextPrimary, 13, b.Text)
    b.TextDraw.Center = true

    function b:_reposition()
        local gx = self.Gb.BG.Position.X
        local gy = self.Gb.BG.Position.Y + self._yIn
        local w = self.Gb.Width - 24
        self.BG.Position = Vector2.new(gx + 12, gy)
        self.BG.Size = Vector2.new(w, 24)
        self.Border.Position = self.BG.Position
        self.Border.Size = self.BG.Size
        self.TextDraw.Position = self.BG.Position + Vector2.new(w / 2, 5)
    end

    function b:_setVisible(state)
        self.BG.Visible = state
        self.Border.Visible = state
        self.TextDraw.Visible = state
        self.TextDraw.Color = Color3.fromHex(self.Disabled and Theme.TextDisabled or Theme.TextPrimary)
    end

    function b:_handleClick(mPos)
        if self.Disabled then return false end
        if pointIn(mPos, self.BG.Position, self.BG.Size) then
            self.Callback()
            return true
        end
        return false
    end

    function b:SetText(txt) self.Text = txt; self.TextDraw.Text = txt end
    function b:SetDisabled(d) self.Disabled = d; self:_setVisible(self.BG.Visible) end

    table.insert(gb.Widgets, b)
    self:_growGroupbox(gb, widgetH)
    gb.InnerCursor = gb.InnerCursor + widgetH
    b:_reposition()
    b:_setVisible(gb.Tab == self.ActiveTab and self.Visible)
    return b
end

-- ============================================================
-- TOGGLE
-- ============================================================
function Library:_addToggle(gb, opts)
    opts = opts or {}
    local widgetH = 26
    local yIn = gb.InnerCursor

    local t = {
        Gb = gb, Window = self,
        Text = opts.Text or "Toggle",
        Value = opts.Default == true,
        Disabled = opts.Disabled or false,
        Callback = opts.Callback or function() end,
        _yIn = yIn, _height = widgetH,
    }

    t.TextDraw = label(Z.WidgetText, Theme.TextPrimary, 13, t.Text)
    t.Track = rect(Z.Widget, Theme.InputBg); t.Track.Corner = 7
    t.TrackBorder = rect(Z.WidgetBorder, Theme.InputBorder, false)
    t.TrackBorder.Thickness = 1; t.TrackBorder.Corner = 7
    t.Knob = rect(Z.WidgetText, Theme.TextPrimary); t.Knob.Corner = 6

    function t:_reposition()
        local gx = self.Gb.BG.Position.X
        local gy = self.Gb.BG.Position.Y + self._yIn
        self.TextDraw.Position = Vector2.new(gx + 12, gy + 3)
        local trackW = 30
        self.Track.Size = Vector2.new(trackW, 14)
        self.Track.Position = Vector2.new(gx + self.Gb.Width - 12 - trackW, gy + 3)
        self.TrackBorder.Position = self.Track.Position
        self.TrackBorder.Size = self.Track.Size
        self.Knob.Size = Vector2.new(10, 10)
        local knobX = self.Value and (self.Track.Position.X + trackW - 12) or (self.Track.Position.X + 2)
        self.Knob.Position = Vector2.new(knobX, self.Track.Position.Y + 2)
    end

    function t:_setVisible(state)
        self.TextDraw.Visible = state
        self.Track.Visible = state
        self.TrackBorder.Visible = state
        self.Knob.Visible = state
        self.TextDraw.Color = Color3.fromHex(self.Disabled and Theme.TextDisabled or Theme.TextPrimary)
        self.Track.Color = Color3.fromHex(self.Value and Theme.Accent or Theme.InputBg)
    end

    function t:_handleClick(mPos)
        if self.Disabled then return false end
        local hitArea = Vector2.new(self.Gb.Width - 24, 22)
        local hitPos = Vector2.new(self.Gb.BG.Position.X + 12, self.Gb.BG.Position.Y + self._yIn)
        if pointIn(mPos, hitPos, hitArea) then
            self.Value = not self.Value
            self:_reposition()
            self:_setVisible(true)
            self.Callback(self.Value)
            return true
        end
        return false
    end

    function t:SetValue(v) self.Value = v and true or false; self:_reposition(); self:_setVisible(true) end
    function t:GetValue() return self.Value end

    table.insert(gb.Widgets, t)
    self:_growGroupbox(gb, widgetH)
    gb.InnerCursor = gb.InnerCursor + widgetH
    t:_reposition()
    t:_setVisible(gb.Tab == self.ActiveTab and self.Visible)
    return t
end

-- ============================================================
-- CHECKBOX
-- ============================================================
function Library:_addCheckbox(gb, opts)
    opts = opts or {}
    local widgetH = 26
    local yIn = gb.InnerCursor

    local c = {
        Gb = gb, Window = self,
        Text = opts.Text or "Checkbox",
        Value = opts.Default == true,
        Disabled = opts.Disabled or false,
        Callback = opts.Callback or function() end,
        _yIn = yIn, _height = widgetH,
    }

    c.Box = rect(Z.Widget, Theme.InputBg); c.Box.Corner = 2
    c.BoxBorder = rect(Z.WidgetBorder, Theme.InputBorder, false)
    c.BoxBorder.Thickness = 1; c.BoxBorder.Corner = 2
    c.Check = rect(Z.WidgetText, Theme.Accent); c.Check.Corner = 1
    c.TextDraw = label(Z.WidgetText, Theme.TextPrimary, 13, c.Text)

    function c:_reposition()
        local gx = self.Gb.BG.Position.X
        local gy = self.Gb.BG.Position.Y + self._yIn
        self.Box.Size = Vector2.new(14, 14)
        self.Box.Position = Vector2.new(gx + 12, gy + 4)
        self.BoxBorder.Position = self.Box.Position
        self.BoxBorder.Size = self.Box.Size
        self.Check.Size = Vector2.new(10, 10)
        self.Check.Position = self.Box.Position + Vector2.new(2, 2)
        self.TextDraw.Position = self.Box.Position + Vector2.new(20, 0)
    end

    function c:_setVisible(state)
        self.Box.Visible = state
        self.BoxBorder.Visible = state
        self.Check.Visible = state and self.Value
        self.TextDraw.Visible = state
        self.TextDraw.Color = Color3.fromHex(self.Disabled and Theme.TextDisabled or Theme.TextPrimary)
    end

    function c:_handleClick(mPos)
        if self.Disabled then return false end
        local hitArea = Vector2.new(self.Gb.Width - 24, 22)
        local hitPos = Vector2.new(self.Gb.BG.Position.X + 12, self.Gb.BG.Position.Y + self._yIn)
        if pointIn(mPos, hitPos, hitArea) then
            self.Value = not self.Value
            self:_setVisible(true)
            self.Callback(self.Value)
            return true
        end
        return false
    end

    function c:SetValue(v) self.Value = v and true or false; self:_setVisible(true) end
    function c:GetValue() return self.Value end

    table.insert(gb.Widgets, c)
    self:_growGroupbox(gb, widgetH)
    gb.InnerCursor = gb.InnerCursor + widgetH
    c:_reposition()
    c:_setVisible(gb.Tab == self.ActiveTab and self.Visible)
    return c
end

-- ============================================================
-- LABEL
-- ============================================================
function Library:_addLabel(gb, opts)
    opts = opts or {}
    local text = opts.Text or "Label"
    local wrap = opts.Wrap == true
    local yIn = gb.InnerCursor

    local lines = {}
    if wrap then
        local charsPerLine = math.max(10, math.floor((gb.Width - 24) / 8))
        local cur = ""
        for word in text:gmatch("%S+") do
            local cand = (cur == "") and word or (cur .. " " .. word)
            if #cand > charsPerLine then
                table.insert(lines, cur)
                cur = word
            else
                cur = cand
            end
        end
        if cur ~= "" then table.insert(lines, cur) end
    else
        lines = { text }
    end
    local widgetH = #lines * 16 + 4

    local lab = { Gb = gb, Window = self, Lines = {}, _yIn = yIn, _height = widgetH, Text = text }
    for _, line in ipairs(lines) do
        local l = label(Z.WidgetText, Theme.TextPrimary, 13, line)
        table.insert(lab.Lines, l)
    end

    function lab:_reposition()
        local gx = self.Gb.BG.Position.X
        local gy = self.Gb.BG.Position.Y + self._yIn
        for i, l in ipairs(self.Lines) do
            l.Position = Vector2.new(gx + 12, gy + (i - 1) * 16)
        end
    end

    function lab:_setVisible(state)
        for _, l in ipairs(self.Lines) do l.Visible = state end
    end

    function lab:_handleClick() return false end

    function lab:SetText(newText)
        for _, l in ipairs(self.Lines) do l.Text = "" end
        self.Lines[1].Text = newText
        self.Text = newText
    end

    table.insert(gb.Widgets, lab)
    self:_growGroupbox(gb, widgetH)
    gb.InnerCursor = gb.InnerCursor + widgetH
    lab:_reposition()
    lab:_setVisible(gb.Tab == self.ActiveTab and self.Visible)
    return lab
end

-- ============================================================
-- SLIDER
-- ============================================================
function Library:_addSlider(gb, opts)
    opts = opts or {}
    local widgetH = 42
    local yIn = gb.InnerCursor

    local s = {
        Gb = gb, Window = self,
        Text = opts.Text or "Slider",
        Min = opts.Min or 0,
        Max = opts.Max or 100,
        Value = opts.Default or opts.Min or 0,
        Step = opts.Step or 1,
        Format = opts.Format or "%d / %d",
        Callback = opts.Callback or function() end,
        _yIn = yIn, _height = widgetH,
    }

    s.Label = label(Z.WidgetText, Theme.TextDim, 12, s.Text)
    s.Track = rect(Z.Widget, Theme.InputBg); s.Track.Corner = 2
    s.TrackBorder = rect(Z.WidgetBorder, Theme.InputBorder, false)
    s.TrackBorder.Thickness = 1; s.TrackBorder.Corner = 2
    s.Fill = rect(Z.WidgetText, Theme.SliderFill); s.Fill.Corner = 2
    s.ValueText = label(Z.WidgetOver, Theme.TextPrimary, 12, "")
    s.ValueText.Center = true

    function s:_format()
        local ok, str = pcall(string.format, self.Format, self.Value, self.Max)
        if ok then return str end
        return tostring(self.Value)
    end

    function s:_reposition()
        local gx = self.Gb.BG.Position.X
        local gy = self.Gb.BG.Position.Y + self._yIn
        local w = self.Gb.Width - 24
        self.Label.Position = Vector2.new(gx + 12, gy)
        self.Track.Size = Vector2.new(w, 18)
        self.Track.Position = Vector2.new(gx + 12, gy + 18)
        self.TrackBorder.Position = self.Track.Position
        self.TrackBorder.Size = self.Track.Size
        local pct = (self.Value - self.Min) / math.max(0.0001, (self.Max - self.Min))
        if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
        self.Fill.Position = self.Track.Position
        self.Fill.Size = Vector2.new(math.max(2, w * pct), 18)
        self.ValueText.Position = self.Track.Position + Vector2.new(w / 2, 2)
        self.ValueText.Text = self:_format()
    end

    function s:_setVisible(state)
        self.Label.Visible = state
        self.Track.Visible = state
        self.TrackBorder.Visible = state
        self.Fill.Visible = state
        self.ValueText.Visible = state
    end

    function s:_setValueFromX(x)
        local w = self.Track.Size.X
        local rel = x - self.Track.Position.X
        local pct = rel / w
        if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end
        local raw = self.Min + (self.Max - self.Min) * pct
        if self.Step > 0 then
            raw = math.floor((raw - self.Min) / self.Step + 0.5) * self.Step + self.Min
        end
        if raw < self.Min then raw = self.Min elseif raw > self.Max then raw = self.Max end
        self.Value = raw
        self:_reposition()
        self.Callback(self.Value)
    end

    function s:_handleClick(mPos)
        if pointIn(mPos, self.Track.Position, self.Track.Size) then
            self.Window._activeSlider = self
            self:_setValueFromX(mPos.X)
            return true
        end
        return false
    end

    function s:SetValue(v) self.Value = v; self:_reposition() end
    function s:GetValue() return self.Value end

    table.insert(gb.Widgets, s)
    self:_growGroupbox(gb, widgetH)
    gb.InnerCursor = gb.InnerCursor + widgetH
    s:_reposition()
    s:_setVisible(gb.Tab == self.ActiveTab and self.Visible)
    return s
end

-- ============================================================
-- TEXTBOX
-- ============================================================
function Library:_addTextbox(gb, opts)
    opts = opts or {}
    local widgetH = 44
    local yIn = gb.InnerCursor

    local tb = {
        Gb = gb, Window = self,
        Text = opts.Text or "Textbox",
        Value = opts.Default or "",
        Placeholder = opts.Placeholder or "Type here...",
        MaxLength = opts.MaxLength or 60,
        Callback = opts.Callback or function() end,
        _yIn = yIn, _height = widgetH,
        _focused = false,
    }

    tb.Label = label(Z.WidgetText, Theme.TextDim, 12, tb.Text)
    tb.Field = rect(Z.Widget, Theme.InputBg); tb.Field.Corner = 3
    tb.FieldBorder = rect(Z.WidgetBorder, Theme.InputBorder, false)
    tb.FieldBorder.Thickness = 1; tb.FieldBorder.Corner = 3
    tb.FieldText = label(Z.WidgetText, Theme.TextPrimary, 13, "")

    function tb:_displayText()
        if self.Value == "" then return self.Placeholder, true end
        return self.Value, false
    end

    function tb:_reposition()
        local gx = self.Gb.BG.Position.X
        local gy = self.Gb.BG.Position.Y + self._yIn
        local w = self.Gb.Width - 24
        self.Label.Position = Vector2.new(gx + 12, gy)
        self.Field.Position = Vector2.new(gx + 12, gy + 16)
        self.Field.Size = Vector2.new(w, 24)
        self.FieldBorder.Position = self.Field.Position
        self.FieldBorder.Size = self.Field.Size
        self.FieldText.Position = self.Field.Position + Vector2.new(8, 5)
        local txt, isPlaceholder = self:_displayText()
        self.FieldText.Text = self._focused and (self.Value == "" and "|" or self.Value) or txt
        self.FieldText.Color = Color3.fromHex(isPlaceholder and not self._focused and Theme.TextDim or Theme.TextPrimary)
        self.FieldBorder.Color = Color3.fromHex(self._focused and Theme.Accent or Theme.InputBorder)
    end

    function tb:_setVisible(state)
        self.Label.Visible = state
        self.Field.Visible = state
        self.FieldBorder.Visible = state
        self.FieldText.Visible = state
        if not state then self._focused = false end
    end

    function tb:_handleClick(mPos)
        local hit = pointIn(mPos, self.Field.Position, self.Field.Size)
        if hit then
            self._focused = true
            self.Window._focusedText = self
            self:_reposition()
            return true
        else
            if self._focused then
                self._focused = false
                if self.Window._focusedText == self then self.Window._focusedText = nil end
                self.Callback(self.Value)
                self:_reposition()
            end
            return false
        end
    end

    function tb:_handleKey(keyCode, shift)
        if not self._focused then return end
        local changed = false
        if keyCode >= 48 and keyCode <= 57 and #self.Value < self.MaxLength then
            self.Value = self.Value .. tostring(keyCode - 48); changed = true
        elseif keyCode >= 65 and keyCode <= 90 and #self.Value < self.MaxLength then
            local c = string.char(keyCode); if not shift then c = c:lower() end
            self.Value = self.Value .. c; changed = true
        elseif keyCode == 32 and #self.Value < self.MaxLength then
            self.Value = self.Value .. " "; changed = true
        elseif keyCode == 189 and #self.Value < self.MaxLength then
            self.Value = self.Value .. "-"; changed = true
        elseif keyCode == 8 and #self.Value > 0 then
            self.Value = self.Value:sub(1, -2); changed = true
        elseif keyCode == 13 or keyCode == 27 then
            self._focused = false
            if self.Window._focusedText == self then self.Window._focusedText = nil end
            self.Callback(self.Value)
            changed = true
        end
        if changed then self:_reposition() end
    end

    function tb:SetValue(v) self.Value = tostring(v); self:_reposition() end
    function tb:GetValue() return self.Value end

    table.insert(gb.Widgets, tb)
    self:_growGroupbox(gb, widgetH)
    gb.InnerCursor = gb.InnerCursor + widgetH
    tb:_reposition()
    tb:_setVisible(gb.Tab == self.ActiveTab and self.Visible)
    return tb
end

-- ============================================================
-- COLOR PICKER
-- ============================================================
function Library:_addColor(gb, opts)
    opts = opts or {}
    local widgetH = 26
    local yIn = gb.InnerCursor

    local default = opts.Default or Color3.fromRGB(255, 255, 255)
    local h, s, v = rgbToHsv(default.R, default.G, default.B)

    local cp = {
        Gb = gb, Window = self,
        Text = opts.Text or "Color",
        Callback = opts.Callback or function() end,
        H = h, S = s, V = v,
        Open = false,
        _yIn = yIn, _height = widgetH,
    }

    cp.TextDraw = label(Z.WidgetText, Theme.TextPrimary, 13, cp.Text)
    cp.Swatch = rect(Z.Widget, "#ffffff")
    cp.SwatchBorder = rect(Z.WidgetBorder, Theme.InputBorder, false)
    cp.SwatchBorder.Thickness = 1

    cp.PopupBg = rect(Z.Popup, Theme.PopupBg); cp.PopupBg.Corner = 3
    cp.PopupBorder = rect(Z.PopupBorder, Theme.BorderLight, false)
    cp.PopupBorder.Thickness = 1; cp.PopupBorder.Corner = 3

    cp._svRows = {}
    for i = 1, 14 do
        local r = rect(Z.PopupText, "#ffffff")
        table.insert(cp._svRows, r)
    end
    cp._hueBars = {}
    for i = 1, 18 do
        local r = rect(Z.PopupText, "#ffffff")
        table.insert(cp._hueBars, r)
    end
    cp._svCursor = rect(Z.PopupOver, "#ffffff", false); cp._svCursor.Thickness = 2
    cp._hueCursor = rect(Z.PopupOver, "#ffffff", false); cp._hueCursor.Thickness = 2

    function cp:_currentColor()
        local r, g, b = hsvToRgb(self.H, self.S, self.V)
        return Color3.new(r, g, b)
    end

    function cp:_updateSwatch() self.Swatch.Color = self:_currentColor() end

    function cp:_reposition()
        local gx = self.Gb.BG.Position.X
        local gy = self.Gb.BG.Position.Y + self._yIn
        self.TextDraw.Position = Vector2.new(gx + 12, gy + 3)
        self.Swatch.Size = Vector2.new(20, 14)
        self.Swatch.Position = Vector2.new(gx + self.Gb.Width - 12 - 20, gy + 3)
        self.SwatchBorder.Position = self.Swatch.Position
        self.SwatchBorder.Size = self.Swatch.Size
        if self.Open then self:_layoutPopup() end
    end

    function cp:_layoutPopup()
        local sx = self.Swatch.Position.X
        local sy = self.Swatch.Position.Y + self.Swatch.Size.Y + 4
        local popupW = 150
        local popupH = 110
        sx = math.min(sx, self.Window.Pos.X + self.Window.Size.X - popupW - 4)
        self.PopupBg.Position = Vector2.new(sx, sy)
        self.PopupBg.Size = Vector2.new(popupW, popupH)
        self.PopupBg.Visible = true
        self.PopupBorder.Position = self.PopupBg.Position
        self.PopupBorder.Size = self.PopupBg.Size
        self.PopupBorder.Visible = true

        local svW, svH = 105, 85
        local svX, svY = sx + 6, sy + 6

        for i, r in ipairs(self._svRows) do
            local frac = (i - 1) / (#self._svRows - 1)
            local rr, gg, bb = hsvToRgb(self.H, 1, 1 - frac)
            r.Position = Vector2.new(svX, svY + (i - 1) * (svH / #self._svRows))
            r.Size = Vector2.new(svW, math.ceil(svH / #self._svRows))
            r.Color = Color3.new(rr, gg, bb)
            r.Visible = true
        end

        for i, r in ipairs(self._hueBars) do
            local frac = (i - 1) / (#self._hueBars - 1)
            local hr, hg, hb = hsvToRgb(frac, 1, 1)
            r.Position = Vector2.new(sx + 6 + svW + 6, svY + (i - 1) * (svH / #self._hueBars))
            r.Size = Vector2.new(24, math.ceil(svH / #self._hueBars))
            r.Color = Color3.new(hr, hg, hb)
            r.Visible = true
        end

        self._svCursor.Position = Vector2.new(svX + self.S * svW - 4, svY + (1 - self.V) * svH - 4)
        self._svCursor.Size = Vector2.new(8, 8)
        self._svCursor.Visible = true
        self._hueCursor.Position = Vector2.new(sx + 6 + svW + 6, svY + self.H * svH - 2)
        self._hueCursor.Size = Vector2.new(24, 4)
        self._hueCursor.Visible = true

        self._svRect = { Pos = Vector2.new(svX, svY), Size = Vector2.new(svW, svH) }
        self._hueRect = { Pos = Vector2.new(sx + 6 + svW + 6, svY), Size = Vector2.new(24, svH) }
    end

    function cp:_close()
        self.Open = false
        if self.Window._openPopup == self then self.Window._openPopup = nil end
        self.PopupBg.Visible = false; self.PopupBorder.Visible = false
        for _, r in ipairs(self._svRows) do r.Visible = false end
        for _, r in ipairs(self._hueBars) do r.Visible = false end
        self._svCursor.Visible = false; self._hueCursor.Visible = false
    end

    function cp:_open()
        if self.Window._openPopup and self.Window._openPopup ~= self then
            self.Window._openPopup:_close()
        end
        self.Open = true
        self.Window._openPopup = self
        self:_layoutPopup()
    end

    function cp:_setVisible(state)
        self.TextDraw.Visible = state
        self.Swatch.Visible = state
        self.SwatchBorder.Visible = state
        if not state then self:_close() end
    end

    function cp:_handleClick(mPos)
        if pointIn(mPos, self.Swatch.Position, self.Swatch.Size) then
            if self.Open then self:_close() else self:_open() end
            return true
        end
        if not self.Open then return false end
        if pointIn(mPos, self.PopupBg.Position, self.PopupBg.Size) then
            if pointIn(mPos, self._svRect.Pos, self._svRect.Size) then
                self.S = clamp01((mPos.X - self._svRect.Pos.X) / self._svRect.Size.X)
                self.V = clamp01(1 - (mPos.Y - self._svRect.Pos.Y) / self._svRect.Size.Y)
                self:_updateSwatch(); self:_layoutPopup()
                self.Callback(self:_currentColor())
                return true
            end
            if pointIn(mPos, self._hueRect.Pos, self._hueRect.Size) then
                self.H = clamp01((mPos.Y - self._hueRect.Pos.Y) / self._hueRect.Size.Y)
                self:_updateSwatch(); self:_layoutPopup()
                self.Callback(self:_currentColor())
                return true
            end
            return true
        end
        return false
    end

    function cp:SetColor(c) self.H, self.S, self.V = rgbToHsv(c.R, c.G, c.B); self:_updateSwatch() end
    function cp:GetColor() return self:_currentColor() end

    table.insert(gb.Widgets, cp)
    self:_growGroupbox(gb, widgetH)
    gb.InnerCursor = gb.InnerCursor + widgetH
    cp:_reposition()
    cp:_updateSwatch()
    cp:_setVisible(gb.Tab == self.ActiveTab and self.Visible)
    return cp
end

-- ============================================================
-- KEYBIND
-- ============================================================
function Library:_addKeybind(gb, opts)
    opts = opts or {}
    local widgetH = 26
    local yIn = gb.InnerCursor

    local kb = {
        Gb = gb, Window = self,
        Text = opts.Text or "Keybind",
        Key = opts.Default or 0,
        Capturing = false,
        Callback = opts.Callback or function() end,
        _yIn = yIn, _height = widgetH,
    }

    kb.TextDraw = label(Z.WidgetText, Theme.TextPrimary, 13, kb.Text)
    kb.BG = rect(Z.Widget, Theme.InputBg); kb.BG.Corner = 3
    kb.Border = rect(Z.WidgetBorder, Theme.InputBorder, false)
    kb.Border.Thickness = 1; kb.Border.Corner = 3
    kb.KeyText = label(Z.WidgetText, Theme.TextDim, 12, "...")
    kb.KeyText.Center = true

    function kb:_reposition()
        local gx = self.Gb.BG.Position.X
        local gy = self.Gb.BG.Position.Y + self._yIn
        self.TextDraw.Position = Vector2.new(gx + 12, gy + 3)
        self.BG.Size = Vector2.new(48, 18)
        self.BG.Position = Vector2.new(gx + self.Gb.Width - 12 - 48, gy + 3)
        self.Border.Position = self.BG.Position
        self.Border.Size = self.BG.Size
        self.KeyText.Position = self.BG.Position + Vector2.new(24, 2)
        self.KeyText.Text = self.Capturing and "..." or keyCodeName(self.Key)
        self.Border.Color = Color3.fromHex(self.Capturing and Theme.Accent or Theme.InputBorder)
    end

    function kb:_setVisible(state)
        self.TextDraw.Visible = state
        self.BG.Visible = state
        self.Border.Visible = state
        self.KeyText.Visible = state
    end

    function kb:_handleClick(mPos)
        if pointIn(mPos, self.BG.Position, self.BG.Size) then
            self.Capturing = true
            self.Window._capturingKeybind = self
            self:_reposition()
            return true
        end
        return false
    end

    function kb:_captureKey(keyCode)
        self.Key = keyCode
        self.Capturing = false
        if self.Window._capturingKeybind == self then self.Window._capturingKeybind = nil end
        self:_reposition()
        self.Callback(keyCode, keyCodeName(keyCode))
    end

    function kb:GetKey() return self.Key end
    function kb:SetKey(k) self.Key = k; self:_reposition() end

    table.insert(gb.Widgets, kb)
    self:_growGroupbox(gb, widgetH)
    gb.InnerCursor = gb.InnerCursor + widgetH
    kb:_reposition()
    kb:_setVisible(gb.Tab == self.ActiveTab and self.Visible)
    return kb
end

-- ============================================================
-- DROPDOWN (all variants)
-- ============================================================
function Library:_addDropdown(gb, variant, opts)
    opts = opts or {}
    local dd = {
        Variant  = variant,
        Gb       = gb,
        Window   = self,
        Text     = opts.Text or "Dropdown",
        Values   = opts.Values or {},
        Disabled = opts.Disabled or false,
        DisabledValues = opts.DisabledValues or {},
        Callback = opts.Callback or function() end,
        Open     = false,
        Selected = nil,
        MultiSelected = {},
        SearchText = "",
        ScrollOffset = 0,
        MaxVisible = 6,
        RowH = 24,
    }

    if variant == "multi" then
        if type(opts.Default) == "table" then
            for _, v in ipairs(opts.Default) do dd.MultiSelected[v] = true end
        end
    else
        dd.Selected = opts.Default
    end

    local yIn = gb.InnerCursor
    local widgetH = 44
    dd._yIn = yIn; dd._height = widgetH

    dd.Label = label(Z.WidgetText, Theme.TextDim, 12, dd.Text)
    dd.Header = rect(Z.Widget, Theme.InputBg); dd.Header.Corner = 3
    dd.HeaderBorder = rect(Z.WidgetBorder, Theme.InputBorder, false)
    dd.HeaderBorder.Thickness = 1; dd.HeaderBorder.Corner = 3
    dd.HeaderText = label(Z.WidgetText, Theme.TextPrimary, 13, "")
    dd.Arrow = label(Z.WidgetText, Theme.TextDim, 13, "v")

    dd.PopupBg = rect(Z.Popup, Theme.PopupBg); dd.PopupBg.Corner = 3
    dd.PopupBorder = rect(Z.PopupBorder, Theme.BorderLight, false)
    dd.PopupBorder.Thickness = 1; dd.PopupBorder.Corner = 3

    dd.SearchBg = rect(Z.Popup, Theme.InputBg); dd.SearchBg.Corner = 3
    dd.SearchBorder = rect(Z.PopupBorder, Theme.InputBorder, false)
    dd.SearchBorder.Thickness = 1; dd.SearchBorder.Corner = 3
    dd.SearchTextDraw = label(Z.PopupText, Theme.TextPrimary, 13, "")

    dd._rowPool = {}
    for i = 1, dd.MaxVisible do
        local row = {}
        row.BG = rect(Z.Popup, Theme.PopupBg)
        row.Hover = rect(Z.Popup, Theme.HoverBg); row.Hover.Visible = false
        row.Text = label(Z.PopupText, Theme.TextPrimary, 13, "")
        row.Check = rect(Z.PopupText, Theme.CheckOn); row.Check.Visible = false; row.Check.Corner = 2
        row.CheckBox = rect(Z.PopupText, Theme.InputBg, false)
        row.CheckBox.Visible = false; row.CheckBox.Thickness = 1; row.CheckBox.Corner = 2
        row.CurrentValue = nil
        table.insert(dd._rowPool, row)
    end

    dd.ScrollUp = rect(Z.Popup, Theme.InputBg); dd.ScrollUp.Visible = false; dd.ScrollUp.Corner = 2
    dd.ScrollUpText = label(Z.PopupText, Theme.TextDim, 13, "^"); dd.ScrollUpText.Visible = false
    dd.ScrollDn = rect(Z.Popup, Theme.InputBg); dd.ScrollDn.Visible = false; dd.ScrollDn.Corner = 2
    dd.ScrollDnText = label(Z.PopupText, Theme.TextDim, 13, "v"); dd.ScrollDnText.Visible = false

    function dd:_getValues()
        if self.Variant == "player" then
            local out = {}
            for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                table.insert(out, p.Name)
            end
            table.sort(out); return out
        elseif self.Variant == "team" then
            return listTeamNames()
        else
            return self.Values
        end
    end

    function dd:_isDisabledValue(v)
        for _, d in ipairs(self.DisabledValues) do if d == v then return true end end
        return false
    end

    function dd:_filteredValues()
        local all = self:_getValues()
        if self.Variant ~= "search" or self.SearchText == "" then return all end
        local out, q = {}, self.SearchText:lower()
        for _, v in ipairs(all) do
            if v:lower():find(q, 1, true) then table.insert(out, v) end
        end
        return out
    end

    function dd:_displayText()
        if self.Variant == "multi" then
            local names = {}
            for _, v in ipairs(self:_getValues()) do
                if self.MultiSelected[v] then table.insert(names, v) end
            end
            if #names == 0 then return "---" end
            return table.concat(names, ", ")
        else
            return self.Selected or "---"
        end
    end

    function dd:_open()
        if self.Disabled then return end
        if self.Window._openPopup and self.Window._openPopup ~= self then
            self.Window._openPopup:_close()
        end
        self.Open = true
        self.Window._openPopup = self
        if self.Variant == "search" then
            self.SearchText = ""
            self.Window._focusedText = self
        end
        self:_layoutPopup()
    end

    function dd:_close()
        self.Open = false
        if self.Window._openPopup == self then self.Window._openPopup = nil end
        if self.Window._focusedText == self then self.Window._focusedText = nil end
        self.PopupBg.Visible = false; self.PopupBorder.Visible = false
        self.SearchBg.Visible = false; self.SearchBorder.Visible = false
        self.SearchTextDraw.Visible = false
        self.ScrollUp.Visible = false; self.ScrollUpText.Visible = false
        self.ScrollDn.Visible = false; self.ScrollDnText.Visible = false
        for _, row in ipairs(self._rowPool) do
            row.BG.Visible = false; row.Hover.Visible = false
            row.Text.Visible = false; row.Check.Visible = false; row.CheckBox.Visible = false
        end
        self:_refreshHeader()
    end

    function dd:_layoutPopup()
        local hx, hy = self.Header.Position.X, self.Header.Position.Y
        local hw = self.Header.Size.X
        local searchH = (self.Variant == "search") and 28 or 0
        local values = self:_filteredValues()
        local visibleCount = math.min(self.MaxVisible, #values)
        local popupH = 8 + searchH + visibleCount * self.RowH + 8

        self.PopupBg.Position = Vector2.new(hx, hy + self.Header.Size.Y + 3)
        self.PopupBg.Size = Vector2.new(hw, popupH)
        self.PopupBg.Visible = true
        self.PopupBorder.Position = self.PopupBg.Position
        self.PopupBorder.Size = self.PopupBg.Size
        self.PopupBorder.Visible = true

        local cursorY = self.PopupBg.Position.Y + 5
        if self.Variant == "search" then
            self.SearchBg.Position = Vector2.new(hx + 5, cursorY)
            self.SearchBg.Size = Vector2.new(hw - 10, 22)
            self.SearchBg.Visible = true
            self.SearchBorder.Position = self.SearchBg.Position
            self.SearchBorder.Size = self.SearchBg.Size
            self.SearchBorder.Visible = true
            self.SearchBorder.Color = Color3.fromHex(Theme.Accent)
            self.SearchTextDraw.Position = self.SearchBg.Position + Vector2.new(7, 4)
            self.SearchTextDraw.Text = (self.SearchText == "") and "Type to search..." or self.SearchText
            self.SearchTextDraw.Color = Color3.fromHex((self.SearchText == "") and Theme.TextDim or Theme.TextPrimary)
            self.SearchTextDraw.Visible = true
            cursorY = cursorY + 28
        end

        local maxScroll = math.max(0, #values - self.MaxVisible)
        if self.ScrollOffset > maxScroll then self.ScrollOffset = maxScroll end
        if self.ScrollOffset < 0 then self.ScrollOffset = 0 end

        for i, row in ipairs(self._rowPool) do
            local idx = self.ScrollOffset + i
            local val = values[idx]
            row.CurrentValue = val
            if val then
                local rowY = cursorY + (i - 1) * self.RowH
                row.BG.Position = Vector2.new(hx + 2, rowY)
                row.BG.Size = Vector2.new(hw - 4, self.RowH)
                row.BG.Visible = true
                row.Text.Position = row.BG.Position + Vector2.new(self.Variant == "multi" and 28 or 10, 6)
                row.Text.Text = val
                local dis = self:_isDisabledValue(val)
                row.Text.Color = Color3.fromHex(dis and Theme.TextDisabled or Theme.TextPrimary)
                row.Text.Visible = true
                local selected = (self.Variant == "multi") and self.MultiSelected[val] or (val == self.Selected)
                row.Hover.Position = row.BG.Position
                row.Hover.Size = row.BG.Size
                row.Hover.Visible = selected and not dis
                if self.Variant == "multi" then
                    row.CheckBox.Position = row.BG.Position + Vector2.new(7, 5)
                    row.CheckBox.Size = Vector2.new(14, 14)
                    row.CheckBox.Visible = true
                    row.CheckBox.Color = Color3.fromHex(Theme.InputBorder)
                    if selected then
                        row.Check.Position = row.CheckBox.Position + Vector2.new(2, 2)
                        row.Check.Size = Vector2.new(10, 10)
                        row.Check.Visible = true
                    else row.Check.Visible = false end
                else
                    row.CheckBox.Visible = false; row.Check.Visible = false
                end
            else
                row.BG.Visible = false; row.Text.Visible = false
                row.Hover.Visible = false; row.Check.Visible = false; row.CheckBox.Visible = false
            end
        end

        if #values > self.MaxVisible then
            self.ScrollUp.Position = Vector2.new(hx + hw - 22, cursorY)
            self.ScrollUp.Size = Vector2.new(16, 16)
            self.ScrollUp.Visible = true
            self.ScrollUpText.Position = self.ScrollUp.Position + Vector2.new(5, 1)
            self.ScrollUpText.Visible = true
            self.ScrollDn.Position = Vector2.new(hx + hw - 22, cursorY + self.MaxVisible * self.RowH - 16)
            self.ScrollDn.Size = Vector2.new(16, 16)
            self.ScrollDn.Visible = true
            self.ScrollDnText.Position = self.ScrollDn.Position + Vector2.new(5, 1)
            self.ScrollDnText.Visible = true
        else
            self.ScrollUp.Visible = false; self.ScrollUpText.Visible = false
            self.ScrollDn.Visible = false; self.ScrollDnText.Visible = false
        end
    end

    function dd:_refreshHeader()
        self.HeaderText.Text = self:_displayText()
        local disabled = self.Disabled
        self.HeaderText.Color = Color3.fromHex(disabled and Theme.TextDisabled or
                                                (self:_displayText() == "---" and Theme.TextDim or Theme.TextPrimary))
        self.HeaderBorder.Color = Color3.fromHex(self.Open and Theme.Accent or Theme.InputBorder)
        self.Arrow.Text = self.Open and "^" or "v"
    end

    function dd:_setVisible(state)
        self.Label.Visible = state
        self.Header.Visible = state
        self.HeaderBorder.Visible = state
        self.HeaderText.Visible = state
        self.Arrow.Visible = state
        if not state then self:_close() end
    end

    function dd:_reposition()
        local gx = self.Gb.BG.Position.X
        local gy = self.Gb.BG.Position.Y + self._yIn
        local w = self.Gb.Width - 24
        self.Label.Position = Vector2.new(gx + 12, gy)
        self.Header.Position = Vector2.new(gx + 12, gy + 16)
        self.Header.Size = Vector2.new(w, 26)
        self.HeaderBorder.Position = self.Header.Position
        self.HeaderBorder.Size = self.Header.Size
        self.HeaderText.Position = self.Header.Position + Vector2.new(10, 5)
        self.Arrow.Position = self.Header.Position + Vector2.new(self.Header.Size.X - 16, 5)
        if self.Open then self:_layoutPopup() end
    end

    function dd:_handleClick(mPos)
        if self.Disabled then return false end
        if pointIn(mPos, self.Header.Position, self.Header.Size) then
            if self.Open then self:_close() else self:_open() end
            return true
        end
        if not self.Open then return false end
        if pointIn(mPos, self.PopupBg.Position, self.PopupBg.Size) then
            if self.ScrollUp.Visible and pointIn(mPos, self.ScrollUp.Position, self.ScrollUp.Size) then
                self.ScrollOffset = self.ScrollOffset - 1; self:_layoutPopup(); return true
            end
            if self.ScrollDn.Visible and pointIn(mPos, self.ScrollDn.Position, self.ScrollDn.Size) then
                self.ScrollOffset = self.ScrollOffset + 1; self:_layoutPopup(); return true
            end
            if self.Variant == "search" and pointIn(mPos, self.SearchBg.Position, self.SearchBg.Size) then
                self.Window._focusedText = self
                return true
            end
            for _, row in ipairs(self._rowPool) do
                if row.BG.Visible and pointIn(mPos, row.BG.Position, row.BG.Size) then
                    local v = row.CurrentValue
                    if not self:_isDisabledValue(v) then
                        if self.Variant == "multi" then
                            self.MultiSelected[v] = (not self.MultiSelected[v]) or nil
                            if not self.MultiSelected[v] then self.MultiSelected[v] = nil end
                            self:_layoutPopup(); self:_refreshHeader()
                            local snap = {}
                            for _, val in ipairs(self:_getValues()) do
                                if self.MultiSelected[val] then table.insert(snap, val) end
                            end
                            self.Callback(snap)
                        else
                            self.Selected = v
                            self:_close(); self:_refreshHeader()
                            self.Callback(v)
                        end
                    end
                    return true
                end
            end
            return true
        end
        return false
    end

    function dd:_handleKey(keyCode, shiftHeld)
        if self.Variant ~= "search" or self.Window._focusedText ~= self then return end
        local changed = false
        if keyCode >= 48 and keyCode <= 57 then
            self.SearchText = self.SearchText .. tostring(keyCode - 48); changed = true
        elseif keyCode >= 65 and keyCode <= 90 then
            local c = string.char(keyCode); if not shiftHeld then c = c:lower() end
            self.SearchText = self.SearchText .. c; changed = true
        elseif keyCode == 32 then
            self.SearchText = self.SearchText .. " "; changed = true
        elseif keyCode == 8 then
            if #self.SearchText > 0 then self.SearchText = self.SearchText:sub(1, -2); changed = true end
        elseif keyCode == 27 then
            self:_close(); return
        elseif keyCode == 13 then
            self.Window._focusedText = nil; changed = true
        elseif keyCode == 38 then
            self.ScrollOffset = self.ScrollOffset - 1; changed = true
        elseif keyCode == 40 then
            self.ScrollOffset = self.ScrollOffset + 1; changed = true
        end
        if changed then
            self.ScrollOffset = 0
            self:_layoutPopup()
        end
    end

    table.insert(gb.Widgets, dd)
    self:_growGroupbox(gb, widgetH)
    gb.InnerCursor = gb.InnerCursor + widgetH
    dd:_reposition()
    dd:_refreshHeader()
    dd:_setVisible(gb.Tab == self.ActiveTab and self.Visible)
    return dd
end

-- ============================================================
-- visibility
-- ============================================================
function Library:SetVisible(state)
    self.Visible = state
    for _, entry in ipairs(self.Objects) do entry.obj.Visible = state end
    for _, tab in ipairs(self.Tabs) do
        tab.BG.Visible = state; tab.Border.Visible = state; tab.Text.Visible = state
        tab.Accent.Visible = state and (tab == self.ActiveTab)
        for _, gb in ipairs(tab.Groupboxes) do
            local show = state and (tab == self.ActiveTab)
            self:_setGroupboxVisible(gb, show)
            for _, w in ipairs(gb.Widgets) do
                if w._setVisible then w:_setVisible(show) end
            end
        end
    end
    if not state then
        if self._openPopup then self._openPopup:_close() end
        self._focusedText = nil
        self._capturingKeybind = nil
        self._activeSlider = nil
    end
end

-- ============================================================
-- input + render
-- ============================================================
function Library:Update(Mouse)
    local tDown = iskeypressed(self.ToggleKey)
    if tDown and not self._lastToggle then self:SetVisible(not self.Visible) end
    self._lastToggle = tDown

    if not self.Visible then
        self._lastMouse1 = ismouse1pressed()
        return
    end

    local mPos = Vector2.new(Mouse.X, Mouse.Y)
    local mouse1 = ismouse1pressed()
    local clicked = mouse1 and not self._lastMouse1

    if clicked then
        local consumed = false

        if self._openPopup then
            consumed = self._openPopup:_handleClick(mPos)
            if not consumed then self._openPopup:_close() end
        end

        if not consumed then
            for _, tab in ipairs(self.Tabs) do
                if pointIn(mPos, tab.BG.Position, tab.BG.Size) then
                    self:SetActiveTab(tab); consumed = true; break
                end
            end
        end

        if not consumed and self.ActiveTab then
            for _, gb in ipairs(self.ActiveTab.Groupboxes) do
                for _, w in ipairs(gb.Widgets) do
                    if w._handleClick and not w.Open then
                        if w:_handleClick(mPos) then consumed = true; break end
                    end
                end
                if consumed then break end
            end
        end

        if not consumed and pointIn(mPos, self.Pos, self.Size) then
            self._dragging = true; self._dragStart = mPos; self._startPos = self.Pos
        end
    end

    if not mouse1 then
        self._dragging = false
        self._activeSlider = nil
    end

    if mouse1 and self._activeSlider then
        self._activeSlider:_setValueFromX(mPos.X)
    end

    if self._dragging and mouse1 then
        local delta = mPos - self._dragStart
        self.Pos = self._startPos + delta
        self:_applyPositions()
    end

    if self._capturingKeybind and iskeypressed then
        for kc in pairs(KeyNames) do
            if iskeypressed(kc) and kc ~= self.ToggleKey then
                self._capturingKeybind:_captureKey(kc)
                self._keyState[kc] = true
                break
            end
        end
    end

    if self._focusedText and iskeypressed then
        local now = tick()
        local shift = iskeypressed(16)
        for kc in pairs(KeyNames) do
            local pressed = iskeypressed(kc)
            local was = self._keyState[kc]
            local rep = self._keyRepeat[kc] and (now - self._keyRepeat[kc] > 0.08)
            local fired = (pressed and not was) or (pressed and rep)
            if fired then
                self._keyRepeat[kc] = now
                self._focusedText:_handleKey(kc, shift)
            end
            self._keyState[kc] = pressed
            if not pressed then self._keyRepeat[kc] = nil end
        end
    else
        if not self._capturingKeybind then
            for kc in pairs(KeyNames) do self._keyState[kc] = iskeypressed(kc) end
        end
    end

    self._lastMouse1 = mouse1
end

Library.Theme = Theme
Library.Z = Z

return Library
