export type SpecialMove = {
  id: string;
  name: string;
  mode: 'rush' | 'guard' | 'orbit' | 'lunge';
  duration: number;
  rushSpeed: number;
  damage: number;
  spinLoss: number;
  color: string;
  description: string;
  extra?: Record<string, number>;
};

export const specialMoves: Record<string, SpecialMove> = {
  StarfallRush: {
    id: 'StarfallRush',
    name: 'Starfall Rush',
    mode: 'rush',
    duration: 0.75,
    rushSpeed: 72,
    damage: 35,
    spinLoss: 15,
    color: '#78c8ff',
    description: 'Blitzschneller Angriff in Richtung des Gegners.',
  },
  ShellGuard: {
    id: 'ShellGuard',
    name: 'Shell Guard',
    mode: 'guard',
    duration: 1.4,
    rushSpeed: 8,
    damage: 14,
    spinLoss: 6,
    color: '#50c878',
    description: 'Defensive Haltung mit Schadensreduktion und Impuls-Wellen.',
    extra: { damageReduction: 0.5, pulseInterval: 0.35, pulseRange: 7 },
  },
  ThunderLoop: {
    id: 'ThunderLoop',
    name: 'Thunder Loop',
    mode: 'orbit',
    duration: 0.9,
    rushSpeed: 58,
    damage: 28,
    spinLoss: 12,
    color: '#ffdc50',
    description: 'Orbitiert um den Gegner und trifft mehrfach.',
    extra: { orbitRadius: 5, orbitSpeed: 14 },
  },
  NightFang: {
    id: 'NightFang',
    name: 'Night Fang',
    mode: 'lunge',
    duration: 0.5,
    rushSpeed: 88,
    damage: 42,
    spinLoss: 18,
    color: '#a050f0',
    description: 'Explosiver Lunge mit maximalem Schaden.',
  },
};

export const modeLabels: Record<SpecialMove['mode'], string> = {
  rush: 'Rush',
  guard: 'Guard',
  orbit: 'Orbit',
  lunge: 'Lunge',
};
