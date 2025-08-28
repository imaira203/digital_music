export type RootStackParamList = {
    Tabs: undefined;
    Home: undefined;
    Player: { fromQueue?: boolean } | undefined;
    Collection: { id: string; kind: 'PLAYLIST' | 'ALBUM'; title: string } | undefined;
    Search: { query?: string } | undefined;
    SearchResults: { query: string };
    Login: undefined;
    Register: undefined;
};