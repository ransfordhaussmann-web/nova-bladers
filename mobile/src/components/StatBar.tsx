import { View, Text, StyleSheet } from 'react-native';
import { colors } from '../theme/colors';

type StatBarProps = {
  label: string;
  value: number;
  max?: number;
  color: string;
};

export function StatBar({ label, value, max = 10, color }: StatBarProps) {
  const pct = Math.min(value / max, 1);

  return (
    <View style={styles.row}>
      <Text style={styles.label}>{label}</Text>
      <View style={styles.track}>
        <View style={[styles.fill, { width: `${pct * 100}%`, backgroundColor: color }]} />
      </View>
      <Text style={styles.value}>{value}</Text>
    </View>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    marginBottom: 8,
  },
  label: {
    width: 64,
    color: colors.textMuted,
    fontSize: 13,
    fontWeight: '600',
  },
  track: {
    flex: 1,
    height: 8,
    backgroundColor: colors.surfaceLight,
    borderRadius: 4,
    overflow: 'hidden',
  },
  fill: {
    height: '100%',
    borderRadius: 4,
  },
  value: {
    width: 20,
    color: colors.text,
    fontSize: 13,
    fontWeight: '700',
    textAlign: 'right',
  },
});
