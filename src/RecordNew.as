class RecordNewTab : Tab {
    RecordNewTab(TabGroup@ parent) {
        super(parent, "Record New", "\\$f00" + Icons::CircleO + "\\$z");
    }

    string m_recordingName = "v1";
    string m_ptr;
    string ptrValidationErr;
    bool ptrValid = false;
    uint64 outPtr;
    uint m_size = 0x360;
    bool m_startOnRaceReset = true;
    int m_recordingStartDelay = 2900;
    int m_recordingDuration = 1700;

    bool ptrChanged;

    void DrawInner() override {
        auto app = GetApp();

        UI::SeparatorText("Record New");
        UI::PushItemWidth(200);

        m_recordingName = UI::InputText("Recording Name", m_recordingName);

        m_ptr = UI::InputText("Pointer", m_ptr, ptrChanged);
        if (ptrChanged) TryParsePtr();
        UI::SameLine();
        UI::Text("\\$i\\$fca" + ptrValidationErr);

        m_size = UI::InputInt("Size", m_size, 8);
        UI::SameLine();
        CopiableValue(Text::Format("0x%x", m_size), Text::Format(" (0x%x)", m_size));
        UI::SameLine();
        if (UI::Button("0x100")) m_size = 0x100;
        UI::SameLine();
        if (UI::Button("0x200")) m_size = 0x200;
        UI::SameLine();
        if (UI::Button("0x360")) m_size = 0x360;
        UI::SameLine();
        if (UI::Button("0x400")) m_size = 0x400;
        UI::SameLine();
        if (UI::Button("0x800")) m_size = 0x800;
        UI::SameLine();
        if (UI::Button("0x1000")) m_size = 0x1000;
        UI::SameLine();
        if (UI::Button("0x2000")) m_size = 0x2000;

        bool noPg = app.CurrentPlayground is null;
        UI::BeginDisabled(noPg);
        bool wasActive = m_startOnRaceReset;
        m_startOnRaceReset = UI::Checkbox("Wait for Race Reset (waits for race time to count up past 0)", m_startOnRaceReset && !noPg);
        if (noPg) m_startOnRaceReset = wasActive;
        UI::EndDisabled();
        m_recordingStartDelay = UI::InputInt("Start Delay (ms)", m_recordingStartDelay);
        AddSimpleTooltip("In playground: Can be as low as -1500 ms (for countdown)\nOut of playground: starts recording after X ms");

        m_recordingDuration = UI::InputInt("Recording Duration (ms)", m_recordingDuration, 200);
        AddSimpleTooltip("miliseconds. -1 for infinite (stops when you press stop).");

        UI::PopItemWidth();
        UI::SeparatorText("Start New Recording");
        UI::BeginDisabled(!ptrValid || m_size == 0 || m_recordingName.Length == 0 || m_recordingStartDelay < -1500);
        if (UI::Button("Record")) {
            MemorySnapshotRecordingTab(g_Recordings, m_recordingName, outPtr, m_size, m_startOnRaceReset && !noPg, m_recordingStartDelay, m_recordingDuration);
        }
        UI::EndDisabled();
        UI::SeparatorText("History");
    }

    private string _ptrValidationErrStart = "\\$i\\$fca";

    bool TryParsePtr() {
        ptrValidationErr = _ptrValidationErrStart;
        ptrValid = false;
        if (m_ptr.Length == 0) return PtrValidationFail("Pointer required");
        if (m_ptr.Length < 3) return PtrValidationFail("Invalid pointer");
        string ptr = m_ptr;
        if (m_ptr.StartsWith("0x")) {
            ptr = m_ptr.SubStr(2);
        }
        if (ptr.Length > 16) return PtrValidationFail("Pointer too long");

        if (Text::TryParseUInt64(ptr, outPtr, 16)) {
            if (outPtr > BASE_ADDR_END) {
                return PtrValidationFail(Text::FormatPointer(outPtr) + " > " + Text::FormatPointer(BASE_ADDR_END));
            }
        } else {
            return PtrValidationFail("Invalid pointer (must be a hex number; 0x prefix optional)");
        }

        return PtrValidationPassed();
    }

    private bool PtrValidationFail(const string &in msg) {
        ptrValidationErr = _ptrValidationErrStart + msg;
        ptrValid = false;
        return false;
    }

    private bool PtrValidationPassed() {
        ptrValidationErr = "\\$i\\$cfc" + Text::FormatPointer(outPtr);
        ptrValid = true;
        return true;
    }
}
