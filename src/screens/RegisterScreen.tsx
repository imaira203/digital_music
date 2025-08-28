import React, { useState } from 'react';
import { View, Text, TextInput, TouchableOpacity, ActivityIndicator, Alert, StatusBar } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';
import { AuthService } from '../services/auth.services';
import { BG, TEXT, SUBTLE } from '../player/store';
import { useNavigation } from '@react-navigation/native';

const auth = new AuthService();

export default function RegisterScreen() {
    const navigation = useNavigation<any>();

    const [username, setUsername] = useState('');
    const [password, setPassword] = useState('');
    const [loading, setLoading] = useState(false);

    const onRegister = async () => {
        setLoading(true);
        const user = await auth.register(username.trim(), password);
        setLoading(false);
        if (user) {
            Alert.alert('Thành công', 'Đăng ký thành công!');
            navigation.goBack();
        } else {
            Alert.alert('Lỗi', 'Đăng ký thất bại!');
        }
    };

    return (
        <SafeAreaView style={{ flex: 1, backgroundColor: BG }}>
            <StatusBar barStyle="light-content" backgroundColor={BG} />
            <View style={{ padding: 24 }}>
                <Text style={{ color: TEXT, fontSize: 24, fontWeight: '800' }}>Tạo tài khoản</Text>
                <View style={{ height: 24 }} />
                <TextInput
                    value={username}
                    onChangeText={setUsername}
                    placeholder="Username"
                    placeholderTextColor={SUBTLE}
                    style={{
                        color: TEXT, borderColor: '#333', borderWidth: 1, borderRadius: 12, paddingHorizontal: 12, height: 48,
                    }}
                />
                <View style={{ height: 16 }} />
                <TextInput
                    value={password}
                    onChangeText={setPassword}
                    placeholder="Password"
                    placeholderTextColor={SUBTLE}
                    secureTextEntry
                    style={{
                        color: TEXT, borderColor: '#333', borderWidth: 1, borderRadius: 12, paddingHorizontal: 12, height: 48,
                    }}
                />
                <View style={{ height: 24 }} />
                <TouchableOpacity
                    onPress={loading ? undefined : onRegister}
                    disabled={loading}
                    style={{ backgroundColor: '#e11', paddingVertical: 14, borderRadius: 12, alignItems: 'center' }}
                >
                    {loading ? <ActivityIndicator color="#fff" /> : <Text style={{ color: '#fff', fontSize: 18, fontWeight: '700' }}>Đăng ký</Text>}
                </TouchableOpacity>
            </View>
        </SafeAreaView>
    );
}
