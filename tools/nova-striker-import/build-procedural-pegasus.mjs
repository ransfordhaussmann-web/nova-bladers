#!/usr/bin/env node
/**
 * Builds a Storm-Pegasus-inspired GLB when Sketchfab download is unavailable.
 * Output: source/storm-pegasus.glb
 */
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { Document, NodeIO, Material, Primitive, Accessor } from '@gltf-transform/core';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const OUT = path.join(__dirname, 'source', 'storm-pegasus.glb');

const COLORS = {
  metal: [0.72, 0.78, 0.88, 1],
  silver: [0.85, 0.88, 0.92, 1],
  blue: [0.18, 0.42, 0.95, 1],
  cyan: [0.35, 0.72, 1.0, 1],
  white: [0.95, 0.97, 1.0, 1],
  dark: [0.25, 0.28, 0.35, 1],
  rubber: [0.12, 0.12, 0.14, 1],
};

function pushTri(positions, normals, indices, a, b, c, nx, ny, nz) {
  const base = positions.length / 3;
  for (const p of [a, b, c]) {
    positions.push(p[0], p[1], p[2]);
    normals.push(nx, ny, nz);
  }
  indices.push(base, base + 1, base + 2);
}

function boxMesh(cx, cy, cz, sx, sy, sz) {
  const hx = sx / 2;
  const hy = sy / 2;
  const hz = sz / 2;
  const positions = [];
  const normals = [];
  const indices = [];
  const faces = [
    { pts: [[-hx, -hy, hz], [hx, -hy, hz], [hx, hy, hz], [-hx, hy, hz]], n: [0, 0, 1] },
    { pts: [[hx, -hy, -hz], [-hx, -hy, -hz], [-hx, hy, -hz], [hx, hy, -hz]], n: [0, 0, -1] },
    { pts: [[-hx, hy, hz], [hx, hy, hz], [hx, hy, -hz], [-hx, hy, -hz]], n: [0, 1, 0] },
    { pts: [[-hx, -hy, -hz], [hx, -hy, -hz], [hx, -hy, hz], [-hx, -hy, hz]], n: [0, -1, 0] },
    { pts: [[hx, -hy, hz], [hx, -hy, -hz], [hx, hy, -hz], [hx, hy, hz]], n: [1, 0, 0] },
    { pts: [[-hx, -hy, -hz], [-hx, -hy, hz], [-hx, hy, hz], [-hx, hy, -hz]], n: [-1, 0, 0] },
  ];
  for (const { pts, n } of faces) {
    const v = (p) => [p[0] + cx, p[1] + cy, p[2] + cz];
    pushTri(positions, normals, indices, v(pts[0]), v(pts[1]), v(pts[2]), ...n);
    pushTri(positions, normals, indices, v(pts[0]), v(pts[2]), v(pts[3]), ...n);
  }
  return { positions, normals, indices };
}

function cylinderMesh(radius, height, segments, rotX = 0) {
  const positions = [];
  const normals = [];
  const indices = [];
  const hh = height / 2;
  const cos = Math.cos(rotX);
  const sin = Math.sin(rotX);
  const rot = (x, y, z) => {
    const y2 = y * cos - z * sin;
    const z2 = y * sin + z * cos;
    return [x, y2, z2];
  };

  const top = [];
  const bot = [];
  for (let i = 0; i < segments; i++) {
    const t = (i / segments) * Math.PI * 2;
    const x = Math.cos(t) * radius;
    const z = Math.sin(t) * radius;
    top.push(rot(x, hh, z));
    bot.push(rot(x, -hh, z));
  }

  for (let i = 0; i < segments; i++) {
    const j = (i + 1) % segments;
    const nx = Math.cos((i / segments) * Math.PI * 2);
    const nz = Math.sin((i / segments) * Math.PI * 2);
    const n = rot(nx, 0, nz);
    pushTri(positions, normals, indices, bot[i], bot[j], top[j], ...n);
    pushTri(positions, normals, indices, bot[i], top[j], top[i], ...n);
  }

  for (let i = 1; i < segments - 1; i++) {
    pushTri(positions, normals, indices, top[0], top[i + 1], top[i], 0, 1, 0);
    pushTri(positions, normals, indices, bot[0], bot[i], bot[i + 1], 0, -1, 0);
  }

  return { positions, normals, indices };
}

function mergeMeshes(meshes) {
  const positions = [];
  const normals = [];
  const indices = [];
  for (const m of meshes) {
    const offset = positions.length / 3;
    positions.push(...m.positions);
    normals.push(...m.normals);
    for (const idx of m.indices) indices.push(idx + offset);
  }
  return { positions, normals, indices };
}

