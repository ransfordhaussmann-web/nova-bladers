import { useCallback, useEffect, useRef, useState } from 'react';
import { Animated, Easing, StyleSheet, Text, View } from 'react-native';
import { movePhaseData, MovePhase, Particle, ParticleInput } from '../data/movePhaseData';
import { SpecialPreview } from '../data/specialPreviews';

const CENTER = 0;
const TARGET_X = 55;

type Props = {
  move: SpecialPreview;
  size: number;
};

function ParticleView({ p, size }: { p: Particle; size: number }) {
  const scale = useRef(new Animated.Value(0.1)).current;
  const opacity = useRef(new Animated.Value(1)).current;
  const fall = useRef(new Animated.Value(0)).current;

  useEffect(() => {
    if (p.kind === 'meteor') {
      Animated.parallel([
        Animated.timing(fall, { toValue: 1, duration: 500, useNativeDriver: true }),
        Animated.timing(opacity, { toValue: 0, duration: 500, useNativeDriver: true }),
      ]).start();
      return;
    }
    const dur = p.kind === 'wall' ? 900 : 650;
    Animated.parallel([
      Animated.timing(scale, { toValue: p.kind === 'ring' ? (p.maxScale ?? 2.2) : 2.5, duration: dur, easing: Easing.out(Easing.quad), useNativeDriver: true }),
      Animated.timing(opacity, { toValue: 0, duration: dur, useNativeDriver: true }),
    ]).start();
  }, [p.id]);

  const half = size / 2;

  if (p.kind === 'meteor') {
    return (
      <Animated.View
        style={[
          styles.meteor,
          {
            left: half + (p.x ?? 0) - 5,
            backgroundColor: p.color,
            opacity,
            transform: [{
              translateY: fall.interpolate({ inputRange: [0, 1], outputRange: [-half * 0.5, half * 0.15] }),
            }],
          },
        ]}
      />
    );
  }

  if (p.kind === 'trail' || p.kind === 'spark') {
    return (
      <View style={[styles.trailDot, { left: half + p.x, top: half + p.y, backgroundColor: p.color }]} />
    );
  }

  if (p.kind === 'dust') {
    return (
      <Animated.View
        style={[
          styles.dust,
          { borderColor: p.color, opacity, transform: [{ scale }] },
        ]}
      />
    );
  }

  const baseStyle = p.kind === 'wall'
    ? [styles.wallRing, { borderColor: p.color, opacity, transform: [{ scale }] }]
    : p.kind === 'aura'
    ? [styles.darkAura, { backgroundColor: p.color + '44', opacity, transform: [{ scale }] }]
    : p.kind === 'burst'
    ? [styles.venomBurst, { backgroundColor: p.color, left: half + p.x, top: half + p.y, opacity, transform: [{ scale }] }]
    : p.kind === 'impact'
    ? [styles.impact, { backgroundColor: p.color, left: half + p.x - 12, top: half + p.y - 12, opacity, transform: [{ scale }] }]
    : [styles.effectRing, { borderColor: p.color, opacity, transform: [{ scale }] }];

  return <Animated.View style={baseStyle} />;
}

