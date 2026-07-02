export type GameMode = {
  players: string;
  name: string;
  description: string;
};

export type Control = {
  action: string;
  input: string;
  description: string;
};

export const gameModes: GameMode[] = [
  {
    players: '1',
    name: 'Training',
    description: 'Übe gegen einen Dummy-Bey in der Arena.',
  },
  {
    players: '2',
    name: '1v1 PvP',
    description: 'Duell gegen einen anderen Spieler.',
  },
  {
    players: '3+',
    name: 'FFA',
    description: 'Free-for-All — letzter Bey in der Bowl gewinnt.',
  },
];

export const controls: Control[] = [
  {
    action: 'Bewegen',
    input: 'WASD / Joystick',
    description: 'Steuere deinen Bey durch die Arena.',
  },
  {
    action: 'Charge',
    input: 'Shift',
    description: 'Erhöht die Geschwindigkeit für einen Angriff.',
  },
  {
    action: 'Dodge',
    input: 'Space',
    description: 'Kurzer Ausweich-Boost.',
  },
  {
    action: 'Special',
    input: 'E',
    description: 'Aktiviert den Bey-Special-Move.',
  },
  {
    action: 'Restart',
    input: 'R',
    description: 'Startet das Match neu.',
  },
];

export const gameStats = {
  maxHp: 100,
  maxSpin: 100,
  maxSpecial: 100,
  hitDamage: 9,
  specialDamage: 35,
  arenaRadius: 36,
};
