import AsyncStorage from '@react-native-async-storage/async-storage';
import { Constants } from '../constants';

// Nếu bạn đã có models/user.ts thì import từ đó.
// Ở đây để generic cho an toàn:
export type User = {
    id?: string;
    username: string;
    token?: string;
    [k: string]: any;
};

const KEY = 'user';

export class AuthService {
    async register(username: string, password: string): Promise<User | null> {
        try {
            const res = await fetch(`${Constants.baseUrl}/account/create`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password }),
            });

            if (res.status === 200) {
                const data = await res.json();
                const user = data as User; // server trả thẳng user
                await this._saveUser(user);
                return user;
            }
            return null;
        } catch {
            return null;
        }
    }

    async login(username: string, password: string): Promise<User | null> {
        try {
            const res = await fetch(`${Constants.baseUrl}/account/login`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ username, password }),
            });

            if (res.status === 201) {
                const json = await res.json();
                const user = (json?.data ?? json) as User; // server trả { data: {...} }
                await this._saveUser(user);
                return user;
            }
            return null;
        } catch {
            return null;
        }
    }

    private async _saveUser(user: User) {
        await AsyncStorage.setItem(KEY, JSON.stringify(user));
    }

    async getUser(): Promise<User | null> {
        const raw = await AsyncStorage.getItem(KEY);
        if (!raw) return null;
        try {
            return JSON.parse(raw) as User;
        } catch {
            return null;
        }
    }

    async logout(): Promise<void> {
        await AsyncStorage.removeItem(KEY);
    }
}
