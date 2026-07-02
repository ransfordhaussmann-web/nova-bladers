export type BeyStats = {
  Attack: number;
  Defense: number;
  Speed: number;
  SpinDecayMult?: number;
};

export type Bey = {
  id: string;
  name: string;
  beyType: 'Attack' | 'Defense' | 'Stamina' | 'Balance';
  color: string;
  stats: BeyStats;
  special: string;
  specialId: string;
  desc: string;
};

export const beyCatalog: Bey[] = [
  {
    id: 'NovaStriker',
    name: 'Nova Striker',
    beyType: 'Attack',
    color: '#508cff',
    stats: { Attack: 8, Defense: 4, Speed: 7 },
    special: 'Starfall Rush',
    specialId: 'StarfallRush',
    desc: 'Schneller Angreifer mit starkem Rush.',
  },
  {
    id: 'IronShell',
    name: 'Iron Shell',
    beyType: 'Defense',
    color: '#50b46e',
    stats: { Attack: 4, Defense: 8, Speed: 5 },
    special: 'Shell Guard',
    specialId: 'ShellGuard',
    desc: 'Defensiver Tank, hält Treffer aus.',
  },
  {
    id: 'VoltDash',
    name: 'Volt Dash',
    beyType: 'Stamina',
    color: '#ffc83c',
    stats: { Attack: 6, Defense: 5, Speed: 9, SpinDecayMult: 0.65 },
    special: 'Thunder Loop',
    specialId: 'ThunderLoop',
    desc: 'Extrem schnell, hält Spin länger.',
  },
  {
    id: 'ShadowBite',
    name: 'Shadow Bite',
    beyType: 'Balance',
    color: '#8c50dc',
    stats: { Attack: 7, Defense: 6, Speed: 6 },
    special: 'Night Fang',
    specialId: 'NightFang',
    desc: 'Ausgewogener Kämpfer mit starken Clashes.',
  },
];
