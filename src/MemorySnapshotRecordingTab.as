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
        int64 initFrameTs = 0;
        while (Time::Now <= recordingEnd && !stopRecordingFlag) {
            if (initFrameTs == 0) initFrameTs = Time::Now;
            frames.InsertLast(MemorySnapshot(ptr, size, initFrameTs, frames.Length));
            yield();
        }
        recordingEnded = Time::Now;
        print("Recording ended at " + recordingEnded);
    }

    void DrawInner() override {
        DrawSearchWindow();
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

    float avgFrameTime = 0.;
    int avgFrameTimeN = 0;

    void _AddAvgFrameTime() {
        avgFrameTime = (avgFrameTime * avgFrameTimeN + g_LastDT) / float(++avgFrameTimeN);
        avgFrameTimeN = Math::Min(avgFrameTimeN, 50);
        UI::Text("Avg Frame Time: " + Text::Format("%.3f", avgFrameTime));
    }

    void DrawRecordingActiveUI() {
        UI::SeparatorText("Recording...");
        UI::Indent();
        auto nbFrames = frames.Length;
        _AddAvgFrameTime();
        int estimatedFrames = int(recordingDuration) < 0 ? -1 : int(float(recordingDuration) / avgFrameTime);
        // UI::Text("Frames: " + );
        string lab = tostring(nbFrames) + " / " + (estimatedFrames > 0 ? tostring(estimatedFrames) : "?");
        UI::PushStyleColor(UI::Col::FrameBg, cDarkRed);
        UI::SetNextItemWidth(UI::GetWindowContentRegionWidth());
        UI::ProgressBar(estimatedFrames > 0 ? float(nbFrames) / estimatedFrames : 0., vec2(-1, 0), lab);
        UI::PopStyleColor();
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
        m_currFrame = nbFrames - 1;
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
        auto priorFrame = (m_CompareToPrior && m_currFrame > 0) ? frames[m_currFrame - 1] : null;
        DrawFrameData(memFrame, priorFrame);
    }

    uint m_currFrame = 0;
    void DrawFramesTimeline() {
        auto contentRegion = UI::GetContentRegionAvail();
        int maxFrame = int(frames.Length) - 1;
        auto pos1 = UI::GetCursorPos();
        if (UI::Button(Icons::StepBackward)) {
            if (m_currFrame > 0) m_currFrame--;
        }
        UI::SameLine();
        auto pos2 = UI::GetCursorPos();
        auto btnWidth = pos2.x - pos1.x;
        auto framePadding = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
        UI::SetNextItemWidth(contentRegion.x - btnWidth * 0 - framePadding.x * 1);
        m_currFrame = UI::SliderInt("##f", m_currFrame, 0, maxFrame, "Frame: %d / " + maxFrame, UI::SliderFlags::AlwaysClamp);
        UI::SameLine();
        if (UI::Button(Icons::StepForward)) {
            if (int(m_currFrame) < maxFrame) m_currFrame++;
        }
    }

    bool showSearchWindow = false;

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
        UI::SameLine();
        UI::Dummy(vec2(30, 0));
        UI::SameLine();
        if (UI::Button(showSearchWindow ? Icons::SearchMinus : Icons::SearchPlus)) {
            showSearchWindow = !showSearchWindow;
        }
        UI::SameLine();

        //------
        auto endPos = UI::GetCursorPos();
        frameCmpOptsWidth = endPos.x - startPos.x;
        UI::Dummy(vec2());
    }

    void DrawFrameData(MemorySnapshot@ memFrame, MemorySnapshot@ priorFrame) {
        UI::SeparatorText("Frame " + m_currFrame);
        UI::Indent();
        UI::Text("Pointer: " + ptrStr); UI::SameLine();
        // UI::Text("Size: " + size); UI::SameLine();
        UI::Text("Size: " + memFrame.size); UI::SameLine();
        CopiableLabeledValue("|t|", tostring(memFrame.ts)); UI::SameLine();
        CopiableLabeledValue("Δ t", tostring(memFrame.ts - frames[0].ts)); UI::SameLine();
        CopiableLabeledFormattedValue("Game t", Time::Format(memFrame.gt), tostring(memFrame.gt)); UI::SameLine();
        CopiableLabeledFormattedValue("Race t", Time::Format(memFrame.rt), tostring(memFrame.rt)); UI::SameLine();
        UI::Dummy(vec2());

        // UI::TextWrapped(memFrame.memHex);
        @memFrame.priorSnapshot = priorFrame;
        memFrame.DrawResearchView();

        UI::Unindent();
    }

    SearchTy searchTy = SearchTy::Bit;
    SearchConstraint@[] searchConstraints;

    void DrawSearchWindow() {
        if (showSearchWindow) {
            float scale = UI::GetScale();
            auto winPos = UI::GetWindowPos() / scale;
            auto currWinSize = UI::GetWindowSize() / scale;
            winPos.x += currWinSize.x + 16 * scale;
            UI::SetNextWindowSize(500, 800, UI::Cond::FirstUseEver);
            UI::SetNextWindowPos(int(winPos.x), int(winPos.y), UI::Cond::Appearing);
            // UI::SetNextWindowContentSize(600);
            if (UI::Begin("Search for Value##"+idNonce, showSearchWindow)) {
                UI::AlignTextToFramePadding();
                UI::Text("Search for:");
                UI::SameLine();
                UI::SetNextItemWidth(200);
                if (UI::BeginCombo("##SearchTy", tostring(searchTy))) {
                    for (int i = 0; i < SearchTy::XXX_LAST; i++) {
                        // if ((1 + 1) % 5 != 0) UI::SameLine();
                        // if (UI::RadioButton(tostring(SearchTy(i)), searchTy == SearchTy(i))) {
                        if (UI::Selectable(tostring(SearchTy(i)), searchTy == SearchTy(i))) {
                            searchTy = SearchTy(i);
                        }
                    }
                    UI::EndCombo();
                }

                UI::SameLine();
                if (UI::Button("Run Search")) {
                    RunSearch();
                }

                UI::AlignTextToFramePadding();
                UI::SeparatorText("Constraints: " + searchConstraints.Length);
                // UI::SameLine();
                if (searchConstraints.Length < 1) {
                    searchConstraints.InsertLast(SearchConstraint(this));
                }
                for (uint i = 0; i < searchConstraints.Length; i++) {
                    auto @sc = searchConstraints[i];
                    UI::PushID(tostring(i));
                    if (UI::Button(Icons::Trash)) {
                        searchConstraints.RemoveAt(i);
                        i--;
                    }
                    UI::SameLine();
                    UI::SeparatorText("Constraint " + i);
                    sc.Draw(searchTy);
                    UI::PopID();
                }
                searchWinPos = UI::GetWindowPos() / scale;
                searchWinSize = UI::GetWindowSize() / scale;
            }
            UI::End();
        }
        RenderResultsWindow();
    }

    vec2 searchWinPos;
    vec2 searchWinSize;
    SearchResults@ searchResults;
    bool showResultsWindow = false;

    void RunSearch() {
        @searchResults = SearchResults(searchTy, size);
        searchResults.ProcessFrames(frames, searchConstraints);
        showResultsWindow = true;
    }

    void RenderResultsWindow() {
        if (!showResultsWindow || searchResults is null) return;
        UI::SetNextWindowPos(Math::Min(int(searchWinPos.x + searchWinSize.x + 16), screen.x - 200.), int(searchWinPos.y), UI::Cond::Appearing);
        UI::SetNextWindowSize(300, 400, UI::Cond::FirstUseEver);
        if (UI::Begin("Search Results##"+idNonce, showResultsWindow)) {
            searchResults.Draw();
        }
        UI::End();
    }
}

