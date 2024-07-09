TabGroup@ g_Recordings = TabGroup("Records", null);
TabGroup@ g_StaticTabs = TabGroup("StaticTabs", null);
Tab@ g_RecordNewTab = RecordNewTab(g_StaticTabs);
Tab@ g_RecordingsTab = RecordingsTab(g_StaticTabs);

void RenderMainUI() {
    UI::BeginTabBar("miantabs");

    g_StaticTabs.DrawTabs(false);
    g_Recordings.DrawTabs(false);

    UI::EndTabBar();
}