export function SpecialMoveAnimator({ move, size }: Props) {
  const phases = movePhaseData[move.id] ?? [];
  const [phaseLabel, setPhaseLabel] = useState('');
  const [particles, setParticles] = useState<Particle[]>([]);
  const [playing, setPlaying] = useState(true);

  const beyX = useRef(new Animated.Value(CENTER)).current;
  const beyY = useRef(new Animated.Value(CENTER)).current;
  const beyScale = useRef(new Animated.Value(1)).current;
  const beyOpacity = useRef(new Animated.Value(1)).current;
  const chargeRing = useRef(new Animated.Value(0.3)).current;
  const chargeOpacity = useRef(new Animated.Value(0)).current;
  const callout = useRef(new Animated.Value(0)).current;
  const orbitAngle = useRef(new Animated.Value(0)).current;

  const timers = useRef<ReturnType<typeof setTimeout>[]>([]);
  const pid = useRef(0);

  const addParticle = useCallback((p: ParticleInput) => {
    const id = ++pid.current;
    setParticles((prev) => [...prev.slice(-24), { ...p, id } as Particle]);
    setTimeout(() => setParticles((prev) => prev.filter((x) => x.id !== id)), 900);
  }, []);

  const clearTimers = () => {
    timers.current.forEach(clearTimeout);
    timers.current = [];
  };

  const later = (fn: () => void, ms: number) => {
    timers.current.push(setTimeout(fn, ms));
  };

  const runChargeAura = (ms: number) => {
    chargeOpacity.setValue(0.7);
    chargeRing.setValue(0.4);
    Animated.parallel([
      Animated.timing(chargeRing, { toValue: 1.6, duration: ms, useNativeDriver: true }),
      Animated.timing(chargeOpacity, { toValue: 0, duration: ms, useNativeDriver: true }),
    ]).start();
    for (let i = 0; i < 8; i++) {
      const angle = (i / 8) * Math.PI * 2;
      later(
        () =>
          addParticle({
            kind: 'spark',
            x: Math.cos(angle) * 28,
            y: Math.sin(angle) * 28 - 10,
            color: move.color,
          }),
        i * (ms / 8)
      );
    }
  };

  const runPhase = (phase: MovePhase, startMs: number) => {
    later(() => setPhaseLabel(phase.label), startMs);

    if (move.id === 'NovaMeteorShower') {
      if (phase.id === 'windup') {
        later(() => {
          beyX.setValue(CENTER);
          beyY.setValue(CENTER);
          runChargeAura(phase.ms);
        }, startMs);
      } else if (phase.id === 'launch') {
        later(() => {
          Animated.timing(beyX, { toValue: TARGET_X * 0.7, duration: phase.ms, useNativeDriver: true }).start();
        }, startMs);
      } else if (phase.id === 'shower') {
        const interval = phase.interval ?? 180;
        const count = Math.floor(phase.ms / interval);
        for (let i = 0; i < count; i++) {
          later(() => {
            const x = TARGET_X * 0.5 + (Math.random() - 0.5) * 30;
            addParticle({ kind: 'meteor', x, color: move.color });
            addParticle({ kind: 'impact', x, y: 10, color: move.color });
          }, startMs + i * interval);
        }
      }
    }

    if (move.id === 'IronVaultLock') {
      if (phase.id === 'burrow') {
        later(() => {
          addParticle({ kind: 'dust', color: move.color });
          Animated.timing(beyOpacity, { toValue: 0.08, duration: phase.ms * 0.6, useNativeDriver: true }).start();
          Animated.timing(beyY, { toValue: CENTER + 25, duration: phase.ms, useNativeDriver: true }).start();
        }, startMs);
      } else if (phase.id === 'wall') {
        later(() => {
          Animated.timing(beyOpacity, { toValue: 1, duration: 200, useNativeDriver: true }).start();
          Animated.timing(beyY, { toValue: CENTER, duration: 200, useNativeDriver: true }).start();
          addParticle({ kind: 'wall', color: move.color });
        }, startMs);
      } else if (phase.id === 'pulse') {
        const interval = phase.interval ?? 320;
        const count = Math.floor(phase.ms / interval);
        for (let i = 0; i < count; i++) {
          later(() => addParticle({ kind: 'ring', maxScale: 1.8 + i * 0.3, color: move.color }), startMs + i * interval);
        }
      }
    }

    if (move.id === 'VoltSonicTempest') {
      if (phase.id === 'charge') {
        later(() => runChargeAura(phase.ms), startMs);
      } else if (phase.id === 'sonic') {
        const interval = phase.interval ?? 280;
        const count = Math.floor(phase.ms / interval);
        for (let i = 0; i < count; i++) {
          later(() => addParticle({ kind: 'ring', maxScale: 1.2 + i * 0.45, color: move.color }), startMs + i * interval);
        }
      } else if (phase.id === 'orbit') {
        later(() => {
          orbitAngle.setValue(0);
          Animated.loop(
            Animated.timing(orbitAngle, { toValue: 1, duration: 600, easing: Easing.linear, useNativeDriver: true }),
            { iterations: Math.ceil(phase.ms / 600) }
          ).start();
          beyX.setValue(0);
          beyY.setValue(0);
        }, startMs);
      }
    }

    if (move.id === 'ShadowEclipseFang') {
      if (phase.id === 'aura') {
        later(() => {
          addParticle({ kind: 'aura', color: move.color });
          Animated.timing(beyY, { toValue: CENTER - 45, duration: phase.ms, useNativeDriver: true }).start();
        }, startMs);
      } else if (phase.id === 'dive') {
        later(() => {
          for (let i = 0; i < 5; i++) {
            addParticle({ kind: 'trail', x: -20 + i * 12, y: -30 + i * 14, color: move.color });
          }
          Animated.parallel([
            Animated.timing(beyY, { toValue: CENTER + 20, duration: phase.ms, useNativeDriver: true }),
            Animated.timing(beyX, { toValue: TARGET_X * 0.5, duration: phase.ms, useNativeDriver: true }),
          ]).start();
        }, startMs);
      } else if (phase.id === 'burst') {
        later(() => {
          addParticle({ kind: 'burst', color: move.color, x: TARGET_X * 0.5, y: 20 });
        }, startMs);
      }
    }
  };

  const play = useCallback(() => {
    clearTimers();
    setParticles([]);
    setPlaying(true);
    beyX.setValue(CENTER);
    beyY.setValue(CENTER);
    beyScale.setValue(1);
    beyOpacity.setValue(1);
    chargeOpacity.setValue(0);
    callout.setValue(0);

    Animated.sequence([
      Animated.timing(callout, { toValue: 1, duration: 250, useNativeDriver: true }),
      Animated.delay(1800),
      Animated.timing(callout, { toValue: 0, duration: 250, useNativeDriver: true }),
    ]).start();

    let offset = 0;
    phases.forEach((phase) => {
      runPhase(phase, offset);
      offset += phase.ms;
    });

    later(() => {
      setPlaying(false);
      setPhaseLabel('Fertig — tippe Replay');
    }, offset + 200);
  }, [move.id]);

  useEffect(() => {
    play();
    return clearTimers;
  }, [move.id, play]);

  const half = size / 2;

  return (
    <View style={[styles.arena, { width: size, height: size, borderRadius: size / 2 }]}>
      <Text style={styles.arenaLabel}>Nova Arena</Text>
      <Text style={[styles.phaseLabel, { color: move.color }]}>{phaseLabel}</Text>

      {/* Dummy target */}
      <View style={[styles.target, { left: half + TARGET_X - 8, top: half - 8 }]} />

      {particles.map((p) => (
        <ParticleView key={p.id} p={p} size={size} />
      ))}

      <Animated.View
        style={[
          styles.chargeRing,
          {
            borderColor: move.color,
            opacity: chargeOpacity,
            transform: [{ scale: chargeRing }],
          },
        ]}
      />

      <Animated.Text style={[styles.callout, { color: move.color, opacity: callout }]}>
        ⚡ {move.name}!
      </Animated.Text>

      {move.id === 'VoltSonicTempest' && phaseLabel.includes('Orbit') ? (
        <Animated.View
          style={[
            styles.bey,
            {
              backgroundColor: move.beyColor,
              left: half - 22,
              top: half - 22,
              transform: [
                {
                  translateX: orbitAngle.interpolate({
                    inputRange: [0, 0.25, 0.5, 0.75, 1],
                    outputRange: [35, 0, -35, 0, 35],
                  }),
                },
                {
                  translateY: orbitAngle.interpolate({
                    inputRange: [0, 0.25, 0.5, 0.75, 1],
                    outputRange: [0, 35, 0, -35, 0],
                  }),
                },
              ],
            },
          ]}
        >
          <View style={[styles.beyRing, { borderColor: move.color }]} />
        </Animated.View>
      ) : (
        <Animated.View
          style={[
            styles.bey,
            {
              backgroundColor: move.beyColor,
              opacity: beyOpacity,
              left: half - 22,
              top: half - 22,
              transform: [{ translateX: beyX }, { translateY: beyY }, { scale: beyScale }],
            },
          ]}
        >
          <View style={[styles.beyRing, { borderColor: move.color }]} />
        </Animated.View>
      )}

      {!playing && (
        <Text style={styles.replayHint} onPress={play}>
          ↻ Replay
        </Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  arena: {
    alignSelf: 'center',
    backgroundColor: '#141b2d',
    borderWidth: 3,
    borderColor: '#5090ff44',
    marginBottom: 12,
    overflow: 'hidden',
  },
  arenaLabel: {
    position: 'absolute',
    top: 14,
    alignSelf: 'center',
    color: '#5090ff',
    fontSize: 9,
    letterSpacing: 2,
    fontWeight: '700',
    zIndex: 30,
  },
  phaseLabel: {
    position: 'absolute',
    bottom: 12,
    alignSelf: 'center',
    fontSize: 11,
    fontWeight: '700',
    zIndex: 30,
    textAlign: 'center',
    paddingHorizontal: 8,
  },
  callout: {
    position: 'absolute',
    top: '38%',
    alignSelf: 'center',
    fontSize: 14,
    fontWeight: '800',
    zIndex: 25,
  },
  target: {
    position: 'absolute',
    width: 16,
    height: 16,
    borderRadius: 8,
    backgroundColor: '#ff506066',
    borderWidth: 2,
    borderColor: '#ff5060',
  },
  bey: {
    position: 'absolute',
    width: 44,
    height: 44,
    borderRadius: 22,
    justifyContent: 'center',
    alignItems: 'center',
    zIndex: 15,
  },
  beyRing: {
    width: 54,
    height: 54,
    borderRadius: 27,
    borderWidth: 2,
    position: 'absolute',
  },
  chargeRing: {
    position: 'absolute',
    alignSelf: 'center',
    top: '50%',
    marginTop: -40,
    width: 80,
    height: 80,
    borderRadius: 40,
    borderWidth: 2,
  },
  effectRing: {
    position: 'absolute',
    alignSelf: 'center',
    top: '50%',
    marginTop: -30,
    width: 60,
    height: 60,
    borderRadius: 30,
    borderWidth: 2,
  },
  wallRing: {
    position: 'absolute',
    alignSelf: 'center',
    top: '50%',
    marginTop: -50,
    width: 100,
    height: 100,
    borderRadius: 50,
    borderWidth: 3,
  },
  darkAura: {
    position: 'absolute',
    alignSelf: 'center',
    top: '50%',
    marginTop: -45,
    width: 90,
    height: 90,
    borderRadius: 45,
  },
  meteor: {
    position: 'absolute',
    width: 10,
    height: 10,
    borderRadius: 5,
    zIndex: 12,
  },
  impact: {
    position: 'absolute',
    width: 24,
    height: 24,
    borderRadius: 12,
    zIndex: 11,
  },
  trailDot: {
    position: 'absolute',
    width: 8,
    height: 8,
    borderRadius: 4,
    zIndex: 12,
  },
  dust: {
    position: 'absolute',
    alignSelf: 'center',
    top: '55%',
    width: 70,
    height: 24,
    borderRadius: 12,
    borderWidth: 2,
    backgroundColor: '#3a353044',
  },
  venomBurst: {
    position: 'absolute',
    width: 20,
    height: 20,
    borderRadius: 10,
    zIndex: 14,
  },
  replayHint: {
    position: 'absolute',
    top: 36,
    right: 14,
    color: '#8896b3',
    fontSize: 12,
    zIndex: 30,
  },
});
