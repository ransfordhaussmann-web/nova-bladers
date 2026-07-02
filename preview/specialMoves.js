/** Shared special move data + deterministic renderer (synced with BeyConfig.lua). */
export const MOVES = [
  {
    id: 'NovaMeteorShower',
    name: 'Nova Meteor Shower',
    bey: 'Nova Striker',
    color: '#4a9eff',
    desc: 'Windup-Aura → Rush zum Gegner → Meteoritenschauer mit Einschlägen',
    phases: [
      { label: 'Windup — Charge Aura', dur: 0.3, fn: (a, t, c) => { chargeAura(a, t, c); sparks(a, t, c); } },
      { label: 'Rush Launch', dur: 0.25, fn: (a, t, c) => { rush(a, t, c); chargeAura(a, 1 - t * 0.5, c); } },
      { label: 'Meteor Barrage', dur: 0.8, fn: (a, t, c) => { meteors(a, t, c); if (t > 0.2) impacts(a, Math.min(1, (t - 0.2) / 0.6), c); beyAtTarget(a); } },
    ],
  },
  {
    id: 'IronVaultLock',
    name: 'Iron Vault Lock',
    bey: 'Iron Shell',
    color: '#50c878',
    desc: 'Eingraben → Stahlwand → Schockwellen-Pulse',
    phases: [
      { label: 'Burrow Underground', dur: 0.45, fn: (a, t, c) => { sink(a, t); dust(a, t, c); } },
      { label: 'Fortress Wall', dur: 0.55, fn: (a, t, c) => { rise(a, t); wall(a, t, c); } },
      { label: 'Pulse Shockwaves', dur: 0.85, fn: (a, t, c) => { wall(a, 1, c); rings(a, t, c); } },
    ],
  },
  {
    id: 'VoltSonicTempest',
    name: 'Volt Sonic Tempest',
    bey: 'Volt Dash',
    color: '#ffcc00',
    desc: 'Aufladen → Schallwellen → Orbit-Angriff',
    phases: [
      { label: 'Spin Charge', dur: 0.35, fn: (a, t, c) => { chargeAura(a, t, c); sparks(a, t, c); } },
      { label: 'Sonic Rings', dur: 0.75, fn: (a, t, c) => sonic(a, t, c) },
      { label: 'Orbit Attack', dur: 0.65, fn: (a, t, c) => orbit(a, t, c) },
    ],
  },
  {
    id: 'ShadowEclipseFang',
    name: 'Shadow Eclipse Fang',
    bey: 'Shadow Bite',
    color: '#8844cc',
    desc: 'Dunkle Aura → Sturzflug → Gift-Burst',
    phases: [
      { label: 'Dark Aura — Lift', dur: 0.25, fn: (a, t, c) => { darkAura(a, t, c); lift(a, t); } },
      { label: 'Aerial Dive', dur: 0.4, fn: (a, t, c) => dive(a, t, c) },
      { label: 'Venom Burst', dur: 0.35, fn: (a, t, c) => venom(a, t, c) },
    ],
  },
];

export function getMove(id) {
  return MOVES.find((m) => m.id === id) ?? MOVES[0];
}

export function moveDuration(move) {
  return move.phases.reduce((s, p) => s + p.dur, 0);
}

export function renderMoveAtTime(arena, labelEl, move, elapsed) {
  clearFx(arena);
  resetBey(arena);

  const total = moveDuration(move);
  if (elapsed >= total) {
    if (labelEl) labelEl.textContent = '';
    return { done: true, phaseLabel: '' };
  }

  let phaseIdx = 0;
  let phaseElapsed = elapsed;
  while (phaseIdx < move.phases.length && phaseElapsed >= move.phases[phaseIdx].dur) {
    phaseElapsed -= move.phases[phaseIdx].dur;
    phaseIdx++;
  }

  if (phaseIdx >= move.phases.length) {
    if (labelEl) labelEl.textContent = '';
    return { done: true, phaseLabel: '' };
  }

  const ph = move.phases[phaseIdx];
  const t = Math.min(1, phaseElapsed / ph.dur);
  if (labelEl) labelEl.textContent = ph.label;
  ph.fn(arena, t, move.color);
  return { done: false, phaseLabel: ph.label };
}

function clearFx(arena) {
  arena.querySelectorAll('.fx').forEach((el) => el.remove());
}

