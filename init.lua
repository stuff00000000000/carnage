--required things
local mq										= require('mq')
local ImGui										= require 'ImGui'
local race_data									= require('raceData')
local ICONS                                     = require('mq.Icons')
local class_settings 							= require("classSettings")
local dir_name									= 'carnage'
--flags
local running, changed 							= true, false
local openGUI, drawGUI							= true, true
local CB_Needed, CB_Size, CB_Invis = false, false, true
local CB_Race,CB_RaceS									= {},{}
local navigatetoZone, PotionNeed 				= false, false

--GUI stuff
local TEXT_BASE_WIDTH, _ 						= ImGui.CalcTextSize("A")
local FLT_MIN, FLT_MAX 							= mq.NumericLimits_Float()
local treeview_nodes, MyTreeNode  				= {}, {}

--GUI tablecolumns
local column_count 								= 5
local ColumnID_Race, ColumnID_Skill, ColumnID_Special, ColumnID_Conquest, ColumnID_Zones
									  			= 1, 2, 3, 4, 5

--counters
local currentKill	= 0
local RaceCount, RacesKilled, currentRaces		= 0, 0, 0
local maxZones									= 9

--Text stuff
local filter, Version							= '', '1.7.1'

--ArraYs
local filteredKillList, invis_type				= {}, {}

--MISC
local LastKill									= os.clock()
local plugins 									= {"MQ2Nav", "MQ2EasyFind", "MQ2Relocate"}
local SlayerKeys								= {Skill=1, Conquest=1, Special=1}
local tabclick									= nil

local function envIsAlphaNum(sIn)
	return (string.match(sIn,"[^%w]") == nil) end

local function envIsNum(sIn)
	return tonumber(sIn) ~= nil end

--Invis Functions

local function buildInvisType()
	invis_type = {}
	for word in string.gmatch(class_settings.settings.class_invis[mq.TLO.Me.Class()], "([^|]+)") do
		table.insert(invis_type, word)
	end
end

local function invis(class_settings)
	if mq.TLO.Me.Combat() == true then
		mq.cmd("/attack off")
	end
	buildInvisType()
	if mq.TLO.Me.Invis() == false then
		print(invis_type[class_settings.settings.invis[mq.TLO.Me.Class()]])
		if invis_type[class_settings.settings.invis[mq.TLO.Me.Class()]] == "Potion" and mq.TLO.FindItemCount('Cloudy Potion') > 0 then
			mq.cmd('/useitem "Cloudy Potion"')
		elseif invis_type[class_settings.settings.invis[mq.TLO.Me.Class()]] == "Circlet of Shadows" then
			mq.cmd('/useitem "Circlet of Shadows"')
		elseif invis_type[class_settings.settings.invis[mq.TLO.Me.Class()]] == "Hide/Sneak" then
			while mq.TLO.Me.Invis() == false do
				mq.delay(100)
				if mq.TLO.Me.AbilityReady("Hide")() == true then
					mq.cmd("/doability hide")
				end
			end
			if mq.TLO.Me.Sneaking() == false then
				while mq.TLO.Me.Sneaking() == false do
					mq.delay(100)
					if mq.TLO.Me.AbilityReady("Sneak")() == true then
						mq.cmd("/doability sneak")
					end
				end
			end
		else
			local ID = class_settings.settings.skill_to_num[invis_type[class_settings.settings.invis[mq.TLO.Me.Class()]]]
			while mq.TLO.Me.AltAbilityReady(ID)() == false do
				mq.delay(50)
			end
			mq.cmdf("/alt act %s", ID)
			mq.delay(500)
			while mq.TLO.Me.Casting() and mq.TLO.Me.Class() ~= "Bard" do
				mq.delay(200)
			end
		end
	end
	mq.delay("1s")
end

local function checkPotionuse()
	buildInvisType()
	if mq.TLO.FindItemCount('Cloudy Potion') == 0 and invis_type[class_settings.settings.invis[mq.TLO.Me.Class()]] == "Potion" then
		CB_Invis = false
		PotionNeed = true
	else
		PotionNeed = false
	end
end

--ACHIEVEMENT Status functions

