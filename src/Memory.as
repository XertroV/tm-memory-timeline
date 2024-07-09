class MemorySnapshot {
    uint64 ptr;
    uint32 size;
    MemoryBuffer@ buf;
    string memHex;
    uint64 ts;

    MemorySnapshot(uint64 ptr, uint32 size) {
        this.ptr = ptr;
        this.size = size;
        @buf = MemoryBuffer(size);
        ts = Time::Now;
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

        auto nbSegments = size / RV_SEGMENT_SIZE;
        for (uint i = 0; i < nbSegments; i++) {
            DrawSegment(i);
        }
        auto remainder = size - (nbSegments * RV_SEGMENT_SIZE);
        if (remainder >= RV_SEGMENT_SIZE) throw("Error caclulating remainder size");
        DrawSegment(nbSegments, remainder);

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
            UI::Text(mem);
            UI::SameLine();
            if (o % 8 != 0) {
                UI::Dummy(vec2(10, 0));
            }
            UI::SameLine();
        }
        DrawRawValues(segOffset, limit);
        UI::Dummy(vec2());
    }

    string Read(uint16 offset, uint count) {
        if (count < 1) return "";
        return this.memHex.SubStr(offset * 3, count * 3 - 1);
    }

    void DrawRawValues(uint64 offset, int bytesToRead) {
        switch (g_RV_RenderAs) {
            case RV_ValueRenderTypes::Float: DrawRawValuesFloat(offset, bytesToRead); return;
            case RV_ValueRenderTypes::Uint32: DrawRawValuesUint32(offset, bytesToRead); return;
            case RV_ValueRenderTypes::Uint32D: DrawRawValuesUint32D(offset, bytesToRead); return;
            case RV_ValueRenderTypes::Uint64: DrawRawValuesUint64(offset, bytesToRead); return;
            case RV_ValueRenderTypes::Uint16: DrawRawValuesUint16(offset, bytesToRead); return;
            case RV_ValueRenderTypes::Uint16D: DrawRawValuesUint16D(offset, bytesToRead); return;
            case RV_ValueRenderTypes::Uint8: DrawRawValuesUint8(offset, bytesToRead); return;
            case RV_ValueRenderTypes::Uint8D: DrawRawValuesUint8D(offset, bytesToRead); return;
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
    void DrawRawValuesUint32(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueUint32(offset + i);
        }
    }
    void DrawRawValuesUint32D(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 4) {
            _DrawRawValueUint32D(offset + i);
        }
    }
    void DrawRawValuesUint64(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 8) {
            _DrawRawValueUint64(offset + i);
        }
    }
    void DrawRawValuesUint16(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueUint16(offset + i);
        }
    }
    void DrawRawValuesUint16D(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 2) {
            _DrawRawValueUint16D(offset + i);
        }
    }
    void DrawRawValuesUint8(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueUint8(offset + i);
        }
    }
    void DrawRawValuesUint8D(uint64 offset, int bytesToRead) {
        for (int i = 0; i < bytesToRead; i += 1) {
            _DrawRawValueUint8D(offset + i);
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

    bool RV_CopiableValue(const string &in value) {
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
        buf.Seek(offset);
        RV_CopiableValue(tostring(buf.ReadFloat()));
    }
    void _DrawRawValueUint32(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(Text::Format("0x%x", buf.ReadUInt32()));
    }
    void _DrawRawValueUint32D(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(tostring(buf.ReadUInt32()));
    }
    void _DrawRawValueUint64(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(Text::FormatPointer(buf.ReadUInt64()));
    }
    void _DrawRawValueUint16(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(Text::Format("0x%x", buf.ReadUInt16()));
    }
    void _DrawRawValueUint16D(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(tostring(buf.ReadUInt16()));
    }
    void _DrawRawValueUint8(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(Text::Format("0x%x", buf.ReadUInt8()));
    }
    void _DrawRawValueUint8D(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(tostring(buf.ReadUInt8()));
    }
    void _DrawRawValueInt32(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(Text::Format("0x%x", buf.ReadInt32()));
    }
    void _DrawRawValueInt32D(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(tostring(buf.ReadInt32()));
    }
    void _DrawRawValueInt16(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(Text::Format("0x%x", buf.ReadInt16()));
    }
    void _DrawRawValueInt16D(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(tostring(buf.ReadInt16()));
    }
    void _DrawRawValueInt8(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(Text::Format("0x%x", buf.ReadInt8()));
    }
    void _DrawRawValueInt8D(uint offset) {
        buf.Seek(offset);
        RV_CopiableValue(tostring(buf.ReadInt8()));
    }
}




    // void _DrawRawValueFloat(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadFloat(valPtr)));
    // }
    // void _DrawRawValueUint32(uint64 valPtr) {
    //     RV_CopiableValue(Text::Format("0x%x", Dev::ReadUInt32(valPtr)));
    // }
    // void _DrawRawValueUint32D(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadUInt32(valPtr)));
    // }
    // void _DrawRawValueUint16(uint64 valPtr) {
    //     RV_CopiableValue(Text::Format("0x%x", Dev::ReadUInt16(valPtr)));
    // }
    // void _DrawRawValueUint16D(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadUInt16(valPtr)));
    // }
    // void _DrawRawValueUint8(uint64 valPtr) {
    //     RV_CopiableValue(Text::Format("0x%x", Dev::ReadUInt8(valPtr)));
    // }
    // void _DrawRawValueUint8D(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadUInt8(valPtr)));
    // }
    // void _DrawRawValueInt32(uint64 valPtr) {
    //     RV_CopiableValue(Text::Format("0x%x", Dev::ReadInt32(valPtr)));
    // }
    // void _DrawRawValueInt32D(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadInt32(valPtr)));
    // }
    // void _DrawRawValueInt16(uint64 valPtr) {
    //     RV_CopiableValue(Text::Format("0x%x", Dev::ReadInt16(valPtr)));
    // }
    // void _DrawRawValueInt16D(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadInt16(valPtr)));
    // }
    // void _DrawRawValueInt8(uint64 valPtr) {
    //     RV_CopiableValue(Text::Format("0x%x", Dev::ReadInt8(valPtr)));
    // }
    // void _DrawRawValueInt8D(uint64 valPtr) {
    //     RV_CopiableValue(tostring(Dev::ReadInt8(valPtr)));
    // }
    // void _DrawRawValueUint64(uint64 valPtr) {
    //     RV_CopiableValue(Text::FormatPointer(Dev::ReadUInt64(valPtr)));
    // }