enum SearchTy {
    Bit, UInt8, Int8, UInt16, Int16, UInt32, Int32, UInt64, Int64, Float, Double, XXX_LAST
}

enum MatchTy {
    Exact_Value, Range, Greater_Than, Less_Than, Greater_Equal, Less_Equal, Increased, Decreased, Changed, Unknown, Group_And, Group_Or, Group_Xor, XXX_LAST
}

enum TimeTy {
    Frame_Number, Abs_Time_ms, Rel_Time_ms, Game_Time_ms, Race_Time_ms, XXX_LAST
}

TimeTy InputCombo_TimeTy(const string &in label, TimeTy current) {
    if (UI::BeginCombo(label, tostring(current))) {
        for (int i = 0; i < TimeTy::XXX_LAST; i++) {
            if (UI::Selectable(tostring(TimeTy(i)), current == TimeTy(i))) {
                current = TimeTy(i);
            }
        }
        UI::EndCombo();
    }
    return current;
}

MatchTy InputCombo_MatchTy(const string &in label, MatchTy current) {
    if (UI::BeginCombo(label, tostring(current).Replace("_", " "))) {
        for (int i = 0; i < MatchTy::XXX_LAST; i++) {
            if (UI::Selectable(tostring(MatchTy(i)), current == MatchTy(i))) {
                current = MatchTy(i);
            }
        }
        UI::EndCombo();
    }
    return current;
}

