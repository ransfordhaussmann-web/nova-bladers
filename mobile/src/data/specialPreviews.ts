export type SpecialPreview = {
  id: string;
  beyName: string;
  name: string;
  color: string;
  beyColor: string;
  phases: string;
  description: string;
};

export const specialPreviews: SpecialPreview[] = [
  {
    id: 'NovaMeteorShower',
    beyName: 'Nova Striker',
    name: 'Nova Meteor Shower',
    color: '#78c8ff',
    beyColor: '#508cff',
    phases: 'Windup → Rush → Meteor Barrage',
    description: 'Charge-Aura, Rush zum Gegner, blaue Meteor-Trails + Explosionen.',
  },
  {
    id: 'IronVaultLock',
    beyName: 'Iron Shell',
    name: 'Iron Vault Lock',
    color: '#50c878',
    beyColor: '#50b46e',
    phases: 'Burrow → Wall → Pulse Waves',
    description: 'Unterirdisch, grüne Festungsmauer, expandierende Schockwellen.',
  },
  {
    id: 'VoltSonicTempest',
    beyName: 'Volt Dash',
    name: 'Volt Sonic Tempest',
    color: '#ffdc50',
    beyColor: '#ffc83c',
    phases: 'Charge → Sonic Rings → Orbit',
    description: 'Gelbe Spin-Aura, expandierende Sonic-Ringe, Orbit-Angriff.',
  },
  {
    id: 'ShadowEclipseFang',
    beyName: 'Shadow Bite',
    name: 'Shadow Eclipse Fang',
    color: '#a050f0',
    beyColor: '#8c50dc',
    phases: 'Dark Aura → Dive → Venom Burst',
    description: 'Lila Dark-Aura, Luft-Dive, Venom-Explosion beim Aufprall.',
  },
];
