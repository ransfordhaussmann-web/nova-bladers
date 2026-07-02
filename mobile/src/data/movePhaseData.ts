/** Phase timings synced with src/ReplicatedStorage/NovaBladers/BeyConfig.lua */
export type MovePhase = {
  id: string;
  label: string;
  ms: number;
  interval?: number;
};

export const movePhaseData: Record<string, MovePhase[]> = {
  NovaMeteorShower: [
    { id: 'windup', label: 'Windup — Charge Aura', ms: 300 },
    { id: 'launch', label: 'Rush Launch', ms: 250 },
    { id: 'shower', label: 'Meteor Barrage', ms: 800, interval: 180 },
  ],
  IronVaultLock: [
    { id: 'burrow', label: 'Burrow Underground', ms: 450 },
    { id: 'wall', label: 'Fortress Wall', ms: 550 },
    { id: 'pulse', label: 'Pulse Shockwaves', ms: 850, interval: 320 },
  ],
  VoltSonicTempest: [
    { id: 'charge', label: 'Spin Charge', ms: 350 },
    { id: 'sonic', label: 'Sonic Rings', ms: 750, interval: 280 },
    { id: 'orbit', label: 'Orbit Attack', ms: 650 },
  ],
  ShadowEclipseFang: [
    { id: 'aura', label: 'Dark Aura — Lift', ms: 250 },
    { id: 'dive', label: 'Aerial Dive', ms: 400 },
    { id: 'burst', label: 'Venom Burst', ms: 350 },
  ],
};

export type Particle =
  | { kind: 'ring'; id: number; maxScale: number; color: string }
  | { kind: 'meteor'; id: number; x: number; color: string }
  | { kind: 'impact'; id: number; x: number; y: number; color: string }
  | { kind: 'trail'; id: number; x: number; y: number; color: string }
  | { kind: 'dust'; id: number; color: string }
  | { kind: 'wall'; id: number; color: string }
  | { kind: 'aura'; id: number; color: string }
  | { kind: 'burst'; id: number; color: string; x: number; y: number }
  | { kind: 'spark'; id: number; x: number; y: number; color: string };

export type ParticleInput =
  | { kind: 'ring'; maxScale: number; color: string }
  | { kind: 'meteor'; x: number; color: string }
  | { kind: 'impact'; x: number; y: number; color: string }
  | { kind: 'trail'; x: number; y: number; color: string }
  | { kind: 'dust'; color: string }
  | { kind: 'wall'; color: string }
  | { kind: 'aura'; color: string }
  | { kind: 'burst'; color: string; x: number; y: number }
  | { kind: 'spark'; x: number; y: number; color: string };
