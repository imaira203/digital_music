import React from 'react';
import { createBottomTabNavigator, BottomTabBar } from '@react-navigation/bottom-tabs';
import { SafeAreaView } from 'react-native-safe-area-context';
import HomeScreen from '../screens/HomeScreen';
import ProfileScreen from '../screens/ProfileScreen';
// import LocalMusicScreen from '../screens/LocalMusicScreen';
import NowPlayingBar from '../components/NowPlayingBar';
import { usePlayer } from '../player/store';
import LocalMusicScreen from '../screens/LocalMusicScreen';
import Icon from 'react-native-vector-icons/MaterialIcons';

const BG = '#0b0b0f';

const Tab = createBottomTabNavigator();

function MyTabBar(props: any) {
    return (
        <SafeAreaView edges={['bottom']} style={{ backgroundColor: BG }}>
            <NowPlayingBar />
            <BottomTabBar {...props} />
        </SafeAreaView>
    );
}

export default function Tabs() {
    return (
        <Tab.Navigator
            tabBar={(p) => <MyTabBar {...p} />}
            screenOptions={{
                headerShown: false,
                tabBarActiveTintColor: '#ff5a5f',
                tabBarInactiveTintColor: '#9aa0a6',
                tabBarStyle: { backgroundColor: BG, borderTopColor: '#222' },
            }}
        >
            <Tab.Screen
                name="Home"
                component={HomeScreen}
                options={{
                    title: 'Home',
                    tabBarIcon: ({ color }) => <Icon name="home" size={30} color="#fff" />,
                }}
            />
            <Tab.Screen
                name="Local"
                component={LocalMusicScreen}
                options={{
                    title: 'Local Music',
                    tabBarIcon: ({ color }) => <Icon name="folder" size={30} color="#fff" />,
                }}
            />
            <Tab.Screen
                name="Profile"
                component={ProfileScreen}
                options={{
                    title: 'Profile',
                    tabBarIcon: ({ color }) => <Icon name="person" size={30} color="#fff" />,
                }}
            />
        </Tab.Navigator>
    );
}

