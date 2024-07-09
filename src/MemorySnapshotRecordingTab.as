uint g_RecordingCounter = 0;

enum RunContext {
    Main = int(Meta::RunContext::Main),
    BeforeScripts = int(Meta::RunContext::BeforeScripts),
    MainLoop = int(Meta::RunContext::MainLoop),
    GameLoop = int(Meta::RunContext::GameLoop),
    AfterMainLoop = int(Meta::RunContext::AfterMainLoop),
    NetworkAfterMainLoop = int(Meta::RunContext::NetworkAfterMainLoop),
    AfterScripts = int(Meta::RunContext::AfterScripts),
    UpdateSceneEngine = int(Meta::RunContext::UpdateSceneEngine),
    // non-openplanet contexts below
    ManialinkCallback = 1000,
    VehicleStateUpdate,
}

class MemorySnapshotRecordingTab : Tab {
    uint recordingId;
    string recordingName;
    uint64 ptr;
    string ptrStr;
    uint size;
    bool waitForRaceReset;
    int recordingStartDelay;
    uint recordingDuration;
    RunContext runCtx;
    Meta::PluginCoroutine@ mainCoro;

    MemorySnapshotRecordingTab(TabGroup@ parent, const string &in recordingName, uint64 ptr, uint size, bool waitForRaceReset, int recordingStartDelay, uint recordingDuration, RunContext runCtx = RunContext::Main) {
        recordingId = ++g_RecordingCounter;
        super(parent, recordingName.Length > 0 ? recordingName : ("#" + recordingId), Icons::Camera);
        this.recordingName = recordingName;
        this.ptr = ptr;
        this.ptrStr = "0x"+Text::FormatPointer(ptr);
        this.size = size;
        this.waitForRaceReset = waitForRaceReset;
        this.recordingStartDelay = recordingStartDelay;
        this.recordingDuration = recordingDuration;
        this.runCtx = runCtx;
        print("Recording " + recordingName + " at " + ptrStr + " with size " + size + " starting");
        @mainCoro = startnew(CoroutineFunc(WaitThenRecord));
        if (runCtx < 1000) {
            mainCoro.WithRunContext(Meta::RunContext(runCtx));
        }
        SetSelectedTab();
    }

    uint64 recordingDelayStartedAt;
    uint64 recordingStarted;
    // when we should end the recording
    uint64 recordingEnd;
    // when the recording actually ended
    uint64 recordingEnded;
    MemorySnapshot@[] frames;
    bool stopRecordingFlag = false;

    protected void WaitThenRecord() {
        auto app = GetApp();
        if (waitForRaceReset && app.CurrentPlayground !is null) {
            CSmArenaClient@ pg;
            // wait for CurrentRaceTime to be negative.
            while ((@pg = cast<CSmArenaClient>(app.CurrentPlayground)) !is null) {
                auto player = cast<CSmPlayer>(pg.GameTerminals[0].GUIPlayer);
                if (player !is null) {
                    auto scriptApi = cast<CSmScriptPlayer>(player.ScriptAPI);
                    if (scriptApi is null) trace("Expected scriptApi but found none");
                    else if (scriptApi.CurrentRaceTime < 0) {
                        recordingStartDelay -= scriptApi.CurrentRaceTime;
                        log_trace("Recording got player curr race time < 0; adjusting start delay to " + recordingStartDelay);
                        break;
                    }
                }
                yield();
            }
        }
        recordingDelayStartedAt = Time::Now;
        if (recordingStartDelay > 0) {
            log_trace("Recording waiting for " + recordingStartDelay + "ms");
            sleep(recordingStartDelay);
        }
        recordingStarted = Time::Now;
        // uint64 = uint64 + uint; since duration is passed as a uint, -1 => far in future.
        recordingEnd = recordingStarted + recordingDuration;
        print("Recording started at " + recordingStarted);
        while (Time::Now <= recordingEnd && !stopRecordingFlag) {
            frames.InsertLast(MemorySnapshot(ptr, size));
            yield();
        }
        recordingEnded = Time::Now;
        print("Recording ended at " + recordingEnded);
    }

