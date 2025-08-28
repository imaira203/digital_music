import { AppState, Platform } from 'react-native';
import { create } from 'zustand';
import TrackPlayer, {
    AppKilledPlaybackBehavior,
    Capability,
    Event,
    RepeatMode,
    useTrackPlayerEvents, // (optional nếu cần trong UI)
} from 'react-native-track-player';
import { PlayerStore, QueueItem } from '../models/song.player';
import { Constants } from '../constants';

// ====== Theme (để NowPlayingBar/Screen dùng chung nếu muốn) ======
export const BG = '#0b0b0f';
export const TEXT = '#ffffff';
export const SUBTLE = '#9aa0a6';

// ====== Config API ======
// TODO: sửa BASE_URL trỏ về backend của bạn
const BASE_URL = Constants.baseUrl;

// ====== Setup RNTP (chỉ khi app đang ACTIVE trên Android) ======
let setupPromise: Promise<void> | null = null;
let isSetup = false;
let listenersRegistered = false;

function waitForForeground(): Promise<void> {
    return new Promise((resolve) => {
        if (AppState.currentState === 'active') return resolve();
        const sub = AppState.addEventListener('change', (s) => {
            if (s === 'active') {
                sub.remove();
                resolve();
            }
        });
    });
}

export async function ensureSetup() {
    if (isSetup) return;
    if (!setupPromise) {
        setupPromise = (async () => {
            if (Platform.OS === 'android' && AppState.currentState !== 'active') {
                await waitForForeground();
            }
            await TrackPlayer.setupPlayer({});
            await TrackPlayer.updateOptions({
                progressUpdateEventInterval: 1,
                capabilities: [
                    Capability.Play,
                    Capability.Pause,
                    Capability.SkipToNext,
                    Capability.SkipToPrevious,
                    Capability.SeekTo,
                    Capability.Stop,
                ],
                compactCapabilities: [Capability.Play, Capability.Pause, Capability.SkipToNext],
                android: {
                    appKilledPlaybackBehavior:
                        AppKilledPlaybackBehavior.StopPlaybackAndRemoveNotification,
                },
            });
            await TrackPlayer.setRepeatMode(RepeatMode.Off);
            isSetup = true;

            if (!listenersRegistered) {
                // Auto-advance khi state === ended (giống just_audio completed)
                TrackPlayer.addEventListener(Event.PlaybackState, ({ state }) => {
                    if (state === 'ended') {
                        usePlayer.getState()._onCompleted();
                    }
                });
                listenersRegistered = true;
            }
        })();
    }
    return setupPromise;
}

// ====== Helpers mạng ======
const HTTP_TIMEOUT = 30_000;
const URL_TTL_MS = 30 * 60 * 1000; // 30 phút (giống biến _urlTtl bên Flutter)
const LOOKAHEAD = 4;
const AUTO_ADVANCE_COOLDOWN_MS = 400;

async function headOk(url: string): Promise<boolean> {
    try {
        const r = await Promise.race([
            fetch(url, { method: 'HEAD' }),
            new Promise<Response>((_, rej) =>
                setTimeout(() => rej(new Error('HEAD timeout')), HTTP_TIMEOUT),
            ) as any,
        ]);
        if ((r.status >= 200 && r.status < 300) || r.status === 206) return true;
    } catch {
        // ignore
    }
    // fallback: GET 1 byte
    try {
        const r = await Promise.race([
            fetch(url, { headers: { Range: 'bytes=0-0' } }),
            new Promise<Response>((_, rej) =>
                setTimeout(() => rej(new Error('RANGE timeout')), HTTP_TIMEOUT),
            ) as any,
        ]);
        return (r.status >= 200 && r.status < 300) || r.status === 206;
    } catch {
        return false;
    }
}

async function jsonGet<T = any>(path: string): Promise<T> {
    const r = await Promise.race([
        fetch(`${BASE_URL}${path}`),
        new Promise<Response>((_, rej) =>
            setTimeout(() => rej(new Error('timeout')), HTTP_TIMEOUT),
        ) as any,
    ]);
    if (!r.ok) throw new Error(`HTTP ${r.status}`);
    return (await r.json()) as T;
}