function addMesh(doc, buffer, name, meshData, color, metallic = 0.3, roughness = 0.45, alpha = 1) {
  const mat = doc.createMaterial(name + '_Mat')
    .setBaseColorFactor([...color.slice(0, 3), alpha])
    .setMetallicFactor(metallic)
    .setRoughnessFactor(roughness);
  if (alpha < 0.99) mat.setAlphaMode(2); // BLEND

  const pos = new Float32Array(meshData.positions);
  const nor = new Float32Array(meshData.normals);
  const idx = meshData.positions.length / 3 > 65535
    ? new Uint32Array(meshData.indices)
    : new Uint16Array(meshData.indices);

  const prim = doc.createPrimitive()
    .setMaterial(mat)
    .setAttribute('POSITION', doc.createAccessor().setType(Accessor.Type.VEC3).setArray(pos).setBuffer(buffer))
    .setAttribute('NORMAL', doc.createAccessor().setType(Accessor.Type.VEC3).setArray(nor).setBuffer(buffer))
    .setIndices(doc.createAccessor().setType(idx instanceof Uint32Array ? Accessor.Type.SCALAR : Accessor.Type.SCALAR).setArray(idx).setBuffer(buffer));

  const mesh = doc.createMesh(name).addPrimitive(prim);
  return doc.createNode(name).setMesh(mesh);
}

async function main() {
  const doc = new Document();
  const buffer = doc.createBuffer('buf');
  const scene = doc.createScene('NovaStriker');
  const root = doc.createNode('Root');

  const parts = [];

  // Fusion wheel — metal ring with attack teeth
  for (let i = 0; i < 24; i++) {
    const angle = (i / 24) * Math.PI * 2;
    const r = 1.55;
    const cx = Math.cos(angle) * r;
    const cz = Math.sin(angle) * r;
    const tooth = i % 2 === 0;
    parts.push(boxMesh(cx, 0, cz, tooth ? 0.42 : 0.28, 0.38, tooth ? 0.55 : 0.35));
  }
  parts.push(cylinderMesh(1.25, 0.42, 32));

  // Three Pegasus attack wings
  for (let w = 0; w < 3; w++) {
    const base = (w / 3) * Math.PI * 2;
    for (let s = 0; s < 5; s++) {
      const t = base + (s - 2) * 0.12;
      const r = 1.05 + s * 0.22;
      parts.push(boxMesh(Math.cos(t) * r, 0.06 + s * 0.02, Math.sin(t) * r, 0.32, 0.12 + s * 0.04, 0.55 + s * 0.15));
    }
  }

  // Energy ring (translucent blue)
  parts.push(cylinderMesh(1.05, 0.22, 40));

  // Face bolt / pegasus crest
  parts.push(cylinderMesh(0.55, 0.18, 24));
  parts.push(boxMesh(0, 0.12, 0.72, 0.55, 0.08, 0.35));
  parts.push(boxMesh(0.38, 0.12, 0.38, 0.35, 0.08, 0.55));
  parts.push(boxMesh(-0.38, 0.12, 0.38, 0.35, 0.08, 0.55));

  // 105 track stem
  parts.push(cylinderMesh(0.38, 0.95, 20));

  // RF flat tip
  parts.push(cylinderMesh(0.48, 0.14, 24));
  parts.push(boxMesh(0, -0.62, 0, 0.72, 0.08, 0.72));

  const wheel = mergeMeshes(parts.slice(0, 26));
  const wings = mergeMeshes(parts.slice(26, 41));
  const ring = parts[41];
  const face = mergeMeshes(parts.slice(42, 46));
  const track = parts[46];
  const tip = mergeMeshes(parts.slice(47));

  root.addChild(addMesh(doc, buffer, 'FusionWheel', wheel, COLORS.metal, 0.85, 0.25));
  root.addChild(addMesh(doc, buffer, 'AttackWings', wings, COLORS.blue, 0.5, 0.35));
  root.addChild(addMesh(doc, buffer, 'EnergyRing', ring, COLORS.cyan, 0.2, 0.5, 0.75));
  root.addChild(addMesh(doc, buffer, 'FaceBolt', face, COLORS.white, 0.6, 0.3));
  root.addChild(addMesh(doc, buffer, 'Track105', track, COLORS.silver, 0.7, 0.35));
  root.addChild(addMesh(doc, buffer, 'RFTip', tip, COLORS.rubber, 0.05, 0.9));

  scene.addChild(root);
  fs.mkdirSync(path.dirname(OUT), { recursive: true });
  await new NodeIO().write(OUT, doc);

  const stat = fs.statSync(OUT);
  console.log('Built procedural Storm Pegasus GLB:', OUT);
  console.log('  Size:', (stat.size / 1024).toFixed(1), 'KB');
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
