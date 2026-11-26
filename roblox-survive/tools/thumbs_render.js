// Renders a cinematic still from an exported piece of the map (terrain voxels + parts + creatures)
// with shadows, glow, depth of field and colour grading.   node thumbs_render.js config.json out.png
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const SP = process.env.SP;
const THREE_DIR = path.join(SP, 'render/node_modules/three');
const cfg = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
const out = process.argv[3];
const scene = JSON.parse(fs.readFileSync(cfg.scene, 'utf8'));

const page = `<!doctype html><html><head><style>body{margin:0;background:#000}canvas{display:block}</style>
<script type="importmap">{"imports":{"three":"file://${THREE_DIR}/build/three.module.js","three/addons/":"file://${THREE_DIR}/examples/jsm/"}}</script>
</head><body><script type="module">
import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { BokehPass } from 'three/addons/postprocessing/BokehPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
const cfg = ${JSON.stringify(cfg)};
const S = ${JSON.stringify(scene)};
const W = cfg.w || 1920, H = cfg.h || 1080;
const renderer = new THREE.WebGLRenderer({ antialias: true, preserveDrawingBuffer: true });
renderer.setSize(W, H);
renderer.shadowMap.enabled = true;
renderer.shadowMap.type = THREE.PCFSoftShadowMap;
renderer.toneMapping = THREE.ACESFilmicToneMapping;
renderer.toneMappingExposure = cfg.exposure || 1.0;
document.body.appendChild(renderer.domElement);
const scene = new THREE.Scene();

// ---- sky: a vertical gradient (plus a soft sun glow) painted on a big inside-out sphere
{
  const c = document.createElement('canvas'); c.width = 16; c.height = 512;
  const g = c.getContext('2d'); const gr = g.createLinearGradient(0, 0, 0, 512);
  const st = cfg.sky.stops || [[0, cfg.sky.top], [1, cfg.sky.bottom]];
  for (const [o, col] of st) gr.addColorStop(o, col);
  g.fillStyle = gr; g.fillRect(0, 0, 16, 512);
  const tex = new THREE.CanvasTexture(c); tex.colorSpace = THREE.SRGBColorSpace;
  const sky = new THREE.Mesh(new THREE.SphereGeometry(3000, 32, 16), new THREE.MeshBasicMaterial({ map: tex, side: THREE.BackSide, fog: false, depthWrite: false }));
  scene.add(sky);
}
if (cfg.fog) scene.fog = new THREE.Fog(new THREE.Color(cfg.fog.color), cfg.fog.near, cfg.fog.far);

// ---- lights
const hemi = new THREE.HemisphereLight(new THREE.Color(cfg.hemi.sky), new THREE.Color(cfg.hemi.ground), cfg.hemi.intensity);
scene.add(hemi);
const sun = new THREE.DirectionalLight(new THREE.Color(cfg.sun.color), cfg.sun.intensity);
const sd = new THREE.Vector3(...cfg.sun.dir).normalize();
const tgt = new THREE.Vector3(...cfg.cam.target);
sun.position.copy(tgt).addScaledVector(sd, 300);
sun.target.position.copy(tgt);
sun.castShadow = true;
sun.shadow.mapSize.set(4096, 4096);
const sc = sun.shadow.camera; sc.left = -170; sc.right = 170; sc.top = 170; sc.bottom = -170; sc.near = 10; sc.far = 700;
sun.shadow.bias = -0.0006; sun.shadow.normalBias = 0.6;
scene.add(sun); scene.add(sun.target);
if (cfg.fill !== 0) { const f = new THREE.DirectionalLight(new THREE.Color(cfg.fillColor || '#cfdcff'), cfg.fill ?? 0.8); f.position.set(...cfg.cam.pos).sub(tgt).normalize().multiplyScalar(100).add(tgt).add(new THREE.Vector3(0, 40, 0)); f.target.position.copy(tgt); scene.add(f); scene.add(f.target); }

// ---- small helpers
function noise3(x, y, z) { const s = Math.sin(x * 12.9898 + y * 78.233 + z * 37.719) * 43758.5453; return s - Math.floor(s); }
function partMaterial(p) {
  const col = new THREE.Color(p.col[0], p.col[1], p.col[2]); col.convertSRGBToLinear();
  const m = p.m;
  const neon = m === 'Neon', glass = m === 'Glass' || m === 'ForceField', metal = ['Metal', 'DiamondPlate', 'Foil', 'CorrodedMetal'].includes(m);
  const rough = metal ? 0.35 : (m === 'SmoothPlastic' || m === 'Plastic' ? 0.6 : (m === 'Ice' || m === 'Glacier' ? 0.2 : 0.9));
  const t = glass ? Math.max(p.t, 0.45) : p.t;
  return new THREE.MeshStandardMaterial({ color: col, roughness: rough, metalness: metal ? 0.55 : 0,
    emissive: neon ? col : new THREE.Color(0, 0, 0), emissiveIntensity: neon ? (cfg.neon || 2.2) : 0,
    transparent: t > 0.01, opacity: 1 - t, depthWrite: t < 0.5 });
}
function partGeo(p) {
  const [sx, sy, sz] = p.s;
  if (p.sh === 'Ball') return new THREE.SphereGeometry(Math.min(sx, sy, sz) / 2, 20, 14);
  if (p.sh === 'Cylinder') { const g = new THREE.CylinderGeometry(Math.min(sy, sz) / 2, Math.min(sy, sz) / 2, sx, 20); g.rotateZ(Math.PI / 2); return g; }
  if (p.sh === 'Wedge') {
    const g = new THREE.BufferGeometry();
    const x = sx / 2, y = sy / 2, z = sz / 2;
    const v = [[-x,-y,-z],[x,-y,-z],[-x,-y,z],[x,-y,z],[-x,y,z],[x,y,z]];
    const f = [[0,2,1],[1,2,3],[2,4,3],[3,4,5],[0,1,4],[1,5,4],[0,4,2],[1,3,5]];
    const pos = []; for (const t of f) for (const i of t) pos.push(...v[i]);
    g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3)); g.computeVertexNormals(); return g;
  }
  return new THREE.BoxGeometry(sx, sy, sz);
}
function matrixOf(c) { return new THREE.Matrix4().set(c[3], c[4], c[5], c[0], c[6], c[7], c[8], c[1], c[9], c[10], c[11], c[2], 0, 0, 0, 1); }
function addParts(list, parent, base) {
  for (const p of list) {
    const mesh = new THREE.Mesh(partGeo(p), partMaterial(p));
    mesh.applyMatrix4(matrixOf(p.c));
    if (base) mesh.applyMatrix4(base);
    mesh.castShadow = p.t < 0.5 && p.m !== 'Neon'; mesh.receiveShadow = true;
    parent.add(mesh);
  }
}

// ---- terrain: smooth surface (surface nets) over the voxel occupancy, coloured by material
const V = S.vox, NX = V.nx, NY = V.ny, NZ = V.nz, R = V.res;
const idx = (x, y, z) => x + NX * (y + NY * z);
const matAt = new Array(NX * NY * NZ), occAt = new Float32Array(NX * NY * NZ);
for (let i = 0; i < NX * NY * NZ; i++) { matAt[i] = S.palette[V.mats.charCodeAt(i) - 48]; occAt[i] = (V.occ.charCodeAt(i) - 48) / 40; }
const TCOL = Object.assign({ Grass: [0.33,0.52,0.25], LeafyGrass: [0.27,0.45,0.22], Ground: [0.42,0.35,0.26], Mud: [0.36,0.29,0.22], Sand: [0.80,0.72,0.52],
  Sandstone: [0.72,0.53,0.38], Snow: [0.92,0.95,0.98], Glacier: [0.68,0.82,0.92], Rock: [0.45,0.45,0.47], Slate: [0.36,0.37,0.40], Basalt: [0.20,0.19,0.21],
  CrackedLava: [0.95,0.42,0.12], Asphalt: [0.25,0.23,0.23], Limestone: [0.80,0.78,0.70] }, {});
for (const k in S.colors) if (!['Air', 'Water'].includes(k)) TCOL[k] = S.colors[k];
// bare ground patches read as noise in a picture: blend them towards the grass around (optional)
if (cfg.dirtToGrass) { const gcol = TCOL.Grass; for (const k of ['Ground', 'Mud']) TCOL[k] = TCOL[k].map((v, i) => v * (1 - cfg.dirtToGrass) + gcol[i] * cfg.dirtToGrass); }
function surfaceNets(field, colorOf, material, glow) {
  const verts = [], cols = [], vidx = new Int32Array((NX) * (NY) * (NZ)).fill(-1), tris = [];
  const iso = 0.5;
  for (let z = 0; z < NZ - 1; z++) for (let y = 0; y < NY - 1; y++) for (let x = 0; x < NX - 1; x++) {
    let inside = 0, cnt = 0; const pos = [0, 0, 0]; let n = 0;
    const corners = [];
    for (let c = 0; c < 8; c++) { const cx = x + (c & 1), cy = y + ((c >> 1) & 1), cz = z + ((c >> 2) & 1); const v = field(cx, cy, cz); corners.push(v); if (v > iso) inside++; }
    if (inside === 0 || inside === 8) continue;
    const edges = [[0,1],[2,3],[4,5],[6,7],[0,2],[1,3],[4,6],[5,7],[0,4],[1,5],[2,6],[3,7]];
    for (const [a, b] of edges) {
      const va = corners[a], vb = corners[b];
      if ((va > iso) !== (vb > iso)) {
        const t = (iso - va) / (vb - va);
        const ax = a & 1, ay = (a >> 1) & 1, az = (a >> 2) & 1, bx = b & 1, by = (b >> 1) & 1, bz = (b >> 2) & 1;
        pos[0] += ax + (bx - ax) * t; pos[1] += ay + (by - ay) * t; pos[2] += az + (bz - az) * t; n++;
      }
    }
    const wx = V.ox + (x + 0.5 + pos[0] / n) * R, wy = V.oy + (y + 0.5 + pos[1] / n) * R, wz = V.oz + (z + 0.5 + pos[2] / n) * R;
    vidx[idx(x, y, z)] = verts.length / 3;
    verts.push(wx, wy, wz);
    const c = colorOf(x, y, z, wx, wy, wz); cols.push(c[0], c[1], c[2]);
  }
  // faces across each grid edge that crosses the surface
  for (let z = 1; z < NZ - 1; z++) for (let y = 1; y < NY - 1; y++) for (let x = 1; x < NX - 1; x++) {
    const v0 = field(x, y, z) > iso;
    const quads = [
      [field(x + 1, y, z) > iso, [[x, y - 1, z - 1], [x, y, z - 1], [x, y, z], [x, y - 1, z]]],
      [field(x, y + 1, z) > iso, [[x - 1, y, z - 1], [x - 1, y, z], [x, y, z], [x, y, z - 1]]],
      [field(x, y, z + 1) > iso, [[x - 1, y - 1, z], [x, y - 1, z], [x, y, z], [x - 1, y, z]]],
    ];
    for (const [v1, q] of quads) {
      if (v0 === v1) continue;
      const ids = q.map(([a, b, c]) => vidx[idx(a, b, c)]);
      if (ids.some(i => i < 0)) continue;
      if (v0) { tris.push(ids[0], ids[1], ids[2], ids[0], ids[2], ids[3]); }
      else { tris.push(ids[0], ids[2], ids[1], ids[0], ids[3], ids[2]); }
    }
  }
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute(verts, 3));
  g.setAttribute('color', new THREE.Float32BufferAttribute(cols, 3));
  g.setIndex(tris); g.computeVertexNormals();
  const mesh = new THREE.Mesh(g, material);
  return mesh;
}
const solid = (x, y, z) => { const i = idx(x, y, z); const m = matAt[i]; return (m === 'Air' || m === 'Water') ? 0 : occAt[i]; };
const water = (x, y, z) => { const i = idx(x, y, z); return matAt[i] === 'Water' ? 1 : 0; };
function terrainColor(x, y, z, wx, wy, wz) {
  // the most solid material among the cell's corners
  let best = null, bo = -1;
  for (let c = 0; c < 8; c++) { const i = idx(x + (c & 1), y + ((c >> 1) & 1), z + ((c >> 2) & 1)); const m = matAt[i]; if (m !== 'Air' && m !== 'Water' && occAt[i] > bo) { bo = occAt[i]; best = m; } }
  const base = TCOL[best] || [0.5, 0.5, 0.5];
  const n = 0.88 + 0.24 * noise3(Math.floor(wx / 3), Math.floor(wy / 3), Math.floor(wz / 3));
  const out = new THREE.Color(base[0] * n, base[1] * n, base[2] * n); out.convertSRGBToLinear();
  return [out.r, out.g, out.b];
}
const terrainMat = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.95, metalness: 0 });
const terr = surfaceNets(solid, terrainColor, terrainMat);
terr.receiveShadow = true; terr.castShadow = true; scene.add(terr);
// lava glows
{
  const lavaVerts = [];
  const lavaMat = new THREE.MeshBasicMaterial({ color: new THREE.Color(1.0, 0.45, 0.1), toneMapped: false });
}
const waterMat = new THREE.MeshStandardMaterial({ color: new THREE.Color(cfg.water || '#2f7fb3'), roughness: 0.08, metalness: 0.2, transparent: true, opacity: 0.78 });
const wmesh = surfaceNets(water, () => [1, 1, 1], waterMat);
wmesh.material.vertexColors = false; wmesh.receiveShadow = true; scene.add(wmesh);

// ---- grass tufts near the camera, standing on the terrain (height read from the voxels)
function heightAt(wx, wz) {
  const x = Math.floor((wx - V.ox) / R), z = Math.floor((wz - V.oz) / R);
  if (x < 0 || z < 0 || x >= NX || z >= NZ) return null;
  for (let y = NY - 1; y >= 0; y--) { const i = idx(x, y, z); const m = matAt[i]; if (m !== 'Air' && m !== 'Water' && occAt[i] > 0.05) { return { y: V.oy + y * R + R * Math.min(1, occAt[i] + 0.0), m }; } }
  return null;
}
if (cfg.grass) {
  const geo = new THREE.ConeGeometry(0.1, 0.9, 3); geo.translate(0, 0.45, 0);
  const mat = new THREE.MeshStandardMaterial({ roughness: 0.9 });
  const n = cfg.grass.count; const inst = new THREE.InstancedMesh(geo, mat, n);
  const c0 = new THREE.Vector3(...(cfg.grass.center || cfg.cam.pos)); const m4 = new THREE.Matrix4(); const q = new THREE.Quaternion(); let k = 0;
  for (let i = 0; i < n * 3 && k < n; i++) {
    const a = Math.random() * Math.PI * 2, r = Math.sqrt(Math.random()) * cfg.grass.radius;
    const wx = c0.x + Math.cos(a) * r, wz = c0.z + Math.sin(a) * r; const h = heightAt(wx, wz);
    if (!h || !['Grass', 'LeafyGrass', 'Ground', 'Mud'].includes(h.m)) continue;
    q.setFromEuler(new THREE.Euler((Math.random() - 0.5) * 0.6, Math.random() * 6.28, (Math.random() - 0.5) * 0.6));
    const sc = 0.5 + Math.random() * 0.6;
    m4.compose(new THREE.Vector3(wx, h.y - 0.35, wz), q, new THREE.Vector3(sc, sc * (0.7 + Math.random() * 0.6), sc));
    inst.setMatrixAt(k, m4);
    const base = TCOL[h.m === 'LeafyGrass' ? 'LeafyGrass' : 'Grass']; const v = 0.75 + Math.random() * 0.5;
    const col = new THREE.Color(base[0] * v, base[1] * v * 1.05, base[2] * v); col.convertSRGBToLinear(); inst.setColorAt(k, col); k++;
  }
  inst.count = k; inst.castShadow = false; inst.receiveShadow = true; scene.add(inst);
}

// ---- parts (buildings, trees, rocks, creatures)
addParts(S.parts, scene);
// lava terrain glows: emissive overlay where the material is cracked lava
{
  let any = false;
  for (let i = 0; i < matAt.length; i++) if (matAt[i] === 'CrackedLava') { any = true; break; }
  if (any) {
    const lavaField = (x, y, z) => { const i = idx(x, y, z); return matAt[i] === 'CrackedLava' ? occAt[i] : 0; };
    const lm = surfaceNets(lavaField, () => [1, 1, 1], new THREE.MeshBasicMaterial({ color: new THREE.Color(2.4, 0.9, 0.2), toneMapped: false }));
    lm.material.vertexColors = false; lm.position.y += 0.15; scene.add(lm);
  }
}
// lights carried by parts (lanterns, torches, crystals), the ones nearest the camera
{
  const cam = new THREE.Vector3(...cfg.cam.pos);
  const ls = S.parts.filter(p => p.l).map(p => ({ p, d: new THREE.Vector3(p.c[0], p.c[1], p.c[2]).distanceTo(cam) })).sort((a, b) => a.d - b.d).slice(0, cfg.maxLights || 10);
  for (const { p } of ls) {
    const l = new THREE.PointLight(new THREE.Color(p.l[0], p.l[1], p.l[2]), p.l[3] * (cfg.lightBoost || 30), p.l[4] * 1.4, 1.6);
    l.position.set(p.c[0], p.c[1], p.c[2]); scene.add(l);
  }
}

// ---- the player: a blocky avatar in a pose, holding an item
function avatar(pl) {
  const g = new THREE.Group();
  const skin = new THREE.Color(...(pl.skin || [0.93, 0.74, 0.6])), shirt = new THREE.Color(...(pl.shirt || [0.2, 0.42, 0.75])), pants = new THREE.Color(...(pl.pants || [0.22, 0.22, 0.28]));
  [skin, shirt, pants].forEach(c => c.convertSRGBToLinear());
  const box = (w, h, d, col) => { const m = new THREE.Mesh(new THREE.BoxGeometry(w, h, d), new THREE.MeshStandardMaterial({ color: col, roughness: 0.7 })); m.castShadow = true; m.receiveShadow = true; return m; };
  const torso = box(2, 2, 1, shirt); torso.position.y = 3; g.add(torso);
  const head = box(1.25, 1.25, 1.25, skin); head.position.y = 4.65; g.add(head);
  for (const sx of [-0.25, 0.25]) { const e = box(0.14, 0.2, 0.05, new THREE.Color(0.04, 0.04, 0.04)); e.position.set(sx, 4.72, -0.64); g.add(e); }
  const mouth = box(0.36, 0.06, 0.05, new THREE.Color(0.35, 0.15, 0.12)); mouth.position.set(0, 4.36, -0.64); g.add(mouth);
  const hair = box(1.34, 0.26, 1.34, new THREE.Color(...(pl.hair || [0.18, 0.11, 0.06])).convertSRGBToLinear()); hair.position.y = 5.36; g.add(hair);
  const back = box(1.34, 0.9, 0.3, new THREE.Color(...(pl.hair || [0.18, 0.11, 0.06])).convertSRGBToLinear()); back.position.set(0, 4.95, 0.55); g.add(back);
  const limb = (col, sx, sy, rx, rz) => {
    const pivot = new THREE.Group(); pivot.position.set(sx, sy, 0);
    const m = box(0.95, 2, 0.95, col); m.position.y = -1; pivot.add(m);
    pivot.rotation.set((rx || 0) * Math.PI / 180, 0, (rz || 0) * Math.PI / 180);
    g.add(pivot); return pivot;
  };
  const P = pl.pose || {};
  const rArm = limb(shirt, 1.48, 4, P.rArm?.[0], P.rArm?.[1]);
  const lArm = limb(shirt, -1.48, 4, P.lArm?.[0], P.lArm?.[1]);
  const rHand = box(0.96, 0.5, 0.96, skin); rHand.position.y = -1.95; rArm.add(rHand);
  const lHand = box(0.96, 0.5, 0.96, skin); lHand.position.y = -1.95; lArm.add(lHand);
  limb(pants, 0.5, 2, P.rLeg?.[0], P.rLeg?.[1]);
  limb(pants, -0.5, 2, P.lLeg?.[0], P.lLeg?.[1]);
  if (P.lean) g.rotation.x = P.lean * Math.PI / 180;
  const hold = (id, arm, extra) => {
    if (!id || !S.items[id]) return;
    const ig = new THREE.Group(); addParts(S.items[id], ig);
    ig.position.set(0, -2.1, 0);
    const e = extra || [90, 0, 0];
    ig.rotation.set(e[0] * Math.PI / 180, e[1] * Math.PI / 180, e[2] * Math.PI / 180);
    arm.add(ig);
  };
  hold(pl.item, rArm, pl.itemRot); hold(pl.offItem, lArm, [0, 0, 0]);
  g.position.set(...pl.pos); g.rotation.y = (pl.yaw || 0) * Math.PI / 180;
  return g;
}
for (const pl of cfg.players || []) scene.add(avatar(pl));

// ---- extras: tornado, lightning
if (cfg.tornado) {
  const t = cfg.tornado; const grp = new THREE.Group();
  for (let k = 0; k < 26; k++) {
    const f = k / 25, r = 3 + Math.pow(f, 1.7) * 38;
    const m = new THREE.Mesh(new THREE.TorusGeometry(r, 2 + f * 5, 8, 40), new THREE.MeshStandardMaterial({ color: new THREE.Color(0.42, 0.4, 0.38).lerp(new THREE.Color(0.25, 0.26, 0.3), f), transparent: true, opacity: 0.55 - f * 0.15, roughness: 1, depthWrite: false }));
    m.rotation.x = Math.PI / 2; m.position.set(Math.sin(k * 0.5) * k * 0.5, k * 4.2, Math.cos(k * 0.4) * k * 0.4); grp.add(m);
  }
  grp.position.set(...t.pos); scene.add(grp);
}
for (const b of cfg.lightning || []) {
  let prev = new THREE.Vector3(...b.from); const to = new THREE.Vector3(...b.to);
  for (let k = 1; k <= 12; k++) {
    const p = prev.clone().lerp(to, 1 / (13 - k)); if (k < 12) { p.x += (Math.random() - 0.5) * 14; p.z += (Math.random() - 0.5) * 14; }
    const len = p.distanceTo(prev); const m = new THREE.Mesh(new THREE.CylinderGeometry(0.5, 0.5, len, 6), new THREE.MeshBasicMaterial({ color: new THREE.Color(3, 3.2, 4), toneMapped: false }));
    m.position.copy(prev).lerp(p, 0.5); m.quaternion.setFromUnitVectors(new THREE.Vector3(0, 1, 0), p.clone().sub(prev).normalize()); scene.add(m); prev = p;
  }
}

// ---- particles: embers, snow, rain, fireflies, ash, dust motes
function spriteTex(kind) {
  const c = document.createElement('canvas'); c.width = c.height = 64; const g = c.getContext('2d');
  if (kind === 'rain') { const gr = g.createLinearGradient(0, 0, 0, 64); gr.addColorStop(0, 'rgba(255,255,255,0)'); gr.addColorStop(1, 'rgba(220,230,255,0.9)'); g.fillStyle = gr; g.fillRect(30, 0, 4, 64); }
  else { const gr = g.createRadialGradient(32, 32, 0, 32, 32, 32); gr.addColorStop(0, 'rgba(255,255,255,1)'); gr.addColorStop(0.4, 'rgba(255,255,255,0.6)'); gr.addColorStop(1, 'rgba(255,255,255,0)'); g.fillStyle = gr; g.fillRect(0, 0, 64, 64); }
  const t = new THREE.CanvasTexture(c); return t;
}
for (const pt of cfg.particles || []) {
  const [x0, y0, z0, x1, y1, z1] = pt.box; const pos = [];
  for (let i = 0; i < pt.count; i++) pos.push(x0 + Math.random() * (x1 - x0), y0 + Math.random() * (y1 - y0), z0 + Math.random() * (z1 - z0));
  const g = new THREE.BufferGeometry(); g.setAttribute('position', new THREE.Float32BufferAttribute(pos, 3));
  const col = new THREE.Color(pt.color); if (pt.glow) col.multiplyScalar(pt.glow);
  const m = new THREE.PointsMaterial({ size: pt.size, map: spriteTex(pt.type), color: col, transparent: true, depthWrite: false, blending: pt.add ? THREE.AdditiveBlending : THREE.NormalBlending, toneMapped: !pt.glow, opacity: pt.opacity || 1 });
  scene.add(new THREE.Points(g, m));
}

// ---- camera and the film look
const camera = new THREE.PerspectiveCamera(cfg.cam.fov || 50, W / H, 0.5, 4000);
camera.position.set(...cfg.cam.pos); if (cfg.cam.up) camera.up.set(...cfg.cam.up); camera.lookAt(tgt);
const composer = new EffectComposer(renderer);
composer.addPass(new RenderPass(scene, camera));
const b = cfg.bloom || {};
composer.addPass(new UnrealBloomPass(new THREE.Vector2(W, H), b.strength ?? 0.6, b.radius ?? 0.6, b.threshold ?? 0.85));
if (cfg.dof) composer.addPass(new BokehPass(scene, camera, { focus: cfg.dof.focus, aperture: cfg.dof.aperture, maxblur: cfg.dof.maxblur }));
const gr = cfg.grade || {};
composer.addPass(new ShaderPass({
  uniforms: { tDiffuse: { value: null }, contrast: { value: gr.contrast ?? 1.08 }, saturation: { value: gr.saturation ?? 1.12 }, tint: { value: new THREE.Vector3(...(gr.tint || [1, 1, 1])) }, vignette: { value: gr.vignette ?? 0.35 } },
  vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position,1.0); }',
  fragmentShader: \`uniform sampler2D tDiffuse; uniform float contrast, saturation, vignette; uniform vec3 tint; varying vec2 vUv;
    void main(){ vec4 c = texture2D(tDiffuse, vUv); vec3 col = c.rgb * tint;
      float l = dot(col, vec3(0.299,0.587,0.114)); col = mix(vec3(l), col, saturation);
      col = (col - 0.5) * contrast + 0.5;
      float d = distance(vUv, vec2(0.5)); col *= 1.0 - vignette * smoothstep(0.35, 0.85, d);
      gl_FragColor = vec4(col, c.a); }\`
}));
composer.addPass(new OutputPass());
composer.render();
document.title = 'done';
</script></body></html>`;

(async () => {
  const file = path.join(path.dirname(out), '_render_' + path.basename(out) + '.html');
  fs.writeFileSync(file, page);
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--allow-file-access-from-files', '--disable-web-security'] });
  const pg = await b.newPage({ viewport: { width: cfg.w || 1920, height: cfg.h || 1080 } });
  pg.on('console', m => { if (m.type() === 'error') console.log('page:', m.text()); });
  pg.on('pageerror', e => console.log('pageerror:', e.message));
  await pg.goto('file://' + file);
  await pg.waitForFunction(() => document.title === 'done', null, { timeout: 600000 });
  await pg.screenshot({ path: out });
  await b.close();
  console.log('wrote', out);
})();