local function IsCompleted(data)
	--Checks if passed data is completed or needs to be checked against the achievement TLO
    if data == 'Completed' then return true end
    return mq.TLO.Achievement(data).Completed() or false
end

--Compute Counts

local function GetKillCounts(data)
	--Returns a number for the kills needed for achievement
    local Counter = 0
    if not mq.TLO.Achievement(data).Completed() then
        local objective = mq.TLO.Achievement(data).ObjectiveByIndex(1)
		local rc_obj = objective.RequiredCount()
        if rc_obj then
            Counter = objective.RequiredCount() - objective.Count()
        end
    end
    return Counter
end

local function GetGlobalKills()
	--Checks kills against the categories
	local SlayerCount = 0
	local ach_counts = {11000004,11000005,11000006,11000007,11000008,11000009,11000010,11000011,11000012,11000013,11000014,11000015,11000016,11000017,11000018,11000019,
	11000020,11000021,11000022,11000023,11000024,11000025,11000026,11000027,11000030,11000031,11000034,11000035,11000036,11000037,11000041,11000042,11000050,11000051,
	11000059,11000104,11000109,11000111,11000127,11000163,11000166,11000175,11000176}
	for i=1, #ach_counts do
		local Kill_Counter = mq.TLO.Achievement(ach_counts[i]).Completed() and 0 or mq.TLO.Achievement(ach_counts[i]).ObjectiveByIndex(1).RequiredCount() - mq.TLO.Achievement(ach_counts[i]).ObjectiveByIndex(1).Count()
		SlayerCount = SlayerCount + Kill_Counter
	end
	return SlayerCount
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

--CONTENT functions

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

local function testkill(data)
	local sk_count = GetKillCounts(data.Skill)
	local sp_count = GetKillCounts(data.Special)
	local co_count = GetKillCounts(data.Conquest)
	if (0 < sk_count or 0 < sp_count or 0 < co_count) then
		return true
	else
		return false
	end
end


local function racefilterbutton()
    for _,race in ipairs(race_data) do
		local sk_count = GetKillCounts(race.Skill)
		local sp_count = GetKillCounts(race.Special)
		local co_count = GetKillCounts(race.Conquest)
		if (0 < sk_count or 0 < sp_count or 0 < co_count) then
			CB_Race[race.Race] = true
		else
			local testNil = race.Race
			if testNil then
				CB_Race[race.Race] = false
			end
		end
	end
end

local function filterKills(data)
	--builds a table of races that still need kills, or requested from filter
    filteredKillList = {}
	RacesKilled = 0
	filter = string.lower(filter)
    for _,race in ipairs(data) do
		if not testkill(race) then
			RacesKilled = RacesKilled + 1
		end
		if CB_Race[race.Race] then
			if CB_Needed and filter ~= '' then
				local mob_optional = race.Optional
				if not mob_optional and testkill(race) and string.find(race.Race:lower(), filter) then
					table.insert(filteredKillList, race)
				end
			elseif CB_Needed then
				local mob_optional = race.Optional
				if not mob_optional and testkill(race) then
					table.insert(filteredKillList, race)
				end
			elseif filter ~= '' then
				if testkill(race) and string.find(race.Race:lower(), filter) then
					table.insert(filteredKillList, race)
				end
			else
				table.insert(filteredKillList, race)
			end
		end
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

local function GetAchievementName(data)
	return mq.TLO.Achievement(data).Name()
end

--GUI HELPERS

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
			ImGui.SetTooltip(mq.TLO.Achievement(data).ObjectiveByIndex(1).Description())
		end
		return
	end
end

local function HoverButtonZone(data)
	--tooltip to hover the name of the zone above the nav button
	if ImGui.IsItemHovered() then
		ImGui.SetTooltip('Zone: '..data)
	end
end

local function DrawKillCounts()
	ImGui.Text('  Creatures Left: ')
	ImGui.SameLine()
	ImGui.Text('%s  ', currentKill)
	ImGui.SameLine()
	ImGui.Text('  Races Left: ')
	ImGui.SameLine()
	ImGui.Text('%s  ', currentRaces)
end

local function DrawATab(data)
	if ImGui.BeginTabItem(data) then
		tabclick = data
		ImGui.EndTabItem()
	end
