import { ScrollView, View, Text, StyleSheet } from 'react-native';
import { LinearGradient } from 'expo-linear-gradient';
import { SafeAreaView } from 'react-native-safe-area-context';
import { SectionHeader } from '../components/SectionHeader';
import { beyCatalog } from '../data/beyCatalog';
import { gameModes, gameStats } from '../data/gameInfo';
import { colors } from '../theme/colors';

export function HomeScreen() {
  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <ScrollView contentContainerStyle={styles.scroll} showsVerticalScrollIndicator={false}>
        <LinearGradient
          colors={['#1a2a5e', '#0a0e1a']}
          style={styles.hero}
          start={{ x: 0, y: 0 }}
          end={{ x: 1, y: 1 }}
        >
          <Text style={styles.heroTag}>ROBLOX SPIN ARENA</Text>
          <Text style={styles.heroTitle}>Nova Bladers</Text>
          <Text style={styles.heroSub}>
            Anime-inspirierter Spin-Arena-Fighter — wähle deinen Bey und kämpfe in der Bowl.
          </Text>
        </LinearGradient>

        <View style={styles.section}>
          <SectionHeader title="Spielmodi" subtitle="Je nach Spieleranzahl" />
          {gameModes.map((mode) => (
            <View key={mode.name} style={styles.modeCard}>
              <View style={styles.modePlayers}>
                <Text style={styles.modePlayersText}>{mode.players}</Text>
              </View>
              <View style={styles.modeInfo}>
                <Text style={styles.modeName}>{mode.name}</Text>
                <Text style={styles.modeDesc}>{mode.description}</Text>
              </View>
            </View>
          ))}
        </View>

        <View style={styles.section}>
          <SectionHeader title="Arena-Stats" subtitle="Kampf-Grundwerte" />
          <View style={styles.statsGrid}>
            {[
              { label: 'Max HP', value: gameStats.maxHp },
              { label: 'Max Spin', value: gameStats.maxSpin },
              { label: 'Special', value: gameStats.maxSpecial },
              { label: 'Arena Ø', value: gameStats.arenaRadius },
            ].map((stat) => (
              <View key={stat.label} style={styles.statBox}>
                <Text style={styles.statValue}>{stat.value}</Text>
                <Text style={styles.statLabel}>{stat.label}</Text>
              </View>
            ))}
          </View>
        </View>

        <View style={styles.section}>
          <SectionHeader title="Beys" subtitle={`${beyCatalog.length} verfügbar`} />
          <View style={styles.beyRow}>
            {beyCatalog.map((bey) => (
              <View key={bey.id} style={[styles.beyDot, { backgroundColor: bey.color }]}>
                <Text style={styles.beyDotText}>{bey.name.split(' ')[0]}</Text>
              </View>
            ))}
          </View>
          <Text style={styles.hint}>
            Tippe auf „Beys" in der Navigation für Details und Special-Moves.
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
    paddingBottom: 32,
  },
  hero: {
    padding: 24,
    paddingTop: 32,
    paddingBottom: 36,
    borderBottomLeftRadius: 24,
    borderBottomRightRadius: 24,
  },
  heroTag: {
    color: colors.accent,
    fontSize: 11,
    fontWeight: '800',
    letterSpacing: 2,
    marginBottom: 8,
  },
  heroTitle: {
    color: colors.text,
    fontSize: 36,
    fontWeight: '900',
    letterSpacing: -0.5,
    marginBottom: 10,
  },
  heroSub: {
    color: colors.textMuted,
    fontSize: 15,
    lineHeight: 22,
  },
  section: {
    paddingHorizontal: 20,
    paddingTop: 24,
  },
  modeCard: {
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
  modePlayers: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: colors.surfaceLight,
    alignItems: 'center',
    justifyContent: 'center',
  },
  modePlayersText: {
    color: colors.accent,
    fontSize: 14,
    fontWeight: '800',
  },
  modeInfo: {
    flex: 1,
  },
  modeName: {
    color: colors.text,
    fontSize: 16,
    fontWeight: '700',
    marginBottom: 2,
  },
  modeDesc: {
    color: colors.textMuted,
    fontSize: 13,
    lineHeight: 18,
  },
  statsGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  statBox: {
    width: '47%',
    backgroundColor: colors.surface,
    borderRadius: 12,
    padding: 16,
    borderWidth: 1,
    borderColor: colors.border,
    alignItems: 'center',
  },
  statValue: {
    color: colors.text,
    fontSize: 28,
    fontWeight: '900',
  },
  statLabel: {
    color: colors.textMuted,
    fontSize: 12,
    marginTop: 4,
    fontWeight: '600',
  },
  beyRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: 10,
  },
  beyDot: {
    paddingHorizontal: 14,
    paddingVertical: 10,
    borderRadius: 12,
    minWidth: '47%',
  },
  beyDotText: {
    color: '#fff',
    fontSize: 13,
    fontWeight: '800',
    textAlign: 'center',
  },
  hint: {
    color: colors.textMuted,
    fontSize: 13,
    marginTop: 14,
    lineHeight: 18,
    fontStyle: 'italic',
  },
});
