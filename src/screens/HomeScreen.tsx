import React, { useCallback, useEffect, useMemo, useState } from 'react';
import {
    ActivityIndicator,
    FlatList,
    Image,
    RefreshControl,
    StatusBar,
    Text,
    TouchableOpacity,
    View,
} from 'react-native';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { SafeAreaView } from 'react-native-safe-area-context';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { fetchHome, fetchPlaylist } from '../api';
import { usePlayer } from '../player/store';
import { RawItem, RawSection } from '../models/song.player';
import { RootStackParamList } from '../models/types';

const BG = '#0b0b0f';
const TEXT = '#ffffff';
const SUBTLE = '#9aa0a6';
const SUBTLE_2 = '#666';
const CARD = '#16181d';

type Props = NativeStackScreenProps<RootStackParamList, 'Home'>;
type NavigationProp = StackNavigationProp<RootStackParamList>;

type Card = {
    id: string;
    kind: 'SONG' | 'PLAYLIST' | 'ALBUM' | 'VIDEO' | 'ARTIST';
    title: string;
    subtitle: string;
    thumb?: string;
};
type UISection = { title: string; contents: Card[] };

//pick best thumbnail in thumbnails array
const pickThumb = (thumbs?: RawItem['thumbnails'], fallback?: string) => {
    if (!thumbs) return fallback;
    const best = thumbs.sort((a, b) => (b.width ?? 0) - (a.width ?? 0))[0];
    return best?.url || fallback;
}