// ExhaustThisConstraint = keep checking frame till it's false
enum MatchFlags {
    Fail = 1, Hit = 2, ExhaustThisConstraint = 4, UseLastFromSelf = 8
}

// Miss = didn't match but don't eliminate this matchIx yet
enum MatchResult {
    Fail = MatchFlags::Fail,
    Hit = MatchFlags::Hit,
    Miss = MatchFlags::Fail | MatchFlags::ExhaustThisConstraint,
    HitRangeAll = MatchFlags::Hit | MatchFlags::ExhaustThisConstraint,
    UseLastFromSelf = MatchFlags::UseLastFromSelf,
}

enum Cmp {
    Lt = -1,
    Eq = 0,
    Gt = 1,
}

Cmp CmpI64(int64 a, int64 b) {
    if (a < b) return Cmp::Lt;
    if (a > b) return Cmp::Gt;
    return Cmp::Eq;
}

class SearchConstraint {
    bool m_hasTime = false;
    uint m_start = 0;
    uint m_end = 0;
    bool m_range = false;
    bool m_rangeAllElseAny = true;
    bool m_required = true;
    MemorySnapshotRecordingTab@ parent;

    string id;

    string m_value;

    SearchTy ty;
    TimeTy timeTy;
    MatchTy matchTy = MatchTy::Exact_Value;

    bool valueValid = false;
    string valueValidationErr;

    uint8 valueBit;
    uint8 valueU8;
    int8 valueI8;
    uint16 valueU16;
    int16 valueI16;
    uint32 valueU32;
    int32 valueI32;
    uint64 valueU64;
    int64 valueI64;
    float valueF32;
    double valueF64;

    SearchConstraint(MemorySnapshotRecordingTab@ parent) {
        id = tostring(Math::Rand(0, TWO_10_8));
        @this.parent = parent;
    }

    // Builder: set type and time type to match prior
    SearchConstraint@ WithLikePrior(SearchConstraint@ prior) {
        ty = prior.ty;
        timeTy = prior.timeTy;
        return this;
    }

    SearchConstraint@ Clone(SearchConstraint@ prior) {
        m_hasTime = prior.m_hasTime;
        m_start = prior.m_start;
        m_end = prior.m_end;
        m_range = prior.m_range;
        m_rangeAllElseAny = prior.m_rangeAllElseAny;
        m_required = prior.m_required;
        timeTy = prior.timeTy;
        ty = prior.ty;
        m_value = prior.m_value;
        UpdateValueValidation(m_value);
        return this;
    }

    MatchResult Match(MemorySnapshot@ memFrame, MemorySnapshot@ priorFrame, uint matchIx) {
        if (!valueValid) return MatchResult::Fail;
        // if too early, skip this frame
        if (IsFrameTooEarly(memFrame)) return MatchResult::Miss;
        // if after range, resolve this frame with the prior value (defaults to fail)
        if (IsFrameAfterRange(memFrame)) return MatchResult::UseLastFromSelf;
        // we should be one of: in range, exact match, or any time
        if (!InRangeOrMatchOrAny(memFrame)) {
            // if we're a range, just miss provided we'll match any single frame in the range
            if (m_range && !m_rangeAllElseAny) return MatchResult::Miss;
            return MatchResult::Fail;
        }
        auto res = MatchData(memFrame, priorFrame, matchIx);
        if (IsRange_And_FrameInRange(memFrame)) {
            // if we're in an all range, anything not a hit is a fail
            if (m_rangeAllElseAny && res & MatchResult::Hit == 0) {
                return MatchResult::Fail;
            }
            res = MatchResult(res | MatchFlags::ExhaustThisConstraint);
        } else if (!m_hasTime) {
            // if we don't have a time, we want to match any frame after the prior and before the next
            res = MatchResult(res | MatchFlags::ExhaustThisConstraint);
        }
        return res;
    }

