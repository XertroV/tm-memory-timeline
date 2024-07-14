const uint64 U64_MAX = uint64(-1);
const uint32 U32_MAX = uint32(-1);

class SearchResults {
    SearchTy ty;
    // bytes
    uint size;
    uint matchSpaceSize;
    uint matchBitsLength;
    uint matchBytesLength;
    // bit position => match index
    uint64[] matchSpace;
    uint lastUpdatedTime = 0;
    uint nbMatches = 0;

    SearchResults(SearchTy ty, uint size) {
        this.ty = ty;
        this.size = size;
        this.matchSpaceSize = size;
        _SetupMatchSpace();
    }

    // return value doesn't matter
    protected bool _SetupMatchSpace() {
        switch (ty) {
            case SearchTy::Bit: return _SetupMatchSpaceFromTyBitsLen(1);
            case SearchTy::UInt8: return _SetupMatchSpaceFromTyBitsLen(8);
            case SearchTy::UInt16: return _SetupMatchSpaceFromTyBitsLen(16);
            case SearchTy::UInt32: return _SetupMatchSpaceFromTyBitsLen(32);
            case SearchTy::UInt64: return _SetupMatchSpaceFromTyBitsLen(64);
            case SearchTy::Int8: return _SetupMatchSpaceFromTyBitsLen(8);
            case SearchTy::Int16: return _SetupMatchSpaceFromTyBitsLen(16);
            case SearchTy::Int32: return _SetupMatchSpaceFromTyBitsLen(32);
            case SearchTy::Int64: return _SetupMatchSpaceFromTyBitsLen(64);
            case SearchTy::Float: return _SetupMatchSpaceFromTyBitsLen(32);
            case SearchTy::Double: return _SetupMatchSpaceFromTyBitsLen(64);
        }
        throw("unhandled SearchTy: " + tostring(ty));
        return false;
    }

    // return value doesn't matter
    protected bool _SetupMatchSpaceFromTyBitsLen(uint bitsLen) {
        matchBitsLength = bitsLen;
        matchSpaceSize = size * 8 / bitsLen;
        matchBytesLength = size / 8;
        matchSpace.Resize(matchSpaceSize / 64 + 1);
        for (uint i = 0; i < matchSpaceSize / 64; i++) {
            matchSpace[i] = U64_MAX;
        }
        for (uint i = matchSpaceSize / 64; i < matchSpaceSize; i++) {
            SetMatchIndex(i, true);
        }
        return true;
    }

    int NextMatchIndex(uint ix) {
        // `& 0x3f` == `% 64`; `>> 6` == `/ 64`
        uint bitOff = ix & 0x3f;
        uint mssIx = ix >> 6;
        if (ix == U32_MAX) {
            mssIx = 0;
            bitOff = 0;
        }
        if (mssIx >= matchSpaceSize) return -1;
        uint64 window = matchSpace[mssIx];
        for (uint i = ix + 1; i < matchSpaceSize; i++) {
            if ((bitOff = i & 0x3f) == 0) {
                mssIx = i >> 6;
                window = matchSpace[mssIx];
            }
            if ((window & (uint64(1) << bitOff)) != 0) return i;
            // if (GetMatchIndex(i)) return i;
        }
        return -1;
    }

    bool GetMatchIndex(uint ix) {
        return (matchSpace[ix / 64] & (uint64(1) << (ix % 64))) != 0;
    }

    void SetMatchIndex(uint ix, bool value) {
        if (value) {
            matchSpace[ix / 64] |= (uint64(1) << (ix % 64));
        } else {
            matchSpace[ix / 64] &= ~(uint64(1) << (ix % 64));
        }
    }


    void ProcessFrames(MemorySnapshot@[] &in frames, SearchConstraint@[] &in constraints) {
        auto nbFrames = frames.Length;
        nbMatches = matchSpaceSize;
        auto updateStart = Time::Now;
        uint matchIx;
        // no loop condition, we'll do that with NextMatchIndex
        for (matchIx = NextMatchIndex(U32_MAX); matchIx < matchSpaceSize; ) {
            // trace('in-loop matchIx: ' + matchIx);
            // for each possible match, we loop through and see if we can eliminate it.
            uint frameIx = 0;
            MemorySnapshot@ frame;
            MemorySnapshot@ prior;
            SearchConstraint@ sc;
            MatchResult matched = MatchResult::Miss;
            MatchResult lastMR = MatchResult::Miss;
            for (uint i = 0; i < constraints.Length; i++) {
                @sc = constraints[i];
                lastMR = MatchResult::Fail;
                if (!sc.m_required) continue;
                while (frameIx < nbFrames) {
                    @frame = frames[frameIx];
                    @prior = frameIx > 0 ? frames[frameIx-1] : null;
                    matched = sc.Match(frame, prior, matchIx);
                    if (matched == MatchResult::UseLastFromSelf) {
                        // we don't want to advance a frame in this case
                        matched = MatchResult(lastMR & ~MatchFlags::ExhaustThisConstraint);
                        break;
                    }
                    frameIx++;
                    if (matched & MatchFlags::ExhaustThisConstraint == 0) break;
                    lastMR = matched;
                }
                // if we didn't find a match, we can elim this matchIx
                if (matched & MatchFlags::Hit == 0) {
                    SetMatchIndex(matchIx, false);
                    nbMatches--;
                    break;
                }
            }
            matchIx = NextMatchIndex(matchIx);
            // we get this if there are no more matches
            if (matchIx < 0) break;
        }
        // trace('after loop matchIx: ' + matchIx);
        // trace('after loop matchIx+1: ' + (matchIx + 1));
        lastUpdatedTime = Time::Now;
        trace('[SearchRes] nbMatches: ' + nbMatches + ' (took: '+(lastUpdatedTime - updateStart)+' ms)');
        UpdateCountMatches();
        trace('[SearchRes] nbMatches: ' + nbMatches + ' w/ indexes: ' + Json::Write(matchGoodIndexes.ToJson()));
    }

    uint[] matchGoodIndexes;
    string matchGoodIxsJsonStr;

    void UpdateCountMatches() {
        nbMatches = 0;
        matchGoodIndexes.Resize(0);
        uint matchIx = -1;
        while ((matchIx = NextMatchIndex(matchIx)) < matchSpaceSize) {
            matchGoodIndexes.InsertLast(matchIx);
            nbMatches++;
        }
        matchGoodIxsJsonStr = Json::Write(matchGoodIndexes.ToJson());
    }

    string LastUpdatedStr() {
        if (lastUpdatedTime == 0) return "Never";
        return Time::Format(Time::Now - lastUpdatedTime) + " ago";
    }

    void Draw() {
        UI::Text("Search Results");
        UI::Text("Last Updated: " + LastUpdatedStr());
        UI::Text("Matches: " + nbMatches);
        UI::Indent();
        UI::TextWrapped(matchGoodIxsJsonStr);
        UI::Unindent();
    }
}
