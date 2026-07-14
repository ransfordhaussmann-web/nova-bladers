export type SpecialMove = {
  id: string;
  name: string;
  mode: 'meteor' | 'fortress' | 'sonic' | 'eclipse';
  duration: number;
  rushSpeed?: number;
  damage: number;
  spinLoss: number;
  color: string;
  description: string;
  phases: string;
};

export const specialMoves: Record<string, SpecialMove> = {
  NovaMeteorShower: {
    id: 'NovaMeteorShower',
    name: 'Nova Meteor Shower',
    mode: 'meteor',
    duration: 1.35,
    rushSpeed: 78,
    damage: 35,
    spinLoss: 14,
    color: '#78c8ff',
    phases: 'Windup → Rush → Meteor Barrage',
    description: 'Charge-Aura, Rush zum Gegner, blaue Meteor-Trails + Explosionen.',
  },
  IronVaultLock: {
    id: 'IronVaultLock',
    name: 'Iron Vault Lock',
    mode: 'fortress',
    duration: 1.85,
    damage: 30,
    spinLoss: 8,
    color: '#50c878',
    phases: 'Burrow → Wall → Pulse Waves',
    description: 'Unterirdisch, grüne Festungsmauer, expandierende Schockwellen.',
  },
  VoltSonicTempest: {
    id: 'VoltSonicTempest',
    name: 'Volt Sonic Tempest',
    mode: 'sonic',
    duration: 1.75,
    damage: 32,
    spinLoss: 12,
    color: '#ffdc50',
    phases: 'Charge → Sonic Rings → Orbit',
    description: 'Gelbe Spin-Aura, expandierende Sonic-Ringe, Orbit-Angriff.',
  },
  ShadowEclipseFang: {
    id: 'ShadowEclipseFang',
    name: 'Shadow Eclipse Fang',
    mode: 'eclipse',
    duration: 1.15,
    rushSpeed: 92,
    damage: 42,
    spinLoss: 18,
    color: '#a050f0',
    phases: 'Dark Aura → Dive → Venom Burst',
    description: 'Lila Dark-Aura, Luft-Dive, Venom-Explosion beim Aufprall.',
  },
};

export const modeLabels: Record<SpecialMove['mode'], string> = {
  meteor: 'Meteor',
  fortress: 'Fortress',
  sonic: 'Sonic',
  eclipse: 'Eclipse',
};