    MatchResult MatchData(MemorySnapshot@ memFrame, MemorySnapshot@ priorFrame, uint matchIx) {
        switch (ty) {
            case SearchTy::Bit: return MatchBit(memFrame, priorFrame, matchIx);
        }
        return MatchResult::Miss;
    }

    bool IsRange_And_FrameInRange(MemorySnapshot@ memFrame) {
        auto frameTsTyd = uint(GetFrameTimeTyped(memFrame));
        return m_hasTime && m_range && m_start <= frameTsTyd && frameTsTyd <= m_end;
    }

    bool InRangeOrMatchOrAny(MemorySnapshot@ memFrame) {
        // if we don't have a time, then we match any time
        if (!m_hasTime) return true;
        auto frameTsTyd = uint(GetFrameTimeTyped(memFrame));
        // if we aren't in a range, we want an exact match
        if (!m_range) return frameTsTyd == m_start;
        // if we are in a range, we want to be in the range
        return m_start <= frameTsTyd && frameTsTyd <= m_end;
    }

    Cmp CmpFrameWTimeTy(MemorySnapshot@ memFrame, int64 ts) {
        return CmpI64(GetFrameTimeTyped(memFrame), ts);
    }

    int64 GetFrameTimeTyped(MemorySnapshot@ memFrame) {
        switch (timeTy) {
            case TimeTy::Frame_Number: return memFrame.frameIx;
            case TimeTy::Abs_Time_ms: return memFrame.ts;
            case TimeTy::Rel_Time_ms: return memFrame.dts;
            case TimeTy::Game_Time_ms: return memFrame.gt;
            case TimeTy::Race_Time_ms: return memFrame.rt;
        }
        throw("Unsupported timeTy: " + tostring(timeTy));
        return 0;
    }

    bool IsFrameTooEarly(MemorySnapshot@ memFrame) {
        if (!m_hasTime) return false;
        return CmpFrameWTimeTy(memFrame, m_start) == Cmp::Lt;
    }

    bool IsFrameAfterRange(MemorySnapshot@ memFrame) {
        if (!m_hasTime) return false;
        if (!m_range) return false;
        return CmpFrameWTimeTy(memFrame, m_end) == Cmp::Gt;
    }

    MatchResult MatchBit(MemorySnapshot@ memFrame, MemorySnapshot@ priorFrame, uint matchIx) {
        switch (matchTy) {
            case MatchTy::Exact_Value: return memFrame.GetIndexedBit(matchIx) == valueBit ? MatchResult::Hit : MatchResult::Fail;
        }
        NotifyError("Unsupported matchTy: " + tostring(matchTy));
        throw("Unsupported matchTy: " + tostring(matchTy));
        return MatchResult::Fail;
    }

    void Draw(SearchTy ty) {
        this.ty = ty;
        UI::PushID(id);
        UI::PushItemWidth(100);

        m_required = UI::Checkbox("##required", m_required);
        AddSimpleTooltip("Required?");
        UI::SameLine();

        m_hasTime = UI::Checkbox("##hastime", m_hasTime);
        AddSimpleTooltip("Specify time/frames?\nWhen false, any frame after the prior and before the next will be matched.");
        UI::SameLine();

        if (!m_hasTime) {
            UI::AlignTextToFramePadding();
            UI::Text("\\$bbb\\$iMatches at any time");
        } else {
            UI::Text("From:");
            UI::SameLine();
            m_start = UI::InputInt("##Start", m_start);
            AddSimpleTooltip("Start time/frame");
            UI::SameLine();
            m_range = UI::Checkbox("##r"+id, m_range);
            AddSimpleTooltip("Is Range?");
            if (m_range) {
                UI::SameLine();
                m_end = UI::InputInt("##End", m_end);
                AddSimpleTooltip("End time/frame");
                UI::SameLine();
                m_rangeAllElseAny = UI::Checkbox("##rAllElseAny", m_rangeAllElseAny);
                AddSimpleTooltip("Match all frames? Otherwise, match any frame");
            }
            UI::SameLine();
            UI::Text("|");
            UI::SameLine();
            timeTy = InputCombo_TimeTy("##TimeTy", timeTy);
        }

        //-----

        UI::AlignTextToFramePadding();
        UI::Text("Match:");
        UI::SameLine();

        matchTy = InputCombo_MatchTy("##MatchTy", matchTy);

        DrawMatchValuesForm();

        if (UI::Button(Icons::Plus + " Add After")) {
            auto sc = SearchConstraint(parent).WithLikePrior(this);
            parent.searchConstraints.InsertAt(parent.searchConstraints.FindByRef(this) + 1, sc);
        }
        UI::SameLine();
        if (UI::Button(Icons::FilesO + " Clone")) {
            auto sc = SearchConstraint(parent).Clone(this);
            parent.searchConstraints.InsertAt(parent.searchConstraints.FindByRef(this) + 1, sc);
        }

        UI::PopItemWidth();
        UI::PopID();
    }

