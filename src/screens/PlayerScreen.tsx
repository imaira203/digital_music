import React, { useCallback, useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import {
    View, Text, Image, SafeAreaView, StatusBar, TouchableOpacity, Modal,
    FlatList, TextInput, Alert
} from 'react-native';
import TrackPlayer, {
    Event, RepeatMode, Track, useActiveTrack, usePlaybackState, useProgress, useTrackPlayerEvents,
} from 'react-native-track-player';
import Icon from 'react-native-vector-icons/MaterialIcons';
import { useNavigation } from '@react-navigation/native';
import { QueueItem } from '../models/song.player';
import { fetchRelated, fetchAudioUrl } from '../api';
import { ensureSetup } from '../player/store';
import { usePlayer } from '../player/store';

const BG = '#0b0b0f';
const TEXT = '#ffffff';
const SUB = '#9aa0a6';
const CARD = '#16181d';

const LOOKAHEAD = 4; // muốn luôn có ít nhất 4 bài sau bài đang phát

// ---------- QueueSheet tách riêng để tránh flick ----------
const QueueSheet = React.memo(function QueueSheet({
    visible, onClose, data, activeIndex, onSelect,
}: {
    visible: boolean;
    onClose: () => void;
    data: QueueItem[];
    activeIndex: number;
    onSelect: (i: number) => void;
}) {
    const listRef = React.useRef<FlatList<any>>(null);

    React.useEffect(() => {
        if (!visible) return;
        if (typeof activeIndex !== 'number' || activeIndex < 0) return;
        const idx = Math.min(Math.max(0, activeIndex), Math.max(0, (data?.length || 1) - 1));
        requestAnimationFrame(() => {
            try {
                listRef.current?.scrollToIndex({ index: idx, animated: true, viewPosition: 0.5 });
            } catch { /* ignore */ }
        });
    }, [visible, activeIndex, data?.length]);

    const ITEM_HEIGHT = 64; // approximate row height for getItemLayout

    return (
        <Modal
            visible={visible}
            transparent
            // Nếu Android còn chớp, thử chuyển 'slide' => 'none'
            animationType="slide"
            statusBarTranslucent
            hardwareAccelerated
            onRequestClose={onClose}
        >
            <View style={{ flex: 1, justifyContent: 'flex-end', backgroundColor: '#0006' }}>
                <View style={{ maxHeight: '70%', backgroundColor: BG, borderTopLeftRadius: 16, borderTopRightRadius: 16, paddingBottom: 16 }}>
                    <View style={{ alignItems: 'center', padding: 8 }}>
                        <View style={{ width: 40, height: 4, backgroundColor: '#444', borderRadius: 2 }} />
                    </View>
                    <Text style={{ color: TEXT, fontSize: 18, fontWeight: '700', paddingHorizontal: 16, marginBottom: 8 }}>
                        Danh sách phát
                    </Text>
                    <FlatList
                        ref={listRef}
                        data={data}
                        keyExtractor={(t, index) => {
                            // Use videoId if available, otherwise fall back to index
                            const id = (t as any)?.videoId || (t as any)?.id || `item-${index}`;
                            return String(id);
                        }}
                        ItemSeparatorComponent={() => <View style={{ height: 1, backgroundColor: '#222' }} />}
                        removeClippedSubviews={false}
                        getItemLayout={(_, index) => ({ length: ITEM_HEIGHT, offset: ITEM_HEIGHT * index, index })}
                        initialScrollIndex={Math.max(0, Math.min(activeIndex, Math.max(0, (data?.length || 1) - 1)))}
                        onScrollToIndexFailed={(info) => {
                            try {
                                const offset = Math.max(0, (info.averageItemLength || ITEM_HEIGHT) * info.index - ITEM_HEIGHT * 3);
                                listRef.current?.scrollToOffset({ offset, animated: false });
                                setTimeout(() => listRef.current?.scrollToIndex({ index: info.index, animated: true, viewPosition: 0.5 }), 300);
                            } catch { /* ignore */ }
                        }}
                        renderItem={({ item, index }) => {
                            const playing = index === activeIndex;
                            return (
                                <TouchableOpacity
                                    onPress={() => onSelect(index)}
                                    style={{ paddingHorizontal: 16, paddingVertical: 12, flexDirection: 'row', alignItems: 'center' }}
                                >
                                    <View style={{ width: 40, height: 40, alignItems: 'center', marginRight: 20, position: 'relative' }}>
                                        <Image source={{ uri: (item as any).artwork }} style={{ width: 40, height: 40, borderRadius: 4 }} />
                                        {playing ? <Icon
                                            name="play-arrow" size={28} color="#1fcebd" style={{ position: 'absolute', top: '50%', left: '50%', transform: [{ translateX: -14 }, { translateY: -14 }] }} /> : null}
                                    </View>

                                    <View style={{ flex: 1 }}>
                                        <Text style={{ color: TEXT, fontWeight: '600' }} numberOfLines={1}>
                                            {(item as QueueItem).title ?? ''}
                                        </Text>
                                        <Text style={{ color: SUB }} numberOfLines={1}>
                                            {(item as QueueItem).artist ?? ''}
                                        </Text>
                                    </View>
                                </TouchableOpacity>
                            );
                        }}
                    />
                    <TouchableOpacity onPress={onClose} style={{ alignSelf: 'center', marginTop: 8, padding: 10 }}>
                        <Text style={{ color: SUB }}>Close</Text>
                    </TouchableOpacity>
                </View>
            </View>
        </Modal>
    );
});

export default function PlayerScreen() {
    const navigation = useNavigation<any>();
    const { queue: storeQueue, currentIndex: storeCurrentIndex } = usePlayer();

    const playback = usePlaybackState();
    const { position, duration } = useProgress(250);
    const activeHook = useActiveTrack() as (Track & { title: string, artist?: string }) | null;
    const [activeLocal, setActiveLocal] = useState<(Track & { title: string, artist?: string }) | null>(null);
    const [queue, setQueue] = useState<QueueItem[]>([]);
    const [activeIndex, setActiveIndex] = useState<number>(-1);

    // Derive a UI fallback from queue when hook/local are undefined
    const uiTrack = useMemo(() => {
        if (activeHook) return activeHook as any;
        if (activeLocal) return activeLocal as any;
        if (queue && activeIndex >= 0 && activeIndex < queue.length) {
            const q = queue[activeIndex] as any;
            return {
                id: q?.videoId,
                url: undefined,
                title: q?.title,
                artist: q?.artist,
                artwork: q?.thumbnailUrl,
            } as any;
        }
        return null;
    }, [activeHook, activeLocal, queue, activeIndex]);

    const active = uiTrack as (Track & { title: string, artist?: string }) | null;
    const isPlaying = (playback as any)?.state === 'playing';

    const [like, setLike] = useState(false);
    const [showQueue, setShowQueue] = useState(false);
    const [playlistName, setPlaylistName] = useState('');
    const [showAdd, setShowAdd] = useState(false);

    // progress bar state
    const [barWidth, setBarWidth] = useState(0);
    const [scrubbing, setScrubbing] = useState(false);
    const [scrubSec, setScrubSec] = useState(0);

    const pos = Math.max(0, position);
    const dur = duration > 0 ? duration : 0; // chỉ dùng duration thật, không ép buộc min = 1

    const fmt = (sec: number) => {
        if (sec <= 0) return '00:00';
        const s = Math.floor(sec);
        const m = Math.floor(s / 60);
        const r = String(s % 60).padStart(2, '0');
        return `${m}:${r}`;
    };

    const xToSec = (x: number) => {
        if (barWidth <= 0 || !dur || dur <= 0) return 0;
        const r = Math.max(0, Math.min(1, x / barWidth));
        return r * dur;
    };

    // đặt nút Queue lên header phải (ổn định — không phụ thuộc progress)
    useLayoutEffect(() => {
        navigation.setOptions({
            headerRight: () => (
                <TouchableOpacity onPress={() => setShowQueue(true)} style={{ paddingHorizontal: 8 }}>
                    <Icon name="queue-music" size={24} color="#fff" />
                </TouchableOpacity>
            ),
        });
    }, [navigation]);

    // nạp queue + index lần đầu
    useEffect(() => {
        (async () => {
            try {
                await ensureSetup();
                const q = await TrackPlayer.getQueue();
                setQueue(q as any);
                const idx = await TrackPlayer.getActiveTrackIndex();
                setActiveIndex(typeof idx === 'number' ? idx : -1);
                const cur = await TrackPlayer.getActiveTrack();
                setActiveLocal((cur as any) ?? null);

                // Sync Zustand store so NowPlayingBar updates
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

    // cập nhật khi đổi bài
    useTrackPlayerEvents([Event.PlaybackActiveTrackChanged], async (e) => {
        if (e.type === Event.PlaybackActiveTrackChanged) {
            await ensureSetup();
            const q = await TrackPlayer.getQueue();
            setQueue(q as any);
            const nextIndex = e.index ?? (await TrackPlayer.getActiveTrackIndex()) ?? -1;
            setActiveIndex(nextIndex);
            setLike(false);
            try {
                const cur = await TrackPlayer.getActiveTrack();
                setActiveLocal((cur as any) ?? null);
            } catch { }

            // Sync Zustand store on active change
            const mapped = (q as any[]).map((t: any) => ({
                videoId: String(t?.id ?? ''),
                title: String(t?.title ?? ''),
                artist: String(t?.artist ?? ''),
                thumbnailUrl: String(t?.artwork ?? ''),
            }));
            (usePlayer as any).setState({ queue: mapped, currentIndex: nextIndex });
        }
    });

    // ----------------- RELATED LOOKAHEAD (append vào queue) -----------------
    const fetchingRef = useRef(false);
    const seenRef = useRef<Set<string>>(new Set());
    const lastEnsuredIdRef = useRef<string | null>(null);
    const lastRunAtRef = useRef<number>(0);

    // khởi tạo seen từ queue ban đầu
    useEffect(() => {
        const ids = new Set<string>();
        (queue || []).forEach((t: any) => {
            const id = String(t?.id ?? t?.videoId ?? '');
            if (id) ids.add(id);
        });
        seenRef.current = ids;
    }, [queue]);

    const ensureLookahead = useCallback(async () => {
        // cooldown để tránh lặp nhanh
        const now = Date.now();
        if (now - lastRunAtRef.current < 1500) return;
        lastRunAtRef.current = now;

        if (fetchingRef.current) return;
        try {
            await ensureSetup();
            const q = (await TrackPlayer.getQueue()) as any[];
            const idx = await TrackPlayer.getActiveTrackIndex();
            if (!q?.length || idx == null || idx < 0) return;

            const remaining = q.length - 1 - idx;
            if (remaining >= LOOKAHEAD) return;

            const current = await TrackPlayer.getActiveTrack();
            const seedId = String((current as any)?.id ?? '');
            if (!seedId) return;

            // nếu vừa ensure cho seedId này gần đây, bỏ qua
            if (lastEnsuredIdRef.current === seedId && remaining >= LOOKAHEAD - 1) return;

            fetchingRef.current = true;

            const related = await fetchRelated(seedId); // [{ videoId, title, artist, thumbnailUrl }]
            if (!Array.isArray(related) || !related.length) return;

            const want: Array<{ videoId: string; title: string; artist?: string; thumbnailUrl?: string }> = [];
            for (const it of related) {
                const vid = String(it?.videoId ?? '');
                if (!vid || seenRef.current.has(vid)) continue;
                seenRef.current.add(vid);
                want.push({
                    videoId: vid,
                    title: it.title ?? '',
                    artist: it.artist,
                    thumbnailUrl: it.thumbnailUrl,
                });
                if (want.length >= LOOKAHEAD - Math.max(0, remaining)) break;
            }
            if (!want.length) return;

            const tracks: any[] = [];
            for (const it of want) {
                const vid = String(it.videoId);
                const meta = await fetchAudioUrl(vid); // { audioUrl, mimeType }
                tracks.push({
                    id: vid,
                    url: meta?.audioUrl,
                    title: it.title ?? '',
                    artist: it.artist ?? '',
                    artwork: it.thumbnailUrl ?? `https://i.ytimg.com/vi/${vid}/hq720.jpg`,
                    contentType: meta?.mimeType,
                });
            }

            await TrackPlayer.add(tracks);
            const newQ = await TrackPlayer.getQueue();
            setQueue(newQ as any);
            lastEnsuredIdRef.current = seedId;
        } catch (e) {
            console.warn('[related] ensureLookahead error', e);
        } finally {
            fetchingRef.current = false;
        }
    }, []);


    // gọi khi vừa mount & mỗi lần đổi bài
    useEffect(() => {
        if (!fetchingRef.current) {
            ensureLookahead();
        }
    }, [active?.id]); // Remove ensureLookahead from dependencies

    // --------------- controls ---------------
    const onPrev = async () => {
        try {
            await ensureSetup();
            if (pos > 5) { await TrackPlayer.seekTo(0); return; }
            await TrackPlayer.skipToPrevious();
        } catch { await TrackPlayer.seekTo(0); }
    };
    const onToggle = async () => {
        try { await ensureSetup(); (isPlaying ? TrackPlayer.pause() : TrackPlayer.play()); }
        catch (e) { Alert.alert('Không thể phát', 'Hãy thử lại sau.'); console.warn(e); }
    };
    const onNext = async () => {
        try { await ensureSetup(); await TrackPlayer.skipToNext(); }
        catch {
            const q = await TrackPlayer.getQueue();
            if (q.length) { await TrackPlayer.skip((q[0] as any).id); await TrackPlayer.play(); }
        }
    };
    const playQueueIndex = async (i: number) => {
        try {
            await ensureSetup();
            const q = await TrackPlayer.getQueue();
            if (!q[i]) return;

            // Use store action if available to keep single source of truth
            const storeActions: any = usePlayer.getState();
            if (typeof storeActions.playQueueIndex === 'function') {
                await storeActions.playQueueIndex(i);
            } else {
                await TrackPlayer.skip(i);
                await TrackPlayer.play();
            }

            setActiveIndex(i);
            setShowQueue(false);

            // Ensure store currentIndex reflects selection
            (usePlayer as any).setState({ currentIndex: i });
        } catch (e) {
            console.warn('skip error', e);
        }
    };

    // --------------- UI ---------------
    const title = active?.title ?? 'Đang phát…';
    const artist = (active as any)?.artist ?? '';
    const artwork = (active as any)?.artwork as string | undefined;

    return (
        <SafeAreaView style={{ flex: 1, backgroundColor: BG }}>
            <StatusBar barStyle="light-content" backgroundColor={BG} />

            {/* Sheet danh sách phát (memo) */}
            <QueueSheet
                visible={showQueue}
                onClose={() => setShowQueue(false)}
                data={queue}
                activeIndex={activeIndex}
                onSelect={playQueueIndex}
            />

            {/* Sheet thêm vào playlist (giữ nguyên) */}
            <Modal visible={showAdd} transparent animationType="fade" onRequestClose={() => setShowAdd(false)}>
                <View style={{ flex: 1, backgroundColor: '#0006', justifyContent: 'center', padding: 24 }}>
                    <View style={{ backgroundColor: BG, borderRadius: 12, padding: 16 }}>
                        <Text style={{ color: TEXT, fontSize: 18, fontWeight: '700', marginBottom: 12 }}>Add to playlist</Text>
                        <View style={{ backgroundColor: CARD, borderRadius: 8, paddingHorizontal: 12 }}>
                            <TextInput
                                placeholder="Playlist name (e.g. Favorites)"
                                placeholderTextColor="#667"
                                value={playlistName}
                                onChangeText={setPlaylistName}
                                style={{ color: TEXT, height: 44 }}
                            />
                        </View>
                        <TouchableOpacity
                            onPress={() => { setShowAdd(false); setPlaylistName(''); Alert.alert('Added to playlist', 'Added to playlist (demo).'); }}
                            style={{ backgroundColor: '#e11', marginTop: 12, paddingVertical: 12, borderRadius: 8, alignItems: 'center' }}
                        >
                            <Text style={{ color: '#fff', fontWeight: '700' }}>Add to playlist</Text>
                        </TouchableOpacity>
                        <TouchableOpacity onPress={() => setShowAdd(false)} style={{ alignItems: 'center', padding: 10 }}>
                            <Text style={{ color: SUB }}>Cancel</Text>
                        </TouchableOpacity>
                    </View>
                </View>
            </Modal>

            {/* Nội dung */}
            <View style={{ flex: 1, padding: 20 }}>
                {/* Artwork */}
                {artwork
                    ? <Image source={{ uri: artwork }} style={{ height: 250, width: '100%', borderRadius: 10, backgroundColor: '#222' }} />
                    : <View style={{ height: 250, width: '100%', borderRadius: 10, backgroundColor: '#222' }} />
                }

                {/* Title / Artist */}
                <Text style={{ color: TEXT, fontSize: 22, fontWeight: '800', textAlign: 'center', marginTop: 16 }} numberOfLines={2}>
                    {title}
                </Text>
                {!!artist && (
                    <Text style={{ color: SUB, fontSize: 16, textAlign: 'center', marginTop: 6 }} numberOfLines={1}>
                        {artist}
                    </Text>
                )}

                {/* Actions giữa */}
                <View style={{ flexDirection: 'row', justifyContent: 'center', marginTop: 12 }}>
                    <TouchableOpacity onPress={() => setLike(v => !v)} style={{ padding: 10, marginHorizontal: 8 }}>
                        <Icon name="favorite" size={24} color={like ? '#e22' : TEXT} />
                    </TouchableOpacity>
                    <TouchableOpacity onPress={() => setShowAdd(true)} style={{ padding: 10, marginHorizontal: 8 }}>
                        <Icon name="playlist-add" size={24} color={TEXT} />
                    </TouchableOpacity>
                    {/* Nút mở queue cũng có thể để ở đây nếu không muốn headerRight */}
                    {/* <TouchableOpacity onPress={() => setShowQueue(true)} style={{ padding: 10, marginHorizontal: 8 }}>
            <Icon name="queue-music" size={24} color={TEXT} />
          </TouchableOpacity> */}
                </View>

                {/* Spacer đẩy controls xuống đáy */}
                <View style={{ flex: 1 }} />

                {/* Progress + seek (tap/drag) */}
                <View style={{ marginTop: 16 }} onLayout={e => setBarWidth(e.nativeEvent.layout.width)}>
                    <View
                        onStartShouldSetResponder={() => true}
                        onMoveShouldSetResponder={() => true}
                        onResponderGrant={e => { setScrubbing(true); setScrubSec(xToSec(e.nativeEvent.locationX)); }}
                        onResponderMove={e => { setScrubSec(xToSec(e.nativeEvent.locationX)); }}
                        onResponderRelease={async e => {
                            const sec = xToSec(e.nativeEvent.locationX);
                            setScrubSec(sec);
                            setScrubbing(false);
                            try { await TrackPlayer.seekTo(sec); } catch (err) { console.warn('seek error', err); }
                        }}
                        style={{ height: 24, justifyContent: 'center' }}
                    >
                        <View style={{ height: 4, backgroundColor: '#333', borderRadius: 2, overflow: 'hidden' }}>
                            {(() => {
                                if (dur <= 0) return null; // không hiển thị progress khi chưa load
                                const cur = scrubbing ? scrubSec : pos;
                                const pct = Math.max(0, Math.min(1, cur / dur));
                                return <View style={{ width: `${pct * 100}%`, height: '100%', backgroundColor: '#fff' }} />;
                            })()}
                        </View>
                    </View>

                    <View style={{ flexDirection: 'row', justifyContent: 'space-between', marginTop: 8 }}>
                        <Text style={{ color: SUB }}>{fmt(scrubbing ? scrubSec : pos)}</Text>
                        <Text style={{ color: SUB }}>{dur > 0 ? fmt(dur) : '00:00'}</Text>
                    </View>

                    {/* Controls ở đáy */}
                    <View style={{ flexDirection: 'row', alignItems: 'center', justifyContent: 'center', marginTop: 12, paddingBottom: 8 }}>
                        <TouchableOpacity onPress={onPrev} style={{ padding: 12 }}>
                            <Icon name="skip-previous" size={44} color="#fff" />
                        </TouchableOpacity>
                        <TouchableOpacity onPress={onToggle} style={{ padding: 12 }}>
                            {isPlaying ? <Icon name="pause" size={56} color="#fff" /> : <Icon name="play-arrow" size={56} color="#fff" />}
                        </TouchableOpacity>
                        <TouchableOpacity onPress={onNext} style={{ padding: 12 }}>
                            <Icon name="skip-next" size={44} color="#fff" />
                        </TouchableOpacity>
                    </View>
                </View>
            </View>
        </SafeAreaView>
    );
}
