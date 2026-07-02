import { useRef, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { Video, ResizeMode, AVPlaybackStatus } from 'expo-av';
import { specialVideoSources } from '../data/specialVideos';
import { SpecialPreview } from '../data/specialPreviews';

type Props = {
  move: SpecialPreview;
  width: number;
};

export function SpecialMoveVideo({ move, width }: Props) {
  const videoRef = useRef<Video>(null);
  const [phaseHint, setPhaseHint] = useState('');

  const source = specialVideoSources[move.id];
  if (!source) return null;

  const height = Math.round(width * (9 / 16));

  const onStatus = (status: AVPlaybackStatus) => {
    if (!status.isLoaded) return;
    const sec = status.positionMillis / 1000;
    const label = phaseLabelFor(move.id, sec);
    if (label !== phaseHint) setPhaseHint(label);
  };

  const replay = async () => {
    const v = videoRef.current;
    if (!v) return;
    await v.setPositionAsync(0);
    await v.playAsync();
  };

  return (
    <View style={[styles.wrap, { width }]}>
      <Video
        ref={videoRef}
        source={source}
        style={[styles.video, { width, height }]}
        resizeMode={ResizeMode.CONTAIN}
        useNativeControls
        isLooping
        shouldPlay
        onPlaybackStatusUpdate={onStatus}
      />
      {phaseHint ? (
        <Text style={[styles.phase, { color: move.color }]}>{phaseHint}</Text>
      ) : null}
      <Pressable style={styles.replay} onPress={replay}>
        <Text style={styles.replayText}>↻ Nochmal abspielen</Text>
      </Pressable>
    </View>
  );
}

/** Phase labels synced with BeyConfig.lua durations. */
function phaseLabelFor(id: string, sec: number): string {
  const phases: Record<string, [number, string][]> = {
    NovaMeteorShower: [
      [0.3, 'Windup — Charge Aura'],
      [0.55, 'Rush Launch'],
      [1.35, 'Meteor Barrage'],
    ],
    IronVaultLock: [
      [0.45, 'Burrow Underground'],
      [1.0, 'Fortress Wall'],
      [1.85, 'Pulse Shockwaves'],
    ],
    VoltSonicTempest: [
      [0.35, 'Spin Charge'],
      [1.1, 'Sonic Rings'],
      [1.75, 'Orbit Attack'],
    ],
    ShadowEclipseFang: [
      [0.25, 'Dark Aura — Lift'],
      [0.65, 'Aerial Dive'],
      [1.0, 'Venom Burst'],
    ],
  };

  const list = phases[id];
  if (!list) return '';
  for (const [end, label] of list) {
    if (sec <= end) return label;
  }
  return '';
}

const styles = StyleSheet.create({
  wrap: {
    alignSelf: 'center',
    marginBottom: 8,
  },
  video: {
    backgroundColor: '#0d1220',
    borderRadius: 12,
    borderWidth: 2,
    borderColor: '#2a3348',
  },
  phase: {
    textAlign: 'center',
    fontSize: 12,
    fontWeight: '700',
    marginTop: 8,
    minHeight: 18,
  },
  replay: {
    alignSelf: 'center',
    marginTop: 6,
    paddingHorizontal: 12,
    paddingVertical: 6,
  },
  replayText: {
    color: '#8896b3',
    fontSize: 13,
    fontWeight: '600',
  },
});
