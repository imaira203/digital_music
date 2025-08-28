import React, { useEffect, useState } from 'react';
import { View, Text, TouchableOpacity, FlatList, StatusBar } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { useNavigation } from '@react-navigation/native';
import { StackNavigationProp } from '@react-navigation/stack';
import { AuthService, User } from '../services/auth.services';
import { BG, TEXT, SUBTLE } from '../player/store';
import { RootStackParamList } from '../models/types';
import Icon from 'react-native-vector-icons/MaterialIcons';

const auth = new AuthService();

type NavigationProp = StackNavigationProp<RootStackParamList>;

export default function ProfileScreen() {
    const navigation = useNavigation<NavigationProp>();
    const [user, setUser] = useState<User | null>(null);

    const load = async () => setUser(await auth.getUser());
    useEffect(() => { const unsub = navigation.addListener('focus', load); return unsub; }, [navigation]);
    useEffect(() => { load(); }, []);

    const avatar = user?.username?.[0]?.toUpperCase() ?? '?';

    return (
        <SafeAreaView style={{ flex: 1, backgroundColor: BG }}>
            <StatusBar barStyle="light-content" backgroundColor={BG} />
            <View style={{ padding: 16, alignItems: 'center' }}>
                <View style={{ width: 100, height: 100, borderRadius: 50, backgroundColor: '#e11', alignItems: 'center', justifyContent: 'center' }}>
                    <Text style={{ color: '#fff', fontSize: 40, fontWeight: '800' }}>{avatar}</Text>
                </View>
                <View style={{ height: 12 }} />
                <Text style={{ color: TEXT, fontSize: 18 }}>{user?.username ?? 'Chưa đăng nhập'}</Text>
            </View>

            <View style={{ paddingHorizontal: 16 }}>
                {user ? (
                    <TouchableOpacity
                        onPress={async () => { await auth.logout(); await load(); }}
                        style={{ backgroundColor: '#222', padding: 12, borderRadius: 10, marginBottom: 12 }}
                    >
                        <Text style={{ color: TEXT, textAlign: 'center' }}>Đăng xuất</Text>
                    </TouchableOpacity>
                ) : (
                    <View style={{ flexDirection: 'row', gap: 12 }}>
                        <TouchableOpacity
                            onPress={() => {
                                navigation.navigate('Login')
                            }}
                            style={{ flex: 1, backgroundColor: '#222', padding: 12, borderRadius: 10 }}
                        >
                            <Text style={{ color: TEXT, textAlign: 'center' }}>Đăng nhập</Text>
                        </TouchableOpacity>
                        <TouchableOpacity
                            onPress={() => {
                                navigation.navigate('Register')
                            }}
                            style={{ flex: 1, backgroundColor: '#222', padding: 12, borderRadius: 10 }}
                        >
                            <Text style={{ color: TEXT, textAlign: 'center' }}>Đăng ký</Text>
                        </TouchableOpacity>
                    </View>
                )}

                <View style={{ height: 16 }} />
                {[
                    { icon: 'favorite', label: 'Danh sách đã thích' },
                    { icon: 'playlist-play', label: 'Danh sách phát đã tạo' },
                    { icon: 'playlist-add', label: 'Tạo danh sách mới' },
                ].map((row, i) => (
                    <View key={i} style={{ paddingVertical: 14, borderBottomWidth: 1, borderBottomColor: '#1e1e1e', flexDirection: 'row', alignItems: 'center', gap: 12 }}>
                        <Icon name={row.icon} size={24} color={TEXT} />
                        <Text style={{ color: TEXT }}>{row.label}</Text>
                    </View>
                ))}
            </View>
        </SafeAreaView>
    );
}
