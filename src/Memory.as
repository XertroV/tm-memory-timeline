class MemorySnapshot {
    uint64 ptr;
    uint32 size;
    MemoryBuffer@ buf;
    string memHex;
    uint64 ts;
    int64 dts;
    int64 gt;
    int64 rt;
    uint frameIx;

    MemorySnapshot(uint64 ptr, uint32 size, int64 initFrameTs, uint frameIx) {
        this.ptr = ptr;
        this.size = size;
        @buf = MemoryBuffer(size);
        ts = Time::Now;
        dts = initFrameTs > 0 ? ts - initFrameTs : 0;
        gt = GetGameTime();
        rt = GetRaceTime();
        this.frameIx = frameIx;
        SaveMemToBuffer();
        memHex = Dev::Read(ptr, size);
    }

    protected void SaveMemToBuffer() {
        buf.Seek(0);
        uint toReadLeft = size;
        uint64 nextPtr = ptr;
        while (toReadLeft > 0) {
            if (toReadLeft >= 8) {
                buf.Write(Dev::ReadUInt64(nextPtr));
                nextPtr += 8;
                toReadLeft -= 8;
            } else {
                buf.Write(Dev::ReadUInt8(nextPtr));
                nextPtr += 1;
                toReadLeft -= 1;
            }
        }
        buf.Seek(0);
    }


    void DrawResearchView() {
        UI::PushFont(g_MonoFont);
        g_RV_RenderAs = DrawComboRV_ValueRenderTypes("Render Values##"+ptr, g_RV_RenderAs);

        if (UI::BeginChild("##"+ptr, vec2(0, 0), true)) {
            auto nbSegments = size / RV_SEGMENT_SIZE;
            for (uint i = 0; i < nbSegments; i++) {
                DrawSegment(i);
            }
            auto remainder = size - (nbSegments * RV_SEGMENT_SIZE);
            if (remainder >= RV_SEGMENT_SIZE) throw("Error caclulating remainder size");
            DrawSegment(nbSegments, remainder);
        }
        UI::EndChild();

        UI::PopFont();
    }

    void DrawSegment(uint n, int limit = -1) {
        if (limit == 0) return;
        limit = limit < 0 ? RV_SEGMENT_SIZE : limit;
        auto segOffset = RV_SEGMENT_SIZE * n;
        auto pastPtr = ptr + segOffset;
        UI::AlignTextToFramePadding();
        UI::Text("\\$888" + Text::Format("0x%03x  ", segOffset));
        if (UI::IsItemClicked()) {
            SetClipboard(Text::FormatPointer(pastPtr));
        }
        UI::SameLine();
        string mem;
        for (int o = 0; o < RV_SEGMENT_SIZE; o += 4) {
            mem = o >= limit ? "__ __ __ __" : Read(segOffset + o, Math::Min(limit, 4));
            DrawMemDiffWithPrev(mem, segOffset + o, limit);
            UI::SameLine();
            if (o % 8 != 0) {
                UI::Dummy(vec2(10, 0));
            }
            UI::SameLine();
        }
        DrawRawValues(segOffset, limit);
        UI::Dummy(vec2());
    }

    MemorySnapshot@ priorSnapshot;

    void DrawMemDiffWithPrev(const string &in mem, uint64 offset, int limit) {
        if (priorSnapshot is null) {
            UI::Text(mem);
            return;
        }
        auto priorMem = priorSnapshot.Read(offset, limit);
        if (mem == priorMem) {
            UI::Text(mem);
            return;
        }
        string diff;
        uint8 byte;
        bool lastWasDiff = false;
        for (int i = 0; i < mem.Length; i++) {
            byte = mem[i];
            if (byte == 0x20) diff += " ";
            else if (i >= priorMem.Length) {
                if (lastWasDiff || i == 0) {
                    diff += "\\$0f0";
                    lastWasDiff = false;
                }
                diff += Text::Format("%c", byte);
            } else if (byte == priorMem[i]) {
                if (lastWasDiff || i == 0) {
                    diff += "\\$bbb";
                    lastWasDiff = false;
                }
                diff += Text::Format("%c", byte);
            } else {
                if (!lastWasDiff || i == 0) {
                    diff += "\\$ff0";
                    lastWasDiff = true;
                }
                diff += Text::Format("%c", byte);
            }
        }
        UI::Text(diff);
    }

    string Read(uint16 offset, uint count) {
        if (count < 1) return "";
        return this.memHex.SubStr(offset * 3, count * 3 - 1);
    }

    void DrawRawValues(uint64 offset, int bytesToRead) {
        switch (g_RV_RenderAs) {
            case RV_ValueRenderTypes::Float: DrawRawValuesFloat(offset, bytesToRead); return;
            case RV_ValueRenderTypes::UInt32: DrawRawValuesUInt32(offset, bytesToRead); return;
            case RV_ValueRenderTypes::UInt32D: DrawRawValuesUInt32D(offset, bytesToRead); return;
            case RV_ValueRenderTypes::UInt64: DrawRawValuesUInt64(offset, bytesToRead); return;
            case RV_ValueRenderTypes::UInt16: DrawRawValuesUInt16(offset, bytesToRead); return;
            case RV_ValueRenderTypes::UInt16D: DrawRawValuesUInt16D(offset, bytesToRead); return;
            case RV_ValueRenderTypes::UInt8: DrawRawValuesUInt8(offset, bytesToRead); return;
            case RV_ValueRenderTypes::UInt8D: DrawRawValuesUInt8D(offset, bytesToRead); return;
            // case RV_ValueRenderTypes::Int32: DrawRawValuesInt32(offset, bytesToRead); return;
            case RV_ValueRenderTypes::Int32D: DrawRawValuesInt32D(offset, bytesToRead); return;
            // case RV_ValueRenderTypes::Int16: DrawRawValuesInt16(offset, bytesToRead); return;
            case RV_ValueRenderTypes::Int16D: DrawRawValuesInt16D(offset, bytesToRead); return;
            // case RV_ValueRenderTypes::Int8: DrawRawValuesInt8(offset, bytesToRead); return;
            case RV_ValueRenderTypes::Int8D: DrawRawValuesInt8D(offset, bytesToRead); return;
            default: {}
        }
        UI::Text("no impl: " + tostring(g_RV_RenderAs));
    }

    void DrawRawValuesFloat(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueFloat(offset + i);
        }
    }
    void DrawRawValuesUInt32(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueUInt32(offset + i);
        }
    }
    void DrawRawValuesUInt32D(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueUInt32D(offset + i);
        }
    }
    void DrawRawValuesUInt64(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 8) {
            _DrawRawValueUInt64(offset + i);
        }
    }
    void DrawRawValuesUInt16(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueUInt16(offset + i);
        }
    }
    void DrawRawValuesUInt16D(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueUInt16D(offset + i);
        }
    }
    void DrawRawValuesUInt8(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueUInt8(offset + i);
        }
    }
    void DrawRawValuesUInt8D(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueUInt8D(offset + i);
        }
    }
    void DrawRawValuesInt32(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueInt32(offset + i);
        }
    }
    void DrawRawValuesInt32D(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueInt32D(offset + i);
        }
    }
    void DrawRawValuesInt16(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueInt16(offset + i);
        }
    }
    void DrawRawValuesInt16D(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueInt16D(offset + i);
        }
    }
    void DrawRawValuesInt8(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueInt8(offset + i);
        }
    }
    void DrawRawValuesInt8D(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueInt8D(offset + i);
        }
    }

    bool RV_CopiableValue(uint offset, const string &in value) {
        auto ret = CopiableValue(value);
        if (UI::IsItemHovered()) {
            if (UI::IsMouseClicked(UI::MouseButton::Middle)) {
                g_RV_RenderAs = RV_ValueRenderTypes((int(g_RV_RenderAs) - 1) % RV_ValueRenderTypes::LAST);
            }
            if (UI::IsMouseClicked(UI::MouseButton::Right)) {
                g_RV_RenderAs = RV_ValueRenderTypes((int(g_RV_RenderAs) + 1) % RV_ValueRenderTypes::LAST);
            }
            // auto scrollDelta = Math::Clamp(g_ScrollThisFrame.x, -1, 1);
            // g_RV_RenderAs = RV_ValueRenderTypes(Math::Clamp(int(g_RV_RenderAs) + scrollDelta, 0, RV_ValueRenderTypes::LAST - 1));
        }
        UI::SameLine();
        return ret;
    }

    void _DrawRawValueFloat(uint offset) {
        RV_CopiableValue(offset, tostring(GetFloat(offset)));
    }
    float GetFloat(uint offset) {
        buf.Seek(offset);
        return buf.ReadFloat();
    }
    void _DrawRawValueDouble(uint offset) {
        RV_CopiableValue(offset, tostring(GetDouble(offset)));
    }
    float GetDouble(uint offset) {
        buf.Seek(offset);
        return buf.ReadDouble();
    }
    void _DrawRawValueUInt32(uint offset) {
        RV_CopiableValue(offset, Text::Format("0x%x", GetUInt32(offset)));
    }
    uint32 GetUInt32(uint offset) {
        buf.Seek(offset);
        return buf.ReadUInt32();
    }
    void _DrawRawValueUInt32D(uint offset) {
        RV_CopiableValue(offset, tostring(GetUInt32(offset)));
    }
    void _DrawRawValueUInt64(uint offset) {
        RV_CopiableValue(offset, Text::FormatPointer(GetUInt64(offset)));
    }
    uint64 GetUInt64(uint offset) {
        buf.Seek(offset);
        return buf.ReadUInt64();
    }
    void _DrawRawValueUInt16(uint offset) {
        RV_CopiableValue(offset, Text::Format("0x%x", GetUInt16(offset)));
    }
    uint16 GetUInt16(uint offset) {
        buf.Seek(offset);
        return buf.ReadUInt16();
    }
    void _DrawRawValueUInt16D(uint offset) {
        RV_CopiableValue(offset, tostring(GetUInt16(offset)));
    }
    void _DrawRawValueUInt8(uint offset) {
        RV_CopiableValue(offset, Text::Format("0x%x", GetUInt8(offset)));
    }
    uint8 GetUInt8(uint offset) {
        buf.Seek(offset);
        return buf.ReadUInt8();
    }
    void _DrawRawValueUInt8D(uint offset) {
        RV_CopiableValue(offset, tostring(GetUInt8(offset)));
    }
    void _DrawRawValueInt32(uint offset) {
        RV_CopiableValue(offset, Text::Format("0x%x", GetInt32(offset)));
    }
    int32 GetInt32(uint offset) {
        buf.Seek(offset);
        return buf.ReadInt32();
    }
    void _DrawRawValueInt32D(uint offset) {
        RV_CopiableValue(offset, tostring(GetInt32(offset)));
    }
    void _DrawRawValueInt16(uint offset) {
        RV_CopiableValue(offset, Text::Format("0x%x", GetInt16(offset)));
    }
    int16 GetInt16(uint offset) {
        buf.Seek(offset);
        return buf.ReadInt16();
    }
    void _DrawRawValueInt16D(uint offset) {
        RV_CopiableValue(offset, tostring(GetInt16(offset)));
    }
    void _DrawRawValueInt8(uint offset) {
        RV_CopiableValue(offset, Text::Format("0x%x", GetInt8(offset)));
    }
    int8 GetInt8(uint offset) {
        buf.Seek(offset);
        return buf.ReadInt8();
    }
    void _DrawRawValueInt8D(uint offset) {
        RV_CopiableValue(offset, tostring(GetInt8(offset)));
    }

    uint8 GetIndexedBit(uint ix) {
        return GetUInt8(ix / 8) & (1 << (ix % 8));
    }
    uint8 GetIndexedUInt8(uint ix) {
        return GetUInt8(ix);
    }
    uint16 GetIndexedUInt16(uint ix) {
        return GetUInt16(ix * 2);
    }
    uint32 GetIndexedUInt32(uint ix) {
        return GetUInt32(ix * 4);
    }
    uint64 GetIndexedUInt64(uint ix) {
        return GetUInt64(ix * 8);
    }
    int8 GetIndexedInt8(uint ix) {
        return GetInt8(ix);
    }
    int16 GetIndexedInt16(uint ix) {
        return GetInt16(ix * 2);
    }
    int32 GetIndexedInt32(uint ix) {
        return GetInt32(ix * 4);
    }
    float GetIndexedFloat(uint ix) {
        return GetFloat(ix * 4);
    }
    double GetIndexedDouble(uint ix) {
        return GetDouble(ix * 8);
    }
}
