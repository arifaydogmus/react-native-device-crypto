package com.reactnativedevicecrypto;

import android.Manifest;
import android.app.KeyguardManager;
import android.content.pm.PackageManager;
import android.os.Build;
import androidx.annotation.NonNull;
import androidx.biometric.BiometricManager;
import static android.content.pm.PackageManager.PERMISSION_GRANTED;
import static androidx.biometric.BiometricManager.Authenticators.*;
import static androidx.biometric.BiometricManager.BIOMETRIC_SUCCESS;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReadableMap;

public class Device {
    public static boolean hasEnrolledBiometry(@NonNull final ReactApplicationContext context) {
        return BiometricManager.from(context).canAuthenticate(BIOMETRIC_STRONG | BIOMETRIC_WEAK) == BIOMETRIC_SUCCESS;
    }

    public static boolean hasPinOrPassword(@NonNull final ReactApplicationContext context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
            return BiometricManager.from(context).canAuthenticate(DEVICE_CREDENTIAL) == BIOMETRIC_SUCCESS;
        }

        KeyguardManager kg = (KeyguardManager) context.getSystemService(ReactApplicationContext.KEYGUARD_SERVICE);
        return kg != null && kg.isDeviceSecure();
    }

    public static boolean hasFingerprint(@NonNull final ReactApplicationContext context) {
        return context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_FINGERPRINT);
    }

    public static boolean hasFaceAuth(@NonNull final ReactApplicationContext context) {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_FACE);
    }

    public static boolean hasIrisAuth(@NonNull final ReactApplicationContext context) {
        return Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q && context.getPackageManager().hasSystemFeature(PackageManager.FEATURE_IRIS);
    }

    public static boolean isAppGrantedToUseBiometry(@NonNull final ReactApplicationContext context) {
        // It was USE_FINGERPRINT before Api28
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.P) {
            return context.checkSelfPermission(Manifest.permission.USE_FINGERPRINT) == PERMISSION_GRANTED;
        }

        return context.checkSelfPermission(Manifest.permission.USE_BIOMETRIC) == PERMISSION_GRANTED;
    }

    public static boolean isCompatible(@NonNull final ReactApplicationContext context, @NonNull ReadableMap options) {
      int accessLevel = options.hasKey("accessLevel") ? options.getInt("accessLevel") : Helpers.AccessLevel.ALWAYS;
      switch (accessLevel) {
        case Helpers.AccessLevel.UNLOCKED_DEVICE:
          return hasPinOrPassword(context);
        case Helpers.AccessLevel.AUTHENTICATION_REQUIRED:
          return hasEnrolledBiometry(context);
        default:
          return true;
      }
    }
}
