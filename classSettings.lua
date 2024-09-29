local mq = require("mq")
local class_settings = {}
class_settings.settings = {}
class_settings.configPath = mq.configDir .. '/carnage/' .. mq.TLO.Me.CleanName() .. '_classSettings.lua'

function class_settings.loadSettings()
	local configData, err = loadfile(class_settings.configPath)
	if err then
		class_settings.createSettings()
	elseif configData then
		class_settings.settings = configData()
		if class_settings.settings.skill_to_num == nil then
			class_settings.settings.skill_to_num = {
				["Shauri's Sonorous Clouding"] = 231,
				["Natural Invisibility"] = 980,
				["Innate Camouflage"] = 80,
				["Perfected Invisibility"] = 3812,
				["Cloak of Shadows"] = 531,
				["Silent Presence"] = 3730,
			}
			class_settings.saveSettings()
		end
	end
end

function class_settings.createSettings()
	---@class Class_Settings_Settings
	class_settings.settings = {
		["invis"] = {
			["Bard"] = 1,
			["Beastlord"] = 1,
			["Berserker"] = 1,
			["Cleric"] = 1,
			["Druid"] = 1,
			["Enchanter"] = 1,
			["Magician"] = 1,
			["Monk"] = 1,
			["Necromancer"] = 1,
			["Paladin"] = 1,
			["Ranger"] = 1,
			["Rogue"] = 1,
			["Shadow Knight"] = 1,
			["Shaman"] = 1,
			["Warrior"] = 1,
			["Wizard"] = 1,
		},
		["class_invis"] = {
			["Bard"] = "Shauri's Sonorous Clouding|Potion",
			["Beastlord"] = "Natural Invisibility|Potion",
			["Berserker"] = "Potion",
			["Cleric"] = "Potion",
			["Druid"] = "Innate Camouflage|Potion",
			["Enchanter"] = "Perfected Invisibility|Potion",
			["Magician"] = "Perfected Invisibility|Potion",
			["Monk"] = "Potion",
			["Necromancer"] = "Cloak of Shadows|Potion|Circlet of Shadows",
			["Paladin"] = "Potion",
			["Ranger"] = "Innate Camouflage|Potion",
			["Rogue"] = "Hide/Sneak|Potion",
			["Shadow Knight"] = "Cloak of Shadows|Potion|Circlet of Shadows",
			["Shaman"] = "Silent Presence|Potion",
			["Warrior"] = "Potion",
			["Wizard"] = "Perfected Invisibility|Potion",
		},
		["skill_to_num"] = {
			["Shauri's Sonorous Clouding"] = 231,
			["Natural Invisibility"] = 980,
			["Innate Camouflage"] = 80,
			["Perfected Invisibility"] = 3812,
			["Cloak of Shadows"] = 531,
			["Silent Presence"] = 3730,
		},
	}
	class_settings.saveSettings()
end

--Save Settings
function class_settings.saveSettings()
	mq.pickle(class_settings.configPath, class_settings.settings)
end

return class_settings
