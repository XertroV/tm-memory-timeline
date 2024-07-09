
const uint64 BASE_ADDR_END = Dev::BaseAddressEnd();

const bool HAS_Z_DRIVE_WINE_INDICATOR = IO::FolderExists("Z:\\etc\\");

[Setting category="General" name="Force disable linux-wine check if you have a Z:\\ drive with an etc folder"]
bool S_ForceDisableLinuxWineCheck = false;

bool Dev_PointerLooksBad(uint64 ptr) {
    // ! testing
    if (HAS_Z_DRIVE_WINE_INDICATOR && !S_ForceDisableLinuxWineCheck) {
        // dev_trace('Has Z drive / ptr: ' + Text::FormatPointer(ptr) + ' < 0x100000000 = ' + tostring(ptr < 0x100000000));
        // dev_trace('base addr end: ' + Text::FormatPointer(BASE_ADDR_END));
        if (ptr < 0x1000000) return true;
    } else {
        // dev_trace('Windows (no Z drive or forced skip) / ptr: ' + Text::FormatPointer(ptr));
        if (ptr < 0x10000000000) return true;
    }

    // todo: something like this should fix linux (also in Dev_GetNodFromPointer)
    // if (ptr < 0x4fff08D0) return true;
    if (ptr % 8 != 0) return true;
    if (ptr == 0) return true;

    // base address is very low under wine (`0x0000000142C3D000`)
    if (!HAS_Z_DRIVE_WINE_INDICATOR || S_ForceDisableLinuxWineCheck) {
        if (ptr > BASE_ADDR_END) return true;
    }
    return false;
}


CMwNod@ Dev_GetOffsetNodSafe(CMwNod@ target, uint16 offset) {
    if (target is null) return null;
    auto ptr = Dev::GetOffsetUint64(target, offset);
    if (Dev_PointerLooksBad(ptr)) return null;
    return Dev::GetOffsetNod(target, offset);
}



namespace NodPtrs {
    void InitializeTmpPointer() {
        if (g_TmpPtrSpace != 0) return;
        g_TmpPtrSpace = Dev::Allocate(0x1000);
        auto nod = CMwNod();
        uint64 tmp = Dev::GetOffsetUint64(nod, 0);
        Dev::SetOffset(nod, 0, g_TmpPtrSpace);
        @g_TmpSpaceAsNod = Dev::GetOffsetNod(nod, 0);
        Dev::SetOffset(nod, 0, tmp);
    }

    uint64 g_TmpPtrSpace = 0;
    CMwNod@ g_TmpSpaceAsNod = null;
}

CMwNod@ Dev_GetArbitraryNodAt(uint64 ptr) {
    if (NodPtrs::g_TmpPtrSpace == 0) {
        NodPtrs::InitializeTmpPointer();
    }
    if (ptr == 0) throw('null pointer passed');
    Dev::SetOffset(NodPtrs::g_TmpSpaceAsNod, 0, ptr);
    return Dev::GetOffsetNod(NodPtrs::g_TmpSpaceAsNod, 0);
}

uint64 Dev_GetPointerForNod(CMwNod@ nod) {
    if (NodPtrs::g_TmpPtrSpace == 0) {
        NodPtrs::InitializeTmpPointer();
    }
    if (nod is null) return 0;
    Dev::SetOffset(NodPtrs::g_TmpSpaceAsNod, 0, nod);
    return Dev::GetOffsetUint64(NodPtrs::g_TmpSpaceAsNod, 0);
}

const bool IS_MEMORY_ALWAYS_ALIGNED = true;
CMwNod@ Dev_GetNodFromPointer(uint64 ptr) {
    // if linux
    // if (ptr < 0xFFFFFFF || ptr % 8 != 0) {
    //     return null;
    // }
    // return Dev_GetArbitraryNodAt(ptr);
    // ! testing
    if (HAS_Z_DRIVE_WINE_INDICATOR && !S_ForceDisableLinuxWineCheck) {
        print("get nod from ptr: " + Text::FormatPointer(ptr));
        if (ptr < 0x1000000 || (IS_MEMORY_ALWAYS_ALIGNED && ptr % 8 != 0) || ptr >> 48 > 0) {
            print("get nod from ptr failed: " + Text::FormatPointer(ptr));
            return null;
        }
    } else if (ptr < 0xFFFFFFFF || (IS_MEMORY_ALWAYS_ALIGNED && ptr % 8 != 0) || ptr >> 48 > 0) {
        print("get nod from ptr failed: " + Text::FormatPointer(ptr));
        return null;
    }
    return Dev_GetArbitraryNodAt(ptr);
}

CGameItemModel@ tmp_ItemModelForMwIdSetting;

uint32 GetMwId(const string &in name) {
    if (tmp_ItemModelForMwIdSetting is null) {
        @tmp_ItemModelForMwIdSetting = CGameItemModel();
    }
    tmp_ItemModelForMwIdSetting.IdName = name;
    return tmp_ItemModelForMwIdSetting.Id.Value;
}

string GetMwIdName(uint id) {
    return MwId(id).GetName();
}