function chargeAura(arena, t, color) {
  const r = 20 + t * 50;
  const el = document.createElement('div');
  el.className = 'fx';
  el.style.cssText = `left:50%;top:50%;width:${r * 2}px;height:${r * 2}px;margin:-${r}px 0 0 -${r}px;border-radius:50%;border:2px solid ${color};opacity:${0.5 - t * 0.4}`;
  arena.appendChild(el);
}

function sparks(arena, t, color) {
  for (let i = 0; i < 8; i++) {
    const angle = (i / 8) * Math.PI * 2;
    const dist = 15 + t * 25;
    const el = document.createElement('div');
    el.className = 'fx';
    el.style.cssText = `left:calc(50% + ${Math.cos(angle) * dist}px);top:calc(50% + ${Math.sin(angle) * dist - 15}px);width:5px;height:5px;background:${color};border-radius:50%;opacity:${0.8 - t * 0.5}`;
    arena.appendChild(el);
  }
}

function beyAtTarget(arena) {
  const bey = arena.querySelector('.bey-dot');
  bey.style.left = '72%';
  bey.style.top = '38%';
}

function rush(arena, t, color) {
  const bey = arena.querySelector('.bey-dot');
  const tx = 28;
  const ty = -12;
  bey.style.left = `${50 + tx * t}%`;
  bey.style.top = `${50 + ty * t}%`;
  const trail = document.createElement('div');
  trail.className = 'fx';
  trail.style.cssText = `left:${50 + tx * t * 0.5}%;top:${50 + ty * t * 0.5}%;width:40px;height:4px;background:${color};opacity:0.5;border-radius:2px;transform:translate(-50%,-50%) rotate(-20deg)`;
  arena.appendChild(trail);
}

function meteors(arena, t, color) {
  for (let i = 0; i < 6; i++) {
    const phase = (t * 3 + i * 0.15) % 1;
    const el = document.createElement('div');
    el.className = 'fx';
    const x = 20 + (i * 13) % 60;
    const y = phase * 90;
    el.style.cssText = `left:${x}%;top:${y}%;width:8px;height:8px;background:${color};border-radius:50%;box-shadow:0 0 8px ${color}`;
    arena.appendChild(el);
  }
}

function impacts(arena, t, color) {
  for (let i = 0; i < 4; i++) {
    const el = document.createElement('div');
    el.className = 'fx';
    const x = 25 + i * 15;
    const r = 10 + t * 25;
    el.style.cssText = `left:${x}%;top:55%;width:${r * 2}px;height:${r * 2}px;margin:-${r}px 0 0 -${r}px;border-radius:50%;border:2px solid ${color};opacity:${1 - t}`;
    arena.appendChild(el);
  }
}

function sink(arena, t) {
  const bey = arena.querySelector('.bey-dot');
  bey.style.transform = `translate(-50%, calc(-50% + ${t * 20}px)) scale(${1 - t * 0.3})`;
  bey.style.opacity = String(1 - t * 0.5);
}

function dust(arena, t, color) {
  for (let i = 0; i < 5; i++) {
    const el = document.createElement('div');
    el.className = 'fx';
    el.style.cssText = `left:${40 + i * 5}%;top:${55 + i * 3}%;width:6px;height:6px;background:${color};border-radius:50%;opacity:${0.6 - t * 0.4}`;
    arena.appendChild(el);
  }
}

function wall(arena, t, color) {
  const el = document.createElement('div');
  el.className = 'fx';
  const h = t * 80;
  el.style.cssText = `left:15%;top:${100 - h}%;width:8px;height:${h}%;background:linear-gradient(to top,${color},transparent);border-radius:4px;opacity:0.8`;
  arena.appendChild(el);
  const el2 = el.cloneNode();
  el2.style.left = '75%';
  arena.appendChild(el2);
}

function rings(arena, t, color) {
  for (let i = 0; i < 3; i++) {
    const el = document.createElement('div');
    el.className = 'fx';
    const r = 20 + (t * 60 + i * 25);
    el.style.cssText = `left:50%;top:50%;width:${r * 2}px;height:${r * 2}px;margin:-${r}px 0 0 -${r}px;border-radius:50%;border:2px solid ${color};opacity:${0.8 - t * 0.6}`;
    arena.appendChild(el);
  }
}

