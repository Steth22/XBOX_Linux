// Renders exported item models into a labelled grid (headless Chromium + three.js).
const fs = require('fs'), path = require('path');
const { chromium } = require('playwright');
const THREE_PATH = process.env.THREE || '/tmp/claude-0/-home-user-XBOX-Linux/c1e93073-5d2e-5524-8b8a-c304d0695d91/scratchpad/render/node_modules/three/build/three.min.js';
(async () => {
  const items = JSON.parse(fs.readFileSync(process.argv[2], 'utf8'));
  const out = process.argv[3];
  const cols = Math.min(8, items.length), cell = 230, rows = Math.ceil(items.length / cols);
  const html = `<html><body style="margin:0;background:#1c2128">
  <canvas id=c width=${cols * cell} height=${rows * cell}></canvas>
  <div id=labels style="position:absolute;left:0;top:0"></div>
  <script>${fs.readFileSync(THREE_PATH, 'utf8')}</script>
  <script>
  const items = ${JSON.stringify(items)}, cols = ${cols}, cell = ${cell};
  const canvas = document.getElementById('c');
  const r = new THREE.WebGLRenderer({ canvas, antialias: true, preserveDrawingBuffer: true });
  r.setScissorTest(true);
  r.setClearColor(0x2a313b);
  items.forEach((it, k) => {
    const scene = new THREE.Scene();
    scene.add(new THREE.AmbientLight(0xffffff, 0.75));
    const d = new THREE.DirectionalLight(0xfff4e6, 1.6); d.position.set(-1, 2, 1.4); scene.add(d);
    const d2 = new THREE.DirectionalLight(0x9fb4ff, 0.5); d2.position.set(1, -0.5, -1); scene.add(d2);
    const g = new THREE.Group();
    for (const p of it.parts) {
      const [sx, sy, sz] = p.s; let geo;
      if (p.sh === 'Ball') { geo = new THREE.SphereGeometry(Math.min(sx, sy, sz) / 2, 24, 16); }
      else if (p.sh === 'Cylinder') { geo = new THREE.CylinderGeometry(Math.min(sy, sz) / 2, Math.min(sy, sz) / 2, sx, 24); geo.rotateZ(Math.PI / 2); }
      else geo = new THREE.BoxGeometry(sx, sy, sz);
      const col = new THREE.Color(p.col[0], p.col[1], p.col[2]);
      const neon = p.m === 'Neon', glass = p.m === 'Glass', metal = p.m === 'Metal' || p.m === 'DiamondPlate' || p.m === 'Foil';
      const mat = new THREE.MeshStandardMaterial({ color: col, roughness: metal ? 0.35 : 0.85, metalness: metal ? 0.6 : 0.0,
        emissive: neon ? col : new THREE.Color(0, 0, 0), emissiveIntensity: neon ? 0.9 : 0,
        transparent: glass || p.t > 0, opacity: glass ? Math.min(0.75, 1 - p.t) : 1 - p.t });
      const mesh = new THREE.Mesh(geo, mat);
      const c = p.c; const m4 = new THREE.Matrix4().set(c[3], c[4], c[5], c[0], c[6], c[7], c[8], c[1], c[9], c[10], c[11], c[2], 0, 0, 0, 1);
      mesh.applyMatrix4(m4); g.add(mesh);
    }
    scene.add(g);
    const box = new THREE.Box3().setFromObject(g), sph = box.getBoundingSphere(new THREE.Sphere());
    const cam = new THREE.PerspectiveCamera(30, 1, 0.1, 1000);
    const dir = new THREE.Vector3(...(${JSON.stringify((process.env.CAMDIR || '1,0.85,1.25').split(',').map(Number))})).normalize();
    cam.position.copy(sph.center).addScaledVector(dir, sph.radius / Math.tan(15 * Math.PI / 180) * 1.05); cam.lookAt(sph.center);
    const x = (k % cols) * cell, y = Math.floor(k / cols) * cell;
    const H = canvas.height;
    r.setViewport(x + 4, H - y - cell + 4, cell - 8, cell - 8); r.setScissor(x + 4, H - y - cell + 4, cell - 8, cell - 8);
    r.render(scene, cam);
    const l = document.createElement('div'); l.textContent = it.id + '  ' + it.name;
    l.style.cssText = 'position:absolute;left:' + (x + 8) + 'px;top:' + (y + 8) + 'px;color:#fff;font:13px sans-serif;text-shadow:0 1px 2px #000';
    document.getElementById('labels').appendChild(l);
  });
  document.title = 'done';
  </script></body></html>`;
  const b = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
  const pg = await b.newPage({ viewport: { width: cols * cell, height: rows * cell } });
  await pg.setContent(html); await pg.waitForFunction(() => document.title === 'done', null, { timeout: 60000 });
  await pg.screenshot({ path: out }); await b.close();
})();
