import React, { useEffect, useMemo, useState } from 'react';
import { ActivityIndicator, FlatList, Text, TextInput, TouchableOpacity, View } from 'react-native';
import { NativeStackScreenProps } from '@react-navigation/native-stack';
import { search, searchSuggestions } from '../api';
import type { RootStackParamList } from '../models/types';
import Icon from 'react-native-vector-icons/MaterialIcons';

const BG = '#0b0b0f';
const TEXT = '#fff';
const SUBTLE = '#9aa0a6';

type Props = NativeStackScreenProps<RootStackParamList, 'Search'>;

export default function SearchScreen({ navigation, route }: Props) {
    const [query, setQuery] = useState(route.params?.query ?? '');
    const [loading, setLoading] = useState(false);
    const [sugs, setSugs] = useState<string[]>([]);

    useEffect(() => {
        let aborted = false;
        (async () => {
            if (!query) {
                setSugs([]);
                return;
            }
            setLoading(true);
            try {
                const data = await searchSuggestions(query);
                if (!aborted) setSugs(data);
            } finally {
                if (!aborted) setLoading(false);
            }
        })();
        return () => {
            aborted = true;
        };
    }, [query]);

    const goResults = (q: string) => {
        if (!q) return;
        navigation.replace('SearchResults', { query: q });
    };

    return (
        <View style={{ flex: 1, backgroundColor: BG, padding: 16 }}>
            <TextInput
                value={query}
                onChangeText={setQuery}
                placeholder="Enter song or artist name..."
                placeholderTextColor={SUBTLE}
                style={{
                    color: TEXT,
                    borderWidth: 1,
                    borderColor: '#222',
                    borderRadius: 12,
                    paddingHorizontal: 14,
                    paddingVertical: 12,
                }}
                onSubmitEditing={() => goResults(query)}
            />
            <View style={{ height: 12 }} />
            {loading ? (
                <ActivityIndicator />
            ) : sugs.length ? (
                <FlatList
                    data={sugs}
                    keyExtractor={(i, idx) => i + idx}
                    renderItem={({ item }) => (
                        <TouchableOpacity
                            onPress={() => goResults(item)}
                            style={{ paddingVertical: 12, borderBottomWidth: 1, borderBottomColor: '#16181d' }}
                        >
                            <Text style={{ color: TEXT, display: 'flex', flexDirection: 'row', alignItems: 'center', gap: 10 }}>
                                <Icon name="search" size={17} color="#fff" style={{ marginTop: 2 }} />
                                <Text style={{ fontSize: 16 }}>{item}</Text>
                            </Text>
                        </TouchableOpacity>
                    )}
                />
            ) : null}
        </View>
    );
}
