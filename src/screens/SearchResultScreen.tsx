import React, { useEffect, useState } from 'react';
import { ActivityIndicator, FlatList, Image, Text, TouchableOpacity, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { search } from '../api';
import { usePlayer } from '../player/store';
import type { RootStackParamList } from '../models/types';
import { RawItem } from '../models/song.player';
import Icon from 'react-native-vector-icons/MaterialIcons';

const BG = '#0b0b0f';
const TEXT = '#fff';
const SUBTLE = '#9aa0a6';

type Props = NativeStackScreenProps<RootStackParamList, 'SearchResults'>;

const thumbOf = (item: RawItem) => {
    const t = item.thumbnails;
    if (t?.length) return (t[t.length - 1].url ?? t[0].url) as string;
    if (item.videoId) return `https://i.ytimg.com/vi/${item.videoId}/hq720.jpg`;
    return undefined;
};

export default function SearchResultScreen({ route, navigation }: Props) {
    const { query } = route.params;
    const [loading, setLoading] = useState(true);
    const [items, setItems] = useState<RawItem[]>([]);
    const playById = usePlayer((s) => s.playById);

    useEffect(() => {
        let off = false;
        (async () => {
            try {
                const res = await search(query);
                if (!off) setItems(res || []);
            } finally {
                if (!off) setLoading(false);
            }
        })();
        return () => {
            off = true;
        };
    }, [query]);

    if (loading) {
        return (
            <View style={{ flex: 1, backgroundColor: BG, alignItems: 'center', justifyContent: 'center' }}>
                <ActivityIndicator />
            </View>
        );
    }

    return (
        <View style={{ flex: 1, backgroundColor: BG }}>
            <FlatList
                data={items}
                keyExtractor={(_, i) => String(i)}
                ItemSeparatorComponent={() => <View style={{ height: 1, backgroundColor: '#16181d' }} />}
                renderItem={({ item }) => {
                    const type = String(item.type ?? '');
                    const title = (item.title ?? item.name ?? 'No title').toString();
                    const artist =
                        (item.artist as any)?.name ??
                        item.artistName ??
                        '';
                    const thumb = thumbOf(item);
                    const subtitle =
                        type === 'ARTIST'
                            ? 'Nghệ sĩ'
                            : type === 'ALBUM'
                                ? `Album · ${artist}`
                                : type === 'PLAYLIST'
                                    ? `Playlist · ${artist}`
                                    : artist;

                    return (
                        <TouchableOpacity
                            onPress={async () => {
                                if (type === 'SONG' || type === 'VIDEO') {
                                    const videoId = String(item.videoId ?? item.id ?? '');
                                    if (!videoId) return;
                                    navigation.navigate('Player', { fromQueue: false });
                                    await playById(videoId);
                                } else {
                                    // TODO: mở ALBUM/PLAYLIST/ARTIST
                                }
                            }}
                            style={{ flexDirection: 'row', padding: 12, alignItems: 'center' }}
                        >
                            {thumb ? (
                                <Image source={{ uri: thumb }} style={{ width: 50, height: 50, borderRadius: 8, marginRight: 12 }} />
                            ) : (
                                <View style={{ width: 50, height: 50, borderRadius: 8, marginRight: 12, backgroundColor: '#222' }} />
                            )}
                            <View style={{ flex: 1 }}>
                                <Text style={{ color: TEXT, fontWeight: '600' }} numberOfLines={1}>
                                    {title}
                                </Text>
                                <Text style={{ color: SUBTLE }} numberOfLines={1}>
                                    <Text style={{ color: SUBTLE, flexDirection: 'row', alignItems: 'center', justifyContent: 'center', gap: 8, fontSize: 16 }}>
                                        {type === "SONG" ? <Icon name="music-note" size={16} color={SUBTLE} /> : type === "VIDEO" ? <Icon name="video-library" size={16} color={SUBTLE} /> : type === "ALBUM" ? <Icon name="album" size={16} color={SUBTLE} /> : type === "PLAYLIST" ? <Icon name="playlist-play" size={16} color={SUBTLE} /> : ""}
                                        {subtitle}
                                    </Text>
                                </Text>
                            </View>
                        </TouchableOpacity>
                    );
                }}
                ListHeaderComponent={
                    <View style={{ paddingHorizontal: 16, paddingVertical: 12, flexDirection: 'row', alignItems: 'center' }}>
                    </View>
                }
            />
        </View>
    );
}
