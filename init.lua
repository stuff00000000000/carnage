local mq					= require('mq')
local ImGui					= require 'ImGui'
local race_data				= require('raceData')
local class_settings 		= require("classSettings")
local TLO					= mq.TLO
local Me					= TLO.Me
local ach					= TLO.Achievement
local Zone 					= TLO.Zone
local SlayerKeys			= {Skill=1,Conquest=1,Special=1}
local myClassSN				= Me.Class.ShortName()
local myClass				= Me.Class()
local myLevel				= Me.Level()
local running 				= true
local window_flags 			= bit32.bor(ImGuiWindowFlags.None)
local treeview_table_flags	= bit32.bor(ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.RowBg, ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.ScrollY)
local tab_bar_flags			= bit32.bor(ImGuiTabBarFlags.None)
local openGUI, drawGUI		= true, true
local guiheader 			= 'Carnage: Gotta Kill Them All'
local CB_Needed				= false
local CB_Size				= false
local CB_Invis				= false
local column_count 			= 5
local SlayerCount			= 0
local SlayerKilled			= 0
local RaceCount				= -1
--changed one race to nil, instead of renumbering race list
local RacesKilled			= 0
local ColumnID_Race 		= 1
local ColumnID_Skill 		= 2
local ColumnID_Special 		= 3
local ColumnID_Conquest 	= 4
local ColumnID_Zones 		= 5
local filteredKillList		= {}
local LastKill				= os.clock()
local plugins 				= {"MQ2Nav", "MQ2EasyFind", "MQ2Relocate"}
local filter				= ''
local TEXT_BASE_WIDTH, _ 	= ImGui.CalcTextSize("A")
local treeview_table_flags2 = bit32.bor(ImGuiTableFlags.BordersV, ImGuiTableFlags.BordersOuterH, ImGuiTableFlags.Resizable, ImGuiTableFlags.RowBg, ImGuiTableFlags.NoBordersInBody)
MyTreeNode 					= {}
local tabclick				= nil
local Version				= '1.2'
local FLT_MIN, FLT_MAX 		= mq.NumericLimits_Float()
local treeview_nodes 		= {}
local navigatetoZone		= false
local CloudyPotion			= TLO.FindItemCount('Cloudy Potion')
local invis_type 			= {}
local changed 				= false
local testing_invis 		= false
local toZone 				= ''
local PotionNeed 			= false

----------------------------------------------------------------------
---Thank you aquietone, brainiac, dannuic, Derple, kaen01, grimmier
---for putting up with me and helping me wrap my head around my logic
---
---Comments brought to you by the song: Look at what you made me do.
---
---SlayerKeys was voted on, by aquietone, as the best alternative to
---                                                   someSetOfKeys
----------------------------------------------------------------------


local function navPause()
	mq.cmd("/nav pause")
	mq.delay(500)
end

local function buildInvisType()
	invis_type = {}
	for word in string.gmatch(class_settings.settings.class_invis[myClass], "([^|]+)") do
		table.insert(invis_type, word)
	end
end
local function invis(class_settings)
	if Me.Combat() == true then
		mq.cmd("/attack off")
	end
	buildInvisType()
	if Me.Invis() == false then
		print(invis_type[class_settings.settings.invis[myClass]])
		if invis_type[class_settings.settings.invis[myClass]] == "Potion" and CloudyPotion() > 0 then
			mq.cmd('/useitem "Cloudy Potion"')
		elseif invis_type[class_settings.settings.invis[myClass]] == "Circlet of Shadows" then
			mq.cmd('/useitem "Circlet of Shadows"')
		elseif invis_type[class_settings.settings.invis[myClass]] == "Hide/Sneak" then
			while Me.Invis() == false do
				mq.delay(100)
				if Me.AbilityReady("Hide")() == true then
					mq.cmd("/doability hide")
				end
			end
			if Me.Sneaking() == false then
				while Me.Sneaking() == false do
					mq.delay(100)
					if Me.AbilityReady("Sneak")() == true then
						mq.cmd("/doability sneak")
					end
				end
			end
		else
			local ID = class_settings.settings.skill_to_num[invis_type[class_settings.settings.invis[myClass]]]
			while Me.AltAbilityReady(ID)() == false do
				mq.delay(50)
			end
			mq.cmdf("/alt act %s", ID)
			mq.delay(500)
			while Me.Casting() and myClass ~= "Bard" do
				mq.delay(200)
			end
		end
	end
	mq.delay("1s")
	testing_invis = false
