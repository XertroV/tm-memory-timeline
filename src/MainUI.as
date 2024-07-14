TabGroup@ g_Recordings = TabGroup("Records", null);
TabGroup@ g_StaticTabs = TabGroup("StaticTabs", null);
Tab@ g_RecordNewTab = RecordNewTab(g_StaticTabs);
Tab@ g_RecordingsTab = RecordingsTab(g_StaticTabs);

const vec4 cDarkPaleBlue = vec4(0.147f, 0.225f, 0.308f, 0.5);
const vec4 cMidBlueGray = vec4(0.4, 0.4, 0.5, .5);
const vec4 cDarkRed = vec4(0.3, 0.2, 0.1, .5);

void RenderMainUI() {
    UI::PushStyleColor(UI::Col::FrameBg, cDarkPaleBlue);
    UI::PushStyleColor(UI::Col::Border, cMidBlueGray);
    UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0f);
    UI::PushStyleVar(UI::StyleVar::FrameRounding, 3.0f);

    UI::BeginTabBar("miantabs");

    g_StaticTabs.DrawTabs(false);
    g_Recordings.DrawTabs(false);

    UI::EndTabBar();

    UI::PopStyleVar(2);
    UI::PopStyleColor(2);
}