function sonic(arena, t, color) {
  for (let i = 0; i < 4; i++) {
    const el = document.createElement('div');
    el.className = 'fx';
    const r = 15 + ((t * 4 + i) % 1) * 70;
    el.style.cssText = `left:50%;top:50%;width:${r * 2}px;height:${r * 2}px;margin:-${r}px 0 0 -${r}px;border-radius:50%;border:2px solid ${color};opacity:${0.7 - ((t * 4 + i) % 1) * 0.6}`;
    arena.appendChild(el);
  }
}

function orbit(arena, t, color) {
  const bey = arena.querySelector('.bey-dot');
  const angle = t * Math.PI * 4;
  const rx = 25;
  const ry = 18;
  bey.style.left = `${50 + Math.cos(angle) * rx}%`;
  bey.style.top = `${50 + Math.sin(angle) * ry}%`;
  const el = document.createElement('div');
  el.className = 'fx';
  el.style.cssText = `left:72%;top:38%;width:30px;height:30px;border-radius:50%;border:2px dashed ${color};opacity:0.5`;
  arena.appendChild(el);
}

function darkAura(arena, t, color) {
  const el = document.createElement('div');
  el.className = 'fx';
  const r = 40 + t * 30;
  el.style.cssText = `left:50%;top:50%;width:${r * 2}px;height:${r * 2}px;margin:-${r}px 0 0 -${r}px;border-radius:50%;background:radial-gradient(circle,${color}44,transparent);opacity:${0.5 + t * 0.3}`;
  arena.appendChild(el);
}

function dive(arena, t, color) {
  const bey = arena.querySelector('.bey-dot');
  bey.style.left = `${50 + 22 * t}%`;
  bey.style.top = `${32 + 6 * t}%`;
  for (let i = 0; i < 5; i++) {
    const el = document.createElement('div');
    el.className = 'fx';
    const pt = Math.max(0, t - i * 0.12);
    el.style.cssText = `left:${50 + 22 * pt}%;top:${32 + 6 * pt}%;width:5px;height:5px;background:${color};border-radius:50%;opacity:${0.7 - i * 0.12}`;
    arena.appendChild(el);
  }
}

function venom(arena, t, color) {
  const el = document.createElement('div');
  el.className = 'fx';
  const r = 15 + t * 50;
  el.style.cssText = `left:72%;top:38%;width:${r * 2}px;height:${r * 2}px;margin:-${r}px 0 0 -${r}px;border-radius:50%;background:radial-gradient(circle,${color}88,transparent);opacity:${0.9 - t * 0.5}`;
  arena.appendChild(el);
  for (let i = 0; i < 8; i++) {
    const p = document.createElement('div');
    p.className = 'fx';
    const a = (i / 8) * Math.PI * 2;
    p.style.cssText = `left:calc(72% + ${Math.cos(a) * r * 0.5}px);top:calc(38% + ${Math.sin(a) * r * 0.5}px);width:5px;height:5px;background:${color};border-radius:50%`;
    arena.appendChild(p);
  }
}

function rise(arena, t) {
  const bey = arena.querySelector('.bey-dot');
  bey.style.transform = `translate(-50%, calc(-50% + ${(1 - t) * 15}px)) scale(${0.7 + t * 0.3})`;
  bey.style.opacity = String(0.3 + t * 0.7);
}

function lift(arena, t) {
  const bey = arena.querySelector('.bey-dot');
  bey.style.top = `${50 - 18 * t}%`;
}

function resetBey(arena) {
  const bey = arena.querySelector('.bey-dot');
  bey.style.left = '50%';
  bey.style.top = '50%';
  bey.style.transform = 'translate(-50%, -50%)';
  bey.style.opacity = '1';
  arena.style.opacity = '1';
}

export function playMove(card, move) {
  if (card.dataset.playing === '1') return;
  card.dataset.playing = '1';
  card.classList.add('playing');
  const arena = card.querySelector('.arena');
  const label = card.querySelector('.phase-label');
  const total = moveDuration(move);
  let elapsed = 0;

  function frame() {
    if (card.dataset.playing !== '1') return;
    elapsed += 1 / 60;
    const { done } = renderMoveAtTime(arena, label, move, elapsed);
    if (!done && elapsed < total) {
      requestAnimationFrame(frame);
    } else {
      card.dataset.playing = '0';
      card.classList.remove('playing');
      clearFx(arena);
      resetBey(arena);
      if (label) label.textContent = '';
    }
  }
  requestAnimationFrame(frame);
}