end

local function IsCompleted(data)
	--Checks if passed data is completed or needs to be checked against the achievement TLO
    if data == 'Completed' then return true end
    return ach(data).Completed() or false
end

local function GetKillCounts(data)
	--Returns a number for the kills needed for achievement
    local Counter = 0
    if not ach(data).Completed() then
        local objective = ach(data).ObjectiveByIndex(1)
        if objective.RequiredCount() ~= nil then
            Counter = objective.RequiredCount() - objective.Count()
        end
    end
    return Counter
end

local function HoverToolTipClue(data)
	--tooltip to hover objective
	if data == 'Completed' then
		return
	elseif IsCompleted(data) then
		return 'Completed'
	elseif data == 'Not Used' then
		return
	else
		if ImGui.IsItemHovered() then
			ImGui.SetTooltip(ach(data).ObjectiveByIndex(1).Description())
		end
		return
	end
end

local function GetDisplayText(data)
	--converts the data from the Slayer Keys (Skill, Special, Conquest) for display: Completed, '', integer
	--if the counts reach 0, this will be displayed until the achievement dings then it changes to Completed
	if data == 'Completed' then
		return data
	elseif IsCompleted(data) then
		return 'Completed'
	elseif data == 'Not Used' then
		return ''
	else
		return ''..GetKillCounts(data)
	end
end

local function LDONwarningText()
	print('\ag----------------------------------------------------------------------------\ax')
	print('\arYou will need a group of three people to get the adventure at the LDON camp.\ax')
	print('\arYou will need to travel to the camp if you didnt arrive by Magus.\ax')
	print('\ag----------------------------------------------------------------------------\ax')
end

local function GetNavCommand (data)
	--converts the data from the Zone keys (zone1, zone2, zone3) to trigger on button push using Relocate or Nav/EasyFind
	--Currently travels from the zone where the button is pushed
	local VividOrange = '\a#f8bd21'
	toZone = data
	if data == 'theater' then
		mq.cmd('/relocate blood')
	else
		--Convert LDON zone labels to starting adventure camp zones
		if data == 'LDONsro' then
			LDONwarningText()
			data = 'southro'
		end
		if data == 'LDONeverfrost' then
			LDONwarningText()
			data = 'everfrost'
		end
		if data == 'LDONbb' then
			LDONwarningText()
			data = 'butcher'
		end
		--Travelto the zone or LDON zone
		mq.cmdf('/travelto %s',data)
		local where = Zone(data).Name
		printf('\arHeading to: \ag%s\ax', where)
		--warning for people to not play AFK
		printf('%sYou are now running dumb towards %s. Please make sure that you are aware that you could die or get stuck on geometry.\ax',VividOrange, where)
	end
	navigatetoZone = true
end

local function HoverButtonZone(data)
	--tooltip to hover the name of the zone above the nav button
	if ImGui.IsItemHovered() then
		ImGui.SetTooltip('Zone: '..data)
	end
end

local function DrawButtons(z1,z2,z3)
	--draws and populates the nav buttons on each line if zone data is available
	if (ImGui.Button("Z1")) then
		GetNavCommand(z1)
	end
	HoverButtonZone(z1)
	if z2 ~= nil then
		ImGui.SameLine()
		if (ImGui.Button("Z2")) then
			GetNavCommand(z2)
		end
		HoverButtonZone(z2)
	end
	if z3 ~= nil then
		ImGui.SameLine()
		if (ImGui.Button("Z3")) then
			GetNavCommand(z3)
		end
		HoverButtonZone(z3)
	end
