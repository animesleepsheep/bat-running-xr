// BAT BALL RUN V5.1 index.html, createMascot / wingGeometry / starGeometry.
// Adapted extraction of the BAT branch: same palettes, shapes, transforms and materials.
// Original ground effects, boost particles and game-state logic are intentionally excluded.
import * as THREE from 'three';
export function buildBat(lod='standard'){
  const low=lod==='lite';
  const mat=(c,rough=.55,metal=.08,emissive=0)=>new THREE.MeshStandardMaterial({color:c,roughness:rough,metalness:metal,emissive,emissiveIntensity:emissive?.27:0});
  const geo={sphere:new THREE.SphereGeometry(1,low?14:28,low?10:20),foot:new THREE.SphereGeometry(1,low?10:18,low?8:14),box:new THREE.BoxGeometry(1,1,1),ear:new THREE.ConeGeometry(1,1,low?8:16),cyl:new THREE.CylinderGeometry(1,1,1,low?10:20),torus:new THREE.TorusGeometry(1,.22,low?6:12,low?12:24)};
  const pal={main:0xb498ff,belly:0xf6eaff,wing:0xff5ec1,ear:0xffaddb,shoe:0x9bfff1};
  function mesh(g,m,x=0,y=0,z=0,sx=1,sy=1,sz=1){const o=new THREE.Mesh(g,m);o.position.set(x,y,z);o.scale.set(sx,sy,sz);return o}
  function wingGeometry(side,color){
    const s=new THREE.Shape();s.moveTo(0,0);
    s.quadraticCurveTo(.42,.30,1.65,.71);s.lineTo(1.97,.38);
    s.quadraticCurveTo(1.71,.12,1.71,-.10);s.quadraticCurveTo(1.39,.13,1.25,-.23);
    s.quadraticCurveTo(.91,-.06,.73,-.44);s.quadraticCurveTo(.40,-.21,.19,-.43);s.quadraticCurveTo(.24,-.10,0,0);
    const g=new THREE.ExtrudeGeometry(s,{depth:0.032,bevelEnabled:true,bevelThickness:0.01,bevelSize:0.01,bevelSegments:low?1:2,curveSegments:low?7:14});
    if(side<0){
      g.scale(-1,1,1);
      // Reverse mirrored triangles for consistent front faces in native renderers.
      const p=g.getAttribute('position'),n=g.getAttribute('normal'),uv=g.getAttribute('uv');
      for(let i=0;i<p.count;i+=3)for(const a of [p,n,uv])if(a){
        for(let j=0;j<a.itemSize;j++){const arr=a.array;const k=(i+1)*a.itemSize+j,m=(i+2)*a.itemSize+j;[arr[k],arr[m]]=[arr[m],arr[k]];}
      }
    }
    const attr=g.getAttribute('position'),base=new THREE.Color(color),tip=new THREE.Color(color).lerp(new THREE.Color(0xfff3f9),.24),c=new THREE.Color(),colors=[];
    for(let i=0;i<attr.count;i++){const amt=Math.min(1,Math.abs(attr.getX(i))/2);c.copy(base).lerp(tip,amt);colors.push(c.r,c.g,c.b)}
    g.setAttribute('color',new THREE.Float32BufferAttribute(colors,3));return g;
  }
  function starGeometry(radius=.14){
    const s=new THREE.Shape();for(let i=0;i<10;i++){const a=i*Math.PI/5-Math.PI/2,r=radius*(i%2?.49:1),x=Math.cos(a)*r,y=Math.sin(a)*r;if(i===0)s.moveTo(x,y);else s.lineTo(x,y)}s.closePath();return new THREE.ShapeGeometry(s);
  }
  const fangGeo=new THREE.BufferGeometry();fangGeo.setAttribute('position',new THREE.Float32BufferAttribute([-.15,.70,-.555,-.08,.70,-.555,-.115,.61,-.558,.08,.70,-.555,.15,.70,-.555,.115,.61,-.558],3));fangGeo.computeVertexNormals();
  const root=new THREE.Group(),pose=new THREE.Group(),core=new THREE.Group();root.name='BatMascot';pose.name='BatPose';core.name='BatCore';root.add(pose);pose.add(core);
  const skin=mat(pal.main,.44,.05),belly=mat(pal.belly,.65),dark=mat(0x171329,.4,.2),wingMat=new THREE.MeshStandardMaterial({color:0xffffff,vertexColors:true,side:THREE.DoubleSide,roughness:.58,metalness:.06,emissive:pal.wing,emissiveIntensity:.09}),soft=mat(pal.shoe,.42,.1),earMat=mat(pal.ear,.48),eyeWhite=mat(0xffffff,.15),pupil=mat(0x181226,.1),shine=new THREE.MeshBasicMaterial({color:0xffffff});
  const goldMat=mat(0xffd24c,.28,.65,0x664400),visorMat=mat(0x5efce8,.18,.35,0x18a898),collarMat=mat(0xff477e,.38,.18,0x44081c),soleMat=mat(0xffffff,.5);
  const b=mesh(geo.sphere,skin,0,.89,0,.53,.54,.48);b.name='Body';core.add(b);
  core.add(mesh(geo.sphere,belly,0,.76,-.34,.35,.35,.15));
  core.add(mesh(geo.sphere,belly,0,.79,-.478,.175,.145,.06));
  const collar=mesh(geo.torus,collarMat,0,.56,0,.38,.36,.32);collar.rotation.x=Math.PI/2;collar.name='RacingCollar';core.add(collar);
  core.add(mesh(geo.sphere,goldMat,0,.55,-.43,.075,.075,.045));
  for(const side of [-1,1]){
    const ribbon=mesh(geo.box,collarMat,side*.11,.50,.46,.075,.22,.028);ribbon.rotation.z=side*.24;ribbon.rotation.x=.28;core.add(ribbon);
  }
  const goggleStrap=mesh(geo.torus,dark,0,1.16,-.01,.47,.44,.18);goggleStrap.rotation.x=Math.PI/2-.18;goggleStrap.name='GoggleStrap';core.add(goggleStrap);
  for(const side of [-1,1]){
    const rim=mesh(geo.cyl,goldMat,side*.19,1.19,-.41,.13,.045,.13);rim.rotation.x=Math.PI/2-.22;rim.rotation.z=side*.12;core.add(rim);
    const lens=mesh(geo.sphere,visorMat,side*.19,1.19,-.435,.105,.095,.035);lens.rotation.z=side*.12;lens.name=side<0?'GoggleL':'GoggleR';core.add(lens);
  }
  const wingL=new THREE.Group(),wingR=new THREE.Group();wingL.name='BatWingL';wingR.name='BatWingR';core.add(wingL,wingR);
  for(const side of [-1,1]){
    core.add(mesh(geo.sphere,eyeWhite,side*.23,.97,-.435,.16,.2,.07));
    core.add(mesh(geo.sphere,pupil,side*.23,.96,-.496,.084,.115,.035));
    core.add(mesh(geo.sphere,shine,side*.26,1.016,-.528,.025,.029,.016));
    const brow=mesh(geo.box,dark,side*.23,1.11,-.455,.12,.028,.03);brow.rotation.z=-side*.14;core.add(brow);
  }
  core.add(mesh(geo.sphere,dark,0,.78,-.543,.048,.038,.02));
  const backmark=new THREE.Mesh(starGeometry(.16),new THREE.MeshBasicMaterial({color:pal.ear,side:THREE.DoubleSide}));backmark.position.set(0,.98,.495);backmark.name='BackStar';core.add(backmark);
  function foot(side){
    const f=new THREE.Group();f.name=side<0?'BatFootL':'BatFootR';f.position.set(side*.27,.24,-.06);
    f.add(mesh(geo.foot,dark,0,-.03,0,.155,.22,.165));
    const cuff=mesh(geo.torus,soft,0,-.10,-.02,.13,.13,.16);cuff.rotation.x=Math.PI/2;f.add(cuff);
    f.add(mesh(geo.foot,soft,0,-.17,-.13,.19,.115,.24));
    f.add(mesh(geo.box,soleMat,0,-.235,-.13,.36,.042,.46));
    f.add(mesh(geo.box,collarMat,side*.10,-.17,-.13,.025,.055,.28));core.add(f);
  }
  function arm(side){
    const a=new THREE.Group();a.name=side<0?'BatArmL':'BatArmR';a.position.set(side*.48,.86,-.07);
    a.add(mesh(geo.sphere,skin,side*.12,-.08,-.05,.15,.13,.14));
    const band=mesh(geo.torus,soft,side*.08,-.05,-.04,.095,.095,.14);band.rotation.y=Math.PI/2;a.add(band);core.add(a);
  }
  core.add(mesh(geo.sphere,belly,0,.68,-.44,.16,.11,.06));
  for(const side of [-1,1]){
    const e=new THREE.Group();e.name=side<0?'BatEarL':'BatEarR';e.position.set(side*.34,1.42,-.05);core.add(e);
    const ear=mesh(geo.ear,skin,0,.10,0,.23,.44,.22);ear.rotation.z=-side*.2;ear.rotation.y=Math.PI/2;e.add(ear);
    const inner=mesh(geo.ear,earMat,side*.01,.11,-.07,.11,.29,.08);inner.rotation.z=-side*.2;inner.rotation.y=Math.PI/2;e.add(inner);
    core.add(mesh(geo.sphere,earMat,side*.37,.72,-.41,.095,.058,.025));
    foot(side);arm(side);
    const wg=side<0?wingL:wingR;wg.position.set(side*.48,.98,.13);
    const membrane=new THREE.Mesh(wingGeometry(side,pal.wing),wingMat);membrane.position.z=.05;membrane.name=side<0?'WingMembraneL':'WingMembraneR';wg.add(membrane);
    const bone1=mesh(geo.box,skin,side*.82,.34,.07,1.55,.045,.045);bone1.rotation.z=side*.38;wg.add(bone1);
    const bone2=mesh(geo.box,earMat,side*.72,.02,.07,1.15,.032,.035);bone2.rotation.z=-side*.12;wg.add(bone2);
    const claw=mesh(geo.ear,goldMat,side*.35,.28,.07,.045,.11,.045);claw.rotation.z=-side*.3;wg.add(claw);
  }
  const tail=new THREE.Group();tail.name='BatTail';tail.position.set(0,.56,.46);core.add(tail);
  tail.add(mesh(geo.box,dark,0,.02,.14,.045,.045,.26));
  const spade=mesh(geo.ear,earMat,0,.04,.29,.11,.14,.04);spade.rotation.x=Math.PI/2;tail.add(spade);
  const fangs=new THREE.Mesh(fangGeo,eyeWhite.clone());fangs.material.side=THREE.DoubleSide;fangs.name='Fangs';core.add(fangs);
  let n=0;root.traverse(o=>{if(o.isMesh&&!o.name)o.name='BatMesh'+String(++n).padStart(3,'0')});root.updateMatrixWorld(true);return root;
}
