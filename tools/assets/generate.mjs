import * as THREE from 'three';
import {GLTFExporter} from 'three/addons/exporters/GLTFExporter.js';
import {mkdir,writeFile,readFile} from 'node:fs/promises';
import {createHash} from 'node:crypto';
import {fileURLToPath} from 'node:url';
import {buildBat} from './mascot.mjs';
// GLTFExporter uses browser FileReader even for a texture-free GLB.
globalThis.FileReader ??= class {
  result=null; onloadend=null; onerror=null;
  readAsArrayBuffer(blob){blob.arrayBuffer().then(x=>{this.result=x;this.onloadend?.({target:this})},e=>this.onerror?.(e));}
  readAsDataURL(blob){blob.arrayBuffer().then(x=>{this.result='data:'+blob.type+';base64,'+Buffer.from(x).toString('base64');this.onloadend?.({target:this})},e=>this.onerror?.(e));}
};
const output=new URL('../../assets/generated/',import.meta.url);
await mkdir(output,{recursive:true});
const sha=b=>createHash('sha256').update(b).digest('hex');
const manifest={schema:1,source:'BAT BALL RUN V5.1 index.html / createMascot bat branch',three_revision:THREE.REVISION,source_sha256:sha(await readFile(new URL('./mascot.mjs',import.meta.url))),assets:{}};
for(const lod of ['standard','lite']){
  const obj=buildBat(lod); const scene=new THREE.Scene();scene.add(obj);
  let triangles=0,meshes=0;const names=new Set();
  obj.traverse(n=>{names.add(n.name);if(n.isMesh){meshes++;const g=n.geometry;triangles+=(g.index?.count??g.getAttribute('position').count)/3;}});
  for(const name of ['BatWingL','BatWingR','BatFootL','BatFootR','BatArmL','BatArmR','BatEarL','BatEarR','BatTail','Body','GoggleL','GoggleR','Fangs'])if(!names.has(name))throw new Error('missing pivot '+name);
  const buffer=Buffer.from(await new GLTFExporter().parseAsync(scene,{binary:true,onlyVisible:true,trs:true}));
  if(buffer.toString('ascii',0,4)!=='glTF'||buffer.readUInt32LE(4)!==2||buffer.readUInt32LE(8)!==buffer.length)throw new Error('bad GLB');
  const json=JSON.parse(buffer.toString('utf8',20,20+buffer.readUInt32LE(12)));
  if(!json.meshes?.length||!json.materials?.length||!json.meshes.some(m=>m.primitives.some(p=>p.attributes.COLOR_0!==undefined)))throw new Error('missing mesh/material/vertex colors');
  const id='bat_'+lod;const file=id+'.glb';await writeFile(new URL(file,output),buffer);
  const bounds=new THREE.Box3().setFromObject(obj);const size=bounds.getSize(new THREE.Vector3()).toArray();
  manifest.assets[id]={path:'res://assets/generated/'+file,bytes:buffer.length,sha256:sha(buffer),triangles,meshes,size_m:size,pivots:[...names].filter(n=>/^Bat(Wing|Foot|Arm|Ear|Tail)/.test(n)),material_count:json.materials.length,forward:'-Z',up:'+Y'};
  console.log('XR002_GLTF_PASS',id,triangles,meshes,buffer.length);
}
if(manifest.assets.bat_lite.triangles>=manifest.assets.bat_standard.triangles*0.6)throw new Error('LOD reduction insufficient');
await writeFile(new URL('catalog.json',output),JSON.stringify(manifest,null,2)+'\n');
console.log('XR002_ASSET_PASS',manifest.three_revision,manifest.assets.bat_standard.triangles,manifest.assets.bat_lite.triangles);