    void DrawMatchValuesForm() {
        UI::AlignTextToFramePadding();
        if (matchTy == MatchTy::Exact_Value) DrawMatchForm_ExactValue();
        else {
            UI::Text("Unsupported: " + tostring(matchTy));
        }
    }

    void DrawMatchForm_ExactValue() {
        UI::Text("Value:");
        UI::SameLine();

        bool changed;
        m_value = UI::InputText("##Value", m_value, changed);
        UpdateValueValidation(m_value);
        UI::SameLine();
        if (!valueValid) {
            UI::Text("\\$fd3 " + Icons::ExclamationTriangle + "  " + valueValidationErr);
        } else {
            UI::Text("\\$6f8 " + Icons::Check + "  " + GetValueAsString());
        }
    }

    bool UpdateValueValidation(const string &in v) {
        valueValid = false;
        valueValidationErr = "--no error--";
        if (m_value.Length == 0) {
            valueValidationErr = "No Value";
            return valueValid = false;
        }
        switch (ty) {
            case SearchTy::Bit: return ValidateBit(v, valueBit);
            case SearchTy::UInt8: return ValidateUInt8(v, valueU8);
            case SearchTy::Int8: return ValidateInt8(v, valueI8);
            case SearchTy::UInt16: return ValidateUInt16(v, valueU16);
            case SearchTy::Int16: return ValidateInt16(v, valueI16);
            case SearchTy::UInt32: return ValidateUInt32(v, valueU32);
            case SearchTy::Int32: return ValidateInt32(v, valueI32);
            case SearchTy::UInt64: return ValidateUInt64(v, valueU64);
            case SearchTy::Int64: return ValidateInt64(v, valueI64);
            case SearchTy::Float: return ValidateFloat(v, valueF32);
            case SearchTy::Double: return ValidateDouble(v, valueF64);
        }
        valueValidationErr = "Unknown Type: " + tostring(ty);
        return valueValid = false;
    }

    string GetValueAsString() {
        if (!valueValid) return "Invalid";
        switch (ty) {
            case SearchTy::Bit: return valueBit == 0 ? "0" : "1";
            case SearchTy::UInt8: return tostring(valueU8);
            case SearchTy::Int8: return tostring(valueI8);
            case SearchTy::UInt16: return tostring(valueU16);
            case SearchTy::Int16: return tostring(valueI16);
            case SearchTy::UInt32: return tostring(valueU32);
            case SearchTy::Int32: return tostring(valueI32);
            case SearchTy::UInt64: return tostring(valueU64);
            case SearchTy::Int64: return tostring(valueI64);
            case SearchTy::Float: return Text::Format("%.3f", valueF32);
            case SearchTy::Double: return Text::Format("%.3f", valueF64);
        }
        return "Unknown ("+tostring(ty)+")";
    }

    int tmpRadix;
    uint tmpU32;
    int tmpI32;

    bool ValidateBit(const string &in _value, uint8 &out vOut) {
        if (_value.Length == 1) {
            if (_value == '0' || _value == 'f' || _value == 'n' || _value == 'F' || _value == 'N') {
                vOut = 0;
                return valueValid = true;
            }
            if (_value == '1' || _value == 't' || _value == 'y' || _value == 'T' || _value == 'Y') {
                vOut = 1;
                return valueValid = true;
            }
        }
        valueValidationErr = "Valid values: 0/1, f/t, n/y";
        return valueValid = false;
    }

