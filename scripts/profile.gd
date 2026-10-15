class_name ArenaProfile
extends RefCounted
var nickname=''
var music_volume=.45
var sfx_volume=.75

static func clean_name(value: String) -> String:
	var out='';var allowed=RegEx.new();allowed.compile('[\\p{L}\\p{N} _.-]')
	for character in value:
		if allowed.search(character):out+=character
		if out.length()>=16:break
	out=' '.join(out.split(' ',false)).strip_edges()
	return 'Pilot' if out.is_empty() or out.to_upper()=='CPU' else out

static func random_name() -> String:
	var colors=['Sunny','Turbo','Lucky','Brave','Mango','Jolly','Cosmic','Bouncy']
	var bots=['Bolt','Gear','Rover','Crab','Kiwi','Otter','Panda','Comet']
	return colors.pick_random()+bots.pick_random()+str(randi_range(10,99))

func read():
	var data={}
	if OS.has_feature('web'):
		var raw=JavaScriptBridge.eval("(()=>{try{return localStorage.getItem('mustika-profile')||'{}'}catch(e){return '{}'}})()")
		var parsed=JSON.parse_string(str(raw))
		if parsed is Dictionary:data=parsed
	else:
		var config=ConfigFile.new()
		if config.load('user://profile.cfg')==OK:data=config.get_value('player','profile',{})
	nickname=clean_name(str(data.get('nickname',random_name())))
	music_volume=clampf(float(data.get('music',.45)),0,1);sfx_volume=clampf(float(data.get('sfx',.75)),0,1)
	save()

func save():
	var data={'nickname':nickname,'music':music_volume,'sfx':sfx_volume}
	if OS.has_feature('web'):
		JavaScriptBridge.eval("try{localStorage.setItem('mustika-profile',"+JSON.stringify(JSON.stringify(data))+")}catch(e){}")
	else:
		var config=ConfigFile.new();config.set_value('player','profile',data);config.save('user://profile.cfg')
