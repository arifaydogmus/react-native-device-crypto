package com.reactnativedevicecrypto;

import android.os.Build;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyInfo;
import android.security.keystore.KeyProperties;
import android.util.Base64;
import android.util.Log;
import androidx.annotation.IntDef;
import androidx.annotation.NonNull;
import com.facebook.react.bridge.Arguments;
import com.facebook.react.bridge.ReactApplicationContext;
import com.facebook.react.bridge.ReadableMap;
import com.facebook.react.bridge.WritableMap;
import java.lang.annotation.Retention;
import java.security.Key;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.KeyStore;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.Signature;
import java.security.cert.Certificate;
import java.security.spec.ECGenParameterSpec;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.SecretKeyFactory;
import javax.crypto.spec.GCMParameterSpec;
import static com.reactnativedevicecrypto.Constants.RN_MODULE;
import static java.lang.annotation.RetentionPolicy.SOURCE;
import static java.nio.charset.StandardCharsets.UTF_8;


public class Helpers {
    private static final String KEY_STORE = "AndroidKeyStore";
    private static final String AES_ALGORITHM = "AES/GCM/NoPadding";
    private static final int AES_IV_SIZE = 128;
    public static final String PEM_HEADER = "-----BEGIN PUBLIC KEY-----\n";
    public static final String PEM_FOOTER = "-----END PUBLIC KEY-----";

    public interface KeyType {
        @Retention(SOURCE)
        @IntDef({ASYMMETRIC, SYMMETRIC})
        @interface Types {}
        int ASYMMETRIC = 0;
        int SYMMETRIC = 1;
    }

    public interface AccessLevel {
      @Retention(SOURCE)
      @IntDef({ALWAYS, UNLOCKED_DEVICE, AUTHENTICATION_REQUIRED})
      @interface Types {}
      int ALWAYS = 0;
      int UNLOCKED_DEVICE = 1;
      int AUTHENTICATION_REQUIRED = 2;
    }

    public static String getError(Exception e) {
        String errorMessage = e.getCause() != null ? e.getCause().getMessage() : e.getMessage();
        Log.e(RN_MODULE, errorMessage);
        return errorMessage;
    }

    public static KeyStore getKeyStore() throws Exception {
        KeyStore keyStore = KeyStore.getInstance(KEY_STORE);
        keyStore.load(null);
        return keyStore;
    }

    public static KeyInfo getKeyInfo(@NonNull String alias, @KeyType.Types int keyType) throws Exception {
        if (keyType == KeyType.ASYMMETRIC) {
          Key key = getPrivateKeyRef(alias);
          KeyFactory factory = KeyFactory.getInstance(key.getAlgorithm(), KEY_STORE);
          return factory.getKeySpec(key, KeyInfo.class);
        } else {
          SecretKey secretKey = getSymmetricKeyRef(alias);
          SecretKeyFactory secretKeyFactory = SecretKeyFactory.getInstance(secretKey.getAlgorithm(), KEY_STORE);
          return (KeyInfo) secretKeyFactory.getKeySpec(secretKey, KeyInfo.class);
        }
    }

    public static boolean isKeyExists(@NonNull String alias, @KeyType.Types int keyType) throws Exception {
        KeyStore keyStore = Helpers.getKeyStore();
        if (!keyStore.containsAlias(alias)) {
          return false;
        }

        if (keyType == KeyType.ASYMMETRIC) {
          return (getPrivateKeyRef(alias) != null);
        } else {
          return (getSymmetricKeyRef(alias) != null);
        }
    }