end

--Navigation Functions

local function navPause()
	mq.cmd("/nav pause")
	mq.delay(500)
end

local function GetNavCommand (data)
	--converts the data from the Zone keys (zone1, zone2, zone3) to trigger on button push using Relocate or Nav/EasyFind
	--Currently travels from the zone where the button is pushed
	local VividOrange = '\a#f8bd21'
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
		local where = mq.TLO.Zone(data).Name
		printf('\arHeading to: \ag%s\ax', where)
		--warning for people to not play AFK
		printf('%sYou are now running dumb towards %s. Please make sure that you are aware that you could die or get stuck on geometry.\ax',VividOrange, where)
	end
	--Starts the flag for navigating to the zone. If the command fails the cycling check will see navigation stopped and set to false.
	navigatetoZone = true
end

local function CheckNavigateInvis()
	if mq.TLO.Me.Invis() == false then
		navPause()
		invis(class_settings)
		navPause()
	end
end


--DRAW THE GUI (Achievement List table)

function MyTreeNode.new(name, KillCount, childIdx, childCount)
    MyTreeNode.__index = MyTreeNode
    local o = {}
    setmetatable(o, MyTreeNode)
    o.Name = GetAchievementName(name)
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
		if ImGui.IsItemHovered() then
			ImGui.SetTooltip(mq.TLO.Achievement(self.Name).ObjectiveByIndex(1).Description())
		end
        ImGui.TableNextColumn()
        ImGui.Text(self.KillCount)
    end
end

local function buildAchView()
	table.insert(treeview_nodes, MyTreeNode.new(11000000, IsCompleteOrMetaCount(11000000),  1,   3))
	table.insert(treeview_nodes, MyTreeNode.new(11000001, IsCompleteOrMetaCount(11000001),  4,  24))
	table.insert(treeview_nodes, MyTreeNode.new(11000002, IsCompleteOrMetaCount(11000002), 28,  37))
	table.insert(treeview_nodes, MyTreeNode.new(11000003, IsCompleteOrMetaCount(11000003), 65, 114))

	local childcount = 1
	for i=11000004, 11000027 do
		table.insert(treeview_nodes, MyTreeNode.new(i, IsCompleteOrMetaCount(i), childcount, -1))
		childcount = childcount + 1
	end
	childcount = childcount + 1
	for i=11000028, 11000064 do
		table.insert(treeview_nodes, MyTreeNode.new(i, IsCompleteOrMetaCount(i), childcount, -1))
		childcount = childcount + 1
	end
	childcount = childcount + 1
	for i=11000065, 11000178 do
		table.insert(treeview_nodes, MyTreeNode.new(i, IsCompleteOrMetaCount(i), childcount, -1))
		childcount = childcount + 1
	end
end

local function DrawAchievementTable()
	ImGui.PushStyleVar(ImGuiStyleVar.IndentSpacing, 0.0)
    if ImGui.TreeNode('Slayer') then
        if ImGui.BeginTable('##3ways', 2, bit32.bor(ImGuiTableFlags.BordersV, ImGuiTableFlags.BordersOuterH, ImGuiTableFlags.Resizable, ImGuiTableFlags.RowBg, ImGuiTableFlags.NoBordersInBody)) then
            -- The first column will use the default _WidthStretch when ScrollX is Off and _WidthFixed when ScrollX is On
            ImGui.TableSetupColumn('Name', ImGuiTableColumnFlags.NoHide)
            ImGui.TableSetupColumn('KillCount', ImGuiTableColumnFlags.WidthFixed, TEXT_BASE_WIDTH * 13.0)
            treeview_nodes[1]:display(treeview_nodes)
            ImGui.EndTable()
        end
        ImGui.TreePop()
    end
end

--DRAW THE GUI (Options)

local function DrawInvisCombo()
	invis_type = {}
	for word in
	string.gmatch(class_settings.settings.class_invis[mq.TLO.Me.Class()], "([^|]+)")
	do
		table.insert(invis_type, word)
	end
	ImGui.PushItemWidth(230)
	class_settings.settings.invis[mq.TLO.Me.Class()], changed = ImGui.Combo(
		"##InvisType",
		class_settings.settings.invis[mq.TLO.Me.Class()],
		invis_type,
		#invis_type,
		#invis_type
	)
	if changed then
		changed = false
		class_settings.saveSettings()
	end