    void DrawInner() override {
        if (Time::Now < recordingEnd && recordingEnded == 0) {
            DrawRecordingActiveUI();
            return;
        }
        if (recordingEnded > 0) {
            DrawRecordingBrowseUI();
            return;
        }
        if (recordingDelayStartedAt > 0) {
            auto waitingTime = Time::Now - recordingDelayStartedAt;
            auto waitingLeft = recordingStartDelay - waitingTime;
            UI::Text("Starting in: " + Time::Format(waitingLeft, true, true));
            return;
        }
        if (recordingStarted == 0) {
            UI::Text("Waiting to start recording...");
            return;
        }
        if (recordingEnd <= 0) {
            UI::Text("Unexpected recording end time.");
            return;
        }

        // otherwise, recording ended
        // DrawRecordingBrowseUI();
        UI::Text("Unknown conditions");
    }

    void DrawRecordingActiveUI() {
        UI::SeparatorText("Recording...");
        UI::Indent();
        auto nbFrames = frames.Length;
        int estimatedFrames = int(recordingDuration) < 0 ? -1 : int(float(recordingDuration) / g_LastDT);
        UI::Text("Frames: " + frames.Length + " / " + (estimatedFrames > 0 ? tostring(estimatedFrames) : "?"));
        UI::Unindent();
        UI::SeparatorText("Recording Controls");
        UI::Indent();
        // if (UI::Button("Pause")) {

        // }
        if (UI::Button("Stop Recording")) {
            stopRecordingFlag = true;
            recordingEnded = Time::Now;
            print("Recording stopped at " + recordingEnded);
        }
        UI::Unindent();
        UI::SeparatorText("Current Data...");
        DrawRecordingBrowseUI();
    }

    void DrawRecordingBrowseUI() {
        DrawFramesTimeline();
        DrawFrameCompareOpts();
        if (m_currFrame >= frames.Length) {
            UI::Text("No frame data available.");
            return;
        }
        auto memFrame = frames[m_currFrame];
        auto priorFrame = m_currFrame > 0 ? frames[m_currFrame - 1] : null;
        DrawFrameData(memFrame, priorFrame);
    }

    uint m_currFrame = 0;
    void DrawFramesTimeline() {
        int maxFrame = int(frames.Length) - 1;
        auto pos1 = UI::GetCursorPos();
        if (UI::Button(Icons::StepBackward)) {
            if (m_currFrame > 0) m_currFrame--;
        }
        UI::SameLine();
        auto pos2 = UI::GetCursorPos();
        auto btnWidth = pos2.x - pos1.x;
        auto framePadding = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
        UI::SetNextItemWidth(UI::GetWindowContentRegionWidth() - btnWidth * 2 - framePadding.x * 2);
        m_currFrame = UI::SliderInt("##f", m_currFrame, 0, maxFrame, "Frame: %d / " + maxFrame, UI::SliderFlags::AlwaysClamp);
        UI::SameLine();
        if (UI::Button(Icons::StepForward)) {
            if (int(m_currFrame) < maxFrame) m_currFrame++;
        }
    }

    bool m_BytesElseBits = true;
    bool m_CompareToPrior = true;
    float frameCmpOptsWidth = 0;
    void DrawFrameCompareOpts() {
        float skipX = frameCmpOptsWidth > 0. ? (UI::GetContentRegionAvail().x - frameCmpOptsWidth) * .5 : 0.;
        UI::Dummy(vec2(skipX, 0));
        UI::SameLine();
        //------
        auto startPos = UI::GetCursorPos();
        if (UI::RadioButton("Bytes", m_BytesElseBits)) {
            m_BytesElseBits = true;
        }
        UI::SameLine();
        if (UI::RadioButton("Bits", !m_BytesElseBits)) {
            m_BytesElseBits = false;
        }
        UI::SameLine();
        m_CompareToPrior = UI::Checkbox("Cmp n-1", m_CompareToPrior);
        //------
        auto endPos = UI::GetCursorPos();
        frameCmpOptsWidth = endPos.x - startPos.x;
    }

    void DrawFrameData(MemorySnapshot@ memFrame, MemorySnapshot@ priorFrame) {
        UI::SeparatorText("Frame " + m_currFrame);
        UI::Indent();
        UI::Text("Pointer: " + ptrStr); UI::SameLine();
        UI::Text("Size: " + size); UI::SameLine();
        UI::Text("Frame Size: " + memFrame.size);
        // UI::TextWrapped(memFrame.memHex);
        memFrame.DrawResearchView();

        UI::Unindent();


    }
}
