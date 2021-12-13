package com.reactnativedevicecrypto;

import androidx.annotation.NonNull;

import com.facebook.react.bridge.Promise;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReactContextBaseJavaModule;
import com.facebook.react.bridge.ReactMethod;
import com.facebook.react.module.annotations.ReactModule;

import java.security.KeyStore;
import java.security.PublicKey;
import java.security.Signature;
import javax.crypto.Cipher;
import javax.crypto.SecretKey;
import androidx.biometric.BiometricPrompt;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import static com.reactnativedevicecrypto.Constants.*;

@SuppressWarnings({"unused", "SameParameterValue"})
@ReactModule(name = DeviceCryptoModule.NAME)
public class DeviceCryptoModule extends ReactContextBaseJavaModule {
    public static final String NAME = "DeviceCrypto";

    public DeviceCryptoModule(ReactApplicationContext reactContext) {
        super(reactContext);
    }

    @Override
    @NonNull
    public String getName() {
        return NAME;
    }


  // REACT METHODS
  // ______________________________________________
  @ReactMethod
  public void createKey(@NonNull String alias, @NonNull ReadableMap options, @NonNull final Promise promise) {
    int keyType = options.hasKey("keyType") ? options.getInt ("keyType") : Helpers.KeyType.ASYMMETRIC;
    ReactApplicationContext context = getReactApplicationContext();

    try {
      if (!Device.isCompatible(context, options)) {
        throw new Exception("The device cannot meet requirements. (Eg: not pin/pass protected or no biometry has been enrolled.");
      }

      if (keyType == Helpers.KeyType.ASYMMETRIC) {
        PublicKey publicKey = Helpers.getOrCreateAsymmetricKey(alias, options);
        if (publicKey == null) {
          throw new Exception("Public key is null.");
        }
        promise.resolve(Helpers.getPublicKeyPEMFormatted(alias));
      } else {
        SecretKey secretKey = Helpers.getOrCreateSymmetricKey(alias, options);
        if (secretKey == null) {
          throw new Exception("Secret key is null.");
        }
        promise.resolve(true);
      }
    } catch (Exception e) {
      promise.reject(E_ERROR, Helpers.getError(e));
    }
  }

  @ReactMethod
  public void deleteKey(@NonNull String alias, @NonNull final Promise promise) {
    try {
      KeyStore keyStore = Helpers.getKeyStore();
      keyStore.deleteEntry(alias);
      promise.resolve(true);
    } catch (Exception e) {
      promise.reject(E_ERROR, Helpers.getError(e));
    }
  }

  @ReactMethod
  public void sign(@NonNull String alias, String plainText, ReadableMap options, @NonNull final Promise promise) {
    try {
      ReactApplicationContext context = getReactApplicationContext();
      Signature signature = Helpers.initializeSignature(alias);

      // Key usage doesn't require biometric authentication (unrestricted)
      if (Helpers.doNonAuthenticatedCryptography(alias, Helpers.KeyType.ASYMMETRIC, context)) {
        String signatureOfTheText = Helpers.sign(plainText, signature);
        if (signatureOfTheText.isEmpty()) {
          throw new Exception("Couldn't sign the text");
        }
        promise.resolve(signatureOfTheText);
        return;
      }

      // Restricted key requires biometric authentication
      BiometricPrompt.CryptoObject cryptoObject = new BiometricPrompt.CryptoObject(signature);
      Authenticator.authenticate(Authenticator.Cryptography.SIGN, plainText, options, cryptoObject, getCurrentActivity(), promise);
    } catch (Exception e) {
      promise.reject(E_ERROR, Helpers.getError(e));
    }
  }

