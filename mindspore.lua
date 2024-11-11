local mq = require('mq')

print ('Helper started. Hiding NPC corpses.')
mq.cmd("/hidecorpse alwaysnpc")

--while not mq.TLO.Achievement(11000027).Completed() and mq.TLO.Zone.ShortName() == 'eastkorlach' do
while mq.TLO.Zone.ShortName() == 'eastkorlach' do
	--mq.cmd('/target clear')
	if mq.TLO.Spawn('Freemind Cipher').Distance() > 15 and mq.TLO.Spawn('Freemind Cipher') ~= nil then
		mq.cmd('/navigate spawn npc Freemind Cipher | log=off')
		while mq.TLO.Navigation.Active() do
			mq.delay(100)
		end
	else
		if mq.TLO.SpawnCount("a budding mindspore npc targetable")() > 0 then
			mq.delay('2s')
			mq.cmd("/eqtarget a_budding_mindspore npc targetable")
			mq.delay(50)
			while mq.TLO.Target.CleanName() == 'a budding mindspore' do
				mq.cmd("/squelch /face fast")
				mq.cmd("/stick 14")
				mq.cmd("/attack on")
				mq.delay(50)
			end
			mq.cmd("/stick off")
		end
		mq.delay('1s')
	end
end

print ('Helper stopped. Achievement completed, or wrong zone.')
mq.cmd("/hidecorpse none")