    bool ValidateUInt8(const string &in _value, uint8 &out vOut) {
        auto value = PrepValueInBase(_value, tmpRadix);
        if (Text::TryParseUInt(value, tmpU32, tmpRadix)) {
            if (tmpU32 <= 0xFF) {
                vOut = uint8(tmpU32);
                return valueValid = true;
            }
            valueValidationErr = "Value too large";
            return valueValid = false;
        }
        valueValidationErr = "Invalid UInt8";
        return valueValid = false;
    }

    bool ValidateInt8(const string &in _value, int8 &out vOut) {
        auto value = PrepValueInBase(_value, tmpRadix);
        if (Text::TryParseInt(value, tmpI32, tmpRadix)) {
            if (tmpI32 >= -128 && tmpI32 <= 127) {
                vOut = int8(tmpI32);
                return valueValid = true;
            }
            valueValidationErr = "Value out of range";
            return valueValid = false;
        }
        valueValidationErr = "Invalid Int8";
        return valueValid = false;
    }

    bool ValidateUInt16(const string &in _value, uint16 &out vOut) {
        auto value = PrepValueInBase(_value, tmpRadix);
        if (Text::TryParseUInt(value, tmpU32, tmpRadix)) {
            if (tmpU32 <= 0xFFFF) {
                vOut = uint16(tmpU32);
                return valueValid = true;
            }
            valueValidationErr = "Value too large";
            return valueValid = false;
        }
        valueValidationErr = "Invalid UInt16";
        return valueValid = false;
    }

    bool ValidateInt16(const string &in _value, uint8 &out vOut) {
        auto value = PrepValueInBase(_value, tmpRadix);
        if (Text::TryParseInt(value, tmpI32, tmpRadix)) {
            if (tmpI32 >= -32768 && tmpI32 <= 32767) {
                valueI16 = int16(tmpI32);
                return valueValid = true;
            }
            valueValidationErr = "Value out of range";
            return valueValid = false;
        }
        valueValidationErr = "Invalid Int16";
        return valueValid = false;
    }

    bool ValidateUInt32(const string &in _value, uint8 &out vOut) {
        auto value = PrepValueInBase(_value, tmpRadix);
        if (Text::TryParseUInt(value, valueU32, tmpRadix)) {
            return valueValid = true;
        }
        valueValidationErr = "Invalid UInt32";
        return valueValid = false;
    }

    bool ValidateInt32(const string &in _value, uint8 &out vOut) {
        auto value = PrepValueInBase(_value, tmpRadix);
        if (Text::TryParseInt(value, valueI32, tmpRadix)) {
            return valueValid = true;
        }
        valueValidationErr = "Invalid Int32";
        return valueValid = false;
    }

    bool ValidateUInt64(const string &in _value, uint8 &out vOut) {
        auto value = PrepValueInBase(_value, tmpRadix);
        if (Text::TryParseUInt64(value, valueU64, tmpRadix)) {
            return valueValid = true;
        }
        valueValidationErr = "Invalid UInt64";
        return valueValid = false;
    }

    bool ValidateInt64(const string &in _value, uint8 &out vOut) {
        auto value = PrepValueInBase(_value, tmpRadix);
        if (Text::TryParseInt64(value, valueI64, tmpRadix)) {
            return valueValid = true;
        }
        valueValidationErr = "Invalid Int64";
        return valueValid = false;
    }

    bool ValidateFloat(const string &in _value, uint8 &out vOut) {
        if (Text::TryParseFloat(_value, valueF32)) {
            return valueValid = true;
        }
        valueValidationErr = "Invalid Float";
        return valueValid = false;
    }

    bool ValidateDouble(const string &in _value, uint8 &out vOut) {
        // if (Text::TryParseDouble(_value, valueF64)) {
        //     return valueValid = true;
        // }
        valueValidationErr = "Double not supported due to openplanet bug";
        return valueValid = false;
    }
}

const uint8 CHAR_x = "x"[0];
const uint8 CHAR_0 = "0"[0];
const uint8 CHAR_b = "b"[0];
const uint8 CHAR_o = "o"[0];

string PrepValueInBase(const string &in val, int &out radix) {
    radix = 10;
    if (val.Length > 2 && val[0] == 0x30) {
        if (val[1] == CHAR_x) {
            radix = 16;
            return val.SubStr(2);
        }
        if (val[1] == CHAR_b) {
            radix = 2;
            return val.SubStr(2);
        }
        if (val[1] == CHAR_o) {
            radix = 8;
            return val.SubStr(2);
        }
    }
    return val;
}
