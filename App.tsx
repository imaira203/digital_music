import React from 'react';
import { NavigationContainer } from '@react-navigation/native';
import { createNativeStackNavigator } from '@react-navigation/native-stack';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import PlayerScreen from './src/screens/PlayerScreen';
import SearchScreen from './src/screens/SearchScreen';
import LoginScreen from './src/screens/LoginScreen';
import RegisterScreen from './src/screens/RegisterScreen';
import SearchResultScreen from './src/screens/SearchResultScreen';
import Tabs from './src/navigation/Tabs';
import type { RootStackParamList } from './src/models/types';
import { StatusBar, TouchableOpacity, View, Platform } from 'react-native';
import { ensureSetup } from './src/player/store';
import Icon from 'react-native-vector-icons/MaterialIcons';

// Preload shaka-player UI on web so TrackPlayer's dynamic import resolves
if (Platform.OS === 'web') {
  try {
    // eslint-disable-next-line @typescript-eslint/no-var-requires
    require('shaka-player/dist/shaka-player.ui.js');
  } catch { }
}

ensureSetup().catch(console.error);

const Stack = createNativeStackNavigator<RootStackParamList>();
const BG = '#0b0b0f';

export default function App() {
  return (
    <SafeAreaProvider>
      <StatusBar barStyle="light-content" backgroundColor={BG} />
      <NavigationContainer>
        <Stack.Navigator
          screenOptions={{
            headerStyle: { backgroundColor: BG },
            headerTintColor: '#fff',
          }}
        >
          <Stack.Screen name="Tabs" component={Tabs} options={{ headerShown: false }} />
          <Stack.Screen name="Player" component={PlayerScreen} options={{ title: 'Now Playing' }} />
          <Stack.Screen name="Search" component={SearchScreen} options={{ title: 'Search' }} />
          <Stack.Screen name="SearchResults" component={SearchResultScreen} options={({ route, navigation }) => ({
            title: `Results for "${route.params?.query || ''}"`,
            headerRight: () => (
              <TouchableOpacity style={{ marginRight: 12 }} onPress={() => navigation.replace('Search', { query: route.params?.query || '' })}>
                <Icon name="search" size={24} color="#fff" />
              </TouchableOpacity>
            ),
            headerLeft: () => (
              <TouchableOpacity style={{ marginLeft: 0, marginRight: 12 }} onPress={() => navigation.goBack()}>
                <Icon name="arrow-back" size={24} color="#fff" />
              </TouchableOpacity>
            ),
          })} />
          <Stack.Screen name="Login" component={LoginScreen} options={{ title: 'Login' }} />
          <Stack.Screen name="Register" component={RegisterScreen} options={{ title: 'Register' }} />
        </Stack.Navigator>
      </NavigationContainer>
    </SafeAreaProvider>
  );
}
