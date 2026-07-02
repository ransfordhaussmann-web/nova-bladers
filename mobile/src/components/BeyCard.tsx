import { Pressable, View, Text, StyleSheet } from 'react-native';
import { Bey } from '../data/beyCatalog';
import { beyTypeColors, colors } from '../theme/colors';
import { StatBar } from './StatBar';

type BeyCardProps = {
  bey: Bey;
  onPress: () => void;
};

export function BeyCard({ bey, onPress }: BeyCardProps) {
  const typeColor = beyTypeColors[bey.beyType] ?? colors.accent;

  return (
    <Pressable
      style={({ pressed }) => [styles.card, pressed && styles.pressed]}
      onPress={onPress}
    >
      <View style={[styles.accent, { backgroundColor: bey.color }]} />
      <View style={styles.content}>
        <View style={styles.header}>
          <Text style={styles.name}>{bey.name}</Text>
          <View style={[styles.badge, { borderColor: typeColor }]}>
            <Text style={[styles.badgeText, { color: typeColor }]}>{bey.beyType}</Text>
          </View>
        </View>
        <Text style={styles.desc} numberOfLines={2}>
          {bey.desc}
        </Text>
        <View style={styles.stats}>
          <StatBar label="ATK" value={bey.stats.Attack} color={colors.attack} />
          <StatBar label="DEF" value={bey.stats.Defense} color={colors.defense} />
          <StatBar label="SPD" value={bey.stats.Speed} color={colors.speed} />
        </View>
        <Text style={styles.special}>Special: {bey.special}</Text>
      </View>
    </Pressable>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: colors.surface,
    borderRadius: 16,
    marginBottom: 14,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: colors.border,
  },
  pressed: {
    opacity: 0.85,
    transform: [{ scale: 0.98 }],
  },
  accent: {
    height: 4,
    width: '100%',
  },
  content: {
    padding: 16,
  },
  header: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 6,
  },
  name: {
    color: colors.text,
    fontSize: 18,
    fontWeight: '800',
    letterSpacing: 0.5,
  },
  badge: {
    borderWidth: 1,
    borderRadius: 8,
    paddingHorizontal: 8,
    paddingVertical: 3,
  },
  badgeText: {
    fontSize: 11,
    fontWeight: '700',
    textTransform: 'uppercase',
  },
  desc: {
    color: colors.textMuted,
    fontSize: 13,
    lineHeight: 18,
    marginBottom: 12,
  },
  stats: {
    marginBottom: 8,
  },
  special: {
    color: colors.accent,
    fontSize: 13,
    fontWeight: '600',
  },
});