    public static boolean doNonAuthenticatedCryptography(@NonNull String alias, @KeyType.Types int keyType, ReactApplicationContext context) throws Exception {
        if (!Helpers.isKeyExists(alias, keyType)) throw new Exception(alias.concat(" is not exists in KeyStore"));
        KeyInfo keyInfo = Helpers.getKeyInfo(alias, keyType);
        if (keyInfo.isUserAuthenticationRequired()) {
            if (!Device.hasEnrolledBiometry(context)) throw new Exception("Device cannot sign/encrypt. (No biometry enrolled)");
            if (!Device.isAppGrantedToUseBiometry(context)) throw new Exception("The app is not granted to use biometry.");
        }

        // We always inverted for better usage
        return !keyInfo.isUserAuthenticationRequired();
    }

    protected static KeyGenParameterSpec.Builder getBuilder(@NonNull String alias, @NonNull @KeyType.Types int keyType, @NonNull ReadableMap options) throws Exception {
        int accessLevel = options.hasKey("accessLevel") ? options.getInt("accessLevel") : Helpers.AccessLevel.ALWAYS;
        boolean invalidateOnNewBiometry = !options.hasKey("invalidateOnNewBiometry") || options.getBoolean("invalidateOnNewBiometry");
        int purposes = KeyProperties.PURPOSE_SIGN | KeyProperties.PURPOSE_VERIFY | KeyProperties.PURPOSE_DECRYPT | KeyProperties.PURPOSE_ENCRYPT;
        KeyGenParameterSpec.Builder builder = new KeyGenParameterSpec.Builder(alias, purposes);

        if (keyType == KeyType.ASYMMETRIC) {
            builder.setAlgorithmParameterSpec(new ECGenParameterSpec("secp256r1"))
                    .setDigests(KeyProperties.DIGEST_SHA256)
                    .setRandomizedEncryptionRequired(true);
        } else {
            builder.setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                    .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                    .setKeySize(256)
                    .setRandomizedEncryptionRequired(true);
        }

        // Initial level is AccessLevel.ALWAYS
        switch (accessLevel) {
          case AccessLevel.UNLOCKED_DEVICE:
            builder.setUserAuthenticationRequired(false);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
              builder.setUnlockedDeviceRequired(true);
            }
            break;
          case AccessLevel.AUTHENTICATION_REQUIRED:
            // Sets whether this key is authorized to be used only if the user has been authenticated.
            builder.setUserAuthenticationRequired(true);
            // Allow pin/pass as a fallback on API 30+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
              builder.setUserAuthenticationParameters(0, KeyProperties.AUTH_DEVICE_CREDENTIAL | KeyProperties.AUTH_BIOMETRIC_STRONG);
            }
            // Invalidate the keys if the user has registered a new biometric
            // credential. The variable "invalidatedByBiometricEnrollment" is true by default.
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
              builder.setInvalidatedByBiometricEnrollment(invalidateOnNewBiometry);
            }
            if (Build.VERSION.SDK_INT > Build.VERSION_CODES.R) {
              builder.setIsStrongBoxBacked(true);
            }
            break;
        }

        return builder;
    }

    // ASYMMETRIC KEY METHODS
    public static PublicKey getOrCreateAsymmetricKey(@NonNull String alias, @NonNull ReadableMap options) throws Exception {
        if (isKeyExists(alias, KeyType.ASYMMETRIC)) {
            return getPublicKeyRef(alias);
        }

        KeyGenParameterSpec.Builder builder = getBuilder(alias, KeyType.ASYMMETRIC, options);
        KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance(KeyProperties.KEY_ALGORITHM_EC, KEY_STORE);
        keyPairGenerator.initialize(builder.build());
        KeyPair keyPair = keyPairGenerator.generateKeyPair();
        return keyPair.getPublic();
    }

    public static PublicKey getPublicKeyRef(@NonNull String alias) throws Exception {
        if (!isKeyExists(alias, KeyType.ASYMMETRIC)) {
            throw new Exception(alias.concat(" not found in keystore"));
        }
        KeyStore keyStore = getKeyStore();
        Certificate certificate = keyStore.getCertificate(alias);
        return certificate.getPublicKey();
    }

    public static PrivateKey getPrivateKeyRef(@NonNull String alias) throws Exception {
        KeyStore keyStore = getKeyStore();
        PrivateKey privateKey = (PrivateKey) keyStore.getKey(alias, null);
        return privateKey;
    }

    public static String getPublicKeyPEMFormatted(@NonNull String alias) throws Exception {
        if (!isKeyExists(alias, KeyType.ASYMMETRIC)) {
            return null;
        }
        PublicKey publicKey = getPublicKeyRef(alias);
        byte[] pubBytes = Base64.encode(publicKey.getEncoded(), Base64.DEFAULT);
        String pubStr = new String(pubBytes);
        return PEM_HEADER.concat(pubStr).concat(PEM_FOOTER);
    }

    public static Signature initializeSignature(@NonNull String alias) throws Exception {
        PrivateKey privateKey = Helpers.getPrivateKeyRef(alias);
        Signature signature = Signature.getInstance("SHA256withECDSA");
        signature.initSign(privateKey);
        return signature;
    }

    public static String sign(@NonNull String textToBeSigned, @NonNull Signature signature) throws Exception {
        signature.update(textToBeSigned.getBytes(UTF_8));
        byte[] signatureBytes = signature.sign();
        byte[] signatureEncoded = Base64.encode(signatureBytes, Base64.NO_WRAP);
        return new String(signatureEncoded);
    }


    // SYMMETRIC KEY METHODS
    // ______________________________________________
    public static SecretKey getOrCreateSymmetricKey(@NonNull String alias, @NonNull ReadableMap options) throws Exception {
        if (isKeyExists(alias, KeyType.SYMMETRIC)) {
            return getSymmetricKeyRef(alias);
        }

        KeyGenParameterSpec.Builder builder = getBuilder(alias, KeyType.SYMMETRIC, options);
        KeyGenerator keyGen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, KEY_STORE);
        keyGen.init(builder.build());
        return keyGen.generateKey();
    }

    public static SecretKey getSymmetricKeyRef(@NonNull String alias) throws Exception {
        KeyStore keyStore = getKeyStore();
        return (SecretKey) keyStore.getKey(alias, null);
    }

    public static Cipher initializeDecrypter(@NonNull String alias, @NonNull String ivDecoded) throws Exception {
        SecretKey secretKey = getSymmetricKeyRef(alias);
        byte[] iv = Base64.decode(ivDecoded, Base64.NO_WRAP);
        Cipher cipher = Cipher.getInstance(AES_ALGORITHM);
        GCMParameterSpec spec = new GCMParameterSpec(AES_IV_SIZE, iv);
        cipher.init(Cipher.DECRYPT_MODE, secretKey, spec);
        return cipher;
    }

    public static String decrypt(@NonNull String textTobeDecrypted, @NonNull Cipher cipher) throws Exception {
        byte[] encrypted = Base64.decode(textTobeDecrypted, Base64.NO_WRAP);
        byte[] decryptedBytes = cipher.doFinal(encrypted);
        return new String(decryptedBytes);
    }

    public static Cipher initializeEncrypter(@NonNull String alias) throws Exception {
        SecretKey secretKey = getSymmetricKeyRef(alias);
        Cipher cipher = Cipher.getInstance(AES_ALGORITHM);
        cipher.init(Cipher.ENCRYPT_MODE, secretKey);
        return cipher;
    }

    public static WritableMap encrypt(@NonNull String textToBeEncrypted, @NonNull Cipher cipher) throws Exception {
        byte[] encryptedBytes = cipher.doFinal(textToBeEncrypted.getBytes(UTF_8));
        WritableMap jsObject = Arguments.createMap();
        jsObject.putString("iv", Base64.encodeToString(cipher.getIV(), Base64.NO_WRAP));
        jsObject.putString("encryptedText", Base64.encodeToString(encryptedBytes, Base64.NO_WRAP));
        return jsObject;
    }

}
