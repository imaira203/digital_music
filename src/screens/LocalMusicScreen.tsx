import React from 'react';
import { View, Text } from 'react-native';

const BG = '#0b0b0f'; const TEXT = '#fff'; const SUBTLE = '#9aa0a6';

export default function LocalMusicScreen() {
    return (
        <View style={{ flex: 1, backgroundColor: BG, alignItems: 'center', justifyContent: 'center' }}>
            <Text style={{ color: TEXT, fontSize: 18, fontWeight: '700' }}>Local Music</Text>
            <Text style={{ color: SUBTLE, marginTop: 8 }}>Đang phát triển…</Text>
        </View>
    );
}