// Trả: { videoId,title,artist,thumbnailUrl,audioUrl }
async function _fetchAudio(videoId: string) {
    const m = await jsonGet<any>(`/youtube/audio/${encodeURIComponent(videoId)}`);
    const audio = String(m?.audioUrl ?? '');
    if (!audio) throw new Error('audioUrl empty');
    return {
        videoId: String(m?.videoId ?? videoId),
        title: String(m?.title ?? ''),
        artist: String(m?.artist ?? ''),
        thumbnailUrl:
            String(m?.thumbnailUrl ?? `https://i.ytimg.com/vi/${videoId}/hq720.jpg`),
        audioUrl: audio,
    };
}

// Trả: Array<{videoId,title,artist,thumbnailUrl}>
async function _fetchRelated(videoId: string) {
    const decoded = await jsonGet<any>(`/youtube/related/${encodeURIComponent(videoId)}`);
    let raw: any[] = [];
    if (Array.isArray(decoded)) raw = decoded;
    else if (decoded && typeof decoded === 'object') {
        for (const k of ['related', 'items', 'contents', 'results', 'data', 'songs']) {
            if (Array.isArray(decoded[k])) {
                raw = decoded[k];
                break;
            }
        }
        if (!raw.length && (decoded.videoId || decoded.id || decoded.title)) raw = [decoded];
    }
    return raw
        .map((m) => {
            const vid = String(m?.videoId ?? m?.id ?? '');
            if (!vid) return null;
            const artist =
                m?.artist ??
                m?.artistName ??
                m?.author?.name ??
                m?.channel?.name ??
                '';
            return {
                videoId: vid,
                title: String(m?.title ?? m?.name ?? ''),
                artist: String(artist ?? ''),
                thumbnailUrl: String(m?.thumbnailUrl ?? `https://i.ytimg.com/vi/${vid}/hq720.jpg`),
            };
        })
        .filter(Boolean) as Array<{ videoId: string; title: string; artist: string; thumbnailUrl: string }>;
}