end

local function filterKills(data)
	--builds a table of races that still need kills, or requested from filter
    filteredKillList = {}
	RacesKilled = 0
	filter = string.lower(filter)
    for _,race in ipairs(data) do
        local sk_count = GetKillCounts(race.Skill)
        local sp_count = GetKillCounts(race.Special)
        local co_count = GetKillCounts(race.Conquest)
		if (0 < sk_count or 0 < sp_count or 0 < co_count) then else RacesKilled = RacesKilled + 1 end
        if (0 < sk_count or 0 < sp_count or 0 < co_count) and string.find(race.Race:lower(), filter) then
            table.insert(filteredKillList, race)
        end
    end
end

local function GetGlobalKills()
	local ach_counts = {11000004,11000005,11000006,11000007,11000008,11000009,11000010,11000011,11000012,11000013,11000014,11000015,11000016,11000017,11000018,11000019,
	11000020,11000021,11000022,11000023,11000024,11000025,11000026,11000027,11000030,11000031,11000034,11000035,11000036,11000037,11000041,11000042,11000050,11000051,
	11000059,11000104,11000109,11000111,11000127,11000163,11000166,11000175,11000176}
	for i=1, #ach_counts do
		local Kill_Counter = ach(ach_counts[i]).Completed() and 0 or ach(ach_counts[i]).ObjectiveByIndex(1).RequiredCount() - ach(ach_counts[i]).ObjectiveByIndex(1).Count()
		SlayerCount = SlayerCount + Kill_Counter
	end
end

local function load_data(data)
	--loads data from the racedata file. does initial checks for achievement completed and changes those from the keyvalue to 'Completed'
	--calculates total kills needed for MegaDeath
	--calculates total races at a minimum needed to be killed for MegaDeath (not races left to kill)
	print('\arLoading race data from file.\ax')
	for k,v in pairs(data) do
		RaceCount = RaceCount + 1
		for key, value in pairs(v) do
			if SlayerKeys[key] then
				if ach(value).Completed() then race_data[k][key] = 'Completed' end
			end
		end
	end
	GetGlobalKills()
	printf('\arRaces marked for death: \ay%s\ax', RaceCount)
	printf('\arCreatures left to Kill: \ay%s\ax', SlayerCount)
	filterKills(data)
end

local function BuildTopPanel()
	--Build top header of gui
	ImGui.Text('Race:')
	ImGui.SameLine()
	ImGui.SetNextItemWidth(100)
	local changed
	filter,changed = ImGui.InputText('##Filter', filter)
	if ImGui.IsItemHovered() then ImGui.SetTooltip('Will filter against the Races you have to complete.') end
	if changed then filterKills(race_data) end
	ImGui.SameLine()
	CB_Needed = ImGui.Checkbox('Needed  ', CB_Needed)
	if ImGui.IsItemHovered() then ImGui.SetTooltip('Will show only Races yet to be completed.') end
end

