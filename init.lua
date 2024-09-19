local mq					= require('mq')
local imgui					= require 'ImGui'
local race_data				= require('raceData')
local TLO					= mq.TLO
local Me					= TLO.Me
local ach					= TLO.Achievement
local Zone 					= TLO.Zone
local SlayerKeys			= {Skill=1,Conquest=1,Special=1}
local running 				= true
local window_flags 			= bit32.bor(ImGuiWindowFlags.None)
local treeview_table_flags	= bit32.bor(ImGuiTableFlags.Reorderable, ImGuiTableFlags.Hideable, ImGuiTableFlags.RowBg, ImGuiTableFlags.Borders, ImGuiTableFlags.Resizable, ImGuiTableFlags.ScrollY)
local openGUI, drawGUI		= true, true
local guiheader 			= 'Carnage: Gotta Kill Them All'
local CB_Needed				= false
local CB_Size				= false
local column_count 			= 5
local SlayerCount			= 0
local SlayerKilled			= 0
local RaceCount				= 0
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

----------------------------------------------------------------------
---Thank you aquietone, brainiac, dannuic, Derple, kaen01, grimmier
---for putting up with me and helping me wrap my head around my logic
---
---Comments brought to you by the song: Look at what you made me do.
---
---SlayerKeys was voted on, by aquietone, as the best alternative to
---                                                   someSetOfKeys
----------------------------------------------------------------------

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

local function GetNavCommand (data)
	--converts the data from the Zone keys (zone1, zone2, zone3) to trigger on button push using Relocate or Nav/EasyFind
	--Currently travels from the zone where the button is pushed
	local VividOrange = '\a#f8bd21'
	local where = Zone(data).Name
	printf('\arHeading to: \ag%s\ax', where)
	if data == 'theater' then
		mq.cmd('/relocate blood')
	else
		mq.cmdf('/travelto %s',data)
	end
	--warning for people to not play AFK
	printf('%sYou are now running dumb towards %s. Please make sure that you are aware that you could die or get stuck on geometry.\ax',VividOrange, where)
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
        if (0 < sk_count or 0 < sp_count or 0 < co_count) and string.find(race.Race:lower(), filter) then
            table.insert(filteredKillList, race)
		else
			RacesKilled = RacesKilled + 1
        end
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
				if ach(value).Completed() then
					race_data[k][key] = 'Completed'
				elseif value ~= 'Not Used' and value ~= nil then
					local Kill_Counter = ach(value).Completed() and 0 or ach(value).ObjectiveByIndex(1).RequiredCount() - ach(value).ObjectiveByIndex(1).Count()
					SlayerCount = SlayerCount + Kill_Counter
				end
			end
		end
	end
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
	ImGui.Text('  Creatures Left: ')
	ImGui.SameLine()
	local currentKill = SlayerCount - SlayerKilled
	ImGui.Text('%s  ', currentKill)
	ImGui.SameLine()
	ImGui.Text('  Races Left: ')
	ImGui.SameLine()
	local RacesLeft = RaceCount	 - RacesKilled
	ImGui.Text('%s  ', RacesLeft)
	ImGui.SameLine()
	CB_Needed = imgui.Checkbox('Needed  ', CB_Needed)
	if ImGui.IsItemHovered() then ImGui.SetTooltip('Will show only Races yet to be completed.') end
	ImGui.SameLine()
	--Im blind as a bat using a 4K monitor with EQ in 4K, but all the pretty colors
	CB_Size = imgui.Checkbox('Text Size  ', CB_Size)
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
					ImGui.Text(GetDisplayText(item.Skill))
					ImGui.TableNextColumn()
					ImGui.Text(GetDisplayText(item.Special))
					ImGui.TableNextColumn()
					ImGui.Text(GetDisplayText(item.Conquest))
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
	printf('\arTimepassed: \ay%s\ax', HasTimePassed)
	if 10 < HasTimePassed then
		filterKills(race_data)
		LastKill = os.clock()
	end
end

local function DisplayGUI()
	--draws something on the screen
	if not openGUI then running = false end
	ImGui.SetNextWindowPos(400, 400, ImGuiCond.Once)
    ImGui.SetNextWindowSize(800, 650, ImGuiCond.Once)
	openGUI, drawGUI = ImGui.Begin(guiheader, openGUI, window_flags)
	if CB_Size then ImGui.SetWindowFontScale(1.5) else ImGui.SetWindowFontScale(1.0) end
	if drawGUI and not Me.Zoning() then
		BuildTopPanel()
		DrawRaceTable()
	end
	ImGui.End()
end

local function initializeDeath()
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
end

load_data(race_data)
initializeDeath()
mq.imgui.init('drawGUI', DisplayGUI)

while running == true do
	--Check for events
	mq.doevents()
	mq.delay('1s')
end