export default function HomeScreen({ navigation: stackNavigation, route }: Partial<Props> = {}) {
    const navigation = useNavigation<NavigationProp>();
    const [sections, setSections] = useState<UISection[]>([]);
    const [loading, setLoading] = useState(true);
    const [refreshing, setRefreshing] = useState(false);
    const [allVideoIds, setAllVideoIds] = useState<string[]>([]);

    const playById = usePlayer((s) => s.playById);
    const playPlaylist = usePlayer((s) => s.playPlaylist);

    const normalize = useCallback((raw: RawSection[] | any): UISection[] => {
        // nếu backend đã trả dạng section[]
        const toSections = (arr: any[]): UISection[] =>
            (arr || []).map((sec: any) => ({
                title: String(sec?.title ?? ''),
                contents: (sec?.contents || []).map((c: RawItem) => {
                    const id =
                        c.id ||
                        c.videoId ||
                        c.playlistId ||
                        c.albumId ||
                        Math.random().toString(36).slice(2);
                    const kind = (c.type) as Card['kind'];
                    const title = c.title ?? c.name ?? '';
                    const subtitle = c.artist?.name ?? c.artistName ?? '';
                    const thumb =
                        pickThumb(c.thumbnails, c.thumbnailUrl) ||
                        (c.videoId ? `https://i.ytimg.com/vi/${c.videoId}/hq720.jpg` : undefined);
                    return { id, kind, title, subtitle, thumb };
                }),
            }));

        if (Array.isArray(raw)) return toSections(raw);

        // fallback: tìm key có mảng section
        if (raw && typeof raw === 'object') {
            for (const k of ['sections', 'data', 'items', 'contents', 'result']) {
                if (Array.isArray(raw[k])) return toSections(raw[k]);
            }
        }
        return [];
    }, []);

    const collectVideoIds = useCallback((secs: UISection[]) => {
        const ids = new Set<string>();
        secs.forEach((s) =>
            s.contents.forEach((c) => {
                if (c.kind === 'SONG' || c.kind === 'VIDEO') ids.add(c.id);
            })
        );
        setAllVideoIds([...ids]);
    }, []);

    const load = useCallback(async () => {
        try {
            const raw = await fetchHome();
            const secs = normalize(raw);
            setSections(secs);
            collectVideoIds(secs);
        } finally {
            setLoading(false);
            setRefreshing(false);
        }
    }, [collectVideoIds, normalize]);

    useEffect(() => {
        load();
    }, [load]);

    const onRefresh = useCallback(() => {
        setRefreshing(true);
        load();
    }, [load]);

    if (loading) {
        return (
            <SafeAreaView style={{ flex: 1, backgroundColor: BG }}>
                <StatusBar barStyle="light-content" backgroundColor={BG} />
                <View style={{ flex: 1, alignItems: 'center', justifyContent: 'center' }}>
                    <ActivityIndicator />
                    <Text style={{ color: SUBTLE, marginTop: 12 }}>Loading…</Text>
                </View>
            </SafeAreaView>
        );
    }

    const SectionRow = ({ section }: { section: UISection }) => (
        <View style={{ marginBottom: 18 }}>
            <Text
                style={{
                    color: TEXT,
                    fontSize: 18,
                    fontWeight: '700',
                    marginHorizontal: 16,
                    marginBottom: 10,
                }}
            >
                {section.title}
            </Text>

            <FlatList
                data={section.contents}
                keyExtractor={(i) => i.id}
                horizontal
                showsHorizontalScrollIndicator={false}
                contentContainerStyle={{ paddingHorizontal: 12 }}
                renderItem={({ item }) => (
                    <TouchableOpacity
                        activeOpacity={0.8}
                        onPress={async () => {
                            if ((item.kind === 'SONG' || item.kind === 'VIDEO') && item.id) {
                                // phát ngay 1 bài
                                navigation.navigate('Player', { fromQueue: false });
                                await playById(item.id);
                            } else if ((item.kind === 'ALBUM' || item.kind === 'PLAYLIST') && item.id) {
                                // mở player (skeleton), rồi fetch playlist và set queue
                                navigation.navigate('Player', { fromQueue: true });
                                try {
                                    const tracks = await fetchPlaylist(item.id);
                                    if (tracks.length) {
                                        await playPlaylist(
                                            tracks.map((t) => ({
                                                videoId: t.videoId,
                                                title: t.title,
                                                artist: t.artist,
                                                thumbnailUrl: t.thumbnailUrl,
                                            })),
                                            0
                                        );
                                    } else {
                                        // no-op; bạn có thể show toast ở đây
                                    }
                                } catch {
                                    // no-op
                                }
                            }
                        }}
                        onLongPress={() => {
                            // Quick actions tương tự Flutter (Play ngay / Shuffle 10)
                            // Bạn có thể thay bằng ActionSheetIOS hay một BottomSheet lib
                            if (allVideoIds.length) {
                                const shuffled = [...allVideoIds].sort(() => Math.random() - 0.5);
                                const list = shuffled.slice(0, Math.min(10, shuffled.length));
                                navigation.navigate('Player', { fromQueue: false });
                                // phát bài đầu rồi enqueue phần còn lại
                                playById(list[0]);
                            }
                        }}
                        style={{
                            width: 140,
                            marginHorizontal: 4,
                            backgroundColor: CARD,
                            borderRadius: 12,
                            overflow: 'hidden',
                        }}
                    >
                        {item.thumb ? (
                            <View>
                                <Image source={{ uri: item.thumb }} style={{ width: '100%', height: 140 }} />
                                <Text style={{ color: SUBTLE_2, marginTop: 6, position: 'absolute', top: -7, right: 1 }}>
                                    <Text style={{ color: SUBTLE_2 }}>
                                        {item.kind === "SONG" ? <Icon name="music-note" size={18} color={SUBTLE_2} /> : item.kind === "VIDEO" ? <Icon name="video-library" size={18} color={SUBTLE_2} /> : item.kind === "ALBUM" ? <Icon name="album" size={18} color={SUBTLE_2} /> : item.kind === "PLAYLIST" ? <Icon name="playlist-play" size={18} color={SUBTLE_2} /> : ""}
                                    </Text>
                                </Text>
                            </View>

                        ) : (
                            <View style={{ width: '100%', height: 140, backgroundColor: '#222' }} />
                        )}
                        <View style={{ padding: 10 }}>
                            <Text numberOfLines={2} style={{ color: TEXT, fontWeight: '600' }}>
                                {item.title}
                            </Text>
                            <Text numberOfLines={1} style={{ color: SUBTLE, fontSize: 12, marginTop: 2 }}>
                                {item.subtitle}
                            </Text>
                        </View>
                    </TouchableOpacity>
                )}
            />
        </View>
    );

    return (
        <SafeAreaView style={{ flex: 1, backgroundColor: BG }}>
            <StatusBar barStyle="light-content" backgroundColor={BG} />
            <FlatList
                style={{ flex: 1, backgroundColor: BG }}
                refreshControl={<RefreshControl tintColor="#fff" refreshing={refreshing} onRefresh={onRefresh} />}
                data={sections}
                keyExtractor={(s) => s.title}
                renderItem={({ item }) => <SectionRow section={item} />}
                ListHeaderComponent={
                    <View style={{ paddingHorizontal: 16, paddingTop: 8, paddingBottom: 13, flexDirection: 'row', alignItems: 'center' }}>
                        <Text style={{ color: TEXT, fontStyle: 'italic', fontSize: 24, fontWeight: '800', flex: 1, flexDirection: 'row', alignItems: 'center' }}>Digital Music
                            <Icon name="queue-music" size={22} color="#fff" style={{ marginLeft: 8, marginTop: 4 }} />
                        </Text>
                        <TouchableOpacity onPress={() => navigation.navigate('Search')}>
                            <Icon name="search" size={30} color="#fff" />
                        </TouchableOpacity>
                    </View>
                }
            />
        </SafeAreaView>
    );
}
