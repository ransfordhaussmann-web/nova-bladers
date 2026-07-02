import { ScrollView, View, Text, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { StatBar } from '../components/StatBar';
import { beyCatalog } from '../data/beyCatalog';
import { modeLabels, specialMoves } from '../data/specialMoves';
import { BeysStackParamList } from '../navigation/types';
import { beyTypeColors, colors } from '../theme/colors';

type Props = NativeStackScreenProps<BeysStackParamList, 'BeyDetail'>;

export function BeyDetailScreen({ route }: Props) {
  const bey = beyCatalog.find((b) => b.id === route.params.beyId);
  if (!bey) {
    return (
      <SafeAreaView style={styles.safe}>
        <Text style={styles.error}>Bey nicht gefunden.</Text>
      </SafeAreaView>
    );
  }

  const special = specialMoves[bey.specialId];
  const typeColor = beyTypeColors[bey.beyType] ?? colors.accent;

  return (
    <SafeAreaView style={styles.safe} edges={['bottom']}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <View style={[styles.banner, { backgroundColor: bey.color }]}>
          <Text style={styles.bannerName}>{bey.name}</Text>
          <View style={[styles.typeBadge, { borderColor: '#ffffff88' }]}>
            <Text style={styles.typeBadgeText}>{bey.beyType}</Text>
          </View>
        </View>

        <View style={styles.body}>
          <Text style={styles.desc}>{bey.desc}</Text>

          <Text style={styles.sectionTitle}>Stats</Text>
          <View style={styles.statsBox}>
            <StatBar label="Attack" value={bey.stats.Attack} color={colors.attack} />
            <StatBar label="Defense" value={bey.stats.Defense} color={colors.defense} />
            <StatBar label="Speed" value={bey.stats.Speed} color={colors.speed} />
            {bey.stats.SpinDecayMult != null && (
              <View style={styles.extraStat}>
                <Text style={styles.extraLabel}>Spin-Haltbarkeit</Text>
                <Text style={[styles.extraValue, { color: colors.speed }]}>
                  +{Math.round((1 - bey.stats.SpinDecayMult) * 100)}%
                </Text>
              </View>
            )}
          </View>

          {special && (
            <>
              <Text style={styles.sectionTitle}>Special Move</Text>
              <View style={[styles.specialCard, { borderColor: special.color }]}>
                <View style={styles.specialHeader}>
                  <Text style={[styles.specialName, { color: special.color }]}>{special.name}</Text>
                  <View style={[styles.modeChip, { backgroundColor: special.color + '33' }]}>
                    <Text style={[styles.modeChipText, { color: special.color }]}>
                      {modeLabels[special.mode]}
                    </Text>
                  </View>
                </View>
                <Text style={styles.specialDesc}>{special.description}</Text>
                <View style={styles.specialStats}>
                  <SpecialStat label="Schaden" value={String(special.damage)} />
                  <SpecialStat label="Dauer" value={`${special.duration}s`} />
                  <SpecialStat label="Speed" value={String(special.rushSpeed)} />
                  <SpecialStat label="Spin-Verlust" value={String(special.spinLoss)} />
                </View>
                {special.extra && (
                  <View style={styles.extraBox}>
                    {Object.entries(special.extra).map(([key, val]) => (
                      <Text key={key} style={styles.extraLine}>
                        {formatExtraKey(key)}: {val}
                      </Text>
                    ))}
                  </View>
                )}
              </View>
            </>
          )}

          <View style={[styles.tipBox, { borderLeftColor: typeColor }]}>
            <Text style={styles.tipTitle}>Tipp</Text>
            <Text style={styles.tipText}>{getTip(bey.beyType)}</Text>
          </View>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

function SpecialStat({ label, value }: { label: string; value: string }) {
  return (
    <View style={styles.specialStatItem}>
      <Text style={styles.specialStatValue}>{value}</Text>
      <Text style={styles.specialStatLabel}>{label}</Text>
    </View>
  );
}

function formatExtraKey(key: string): string {
  return key.replace(/([A-Z])/g, ' $1').replace(/^./, (s) => s.toUpperCase());
}

function getTip(type: string): string {
  const tips: Record<string, string> = {
    Attack: 'Charge und Special kombinieren für maximalen Rush-Schaden.',
    Defense: 'Shell Guard aktivieren, wenn der Gegner angreift — dann kontern.',
    Stamina: 'Halte Abstand und lass den Spin auslaufen. Thunder Loop für sichere Treffer.',
    Balance: 'Flexibel spielen — Night Fang für den entscheidenden Burst.',
  };
  return tips[type] ?? 'Experimentiere mit Charge und Dodge.';
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: colors.background,
  },
  scroll: {
    paddingBottom: 32,
  },
  error: {
    color: colors.text,
    padding: 20,
  },
  banner: {
    padding: 28,
    paddingTop: 20,
    alignItems: 'center',
  },
  bannerName: {
    color: '#fff',
    fontSize: 28,
    fontWeight: '900',
    textAlign: 'center',
    marginBottom: 10,
  },
  typeBadge: {
    borderWidth: 1.5,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 4,
  },
  typeBadgeText: {
    color: '#fff',
    fontSize: 12,
    fontWeight: '800',
    textTransform: 'uppercase',
    letterSpacing: 1,
  },
  body: {
    padding: 20,
  },
  desc: {
    color: colors.textMuted,
    fontSize: 15,
    lineHeight: 22,
    marginBottom: 20,
  },
  sectionTitle: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '800',
    marginBottom: 12,
  },
  statsBox: {
    backgroundColor: colors.surface,
    borderRadius: 14,
    padding: 16,
    marginBottom: 24,
    borderWidth: 1,
    borderColor: colors.border,
  },
  extraStat: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    marginTop: 4,
    paddingTop: 8,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  extraLabel: {
    color: colors.textMuted,
    fontSize: 13,
  },
  extraValue: {
    fontSize: 13,
    fontWeight: '700',
  },
  specialCard: {
    backgroundColor: colors.surface,
    borderRadius: 14,
    padding: 16,
    marginBottom: 24,
    borderWidth: 1.5,
  },
  specialHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8,
  },
  specialName: {
    fontSize: 20,
    fontWeight: '800',
  },
  modeChip: {
    borderRadius: 8,
    paddingHorizontal: 10,
    paddingVertical: 4,
  },
  modeChipText: {
    fontSize: 11,
    fontWeight: '800',
    textTransform: 'uppercase',
  },
  specialDesc: {
    color: colors.textMuted,
    fontSize: 14,
    lineHeight: 20,
    marginBottom: 14,
  },
  specialStats: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 8,
  },
  specialStatItem: {
    width: '47%',
    backgroundColor: colors.surfaceLight,
    borderRadius: 10,
    padding: 10,
    alignItems: 'center',
  },
  specialStatValue: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '800',
  },
  specialStatLabel: {
    color: colors.textMuted,
    fontSize: 11,
    marginTop: 2,
  },
  extraBox: {
    marginTop: 12,
    paddingTop: 12,
    borderTopWidth: 1,
    borderTopColor: colors.border,
  },
  extraLine: {
    color: colors.textMuted,
    fontSize: 12,
    marginBottom: 4,
  },
  tipBox: {
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 16,
    borderLeftWidth: 4,
  },
  tipTitle: {
    color: colors.text,
    fontSize: 14,
    fontWeight: '700',
    marginBottom: 4,
  },
  tipText: {
    color: colors.textMuted,
    fontSize: 13,
    lineHeight: 19,
  },
});