  @ReactMethod
  public void encrypt(@NonNull String alias, String plainText, ReadableMap options, @NonNull final Promise promise) {
    try {
      ReactApplicationContext context = getReactApplicationContext();
      Cipher cipher = Helpers.initializeEncrypter(alias);

      // Key usage doesn't require biometric authentication (unrestricted)
      if (Helpers.doNonAuthenticatedCryptography(alias, Helpers.KeyType.SYMMETRIC, context)) {
        WritableMap jsObject = Helpers.encrypt(plainText, cipher);
        promise.resolve(jsObject);
        return;
      }

      // Restricted key requires biometric authentication
      BiometricPrompt.CryptoObject cryptoObject = new BiometricPrompt.CryptoObject(cipher);
      Authenticator.authenticate(Authenticator.Cryptography.ENCRYPT, plainText, options, cryptoObject, getCurrentActivity(), promise);
    } catch (Exception e) {
      promise.reject(E_ERROR, Helpers.getError(e));
    }
  }

  @ReactMethod
  public void decrypt(@NonNull String alias, String plainText, String ivDecoded, ReadableMap options, @NonNull final Promise promise) {
    try {
      ReactApplicationContext context = getReactApplicationContext();
      Cipher cipher = Helpers.initializeDecrypter(alias, ivDecoded);

      // Key usage doesn't require biometric authentication (unrestricted)
      if (Helpers.doNonAuthenticatedCryptography(alias, Helpers.KeyType.SYMMETRIC, context)) {
        promise.resolve(Helpers.decrypt(plainText, cipher));
        return;
      }

      // Restricted key requires biometric authentication
      BiometricPrompt.CryptoObject cryptoObject = new BiometricPrompt.CryptoObject(cipher);
      Authenticator.authenticate(Authenticator.Cryptography.DECRYPT, plainText, options, cryptoObject, getCurrentActivity(), promise);
    } catch (Exception e) {
      promise.reject(E_ERROR, Helpers.getError(e));
    }
  }


  // HELPERS
  // ______________________________________________
  @ReactMethod
  public void getPublicKey(@NonNull String alias, @NonNull final Promise promise) {
    try {
      promise.resolve(Helpers.getPublicKeyPEMFormatted(alias));
    } catch (Exception e) {
      promise.reject(E_ERROR, Helpers.getError(e));
    }
  }

  @ReactMethod
  public void isKeyExists(@NonNull String alias, @Helpers.KeyType.Types int keyType, @NonNull final Promise promise) {
    try {
      promise.resolve(Helpers.isKeyExists(alias, keyType));
    } catch (Exception e) {
      promise.reject(E_ERROR, Helpers.getError(e));
    }
  }

  @ReactMethod
  public void isBiometryEnrolled(@NonNull final Promise promise) {
    try {
      promise.resolve(Device.hasEnrolledBiometry(getReactApplicationContext()));
    } catch (Exception e) {
      promise.reject(E_ERROR, Helpers.getError(e));
    }
  }

  @ReactMethod
  public void deviceSecurityLevel(@NonNull final Promise promise) {
    try {
      // Class 2 or Class 3 biometry
      if (Device.hasEnrolledBiometry(getReactApplicationContext())) {
        promise.resolve(BIOMETRY);
        return;
      }

      // Pin, password or pattern protected
      if (Device.hasPinOrPassword(getReactApplicationContext())) {
        promise.resolve(PIN_OR_PATTERN);
        return;
      }
      promise.resolve(NOT_PROTECTED);
    } catch (Exception e) {
      promise.reject(E_ERROR, Helpers.getError(e));
    }
  }

  @ReactMethod
  public void getBiometryType(@NonNull final Promise promise) {
    try{
      if (Device.hasIrisAuth(getReactApplicationContext())) {
        promise.resolve(IRIS);
        return;
      }

      if (Device.hasFaceAuth(getReactApplicationContext())) {
        promise.resolve(FACE);
        return;
      }

      if (Device.hasFingerprint(getReactApplicationContext())) {
        promise.resolve(TOUCH);
        return;
      }

      promise.resolve(NONE);
    } catch (Exception e) {
      promise.reject(E_ERROR, Helpers.getError(e));
    }
  }

  @ReactMethod
  public void authenticateWithBiometry(ReadableMap options, final Promise promise) {
    try {
      Authenticator.authenticate(options, getCurrentActivity(), promise);
    } catch (Exception e) {
      Helpers.getError(e);
    }
  }

}
