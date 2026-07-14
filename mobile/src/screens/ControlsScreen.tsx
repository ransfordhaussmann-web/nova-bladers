import { ScrollView, View, Text, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { SectionHeader } from '../components/SectionHeader';
import { controls } from '../data/gameInfo';
import { colors } from '../theme/colors';

export function ControlsScreen() {
  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <ScrollView contentContainerStyle={styles.scroll}>
        <SectionHeader
          title="Steuerung"
          subtitle="Tastatur & Mobile-Controls im Roblox-Spiel"
        />

        {controls.map((ctrl) => (
          <View key={ctrl.action} style={styles.card}>
            <View style={styles.keyBox}>
              <Text style={styles.keyText}>{ctrl.input}</Text>
            </View>
            <View style={styles.info}>
              <Text style={styles.action}>{ctrl.action}</Text>
              <Text style={styles.desc}>{ctrl.description}</Text>
            </View>
          </View>
        ))}

        <View style={styles.mobileNote}>
          <Text style={styles.mobileTitle}>📱 Mobile</Text>
          <Text style={styles.mobileText}>
            Auf dem Handy steuerst du den Bey per Touch-Joystick. Charge, Dodge und Special
            sind als Buttons auf dem Bildschirm verfügbar — genau wie in der Roblox-App.
          </Text>
        </View>
      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: colors.background,
  },
  scroll: {
    padding: 20,
    paddingBottom: 32,
  },
  card: {
    flexDirection: 'row',
    backgroundColor: colors.surface,
    borderRadius: 14,
    padding: 14,
    marginBottom: 10,
    borderWidth: 1,
    borderColor: colors.border,
    alignItems: 'center',
    gap: 14,
  },
  keyBox: {
    backgroundColor: colors.surfaceLight,
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    minWidth: 80,
    alignItems: 'center',
  },
  keyText: {
    color: colors.accent,
    fontSize: 13,
    fontWeight: '800',
    textAlign: 'center',
  },
  info: {
    flex: 1,
  },
  action: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 2,
  },
  desc: {
    color: colors.textMuted,
    fontSize: 13,
    lineHeight: 18,
  },
  mobileNote: {
    backgroundColor: colors.surface,
    borderRadius: 14,
    padding: 16,
    marginTop: 14,
    borderWidth: 1,
    borderColor: colors.accent + '44',
  },
  mobileTitle: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 8,
  },
  mobileText: {
    color: colors.textMuted,
    fontSize: 14,
    lineHeight: 21,
  },
});