end

local function helperShards()
	ImGui.Text("Table Flipper (Shard's Landing) ")
	ImGui.SameLine()
	if (ImGui.Button("Go To Zone SL")) then
		if mq.TLO.Zone.ShortName() == 'shardslanding' then
			print('You are already in the zone.')
		else
			mq.cmd('/travelto shardslanding')
			navigatetoZone = true
		end
	end
	ImGui.SameLine()
	if (ImGui.Button("Go To Spot SL")) then
		if mq.TLO.Zone.ShortName() == 'shardslanding' then
			mq.cmd('/nav spawn object an eerily familiar plant')
			navigatetoZone = true
		else
			mq.cmd('/travelto shardslanding')
			print('You need to travel to the zone.')
		end
	end
	ImGui.SameLine()
	if (ImGui.Button("Start Helper SL")) then
		print('Adjust your automation as you desire, request paused.')
		mq.cmdf('/lua run %s/skull.lua', dir_name)
	end
	ImGui.SameLine()
	if (ImGui.Button("Stop Helper SL")) then
		mq.cmdf('/lua stop %s/skull.lua', dir_name)
	end
end

local function helperUndershore()
	ImGui.Text('Table Flipper (The Undershore) ')
	ImGui.SameLine()
	if (ImGui.Button("Go To Zone TU")) then
		if mq.TLO.Zone.ShortName() == 'eastkorlach' then
			print('You are already in the zone.')
		else
			mq.cmd('/travelto eastkorlach')
			navigatetoZone = true
		end
	end
	ImGui.SameLine()
	if (ImGui.Button("Go To Spot TU")) then
		if mq.TLO.Zone.ShortName() == 'eastkorlach' then
			mq.cmd('/nav spawn npc Freemind Cipher')
			navigatetoZone = true
		else
			mq.cmd('/travelto eastkorlach')
			print('You need to travel to the zone.')
		end
	end
	ImGui.SameLine()
	if (ImGui.Button("Start Helper TU")) then
		print('Adjust your automation as you desire, request paused.')
		mq.cmdf('/lua run %s/mindspore.lua',dir_name)
	end
	ImGui.SameLine()
	if (ImGui.Button("Stop Helper TU")) then
		mq.cmdf('/lua stop %s/mindspore.lua',dir_name)
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
	ImGui.Separator()
	ImGui.Text('Helpers:')
	helperShards()
	helperUndershore()
end

--DRAW THE GUI

local function DrawButtons(item)
	--draws and populates the nav buttons on each line if zone data is available
	if (ImGui.Button("Z1")) then
		GetNavCommand(item.zone1)
	end
	HoverButtonZone(item.zone1)

	for i=2,maxZones,1 do
		if item['zone'..i] ~= nil then
			ImGui.SameLine()
			if (ImGui.Button("Z"..i)) then
				GetNavCommand(item['zone'..i])
			end
			HoverButtonZone(item['zone'..i])
		end
	end
end

local function racefilterpopup()

	ImGui.SetNextWindowSize(ImVec2(1000,0))
	if ImGui.BeginPopupContextItem('Race_Filters') then
        ImGui.Text('Races: ')
		ImGui.SameLine()
		if ImGui.Button('Needed?') then
			racefilterbutton()
			filterKills(race_data)
		end
		ImGui.Separator()
		local counting = 0
		local changed
		ImGui.Columns(5, '#checkboxes')
		ImGui.SetColumnWidth(1,200)
		ImGui.SetColumnWidth(2,200)
		ImGui.SetColumnWidth(3,200)
		ImGui.SetColumnWidth(4,200)
		ImGui.SetColumnWidth(5,200)
			for _,k in ipairs(CB_Race) do
				counting = counting + 1
				if counting <= 26 then
						local textchange = string.sub(k,1,19)
						CB_Race[k], changed = ImGui.Checkbox(textchange, CB_Race[k])
						if changed then filterKills(race_data) end
				else
					ImGui.NextColumn()
					counting = 0
				end
			end
		ImGui.EndPopup()
	end
