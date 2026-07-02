import { useState } from 'react';
import { Dimensions, Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { SpecialMoveAnimator } from '../components/SpecialMoveAnimator';
import { SectionHeader } from '../components/SectionHeader';
import { specialPreviews } from '../data/specialPreviews';
import { colors } from '../theme/colors';

const ARENA_SIZE = Math.min(Dimensions.get('window').width - 48, 360);

export function PreviewScreen() {
  const [selected, setSelected] = useState(0);
  const [replayKey, setReplayKey] = useState(0);
  const move = specialPreviews[selected];

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <SectionHeader
          title="Special Animation"
          subtitle="Phasen wie im Roblox-Spiel — Windup, Rush, VFX"
        />

        <SpecialMoveAnimator move={move} size={ARENA_SIZE} key={`${move.id}-${replayKey}`} />

        <Pressable style={styles.replayBtn} onPress={() => setReplayKey((k) => k + 1)}>
          <Text style={styles.replayBtnText}>↻ Animation wiederholen</Text>
        </Pressable>

        <View style={styles.hud}>
          <Text style={styles.hudTitle}>{move.beyName}</Text>
          <Text style={styles.hudStats}>
            HP: 100 · RPM: 85 · <Text style={styles.energy}>⚡ ENERGY READY</Text>
          </Text>
          <Text style={[styles.hudPhases, { color: move.color }]}>{move.phases}</Text>
        </View>

        {specialPreviews.map((m, i) => (
          <Pressable
            key={m.id}
            style={[styles.card, selected === i && { borderColor: m.color }]}
            onPress={() => {
              setSelected(i);
              setReplayKey((k) => k + 1);
            }}
          >
            <View style={[styles.cardAccent, { backgroundColor: m.color }]} />
            <Text style={[styles.cardTitle, { color: m.color }]}>{m.name}</Text>
            <Text style={styles.cardBey}>{m.beyName}</Text>
            <Text style={styles.cardDesc}>{m.description}</Text>
          </Pressable>
        ))}
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: colors.background },
  scroll: { padding: 20, paddingBottom: 40 },
  replayBtn: {
    alignSelf: 'center',
    backgroundColor: colors.surface,
    borderRadius: 10,
    paddingHorizontal: 20,
    paddingVertical: 10,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: colors.border,
  },
  replayBtnText: { color: colors.accent, fontWeight: '700', fontSize: 14 },
  hud: {
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 14,
    marginBottom: 16,
    borderWidth: 1,
    borderColor: colors.border,
  },
  hudTitle: { color: colors.text, fontWeight: '700', fontSize: 15 },
  hudStats: { color: colors.textMuted, fontSize: 13, marginTop: 4 },
  energy: { color: colors.speed, fontWeight: '700' },
  hudPhases: { fontSize: 12, marginTop: 6, fontWeight: '600' },
  card: {
    backgroundColor: colors.surface,
    borderRadius: 14,
    padding: 14,
    marginBottom: 10,
    borderWidth: 1.5,
    borderColor: colors.border,
    overflow: 'hidden',
  },
  cardAccent: { position: 'absolute', top: 0, left: 0, right: 0, height: 3 },
  cardTitle: { fontSize: 16, fontWeight: '800' },
  cardBey: { color: colors.textMuted, fontSize: 12, marginTop: 2 },
  cardDesc: { color: colors.textMuted, fontSize: 13, marginTop: 6, lineHeight: 18 },
});
