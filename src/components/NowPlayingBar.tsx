import React, { useCallback, useEffect, useState } from 'react';
import { Image, TouchableOpacity, View, Text, LayoutChangeEvent } from 'react-native';
import { useNavigation } from '@react-navigation/native';
import { useProgress, useTrackPlayerEvents, Event, useActiveTrack } from 'react-native-track-player';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { usePlayer } from '../player/store';
import TrackPlayer from 'react-native-track-player';
import { ensureSetup } from '../player/store';

const BG = '#0b0b0f';
const SUBTLE = '#9aa0a6';

export default function NowPlayingBar() {
    const nav = useNavigation<any>();
    const { position, duration } = useProgress(250); // update mỗi 250ms
    const { queue, currentIndex, isPlaying, togglePlay } = usePlayer();

    // Hook fallback from native (survives app reload)
    const activeHook: any = useActiveTrack();

    // Hydrate store from native player after reloads
    useEffect(() => {
        (async () => {
            try {
                await ensureSetup();
                const q = await TrackPlayer.getQueue();
                const idx = await TrackPlayer.getActiveTrackIndex();
                const mapped = (q as any[]).map((t: any) => ({
                    videoId: String(t?.id ?? ''),
                    title: String(t?.title ?? ''),
                    artist: String(t?.artist ?? ''),
                    thumbnailUrl: String(t?.artwork ?? ''),
                }));
                (usePlayer as any).setState({ queue: mapped, currentIndex: (typeof idx === 'number' ? idx : -1) });
            } catch { }
        })();
    }, []);

    // Keep in sync when active track changes at native layer
    useTrackPlayerEvents([Event.PlaybackActiveTrackChanged], async () => {
        try {
            await ensureSetup();
            const q = await TrackPlayer.getQueue();
            const idx = await TrackPlayer.getActiveTrackIndex();
            const mapped = (q as any[]).map((t: any) => ({
                videoId: String(t?.id ?? ''),
                title: String(t?.title ?? ''),
                artist: String(t?.artist ?? ''),
                thumbnailUrl: String(t?.artwork ?? ''),
            }));
            (usePlayer as any).setState({ queue: mapped, currentIndex: (typeof idx === 'number' ? idx : -1) });
        } catch { }
    });

    const [barWidth, setBarWidth] = useState(0);
    const onBarLayout = useCallback((e: LayoutChangeEvent) => {
        setBarWidth(e.nativeEvent.layout.width);
    }, []);

    // Prefer store item; fallback to native hook when store is empty on reload
    const storeItem = queue?.[currentIndex as any];
    const item = storeItem || (activeHook ? {
        videoId: activeHook?.id,
        title: activeHook?.title,
        artist: activeHook?.artist,
        thumbnailUrl: activeHook?.artwork,
        duration: activeHook?.duration,
    } : null);

    if (!item) return null;

    // Một số stream không có duration -> fallback qua metadata nếu có
    const total: number = Number(duration) || Number((item as any).duration) || 0;
    const progress = total > 0 ? Math.min(1, Math.max(0, position / total)) : 0;

    return (
        <View style={{ backgroundColor: BG, borderTopWidth: 0.5, borderTopColor: '#222' }}>
            <TouchableOpacity
                onPress={() => nav.navigate('Player', { fromQueue: true })}
                style={{ flexDirection: 'row', padding: 12, alignItems: 'center' }}
                activeOpacity={0.8}
            >
                {item.thumbnailUrl ? (
                    <Image
                        source={{ uri: item.thumbnailUrl }}
                        style={{ width: 48, height: 48, borderRadius: 8, marginRight: 12 }}
                    />
                ) : null}

                <View style={{ flex: 1 }}>
                    <Text numberOfLines={1} style={{ color: '#fff', fontWeight: '600' }}>
                        {item.title || 'Đang phát…'}
                    </Text>
                    <Text numberOfLines={1} style={{ color: SUBTLE }}>
                        {item.artist || ''}
                    </Text>

                    <View
                        onLayout={onBarLayout}
                        style={{
                            height: 4,
                            backgroundColor: '#222',
                            borderRadius: 2,
                            marginTop: 6,
                            overflow: 'hidden',
                        }}
                    >
                        <View
                            style={{
                                height: 4,
                                width: barWidth * progress,
                                backgroundColor: '#fff', // << màu fill
                            }}
                        />
                    </View>
                </View>

                <TouchableOpacity style={{ paddingHorizontal: 8, paddingVertical: 4 }} onPress={togglePlay}>
                    <Icon name={isPlaying ? 'pause' : 'play-arrow'} size={30} color="#fff" />
                </TouchableOpacity>
            </TouchableOpacity>
        </View>
    );
}
