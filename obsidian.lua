-- ============================================================
-- DrawObsidian - Matcha Drawing-based Obsidian-style UI
-- Window + tabs + groupboxes + dropdowns (all variants)
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
}

local Z = {
    Bg = 10, Panel = 20, Border = 25, Tab = 30, TabText = 35,
    Groupbox = 40, GroupboxBorder = 42, GroupboxText = 45,
    Widget = 50, WidgetBorder = 52, WidgetText = 55,
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

-- safe Teams resolver, some matcha builds dont expose GetTeams
local function listTeamNames()
    local out = {}
    local ok, teams = pcall(function() return game:GetService("Teams") end)
    if not ok or not teams then return out end
    -- try the API method first, fall back to GetChildren
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
    self.ToggleKey = opts.ToggleKey or 0x70

    self.Objects = {}
    self._dragging = false
    self._dragStart = nil
    self._startPos = nil
    self._lastMouse1 = false
    self._lastToggle = false
    self._openPopup = nil
    self._focusedSearch = nil
    self._keyState = {}
    self._keyRepeat = {}

    self.Bg = rect(Z.Bg, Theme.WindowBg); self.Bg.Size = self.Size; self.Bg.Corner = 4
    table.insert(self.Objects, { obj = self.Bg, off = Vector2.new(0, 0) })

    self.BgBorder = rect(Z.Border, Theme.Border, false)
    self.BgBorder.Size = self.Size; self.BgBorder.Thickness = 1; self.BgBorder.Corner = 4
    table.insert(self.Objects, { obj = self.BgBorder, off = Vector2.new(0, 0) })

    self.Sidebar = rect(Z.Panel, Theme.SidebarBg)
    self.Sidebar.Size = Vector2.new(self.SidebarW, self.Size.Y); self.Sidebar.Corner = 4
    table.insert(self.Objects, { obj = self.Sidebar, off = Vector2.new(0, 0) })

    self.SidebarDivider = rect(Z.Border, Theme.Border)
    self.SidebarDivider.Size = Vector2.new(1, self.Size.Y)
    table.insert(self.Objects, { obj = self.SidebarDivider, off = Vector2.new(self.SidebarW, 0) })

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
            for _, w in ipairs(gb.Widgets) do
                if w._reposition then w:_reposition(self.Pos) end
            end
        end
    end
end

function Library:_repositionGroupbox(gb)
    gb.BG.Position      = self.Pos + gb.Off
    gb.Border.Position  = gb.BG.Position
    gb.Title.Position   = gb.BG.Position + Vector2.new(10, -7)
    gb.TitleBg.Position = gb.BG.Position + Vector2.new(8, -8)
end

function Library:AddTab(name)
    local index = #self.Tabs + 1
    local yOff = 50 + (index - 1) * 30

    local tab = {}
    tab.Name = name
    tab.Off = Vector2.new(8, yOff)
    tab.Groupboxes = {}
    tab.LeftCursor = 14
    tab.RightCursor = 14
    tab.Window = self

    tab.BG = rect(Z.Tab, Theme.TabIdle)
    tab.BG.Size = Vector2.new(self.SidebarW - 16, 26); tab.BG.Corner = 4

    tab.Border = rect(Z.Border, Theme.TabIdle, false)
    tab.Border.Size = tab.BG.Size; tab.Border.Thickness = 1; tab.Border.Corner = 4

    tab.Accent = rect(Z.TabText, Theme.Accent)
    tab.Accent.Size = Vector2.new(2, 26); tab.Accent.Corner = 1

    tab.Text = label(Z.TabText, Theme.TextDim, 13, name)

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

function Library:_createGroupbox(tab, side, name)
    local gb = {}
    gb.Name = name; gb.Side = side; gb.Tab = tab

    local contentW = self.Size.X - self.SidebarW - 1
    local gutter = 10
    local colW = (contentW - gutter * 3) / 2
    local xOff = (side == "left") and (self.SidebarW + 1 + gutter)
                                   or  (self.SidebarW + 1 + gutter * 2 + colW)

    gb.Width = colW
    gb.Height = 14
    gb.InnerCursor = 14
    gb.Widgets = {}

    local cursor = (side == "left") and tab.LeftCursor or tab.RightCursor
    gb.Off = Vector2.new(xOff, cursor)

    gb.BG = rect(Z.Groupbox, Theme.GroupboxBg)
    gb.BG.Size = Vector2.new(gb.Width, gb.Height); gb.BG.Corner = 4

    gb.Border = rect(Z.GroupboxBorder, Theme.Border, false)
    gb.Border.Size = gb.BG.Size; gb.Border.Thickness = 1; gb.Border.Corner = 4

    gb.TitleBg = rect(Z.GroupboxBorder, Theme.WindowBg)
    gb.TitleBg.Size = Vector2.new(8 + #name * 6 + 8, 3); gb.TitleBg.Filled = true

    gb.Title = label(Z.GroupboxText, Theme.TextPrimary, 12, name, true)

    gb.Window = self
    function gb:AddDropdown(opts)       return self.Window:_addDropdown(self, "single", opts) end
    function gb:AddSearchDropdown(opts) return self.Window:_addDropdown(self, "search", opts) end
    function gb:AddMultiDropdown(opts)  return self.Window:_addDropdown(self, "multi",  opts) end
    function gb:AddPlayerDropdown(opts) return self.Window:_addDropdown(self, "player", opts) end
    function gb:AddTeamDropdown(opts)   return self.Window:_addDropdown(self, "team",   opts) end

    if side == "left" then tab.LeftCursor = cursor + gb.Height + 10
    else tab.RightCursor = cursor + gb.Height + 10 end

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
        RowH = 22,
    }

    if variant == "multi" then
        if type(opts.Default) == "table" then
            for _, v in ipairs(opts.Default) do dd.MultiSelected[v] = true end
        end
    else
        dd.Selected = opts.Default
    end

    local yIn = gb.InnerCursor
    local widgetH = 38
    dd._yIn = yIn

    dd.Label = label(Z.WidgetText, Theme.TextDim, 11, dd.Text)

    dd.Header = rect(Z.Widget, Theme.InputBg)
    dd.Header.Size = Vector2.new(gb.Width - 20, 22); dd.Header.Corner = 3

    dd.HeaderBorder = rect(Z.WidgetBorder, Theme.InputBorder, false)
    dd.HeaderBorder.Size = dd.Header.Size; dd.HeaderBorder.Thickness = 1; dd.HeaderBorder.Corner = 3

    dd.HeaderText = label(Z.WidgetText, Theme.TextPrimary, 12, "")
    dd.Arrow = label(Z.WidgetText, Theme.TextDim, 12, "v")

    dd.PopupBg = rect(Z.Popup, Theme.PopupBg); dd.PopupBg.Corner = 3
    dd.PopupBorder = rect(Z.PopupBorder, Theme.BorderLight, false)
    dd.PopupBorder.Thickness = 1; dd.PopupBorder.Corner = 3

    dd.SearchBg = rect(Z.Popup, Theme.InputBg); dd.SearchBg.Corner = 3
    dd.SearchBorder = rect(Z.PopupBorder, Theme.InputBorder, false)
    dd.SearchBorder.Thickness = 1; dd.SearchBorder.Corner = 3
    dd.SearchTextDraw = label(Z.PopupText, Theme.TextPrimary, 12, "")

    dd._rowPool = {}
    for i = 1, dd.MaxVisible do
        local row = {}
        row.BG = rect(Z.Popup, Theme.PopupBg)
        row.Hover = rect(Z.Popup, Theme.HoverBg); row.Hover.Visible = false
        row.Text = label(Z.PopupText, Theme.TextPrimary, 12, "")
        row.Check = rect(Z.PopupText, Theme.CheckOn); row.Check.Visible = false; row.Check.Corner = 2
        row.CheckBox = rect(Z.PopupText, Theme.InputBg, false)
        row.CheckBox.Visible = false; row.CheckBox.Thickness = 1; row.CheckBox.Corner = 2
        row.CurrentValue = nil
        table.insert(dd._rowPool, row)
    end

    dd.ScrollUp = rect(Z.Popup, Theme.InputBg); dd.ScrollUp.Visible = false; dd.ScrollUp.Corner = 2
    dd.ScrollUpText = label(Z.PopupText, Theme.TextDim, 12, "^"); dd.ScrollUpText.Visible = false
    dd.ScrollDn = rect(Z.Popup, Theme.InputBg); dd.ScrollDn.Visible = false; dd.ScrollDn.Corner = 2
    dd.ScrollDnText = label(Z.PopupText, Theme.TextDim, 12, "v"); dd.ScrollDnText.Visible = false

    function dd:_getValues()
        if self.Variant == "player" then
            local out = {}
            for _, p in ipairs(game:GetService("Players"):GetPlayers()) do
                table.insert(out, p.Name)
            end
            table.sort(out)
            return out
        elseif self.Variant == "team" then
            return listTeamNames()
        else
            return self.Values
        end
    end

    function dd:_isDisabledValue(v)
        for _, d in ipairs(self.DisabledValues) do
            if d == v then return true end
        end
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
            self.Window._focusedSearch = self
        end
        self:_layoutPopup()
    end

    function dd:_close()
        self.Open = false
        if self.Window._openPopup == self then self.Window._openPopup = nil end
        if self.Window._focusedSearch == self then self.Window._focusedSearch = nil end
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
        local searchH = (self.Variant == "search") and 24 or 0
        local values = self:_filteredValues()
        local visibleCount = math.min(self.MaxVisible, #values)
        local popupH = 6 + searchH + visibleCount * self.RowH + 6

        self.PopupBg.Position = Vector2.new(hx, hy + self.Header.Size.Y + 2)
        self.PopupBg.Size = Vector2.new(hw, popupH)
        self.PopupBg.Visible = true
        self.PopupBorder.Position = self.PopupBg.Position
        self.PopupBorder.Size = self.PopupBg.Size
        self.PopupBorder.Visible = true

        local cursorY = self.PopupBg.Position.Y + 4
        if self.Variant == "search" then
            self.SearchBg.Position = Vector2.new(hx + 4, cursorY)
            self.SearchBg.Size = Vector2.new(hw - 8, 20)
            self.SearchBg.Visible = true
            self.SearchBorder.Position = self.SearchBg.Position
            self.SearchBorder.Size = self.SearchBg.Size
            self.SearchBorder.Visible = true
            self.SearchBorder.Color = Color3.fromHex(Theme.Accent)
            self.SearchTextDraw.Position = self.SearchBg.Position + Vector2.new(6, 4)
            self.SearchTextDraw.Text = (self.SearchText == "") and "Type to search..." or self.SearchText
            self.SearchTextDraw.Color = Color3.fromHex((self.SearchText == "") and Theme.TextDim or Theme.TextPrimary)
            self.SearchTextDraw.Visible = true
            cursorY = cursorY + 24
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

                row.Text.Position = row.BG.Position + Vector2.new(self.Variant == "multi" and 24 or 8, 5)
                row.Text.Text = val
                local dis = self:_isDisabledValue(val)
                row.Text.Color = Color3.fromHex(dis and Theme.TextDisabled or Theme.TextPrimary)
                row.Text.Visible = true

                local selected = (self.Variant == "multi") and self.MultiSelected[val] or (val == self.Selected)
                row.Hover.Position = row.BG.Position
                row.Hover.Size = row.BG.Size
                row.Hover.Visible = selected and not dis

                if self.Variant == "multi" then
                    row.CheckBox.Position = row.BG.Position + Vector2.new(6, 4)
                    row.CheckBox.Size = Vector2.new(12, 12)
                    row.CheckBox.Visible = true
                    row.CheckBox.Color = Color3.fromHex(Theme.InputBorder)
                    if selected then
                        row.Check.Position = row.CheckBox.Position + Vector2.new(2, 2)
                        row.Check.Size = Vector2.new(8, 8)
                        row.Check.Visible = true
                    else
                        row.Check.Visible = false
                    end
                else
                    row.CheckBox.Visible = false; row.Check.Visible = false
                end
            else
                row.BG.Visible = false; row.Text.Visible = false
                row.Hover.Visible = false; row.Check.Visible = false; row.CheckBox.Visible = false
            end
        end

        if #values > self.MaxVisible then
            self.ScrollUp.Position = Vector2.new(hx + hw - 18, cursorY)
            self.ScrollUp.Size = Vector2.new(14, 14)
            self.ScrollUp.Visible = true
            self.ScrollUpText.Position = self.ScrollUp.Position + Vector2.new(4, 1)
            self.ScrollUpText.Visible = true
            self.ScrollDn.Position = Vector2.new(hx + hw - 18, cursorY + self.MaxVisible * self.RowH - 14)
            self.ScrollDn.Size = Vector2.new(14, 14)
            self.ScrollDn.Visible = true
            self.ScrollDnText.Position = self.ScrollDn.Position + Vector2.new(4, 1)
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

    function dd:_reposition(winPos)
        local gx = self.Gb.BG.Position.X
        local gy = self.Gb.BG.Position.Y + self._yIn
        self.Label.Position = Vector2.new(gx + 10, gy)
        self.Header.Position = Vector2.new(gx + 10, gy + 14)
        self.HeaderBorder.Position = self.Header.Position
        self.HeaderText.Position = self.Header.Position + Vector2.new(8, 4)
        self.Arrow.Position = self.Header.Position + Vector2.new(self.Header.Size.X - 14, 4)
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
                self.Window._focusedSearch = self
                return true
            end
            for _, row in ipairs(self._rowPool) do
                if row.BG.Visible and pointIn(mPos, row.BG.Position, row.BG.Size) then
                    local v = row.CurrentValue
                    if not self:_isDisabledValue(v) then
                        if self.Variant == "multi" then
                            self.MultiSelected[v] = (not self.MultiSelected[v]) or nil
                            if not self.MultiSelected[v] then self.MultiSelected[v] = nil end
                            self:_layoutPopup()
                            self:_refreshHeader()
                            local snap = {}
                            for _, val in ipairs(self:_getValues()) do
                                if self.MultiSelected[val] then table.insert(snap, val) end
                            end
                            self.Callback(snap)
                        else
                            self.Selected = v
                            self:_close()
                            self:_refreshHeader()
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
        if self.Variant ~= "search" or self.Window._focusedSearch ~= self then return end
        local changed = false
        if keyCode >= 48 and keyCode <= 57 then
            self.SearchText = self.SearchText .. tostring(keyCode - 48); changed = true
        elseif keyCode >= 65 and keyCode <= 90 then
            local c = string.char(keyCode)
            if not shiftHeld then c = c:lower() end
            self.SearchText = self.SearchText .. c; changed = true
        elseif keyCode == 32 then
            self.SearchText = self.SearchText .. " "; changed = true
        elseif keyCode == 8 then
            if #self.SearchText > 0 then self.SearchText = self.SearchText:sub(1, -2); changed = true end
        elseif keyCode == 27 then
            self:_close(); return
        elseif keyCode == 13 then
            self.Window._focusedSearch = nil; changed = true
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

    dd:_reposition(self.Pos)
    dd:_refreshHeader()
    dd:_setVisible(gb.Tab == self.ActiveTab and self.Visible)
    return dd
end

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
    if not state and self._openPopup then self._openPopup:_close() end
end

local KeyNames = {
    [48]="0",[49]="1",[50]="2",[51]="3",[52]="4",[53]="5",[54]="6",[55]="7",[56]="8",[57]="9",
    [8]="Backspace",[13]="Enter",[16]="Shift",[27]="Esc",[32]="Space",[38]="Up",[40]="Down",
    [65]="A",[66]="B",[67]="C",[68]="D",[69]="E",[70]="F",[71]="G",[72]="H",[73]="I",[74]="J",
    [75]="K",[76]="L",[77]="M",[78]="N",[79]="O",[80]="P",[81]="Q",[82]="R",[83]="S",[84]="T",
    [85]="U",[86]="V",[87]="W",[88]="X",[89]="Y",[90]="Z",
}

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

        if not consumed then
            if self.ActiveTab then
                for _, gb in ipairs(self.ActiveTab.Groupboxes) do
                    for _, w in ipairs(gb.Widgets) do
                        if w._handleClick and not w.Open then
                            if w:_handleClick(mPos) then consumed = true; break end
                        end
                    end
                    if consumed then break end
                end
            end
        end

        if not consumed and pointIn(mPos, self.Pos, self.Size) then
            self._dragging = true; self._dragStart = mPos; self._startPos = self.Pos
        end
    end

    if not mouse1 then self._dragging = false end

    if self._dragging and mouse1 then
        local delta = mPos - self._dragStart
        self.Pos = self._startPos + delta
        self:_applyPositions()
    end

    if self._focusedSearch and iskeypressed then
        local now = tick()
        local shift = iskeypressed(16)
        for kc in pairs(KeyNames) do
            local pressed = iskeypressed(kc)
            local was = self._keyState[kc]
            local rep = self._keyRepeat[kc] and (now - self._keyRepeat[kc] > 0.08)
            local fired = (pressed and not was) or (pressed and rep)
            if fired then
                self._keyRepeat[kc] = now
                self._focusedSearch:_handleKey(kc, shift)
            end
            self._keyState[kc] = pressed
            if not pressed then self._keyRepeat[kc] = nil end
        end
    end

    self._lastMouse1 = mouse1
end

Library.Theme = Theme
Library.Z = Z

return Library
