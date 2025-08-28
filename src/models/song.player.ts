export type SongPlayer = {
    videoId: string;
    title: string;
    artist: string;
    thumbnailUrl?: string;
    duration?: string;
    audioUrl: string;
    mimeType: string;
};

// ====== Types ======
export type QueueItem = {
    videoId: string;
    title: string;
    artist: string;
    thumbnailUrl: string;
    duration?: string;
    audioUrl?: string;  // JIT
    fetchedAt?: number; // ms epoch
};

export type PlayerStore = {
    // observable
    queue: QueueItem[];
    currentIndex: number;
    title?: string;
    artist?: string;
    thumbnailUrl?: string;
    isPlaying: boolean;
    isLoading: boolean;
    liked: boolean;

    // public API
    playById: (videoId: string) => Promise<void>; // radio mode
    playPlaylist: (tracks: QueueItem[], startIndex?: number) => Promise<void>;
    addToQueue: (items: QueueItem[]) => void;
    pause: () => Promise<void>;
    resume: () => Promise<void>;
    togglePlay: () => Promise<void>;
    playNext: () => Promise<boolean>;
    playPrevious: () => Promise<boolean>;
    playQueueIndex: (i: number) => Promise<void>;
    playFirstInQueue: () => Promise<boolean>;
    playLastInQueue: () => Promise<void>;
    queueNextTap: () => void;
    toggleLike: () => void;

    // internal
    _radioMode: boolean;
    _seen: Set<string>;
    _relatedCache: Record<string, QueueItem[]>;
    _relatedCursor: Record<string, number>;
    _switching: boolean;
    _advancing: boolean;
    _lastAutoAdvance?: number;
    _pendingNextTaps: number;
    _nextDebounce?: ReturnType<typeof setTimeout>;

    _onCompleted: () => Promise<void>;
    _ensureFreshAudioUrl: (item: QueueItem) => Promise<void>;
    _refreshAudioInfo: (videoId: string) => Promise<QueueItem>;
    _ensureNextFromRelated: (minLookahead?: number) => Promise<boolean>;
    _playCurrent: () => Promise<void>;
    _skipMany: (count: number) => Promise<boolean>;
};


export type RawThumb = { url: string; width?: number; height?: number };
export type RawItem = {
    type: 'SONG' | 'PLAYLIST' | 'ALBUM' | 'VIDEO' | 'ARTIST';
    id?: string;            // SONG id (videoId)
    videoId?: string;       // alternative
    playlistId?: string;
    albumId?: string;
    title?: string;
    name?: string;
    artist?: { name?: string | null; artistId?: string | null } | null;
    thumbnails?: RawThumb[];
    thumbnailUrl?: string;
    artistName?: string;
};
export type RawSection = { title: string; contents: RawItem[] };

export type TrackMeta = {
    videoId: string;
    title: string;
    artist: string;
    thumbnailUrl: string;
};
