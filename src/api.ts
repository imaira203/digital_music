// src/api/index.ts
import { SongPlayer, QueueItem, RawItem, TrackMeta, RawSection } from './models/song.player';
import { Constants } from './constants';
import { http } from './services/http.services';           // <— axios instance đã bật cache

export const API_BASE = Constants.baseUrl;

// Kiểu dữ liệu
export type Song = {
    videoId: string;
    title: string;
    artist: string;
    thumbnailUrl?: string;
    duration?: string;
    audioUrl: string;
};

export async function fetchSongs(): Promise<Song[]> {
    console.log('fetchSongs');
    console.log(API_BASE);
    const { data } = await http.get(`${API_BASE}/songs`, {
        headers: {
            Accept: 'application/json',
            'Cache-Control': 'no-cache',
            Pragma: 'no-cache',
            Expires: '0'
        }
    });
    return data;
}

export async function fetchHome(): Promise<RawSection[]> {
    const { data } = await http.get(`${Constants.baseUrl}/songs`, { headers: { Accept: 'application/json' } });
    return data as any;
}

export async function fetchPlaylist(playlistId: string): Promise<TrackMeta[]> {
    const { data } = await http.get(`${Constants.baseUrl}/youtube/playlist/${playlistId}`, {
        headers: { Accept: 'application/json' },
    });
    const songs: any[] = Array.isArray(data?.songs) ? data.songs : [];
    return songs.map((m) => {
        const vid = (m.videoId ?? m.id ?? '').toString();
        return {
            videoId: vid,
            title: (m.title ?? m.name ?? '').toString(),
            artist: (m.artist ?? m.artistName ?? '').toString(),
            thumbnailUrl: m.thumbnailUrl ?? (vid ? `https://i.ytimg.com/vi/${vid}/hq720.jpg` : ''),
        } as TrackMeta;
    });
}

// JSON trả về { audioUrl, mimeType, ... } — cache theo header response
export async function fetchAudioUrl(videoId: string): Promise<SongPlayer | null> {
    const { data, status } = await http.get(`${API_BASE}/youtube/audio/${videoId}`, {
        headers: { Accept: 'application/json' },
    });
    if (status === 200) return data;
    return null;
}

export async function fetchRelated(videoId: string): Promise<SongPlayer[]> {
    const { data, status } = await http.get(`${API_BASE}/youtube/related/${videoId}`, {
        headers: { Accept: 'application/json' },
    });
    if (status === 200) return data;
    return [];
}

export async function search(query: string): Promise<RawItem[]> {
    const { data } = await http.get(`${Constants.baseUrl}/search`, {
        params: { q: query },
        headers: { Accept: 'application/json' },
    });
    return data as RawItem[];
}

export async function searchSuggestions(query: string): Promise<string[]> {
    if (!query) return [];
    const { data } = await http.get(`${Constants.baseUrl}/search/suggestions`, {
        params: { q: query },
        headers: { Accept: 'application/json' },
        // nếu server đặt no-store thì sẽ không cache
    });
    return Array.isArray(data) ? data.map((x: any) => String(x)) : [];
}
