local mq = require('mq')

print ('Helper started.')

while not mq.TLO.Achievement(11000027).Completed() and mq.TLO.Zone.ShortName() == 'shardslanding' do
    local distanceToMob = mq.TLO.Spawn('an eerily familiar plant object').Distance()
    local MobHealth = mq.TLO.Spawn('an eerily familiar plant object').PctHPs()
    if distanceToMob and MobHealth > 10 then
        mq.cmd('/navigate spawn object an eerily familiar plant | distance=3 log=off')
        mq.delay(100)
        while mq.TLO.Navigation.Active() do
			mq.delay(50)
		end
        mq.cmd("/eqtarget an eerily familiar plant object")
        mq.delay(10)
        mq.cmd("/open")
    end
    mq.delay('1s')
end

print ('Helper stopped. Achievement completed, or wrong zone.')