local function DrawRaceTable()
	--Draw the race table tab
	if ImGui.BeginTable('##List_table', column_count, treeview_table_flags) then
		ImGui.TableSetupColumn('Race', 0, 150, ColumnID_Race)
		ImGui.TableSetupColumn('Skill', 0, 100, ColumnID_Skill)
		ImGui.TableSetupColumn('Special', 0, 100, ColumnID_Special)
		ImGui.TableSetupColumn('Conquest', 0, 100, ColumnID_Conquest)
		ImGui.TableSetupColumn('Zones', 0, 150, ColumnID_Zones)
		ImGui.TableSetupScrollFreeze(0, 1)
		ImGui.TableHeadersRow()
		local clipper = ImGuiListClipper.new()
		--switch for filtered or total table display
		local tmpTable = (CB_Needed or filter ~= '') and filteredKillList or race_data
		clipper:Begin(#tmpTable)
		while clipper:Step() do
			for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
				local item = tmpTable[row_n + 1]
				if item.Race == nil then goto continue end
				ImGui.PushID(item)
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					ImGui.Text(item.Race)
					ImGui.TableNextColumn()
					if GetDisplayText(item.Skill) == 'Completed' then
						ImGui.TextColored(ImVec4(1.0, 1.0, 0.0, 1.0), "Completed")
					else
						ImGui.Text(GetDisplayText(item.Skill))
					end
					HoverToolTipClue(item.Skill)
					ImGui.TableNextColumn()
					if GetDisplayText(item.Special) == 'Completed' then
						ImGui.TextColored(ImVec4(1.0, 1.0, 0.0, 1.0), "Completed")
					else
					ImGui.Text(GetDisplayText(item.Special))
					end
					HoverToolTipClue(item.Special)
					ImGui.TableNextColumn()
					if GetDisplayText(item.Conquest) == 'Completed' then
						ImGui.TextColored(ImVec4(1.0, 1.0, 0.0, 1.0), "Completed")
					else
					ImGui.Text(GetDisplayText(item.Conquest))
					end
					HoverToolTipClue(item.Conquest)
					ImGui.TableNextColumn()
					DrawButtons(item.zone1,item.zone2,item.zone3)
					ImGui.TableNextColumn()
				ImGui.PopID()
				::continue::
			end
		end
		ImGui.EndTable()
	end
end

local function DeathCheckUpdate()
	--triggered on death event, checks if time has passed so it doesn't update on hundreds of kills at once
	local HasTimePassed = os.clock() - LastKill
	if 10 < HasTimePassed then
		filterKills(race_data)
		LastKill = os.clock()
	end
end

function MyTreeNode.new(name, KillCount, childIdx, childCount)
    MyTreeNode.__index = MyTreeNode
    local o = {}
    setmetatable(o, MyTreeNode)
    o.Name = name
    o.KillCount = KillCount
    o.ChildIdx = childIdx
    o.ChildCount = childCount
    return o
end

function MyTreeNode:display(all_nodes)
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    local is_folder = self.ChildCount > 0
    if is_folder then
        local open = ImGui.TreeNodeEx(self.Name, ImGuiTreeNodeFlags.SpanFullWidth)
        ImGui.TableNextColumn()
        ImGui.Text(self.KillCount)
        if open then
            for child_n = 1, self.ChildCount do
                all_nodes[self.ChildIdx + child_n]:display(all_nodes)
            end
            ImGui.TreePop()
        end
    else
        ImGui.TreeNodeEx(self.Name, bit32.bor(ImGuiTreeNodeFlags.Leaf, ImGuiTreeNodeFlags.NoTreePushOnOpen, ImGuiTreeNodeFlags.SpanFullWidth))
        ImGui.TableNextColumn()
        ImGui.Text(self.KillCount)
    end
end

local function GetAchievementName(data)
	return ach(data).Name()
end

local function IsCompleteOrMetaCount(data)
	if IsCompleted(data) then return 'Completed'
	elseif data == 11000000 then return ''
	else
		local TotalKills = 0
		if data == 11000001 then
			for i=11000004, 11000027 do TotalKills = TotalKills + GetKillCounts(i) end
		elseif data == 11000002 then
			for i=11000028, 11000064 do TotalKills = TotalKills + GetKillCounts(i) end
		elseif data == 11000003 then
			for i=11000065, 11000178 do TotalKills = TotalKills + GetKillCounts(i) end
		else
			TotalKills = GetKillCounts(data)
		end
		return TotalKills
	end
end

local function buildAchView()
	table.insert(treeview_nodes, MyTreeNode.new(GetAchievementName(11000000), IsCompleteOrMetaCount(11000000),  1,  3))
	table.insert(treeview_nodes, MyTreeNode.new(GetAchievementName(11000001), IsCompleteOrMetaCount(11000001),  4,  24))
	table.insert(treeview_nodes, MyTreeNode.new(GetAchievementName(11000002), IsCompleteOrMetaCount(11000002), 28,  37))
	table.insert(treeview_nodes, MyTreeNode.new(GetAchievementName(11000003), IsCompleteOrMetaCount(11000003), 65, 114))

	local childcount = 1
	for i=11000004, 11000027 do
		table.insert(treeview_nodes, MyTreeNode.new(GetAchievementName(i), IsCompleteOrMetaCount(i), childcount, -1))
		childcount = childcount + 1
	end
	childcount = childcount + 1
	for i=11000028, 11000064 do
		table.insert(treeview_nodes, MyTreeNode.new(GetAchievementName(i), IsCompleteOrMetaCount(i), childcount, -1))
		childcount = childcount + 1
	end
	childcount = childcount + 1
	for i=11000065, 11000178 do
		table.insert(treeview_nodes, MyTreeNode.new(GetAchievementName(i), IsCompleteOrMetaCount(i), childcount, -1))
		childcount = childcount + 1
	end
end

local function ShowTableDemoTreeView()
	ImGui.PushStyleVar(ImGuiStyleVar.IndentSpacing, 0.0)
    if ImGui.TreeNode('Slayer') then
        if ImGui.BeginTable('##3ways', 2, treeview_table_flags2) then
            -- The first column will use the default _WidthStretch when ScrollX is Off and _WidthFixed when ScrollX is On
            ImGui.TableSetupColumn('Name', ImGuiTableColumnFlags.NoHide)
            ImGui.TableSetupColumn('KillCount', ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 13.0)
            treeview_nodes[1]:display(treeview_nodes)
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end
end

local function DrawAchievementTable()
	ShowTableDemoTreeView()
end

local function DrawInvisCombo()
	invis_type = {}
	for word in
	string.gmatch(class_settings.settings.class_invis[myClass], "([^|]+)")
	do
		table.insert(invis_type, word)
	end
	ImGui.PushItemWidth(230)
	class_settings.settings.invis[myClass], changed = ImGui.Combo(
		"##InvisType",
		class_settings.settings.invis[myClass],
		invis_type,
		#invis_type,
		#invis_type
	)
	if changed then
		changed = false
		class_settings.saveSettings()
	end
end

local function DrawOptions()
	--Im blind as a bat using a 4K monitor with EQ in 4K, but all the pretty colors
	CB_Size = ImGui.Checkbox('Text Size', CB_Size)
	ImGui.Text('Increase text size by 50% for the sight impared.')
	CB_Invis = ImGui.Checkbox('Travel Invis', CB_Invis)
	if PotionNeed then 
		ImGui.SameLine()
		ImGui.Text('Need Potions')
	end
	ImGui.Text('When navigating to a zone, be invisible if possible.')
	ImGui.Text('')
	ImGui.Text('Invis Type: ')
	ImGui.SameLine()
	DrawInvisCombo()
end

local function CheckNavigateInvis()
	if Me.Invis() == false then
		navPause()
		invis(class_settings)
		navPause()
	end
end

local function DrawMainGui()
	ImGui.Text('Carnage')
	ImGui.Text('Version: %s', Version)
	ImGui.Text('Current Class: %s', myClass)
	ImGui.SameLine()
	ImGui.Text('Level: %s', myLevel)
	ImGui.Text('Cloudy Potions: %s', CloudyPotion())
	buildInvisType()
	ImGui.Text('Innate Invis: %s', invis_type[class_settings.settings.invis[myClass]])
--	if (ImGui.Button("Invis")) then
--		testing_invis = true
--	end
ImGui.Spacing()
ImGui.TextWrapped('Carnage will help your character achieve Megadeath.')
ImGui.Spacing()
ImGui.TextWrapped('It gives the minumum races needed to kill to achieve this, as well as, the zones that those races can appear in. It can let you travel to those zones with a click.')
ImGui.Spacing()
ImGui.TextWrapped('The Creatures Left and Races Left are how many are need to achieve. You may happen to kill more before you get the achievement as some of the races overlap the different achievements. Killing races that are not listed may decrease counts. You can hover over the count to get the true criteria.')

end

local function DrawKillCounts()
	ImGui.Text('  Creatures Left: ')
	ImGui.SameLine()
	local currentKill = SlayerCount - SlayerKilled
	ImGui.Text('%s  ', currentKill)
	ImGui.SameLine()
	ImGui.Text('  Races Left: ')
	ImGui.SameLine()
	local RacesLeft = RaceCount	 - RacesKilled
	ImGui.Text('%s  ', RacesLeft)
end

local function DisplayGUI()
	--draws something on the screen
	if not openGUI then running = false end
	ImGui.SetNextWindowPos(400, 400, ImGuiCond.Once)
    ImGui.SetNextWindowSize(800, 650, ImGuiCond.Once)
	if CB_Size then
		ImGui.SetNextWindowSizeConstraints(ImVec2(950, 250), ImVec2(FLT_MAX, FLT_MAX))
	else
		ImGui.SetNextWindowSizeConstraints(ImVec2(650, 250), ImVec2(FLT_MAX, FLT_MAX))
	end
	openGUI, drawGUI = ImGui.Begin(guiheader, openGUI, window_flags)
	if CB_Size then ImGui.SetWindowFontScale(1.5) else ImGui.SetWindowFontScale(1.0) end
	if drawGUI and not Me.Zoning() then
		if ImGui.BeginTabBar('CarnageTabs', tab_bar_flags) then
			if ImGui.BeginTabItem('Carnage Main') then
				tabclick = 'Carnage Main'
				DrawMainGui()
				ImGui.EndTabItem()
			end
			if ImGui.BeginTabItem('Races To Kill') then
				tabclick = 'Races To Kill'
				BuildTopPanel()
				DrawRaceTable()
				ImGui.EndTabItem()
			end
			if ImGui.BeginTabItem('Achievements') then
				tabclick = 'Achievements'
				DrawAchievementTable()
				ImGui.EndTabItem()
			end
			if ImGui.BeginTabItem('Options') then
				tabclick = 'Options'
				ImGui.EndTabItem()
			end
			ImGui.SameLine()
			ImGui.EndTabBar()
		end
		ImGui.SameLine()
		DrawKillCounts()
		if tabclick == 'Options' then
			DrawOptions()
		end
	end
	ImGui.End()
end

local function checkPotionuse()
	buildInvisType()
	if CloudyPotion() == 0 and invis_type[class_settings.settings.invis[myClass]] == "Potion" then
		CB_Invis = false
		PotionNeed = true
	else
		PotionNeed = false
	end
end

local function initializeDeath()
	buildAchView()
	--Define trigger events to update filterdata
	mq.event('SomeoneKills','#*#has been slain by#*#',DeathCheckUpdate)
	mq.event('YouKill','#*#You have slain#*#',DeathCheckUpdate)

	--check for plugins that are used in this script
	for _, plugin in ipairs(plugins) do
		if TLO.Plugin(plugin)() == nil then
			printf('"\ar%s \aois required for this script.', plugin)
			printf('\aoLoaded \ar%s \aowith \agnoauto\ao.', plugin)
			mq.cmdf('/plugin %s noauto', plugin)
		end
	end
	class_settings.loadSettings()
end

load_data(race_data)
initializeDeath()
mq.imgui.init('drawGUI', DisplayGUI)

while running == true do
	CloudyPotion			= TLO.FindItemCount('Cloudy Potion')
	checkPotionuse()
	--Check for events
	if navigatetoZone and CB_Invis then CheckNavigateInvis() end
	if testing_invis then invis(class_settings) end
	if toZone == Zone.ShortName() and navigatetoZone then navigatetoZone = false end
	if TLO.Navigation.Active() then else navigatetoZone = false end
	mq.doevents()
	mq.delay('1s')
end