end

local function BuildTopPanel()
	--Build top header of gui
	ImGui.SmallButton(ICONS.MD_SETTINGS)
	ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 10, 10)
	racefilterpopup()
	ImGui.PopStyleVar()
    ImGui.SameLine()
	ImGui.Text('Race:')
	ImGui.SameLine()
	ImGui.SetNextItemWidth(100)
	local changed
	filter, changed = ImGui.InputText('##Filter', filter)
	if ImGui.IsItemHovered() then ImGui.SetTooltip('Will filter against the Races you have to complete.') end
	if changed then filterKills(race_data) end
	ImGui.SameLine()
	CB_Needed,changed = ImGui.Checkbox('Needed  ', CB_Needed)
	if changed then filterKills(race_data) end
	if ImGui.IsItemHovered() then ImGui.SetTooltip('Will show only Races yet to be completed.') end

end

local function DrawRaceCellContents(data)
	if GetDisplayText(data) == 'Completed' then
		ImGui.TextColored(ImVec4(1.0, 1.0, 0.0, 1.0), "Completed")
	else
		ImGui.Text(GetDisplayText(data))
	end
	HoverToolTipClue(data)
end

local function DrawRaceTable()
	--Draw the race table tab
	if ImGui.BeginTable('##List_table', column_count, bit32.bor(ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.RowBg, ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.ScrollY)) then
		ImGui.TableSetupColumn('Race', 0, 150, ColumnID_Race)
		ImGui.TableSetupColumn('Skill', 0, 70, ColumnID_Skill)
		ImGui.TableSetupColumn('Special', 0, 70, ColumnID_Special)
		ImGui.TableSetupColumn('Conquest', 0, 70, ColumnID_Conquest)
		ImGui.TableSetupColumn('Zones', 0, 150, ColumnID_Zones)
		ImGui.TableSetupScrollFreeze(0, 1)
		ImGui.TableHeadersRow()
		local clipper = ImGuiListClipper.new()
		clipper:Begin(#filteredKillList)
		while clipper:Step() do
			for row_n = clipper.DisplayStart, clipper.DisplayEnd - 1, 1 do
				local item = filteredKillList[row_n + 1]
				if item.Race == nil then goto continue end
				ImGui.PushID(item)
					ImGui.TableNextRow()
					ImGui.TableNextColumn()
					ImGui.TextWrapped(item.Race)
					ImGui.TableNextColumn()
					DrawRaceCellContents(item.Skill)
					ImGui.TableNextColumn()
					DrawRaceCellContents(item.Special)
					ImGui.TableNextColumn()
					DrawRaceCellContents(item.Conquest)
					ImGui.TableNextColumn()
					DrawButtons(item)
					ImGui.TableNextColumn()
				ImGui.PopID()
				::continue::
			end
		end
		ImGui.EndTable()
	end
end

local function DrawMainGui()
	ImGui.Text('Carnage')
	ImGui.Text('Version: %s', Version)
	ImGui.Text('Current Class: %s', mq.TLO.Me.Class())
	ImGui.SameLine()
	ImGui.Text('Level: %s', mq.TLO.Me.Level())
	ImGui.Text('Cloudy Potions: %s', mq.TLO.FindItemCount('Cloudy Potion'))
	buildInvisType()
	ImGui.Text('Innate Invis: %s', invis_type[class_settings.settings.invis[mq.TLO.Me.Class()]])
	ImGui.Spacing()
	ImGui.TextWrapped('Carnage will help your character achieve Megadeath.')
	ImGui.Spacing()
	ImGui.TextWrapped('It gives the minumum races needed to kill to achieve this, as well as, the zones that those races can appear in. It can let you travel to those zones with a click.')
	ImGui.Spacing()
	ImGui.TextWrapped('The Creatures Left and Races Left are how many are need to achieve. You may happen to kill more before you get the achievement as some of the races overlap the different achievements. Killing races that are not listed may decrease counts. You can hover over the count to get the true criteria.')
	ImGui.Spacing()
	ImGui.TextWrapped('There are helpers under the Options menu. Four buttons: one to get you to the zone, one to get you to the spot in the zone, one to start a lua to kill things, one to stop that lua. The helper will run once you start it until you stop it or you completed the achievement associated with it.')
	ImGui.Spacing()
	ImGui.TextWrapped('There is some delay built into the helpers so it looks like an OCD human is doing it. The helper will also /hidecorpse alwaysnpc and /hidecorpse none when it ends.')
	
end

local function DrawPanels(data)
	if data == 'About' then
		DrawMainGui()
	end
	if data == 'Races To Kill' then
		BuildTopPanel()
		DrawRaceTable()
	end
	if data == 'Achievements' then
		DrawAchievementTable()
	end
	if data == 'Options' then
		DrawOptions()
	end
end

local function DisplayGUI()
	--draws something on the screen
	if not openGUI then
		running = false
	end
	ImGui.SetNextWindowPos(400, 400, ImGuiCond.Once)
    ImGui.SetNextWindowSize(800, 650, ImGuiCond.Once)
	if CB_Size then
		ImGui.SetNextWindowSizeConstraints(ImVec2(950, 250), ImVec2(FLT_MAX, FLT_MAX))
	else
		ImGui.SetNextWindowSizeConstraints(ImVec2(650, 250), ImVec2(FLT_MAX, FLT_MAX))
	end
	openGUI, drawGUI = ImGui.Begin('Carnage: Gotta Kill Them All', openGUI, bit32.bor(ImGuiWindowFlags.None))
	if CB_Size then ImGui.SetWindowFontScale(1.5) else ImGui.SetWindowFontScale(1.0) end
	if drawGUI and not mq.TLO.Me.Zoning() then
		if ImGui.BeginTabBar('CarnageTabs', bit32.bor(ImGuiTabBarFlags.None)) then
			DrawATab('Races To Kill')
			DrawATab('Achievements')
			DrawATab('Options')
			DrawATab('About')
			ImGui.EndTabBar()
		end
		ImGui.SameLine()
		DrawKillCounts()
		DrawPanels(tabclick)
	end
	ImGui.End()
end

--CHECKING STUFF

local function CheckNavigating()
	if navigatetoZone and CB_Invis then
		CheckNavigateInvis()
	end
	if mq.TLO.Navigation.Active() then
	else
		navigatetoZone = false
	end
end

local function CheckCounts()
	currentKill 			= GetGlobalKills()
	currentRaces 			= RaceCount 	- RacesKilled
end

--START STUFF


local function load_data(data)
	--loads data from the racedata file. does initial checks for achievement completed and changes those from the keyvalue to 'Completed'
	--calculates total kills needed for MegaDeath
	--calculates total races at a minimum needed to be killed for MegaDeath (not races left to kill)
	print('\arLoading race data from file.\ax')
	for k,v in ipairs(data) do
		RaceCount = RaceCount + 1
		for key, value in pairs(v) do
			if SlayerKeys[key] then
				if mq.TLO.Achievement(value).Completed() then
					race_data[k][key] = 'Completed'
				end
			end
		end
	end
	for k in ipairs(race_data) do
		table.insert(CB_Race,race_data[k].Race)
		CB_Race[race_data[k].Race] = true
	end
	printf('\arRaces marked for death: \ay%s\ax', RaceCount)
	printf('\arCreatures left to Kill: \ay%s\ax', GetGlobalKills())
	filterKills(data)
end

local function initializeDeath()
	load_data(race_data)
	buildAchView()
	--Define trigger events to update filterdata
	mq.event('SomeoneKills','#*#has been slain by#*#',DeathCheckUpdate)
	mq.event('YouKill','#*#You have slain#*#',DeathCheckUpdate)
	--check for plugins that are used in this script
	for _, plugin in ipairs(plugins) do
		if mq.TLO.Plugin(plugin)() == nil then
			printf('"\ar%s \aois required for this script.', plugin)
			printf('\aoLoaded \ar%s \aowith \agnoauto\ao.', plugin)
			mq.cmdf('/plugin %s noauto', plugin)
		end
	end
	class_settings.loadSettings()
	mq.imgui.init('drawGUI', DisplayGUI)
end

initializeDeath()

while running == true do
	checkPotionuse()
	CheckNavigating()
	CheckCounts()
	mq.doevents()
	mq.delay('1s')
end