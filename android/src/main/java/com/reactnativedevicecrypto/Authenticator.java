package com.reactnativedevicecrypto;

import android.app.Activity;
import android.util.Log;
import androidx.annotation.IntDef;
import androidx.annotation.NonNull;
import androidx.biometric.BiometricPrompt;
import androidx.fragment.app.FragmentActivity;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.UiThreadUtil;
import com.facebook.react.bridge.Promise;
import java.lang.annotation.Retention;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import static com.reactnativedevicecrypto.Constants.BIOMETRY_DESCRIPTION;
import static com.reactnativedevicecrypto.Constants.BIOMETRY_SUBTITLE;
import static com.reactnativedevicecrypto.Constants.BIOMETRY_TITLE;
import static com.reactnativedevicecrypto.Constants.RN_MODULE;
import static com.reactnativedevicecrypto.Constants.E_ERROR;
import static java.lang.annotation.RetentionPolicy.SOURCE;

public class Authenticator {
    private static BiometricPrompt biometricPrompt;

    public interface Cryptography {
        @Retention(SOURCE)
        @IntDef({NONE, ENCRYPT, DECRYPT, SIGN, VERIFY})
        @interface Types {}
        int NONE = 0;
        int ENCRYPT = 1;
        int DECRYPT = 2;
        int SIGN = 3;
        int VERIFY = 4;
    }

    public static void authenticate(@Cryptography.Types int cryptographyType, @NonNull String plainText, ReadableMap options, BiometricPrompt.CryptoObject cryptoObject, Activity activity, final Promise promise) {
        _authenticate(cryptographyType, plainText, options, cryptoObject, activity, promise);
    }

    public static void authenticate(ReadableMap options, Activity activity, final Promise promise) {
        _authenticate(Cryptography.NONE, "", options, null, activity, promise);
    }

    protected static void _authenticate(@Cryptography.Types int cryptographyType, @NonNull String plainText, ReadableMap options, BiometricPrompt.CryptoObject cryptoObject, Activity activity, final Promise promise) {
        UiThreadUtil.runOnUiThread(new Runnable() {
            @Override
            public void run() {
                try {
                    Executor executor = Executors.newSingleThreadExecutor();
                    String title = options.hasKey("biometryTitle") ? options.getString("biometryTitle") : BIOMETRY_TITLE;
                    String subTitle = options.hasKey("biometrySubTitle") ? options.getString("biometrySubTitle") : BIOMETRY_SUBTITLE;
                    String description = options.hasKey("biometryDescription") ? options.getString("biometryDescription") : BIOMETRY_DESCRIPTION;

                    BiometricPrompt.PromptInfo promptInfo = new BiometricPrompt.PromptInfo.Builder()
                            .setTitle(title)
                            .setSubtitle(subTitle)
                            .setDescription(description)
                            .setNegativeButtonText("Cancel")
                            .build();

                    BiometricPrompt.AuthenticationCallback authCallback = new BiometricPrompt.AuthenticationCallback() {
                        @Override
                        public void onAuthenticationError(int errorCode, @NonNull CharSequence errString) {
                            super.onAuthenticationError(errorCode, errString);
                            promise.reject(E_ERROR, String.valueOf(errorCode).concat("- ").concat(errString.toString()));
                            biometricPrompt.cancelAuthentication();
                            return;
                        }

                        @Override
                        public void onAuthenticationSucceeded(@NonNull BiometricPrompt.AuthenticationResult result) {
                            super.onAuthenticationSucceeded(result);
                            BiometricPrompt.CryptoObject cryptoObject = result.getCryptoObject();
                            try {
                                switch (cryptographyType) {
                                    case Cryptography.SIGN:
                                        promise.resolve(Helpers.sign(plainText, cryptoObject.getSignature()));
                                        return;
                                    case Cryptography.DECRYPT:
                                        promise.resolve(Helpers.decrypt(plainText, cryptoObject.getCipher()));
                                        return;
                                    case Cryptography.ENCRYPT:
                                        promise.resolve(Helpers.encrypt(plainText, cryptoObject.getCipher()));
                                        return;
                                    case Cryptography.NONE:
                                        promise.resolve(true);
                                        return;
                                }
                            } catch (Exception e) {
                                promise.reject(E_ERROR, Helpers.getError(e));
                            }
                        }

                        @Override
                        public void onAuthenticationFailed() {
                            super.onAuthenticationFailed();
                            return;
                        }
                    };

                    biometricPrompt = new BiometricPrompt((FragmentActivity) activity, executor, authCallback);
                    if (cryptographyType == Cryptography.NONE) {
                        biometricPrompt.authenticate(promptInfo);
                    } else {
                        biometricPrompt.authenticate(promptInfo, cryptoObject);
                    }
                } catch (Exception e) {
                    Log.e(RN_MODULE, e.getMessage());
                }
            }
        });
    }
}
