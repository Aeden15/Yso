local network,feedback,downloads=arg[1],arg[2],arg[3]
assert(network and feedback and downloads,'pass extracted package fixtures')
local notes,requests,timers={},0,0
Legacy={NDB={db={Existing={city='Ashtan',title='Existing'}}},Settings={NDB={}}}
cecho=function(message) notes[#notes+1]=message end
Legacy.echo=function(message) notes[#notes+1]=message end
postHTTP=function() error('Discord posting must be removed') end
downloadFile=function() requests=requests+1 end
tempTimer=function() timers=timers+1;error('cache lookup must not schedule network timing') end
registerAnonymousEventHandler=function() return 1 end
getMudletHomeDir=function() return 'mock-profile' end
local cached,read_paths=nil,{}
io.open=function(path)
 read_paths[#read_paths+1]=path
 if not cached then return nil,'missing' end
 return {read=function() return 'cached-json' end,close=function() return true end}
end
yajl={to_value=function() return cached end}
dofile(network);dofile(feedback);dofile(downloads)
assert(Legacy.Ideas('idea')==false)
assert(Feedback('report')==false)
assert(Download('Fresh')==false and Download('Update')==false)
assert(Legacy_Downloads()==false)
assert(requests==0,'local feedback sent network requests')
assert(Legacy.NDB.getOnline()==false)
assert(Legacy.NDB.db.Existing.city=='Ashtan','offline refresh erased existing NDB records')
local before=#read_paths
assert(Legacy.NDB.lookup('../escape')==false)
assert(Legacy.NDB.lookup('Foe/child')==false)
assert(#read_paths==before,'invalid name reached the filesystem')
assert(Legacy.NDB.lookup('Missing')==false)
assert(requests==0 and timers==0,'missing cache attempted refresh or deferred read')
cached={name='Foe',fullname='Foe the Wise',city='ashtan',class='magi',house='(none)',level='100',xp_rank='10'}
local highlighted=0
Legacy.Settings.NDB.newHL=function(name) assert(name=='Foe');highlighted=highlighted+1 end
assert(Legacy.NDB.lookup('foe')==true)
assert(Legacy.NDB.db.Foe.class=='Magi' and Legacy.NDB.db.Foe.city=='Ashtan')
assert(Legacy.NDB.db.Foe.level==100 and highlighted==1)
assert(Legacy.NDB.db.Existing.city=='Ashtan')
cached={name='Other',city='shallam'}
assert(Legacy.NDB.lookup('Foe')==false,'mismatched cache record was trusted')
assert(Legacy.NDB.db.Foe.city=='Ashtan','bad cache overwrote known record')
cached={name='Foe',city={},class={},house={}}
assert(Legacy.NDB.lookup('Foe')==false,'malformed fields were accepted')
cached={name='Foe',city='ashtan',class='magi',house='(none)'}
yajl=nil
assert(Legacy.NDB.lookup('Foe')==true,'known in-memory cache should work without decoder')
Legacy.NDB.db.Foe=nil
assert(Legacy.NDB.lookup('Foe')==false,'missing decoder should fail safely')
local status=Legacy.NDB.network_status()
assert(status.mode=='cache_only' and status.refresh_enabled==false)
assert(status.reason=='secure_endpoint_unverified' and status.cached_records==1)
assert(requests==0 and timers==0)
print('PASS: local-only feedback, validated cache lookup, safe missing decoder, and NDB status')
