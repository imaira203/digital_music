import 'react-native-url-polyfill/auto';
import 'react-native-get-random-values';
import process from 'process';
import { Buffer } from 'buffer';

if (!(global as any).process) (global as any).process = process;
if (!(global as any).Buffer) (global as any).Buffer = Buffer;

import 'react-native-gesture-handler';
import { registerRootComponent } from 'expo';
import TrackPlayer from 'react-native-track-player';
import service from './src/player/service';
import App from './App';
import playbackService from './src/player/playbackService';


// TODO: Replace with expo-notifications when available
async function ensureChannel() {
    // Placeholder for notification channel creation
}
ensureChannel();


// TODO: Replace with expo-notifications when available
// Handle background notifications using Expo's notification system


TrackPlayer.registerPlaybackService(() => playbackService);
TrackPlayer.registerPlaybackService(() => service);

registerRootComponent(App);