export const usePlayer = create<PlayerStore>((set, get) => ({
    queue: [],
    currentIndex: -1,
    title: undefined,
    artist: undefined,
    thumbnailUrl: undefined,
    isPlaying: false,
    isLoading: false,
    liked: false,

    _radioMode: false,
    _seen: new Set(),
    _relatedCache: {},
    _relatedCursor: {},
    _switching: false,
    _advancing: false,
    _lastAutoAdvance: undefined,
    _pendingNextTaps: 0,
    _nextDebounce: undefined,

    // ------- Public controls -------

    togglePlay: async () => {
        const st = get();
        if (st.isPlaying) {
            await TrackPlayer.pause();
        } else {
            await TrackPlayer.play();
        }
        set((s) => ({ isPlaying: !s.isPlaying }));
    },

    toggleLike: () => set((s) => ({ liked: !s.liked })),


    playById: async (videoId) => {
        set({ isLoading: true });
        const st = get();
        st._radioMode = true;
        st._seen.clear();
        set({ queue: [], currentIndex: 0 });

        try {
            const info = await st._refreshAudioInfo(videoId); // chưa gán vào player vội
            const first: QueueItem = {
                videoId,
                title: info.title,
                artist: info.artist,
                thumbnailUrl: info.thumbnailUrl,
            };
            const nextQueue = [first];
            st._seen.add(videoId);
            set({ queue: nextQueue });

            await st._ensureNextFromRelated(LOOKAHEAD);
            await st._playCurrent();
        } finally {
            set({ isLoading: false });
        }
    },

    playPlaylist: async (tracks, startIndex = 0) => {
        const st = get();
        st._radioMode = false;
        const seen = new Set<string>();
        const normalized = tracks
            .map((it) => {
                const vid = String(it.videoId);
                if (!vid) return null;
                seen.add(vid);
                return {
                    videoId: vid,
                    title: it.title ?? '',
                    artist: it.artist ?? '',
                    thumbnailUrl: it.thumbnailUrl ?? `https://i.ytimg.com/vi/${vid}/hq720.jpg`,
                } as QueueItem;
            })
            .filter(Boolean) as QueueItem[];
        st._seen = seen;
        set({ queue: normalized, currentIndex: Math.min(startIndex, Math.max(0, normalized.length - 1)) });
        await get()._playCurrent();
    },

    addToQueue: (items) => {
        const st = get();
        const appended: QueueItem[] = [];
        for (const it of items) {
            const vid = String(it.videoId ?? '');
            if (!vid || st._seen.has(vid)) continue;
            st._seen.add(vid);
            appended.push({
                videoId: vid,
                title: it.title ?? '',
                artist: it.artist ?? '',
                thumbnailUrl: it.thumbnailUrl ?? `https://i.ytimg.com/vi/${vid}/hq720.jpg`,
            });
        }
        if (appended.length) set((s) => ({ queue: [...s.queue, ...appended] }));
    },

    pause: async () => {
        await ensureSetup();
        await TrackPlayer.pause();
        set({ isPlaying: false });
    },

    resume: async () => {
        await ensureSetup();
        await TrackPlayer.play();
        set({ isPlaying: true });
    },

    playNext: async () => {
        const st = get();
        if (st._switching || st._advancing) {
            return false;
        }
        const q = st.queue;
        const i = st.currentIndex;
        if (i < q.length - 1) {
            set({ currentIndex: i + 1 });
            await st._playCurrent();
            return true;
        }
        // Loop về đầu
        if (q.length) {
            set({ currentIndex: 0 });
            await st._playCurrent();
            return true;
        }
        return false;
    },

    playPrevious: async () => {
        const st = get();
        if (st._switching || st._advancing) return false;
        if (st.currentIndex > 0) {
            set({ currentIndex: st.currentIndex - 1 });
            await st._playCurrent();
            return true;
        }
        return false;
    },

    playQueueIndex: async (i) => {
        const st = get();
        if (!st.queue[i]) return;
        set({ currentIndex: i });
        await st._playCurrent();
    },

    playFirstInQueue: async () => {
        const st = get();
        if (!st.queue.length) return false;
        set({ currentIndex: 0 });
        await st._playCurrent();
        return true;
    },

    playLastInQueue: async () => {
        const st = get();
        if (!st.queue.length) return;
        set({ currentIndex: st.queue.length - 1 });
        await st._playCurrent();
    },

    queueNextTap: () => {
        const st = get();
        st._pendingNextTaps++;
        if (st._nextDebounce) clearTimeout(st._nextDebounce);
        st._nextDebounce = setTimeout(async () => {
            const taps = get()._pendingNextTaps;
            set({ _pendingNextTaps: 0 });
            await get()._skipMany(taps);
        }, 120);
    },


    // ------- Internal -------
    _onCompleted: async () => {
        const st = get();
        const now = Date.now();
        if (st._advancing) return;
        if (st._lastAutoAdvance && now - st._lastAutoAdvance < AUTO_ADVANCE_COOLDOWN_MS) return;
        st._advancing = true;
        try {
            st._lastAutoAdvance = now;
            const moved = await get().playNext();
            if (!moved) {
                await ensureSetup();
                await TrackPlayer.stop();
                set({ isPlaying: false });
            }
        } finally {
            st._advancing = false;
        }
    },

    _refreshAudioInfo: async (videoId) => {
        const info = await _fetchAudio(videoId);
        return {
            videoId: info.videoId,
            title: info.title,
            artist: info.artist,
            thumbnailUrl: info.thumbnailUrl,
            audioUrl: info.audioUrl,
            fetchedAt: Date.now(),
        };
    },

    _ensureFreshAudioUrl: async (item) => {
        const stale = !item.fetchedAt || Date.now() - (item.fetchedAt ?? 0) > URL_TTL_MS;
        if (!item.audioUrl || stale) {
            const fresh = await get()._refreshAudioInfo(item.videoId);
            item.audioUrl = fresh.audioUrl;
            item.fetchedAt = fresh.fetchedAt;
            item.title ||= fresh.title;
            item.artist ||= fresh.artist;
            item.thumbnailUrl ||= fresh.thumbnailUrl;
            return;
        }
        const ok = await headOk(item.audioUrl);
        if (!ok) {
            const fresh = await get()._refreshAudioInfo(item.videoId);
            item.audioUrl = fresh.audioUrl;
            item.fetchedAt = fresh.fetchedAt;
            item.title ||= fresh.title;
            item.artist ||= fresh.artist;
            item.thumbnailUrl ||= fresh.thumbnailUrl;
        }
    },

    _ensureNextFromRelated: async (minLookahead = LOOKAHEAD) => {
        const st = get();
        if (!st._radioMode) return false;
        const q = st.queue;
        const idx = st.currentIndex;
        if (idx < 0 || idx >= q.length) return false;

        let added = false;

        while (q.length - 1 - idx < minLookahead) {
            const seed = q[idx]?.videoId;
            if (!seed) break;

            let pool = st._relatedCache[seed] || [];
            if (!pool.length) {
                pool = (await _fetchRelated(seed)) as QueueItem[];
                st._relatedCache[seed] = pool;
                st._relatedCursor[seed] = 0;
            }
            let cur = st._relatedCursor[seed] ?? 0;
            let pushed = false;

            while (cur < pool.length) {
                const it = pool[cur++];
                if (it?.videoId && !st._seen.has(it.videoId)) {
                    st._relatedCursor[seed] = cur;
                    st._seen.add(it.videoId);
                    q.push({
                        videoId: it.videoId,
                        title: it.title ?? '',
                        artist: it.artist ?? '',
                        thumbnailUrl: it.thumbnailUrl ?? `https://i.ytimg.com/vi/${it.videoId}/hq720.jpg`,
                    });
                    set({ queue: [...q] });
                    added = pushed = true;
                    break;
                }
            }

            if (!pushed) {
                delete st._relatedCache[seed];
                delete st._relatedCursor[seed];
                break;
            }
        }

        return added;
    },

    _playCurrent: async () => {
        await ensureSetup();
        const st = get();
        const q = st.queue;
        const i = st.currentIndex;
        if (i < 0 || i >= q.length) return;

        const cur = q[i];

        st._switching = true;
        set({ isLoading: true });

        try {
            await get()._ensureFreshAudioUrl(cur);
            const url = String(cur.audioUrl);
            if (!url) throw new Error('no audioUrl');

            // Cập nhật UI fields
            set({
                title: cur.title,
                artist: cur.artist,
                thumbnailUrl: cur.thumbnailUrl,
            });

            await TrackPlayer.reset();
            await TrackPlayer.add({
                id: cur.videoId,
                url,
                title: cur.title || 'Unknown',
                artist: cur.artist || 'Unknown',
                artwork: cur.thumbnailUrl,
            });
            await TrackPlayer.play();
            set({ isPlaying: true });

            if (st._radioMode) {
                // prime tiếp
                void get()._ensureNextFromRelated(LOOKAHEAD);
            }
        } catch (e) {
            // Retry 1 lần
            try {
                const fresh = await get()._refreshAudioInfo(cur.videoId);
                cur.audioUrl = fresh.audioUrl;
                cur.fetchedAt = fresh.fetchedAt;
                cur.title ||= fresh.title;
                cur.artist ||= fresh.artist;
                cur.thumbnailUrl ||= fresh.thumbnailUrl;

                await TrackPlayer.reset();
                await TrackPlayer.add({
                    id: cur.videoId,
                    url: String(cur.audioUrl),
                    title: cur.title || 'Unknown',
                    artist: cur.artist || 'Unknown',
                    artwork: cur.thumbnailUrl,
                });
                await TrackPlayer.play();
                set({ isPlaying: true });
            } catch {
                // skip nếu thất bại
                await get()._skipMany(1);
            }
        } finally {
            st._switching = false;
            set({ isLoading: false });
        }
    },

    _skipMany: async (count) => {
        if (count <= 0) return false;
        const st = get();
        if (st._advancing) return false;

        st._advancing = true;
        try {
            if (st._radioMode) {
                await get()._ensureNextFromRelated(count);
            }
            const q = st.queue;
            const target = Math.max(
                0,
                Math.min(q.length - 1, st.currentIndex + count),
            );
            if (target === st.currentIndex) return false;
            set({ currentIndex: target });
            await get()._playCurrent();
            if (st._radioMode) void get()._ensureNextFromRelated(LOOKAHEAD);
            return true;
        } finally {
            st._advancing = false;
        }
    },
}));
