const string PluginName = Meta::ExecutingPlugin().Name;
const string MenuIconColor = "\\$f5d";
const string PluginIcon = Icons::Cogs;
const string MenuTitle = MenuIconColor + PluginIcon + "\\$z " + PluginName;

UI::Font@ g_MonoFont;
UI::Font@ g_BoldFont;
UI::Font@ g_BigFont;
UI::Font@ g_MidFont;
UI::Font@ g_NormFont;
void LoadFonts() {
    @g_BoldFont = UI::LoadFont("DroidSans-Bold.ttf");
    @g_MonoFont = UI::LoadFont("DroidSansMono.ttf");
    @g_BigFont = UI::LoadFont("DroidSans.ttf", 26);
    @g_MidFont = UI::LoadFont("DroidSans.ttf", 20);
    @g_NormFont = UI::LoadFont("DroidSans.ttf", 16);
}

void Main() {
    LoadFonts();
    for (int i = -1; i < 10; i++) {
        print("RunContext(" + i + ") = " + tostring(Meta::RunContext(i)));
    }
}

vec2 screen;
float g_LastDT;
void Update(float dt) {
    g_LastDT = dt;
    screen.x = Draw::GetWidth();
    screen.y = Draw::GetHeight();
}

[Setting hidden]
bool g_WindowOpen = true;


void Render() {
    if (!g_WindowOpen) return;

    UI::SetNextWindowSize(800, 600, UI::Cond::FirstUseEver);
    if (UI::Begin(PluginName, g_WindowOpen, UI::WindowFlags::None)) {
        RenderMainUI();
    }
    UI::End();
}

void RenderMenu() {
    if (UI::MenuItem(MenuTitle, "", g_WindowOpen)) {
        g_WindowOpen = !g_WindowOpen;
    }
}
