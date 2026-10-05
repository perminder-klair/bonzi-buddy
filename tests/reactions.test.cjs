const fs=require('node:fs'),vm=require('node:vm'),assert=require('node:assert/strict');
const rules={};vm.createContext(rules);vm.runInContext(fs.readFileSync('app/ReactionRules.js','utf8'),rules);
assert.equal(rules.focusReason({fullscreen:true,blockedApp:false},false,{fullscreenQuiet:true,dndQuiet:true}),'Fullscreen');
assert.equal(rules.focusReason({},true,{dndQuiet:true}),'Do Not Disturb');
assert.equal(rules.focusReason({blockedApp:true},false,{}),'Chosen app');
assert.equal(rules.focusReason({fullscreen:true},false,{fullscreenQuiet:false}), '');
assert.equal(rules.canReact({hidden:false,sleeping:false,focus:'',personality:'quiet',last:0,now:1000000,cooldown:30}),false);
assert.equal(rules.canReact({hidden:false,sleeping:false,focus:'',personality:'balanced',last:100000,now:110000,cooldown:30}),false);
assert.equal(rules.canReact({hidden:false,sleeping:false,focus:'',personality:'balanced',last:100000,now:140000,cooldown:30}),true);
assert.equal(rules.canReact({hidden:true,focus:'',personality:'chatty',last:0,now:1e6,cooldown:30}),false);
const home={x:10,y:10};
const moved=rules.avoidWindow(home,100,{width:1000,height:800},{x:0,y:0,width:500,height:800});
assert(moved.x>=500 && moved.x+100<=1000);
const full=rules.avoidWindow(home,100,{width:1000,height:800},{x:0,y:0,width:1000,height:800});
assert.equal(full.x,10);assert.equal(full.y,10); // no pointless hopping when all corners overlap
const other=rules.avoidWindow(home,100,{width:1000,height:800},null);assert.equal(other.x,10);
console.log('PASS: focus gates, personality, cooldown, hidden state, overlap avoidance');

const move = {menu:false,dragging:false,hovered:false,now:100000,dragUntil:0,lastMove:0,sampleAge:100,cursor:{x:900,y:700},x:10,y:10,size:160};
assert.equal(rules.canAvoid(move),true);
for(const change of [{menu:true},{hovered:true},{dragging:true},{sampleAge:800},{cursor:null},{lastMove:90000},{dragUntil:110000},{cursor:{x:210,y:210}}]) assert.equal(rules.canAvoid({...move,...change}),false);
console.log('PASS: catchable avoidance, pointer proximity, fresh samples, menu/drag freezes, movement cooldown');
