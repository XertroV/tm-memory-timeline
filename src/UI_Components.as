RV_ValueRenderTypes DrawComboRV_ValueRenderTypes(const string &in label, RV_ValueRenderTypes val) {
    return RV_ValueRenderTypes(
        DrawArbitraryEnum(label, int(val), RV_ValueRenderTypes::LAST, function(int v) {
            return tostring(RV_ValueRenderTypes(v));
        })
    );
}

shared funcdef string EnumToStringF(int);

shared int DrawArbitraryEnum(const string &in label, int val, int nbVals, EnumToStringF@ eToStr) {
    if (UI::BeginCombo(label, eToStr(val))) {
        for (int i = 0; i < nbVals; i++) {
            if (UI::Selectable(eToStr(i), val == i)) {
                val = i;
            }
        }
        UI::EndCombo();
    }
    return val;
}
