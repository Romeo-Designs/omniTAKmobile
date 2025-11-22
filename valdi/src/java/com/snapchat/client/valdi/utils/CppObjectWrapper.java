package com.snapchat.client.valdi.utils;

import com.snap.valdi.utils.NativeHandlesManager;
import com.snap.valdi.utils.Ref;
import com.snapchat.client.valdi.NativeBridge;
import androidx.annotation.Keep;

@Keep
public class CppObjectWrapper extends NativeHandleWrapper implements Ref {

    private boolean destroyDisabled;

    public CppObjectWrapper(long nativeHandle) {
        super(nativeHandle);

        this.destroyDisabled = NativeHandlesManager.INSTANCE.add(this);
    }

    @Override
    protected void destroyHandle(long handle) {
        if (destroyDisabled) {
            return;
        }

        NativeBridge.deleteNativeHandle(handle);
    }

    @Override
    public Object get() {
        return this.getNativeHandle();
    }
}
