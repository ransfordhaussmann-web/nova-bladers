import { NavigationContainer, DarkTheme } from '@react-navigation/native';
import { createBottomTabNavigator } from '@react-navigation/bottom-tabs';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { Text, StyleSheet } from 'react-native';
import { BeyDetailScreen } from '../screens/BeyDetailScreen';
import { BeyListScreen } from '../screens/BeyListScreen';
import { PreviewScreen } from '../screens/PreviewScreen';
import { ControlsScreen } from '../screens/ControlsScreen';
import { HomeScreen } from '../screens/HomeScreen';
import { colors } from '../theme/colors';
import { BeysStackParamList, RootTabParamList } from './types';

const Tab = createBottomTabNavigator<RootTabParamList>();
const BeysStack = createNativeStackNavigator<BeysStackParamList>();

const navTheme = {
  ...DarkTheme,
  colors: {
    ...DarkTheme.colors,
    background: colors.background,
    card: colors.surface,
    border: colors.border,
    primary: colors.accent,
    text: colors.text,
  },
};

function BeysNavigator() {
  return (
    <BeysStack.Navigator
      screenOptions={{
        headerStyle: { backgroundColor: colors.surface },
        headerTintColor: colors.text,
        headerTitleStyle: { fontWeight: '700' },
        contentStyle: { backgroundColor: colors.background },
      }}
    >
      <BeysStack.Screen name="BeyList" component={BeyListScreen} options={{ title: 'Beys' }} />
      <BeysStack.Screen
        name="BeyDetail"
        component={BeyDetailScreen}
        options={({ route }) => ({
          title: route.params.beyId.replace(/([A-Z])/g, ' $1').trim(),
        })}
      />
    </BeysStack.Navigator>
  );
}

function TabIcon({ label, focused }: { label: string; focused: boolean }) {
  const icons: Record<string, string> = {
    Home: '⚡',
    Preview: '✨',
    Beys: '🌀',
    Controls: '🎮',
  };
  return (
    <Text style={[styles.tabIcon, focused && styles.tabIconFocused]}>
      {icons[label] ?? '•'}
    </Text>
  );
}

export function RootNavigator() {
  return (
    <NavigationContainer theme={navTheme}>
      <Tab.Navigator
        screenOptions={({ route }) => ({
          headerShown: false,
          tabBarStyle: styles.tabBar,
          tabBarActiveTintColor: colors.accent,
          tabBarInactiveTintColor: colors.textMuted,
          tabBarLabelStyle: styles.tabLabel,
          tabBarIcon: ({ focused }) => <TabIcon label={route.name} focused={focused} />,
        })}
      >
        <Tab.Screen
          name="Home"
          component={HomeScreen}
          options={{ title: 'Start', headerShown: false }}
        />
        <Tab.Screen
          name="Preview"
          component={PreviewScreen}
          options={{ title: 'Vorschau' }}
        />
        <Tab.Screen name="Beys" component={BeysNavigator} options={{ headerShown: false }} />
        <Tab.Screen name="Controls" component={ControlsScreen} options={{ title: 'Steuerung' }} />
      </Tab.Navigator>
    </NavigationContainer>
  );
}

const styles = StyleSheet.create({
  tabBar: {
    backgroundColor: colors.surface,
    borderTopColor: colors.border,
    borderTopWidth: 1,
    height: 64,
    paddingBottom: 8,
    paddingTop: 4,
  },
  tabLabel: {
    fontSize: 11,
    fontWeight: '600',
  },
  tabIcon: {
    fontSize: 20,
    opacity: 0.6,
  },
  tabIconFocused: {
    opacity: 1,
  },
});
