int64 GetGameTime() {
    try {
        return GetApp().Network.PlaygroundClientScriptAPI.GameTime;
    } catch {}
    return 0;
}

int64 GetRaceTime() {
    try {
        return cast<CSmScriptPlayer>(cast<CSmPlayer>(GetApp().CurrentPlayground.GameTerminals[0].GUIPlayer).ScriptAPI).CurrentRaceTime;
    } catch {}
    return 0;
}
