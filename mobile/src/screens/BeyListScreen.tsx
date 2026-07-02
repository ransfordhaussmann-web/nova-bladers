import { FlatList, StyleSheet } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { BeyCard } from '../components/BeyCard';
import { SectionHeader } from '../components/SectionHeader';
import { beyCatalog } from '../data/beyCatalog';
import { BeysStackParamList } from '../navigation/types';
import { colors } from '../theme/colors';

type Props = NativeStackScreenProps<BeysStackParamList, 'BeyList'>;

export function BeyListScreen({ navigation }: Props) {
  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <FlatList
        data={beyCatalog}
        keyExtractor={(item) => item.id}
        contentContainerStyle={styles.list}
        ListHeaderComponent={
          <SectionHeader
            title="Bey-Katalog"
            subtitle="Alle Beys mit Stats und Special-Moves"
          />
        }
        renderItem={({ item }) => (
          <BeyCard bey={item} onPress={() => navigation.navigate('BeyDetail', { beyId: item.id })} />
        )}
      />
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  safe: {
    flex: 1,
    backgroundColor: colors.background,
  },
  list: {
    padding: 20,
    paddingBottom: 32,
  },
});
