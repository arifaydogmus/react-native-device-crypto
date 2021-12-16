# react-native-device-crypto

React Native Device Crypto provides functionality to use hardware-based secure encryption.
To further protect sensitive data within your app, you can incorporate cryptography into your biometric authentication workflow.
After the user authenticates successfully using a biometric prompt, your app can perform a cryptographic operation. For example, if you authenticate, your app can then perform encryption, decryption and signing.

- [Device Crypto for React Native](#react-native-device-crypto)
  - [Features](#features)
  - [Important Notes](#important-notes)
  - [Installation](#installation)
  - [Usage](#usage)
  - [API](#api)
    - [getOrCreateAsymmetricKey](#getOrCreateAsymmetricKey)
    - [getOrCreateSymmetricKey](#getOrCreateSymmetricKey)
    - [isKeyExists](#isKeyExists)
    - [getPublicKey](#getPublicKey)
    - [deleteKey](#deleteKey)
    - [sign](#sign)
    - [encrypt](#encrypt)
    - [decrypt](#decrypt)
    - [isBiometryEnrolled](#isBiometryEnrolled)
    - [deviceSecurityLevel](#deviceSecurityLevel)
    - [getBiometryType](#getBiometryType)
    - [authenticateWithBiometry](#authenticateWithBiometry)

## Features

- Full TypeScript support
- No third party dependencies
- Native biometric screen support
- Easy installation and usage

Also, the module allows you to

- Create a asymmetric/symmetric key where as the private key/secret key is stored in the secure hardware (Sencure Enclave/Strongbox/TEE)
- Set access level of the key usage.
- Set the key life time.
- Sign a string with the private key.
- Encrypt/decrypt with secret key.
- Detect what type of biometric sensor is available on the device.
- Detect what kind of protection is set it up on the device.
- Fires native biometric screen to check that user is authenticated.

## Important Notes

Extremely secure iOS encryption and decryption via secure enclave, elliptic curves.
Very secure Android encryption and decryption via Android KeyStore.

This package requires a compiled SDK version of 30 (Android 11.0) or higher
The Android side uses the android.security.keystore API and requires a minimum SDK version of 23, due to availability of the hardware-backed security.

This package requires an iOS target SDK version of iOS 11 or higher

Ensure that you have the NSFaceIDUsageDescription entry set in your react native iOS project, or Face ID will not work properly. This description will be presented to the user the first time a biometrics action is taken, and the user will be asked if they want to allow the app to use Face ID. If the user declines the usage of face id for the app, the `getBiometryType` function will indicate biometrics is unavailable until the face id permission is specifically allowed for the app by the user.

## Installation

1. Run `yarn add react-native-device-crypto` or `npm i react-native-device-crypto`

   1 a. **If React Native version <= 0.59**: `react-native link react-native-device-crypto` and check `MainApplication.java` to verify the package was added.

2. Run `pod install` in `ios/` directory to install iOS dependencies.
3. If you want to support FaceID, add a `NSFaceIDUsageDescription` entry in your `Info.plist`.
4. Re-build your Android and iOS projects.

## Usage

Please see `Example Project` for fully working project.

### An Usage Example - Device Binding (Pairing)

When a user enrolls in biometrics, a key pair is generated. The private key is stored securely on the device and the public key is sent to a server for registration. When the user wishes to authenticate, the user is prompted for biometrics, which unlocks the securely stored private key. Then a cryptographic signature is generated and sent to the server for verification. The server then verifies the signature. If the verification was successful, the server returns an appropriate response and authorizes the user.

## API

### getOrCreateAsymmetricKey

`async getOrCreateAsymmetricKey(alias: string, options: KeyCreationParams): Promise<string>`

Creates an asymmetric key in the secure hardware with given access parameters. Returns Public Key if successfull.

```
interface KeyCreationParams {
  accessLevel: AccessLevel;
  invalidateOnNewBiometry?: boolean;
}
```

`invalidateOnNewBiometry` : The key has been invalidated when the user removes biometry or enrolls new biometry if this is true. (This is irreversable)

| Access Level            | Description                                                                                       |
| ----------------------- | ------------------------------------------------------------------------------------------------- |
| Always                  | The key is always accessible even if the device locked. (aka unrestricted key)                    |
| Unlocked device         | The key is accessible when the device has been unlocked. (aka unrestricted key)                   |
| Authentication Required | The key is accessible when the user authenticate their selves with biometry. (aka restricted key) |

Cryptography algorithms

256-bit ECC Keys for Suite-B EC (aka secp256k1) EC (Elliptic Curve) keypair on iOS

NIST P-256 (aka secp256r1 aka prime256v1) EC (Elliptic Curve) keypair on Android

- The key material of the generated symmetric and private keys is not accessible. The key material of the public keys is accessible.

### getOrCreateSymmetricKey

`async getOrCreateSymmetricKey(alias: string, options: KeyCreationParams): Promise<boolean>`

Creates a symmetric key in the secure hardware with given access parameters. Returns `true` if successfull

```
interface KeyCreationParams {
  accessLevel: AccessLevel;
  invalidateOnNewBiometry?: boolean;
}
```

`invalidateOnNewBiometry` : The key has been invalidated when the user removes biometry or enrolls new biometry if this is true. (This is irreversable)

| Access Level            | Description                                                                                       |
| ----------------------- | ------------------------------------------------------------------------------------------------- |
| Always                  | The key is always accessible even if the device locked. (aka unrestricted key)                    |
| Unlocked device         | The key is accessible when the device has been unlocked. (aka unrestricted key)                   |
| Authentication Required | The key is accessible when the user authenticate their selves with biometry. (aka restricted key) |

Cryptography algorithms

AES256

**Note for IOS :**
We don’t explicitly create the symmetric key. Instead, we call native `SecKeyCreateEncryptedData` to create a symmetric key for you. This function creates the symmetric key, uses it to encrypt your data, and then encrypts the key itself with the public key (We create in background to provide it later on encrypt/decrypt operations). It then packages all of this data together and returns it to you. You then transmit it to a receiver, who uses the corresponding private key in a call to native `SecKeyCreateDecryptedData` to reverse the operation.
That is why `encrypt` method returns IV as `NotRequired` on IOS.

### isKeyExists

`async isKeyExists(alias: string, keyType: KeyTypes): Promise<boolean>`

Checks the key is exist in secure hardware or not.

### getPublicKey

`async getPublicKey(alias: string): Promise<string>`

Gets PEM formatted public key.

### deleteKey

`async deleteKey(alias: string): Promise<boolean>`

Deletes the key from secure hardware. (This is irreversable.)

### sign

`async sign(alias: string, plainText: string, options: BiometryParams): Promise<string>`

Signs the given string with private key and returns Base64 encoded signature.

- If your private key requires biometric credentials to unlock (`unlockedDeviceRequired` and `authenticationRequired` should be `true` when creating the key in this case), the user must authenticate their biometric credentials each time before your app accesses the key.

### encrypt

` async encrypt(alias: string, plainText: string, options: BiometryParams): Promise<EncryptionResult>`

Encrypts the given string with the secret key and returns Base64 encoded encrypted text and IV code.

- `iv` is always `NotRequired`. Please see the note on [getOrCreateSymmetricKey](#getOrCreateSymmetricKey)
- If your secret key requires biometric credentials to unlock (`unlockedDeviceRequired` and `authenticationRequired` should be `true` when creating the key in this case), the user must authenticate their biometric credentials each time before your app accesses the key.

### decrypt

`async decrypt(alias: string, plainText: string, iv: string, options: BiometryParams): Promise<string>`

Decrypts the given Base64 encoded encrypted text with IV and the secret key.

- `iv` ignored on IOS and cannot be null. Please see the note on [getOrCreateSymmetricKey](#getOrCreateSymmetricKey)
- If your secret key requires biometric credentials to unlock (`unlockedDeviceRequired` and `authenticationRequired` should be `true` when creating the key in this case), the user must authenticate their biometric credentials each time before your app accesses the key.

### isBiometryEnrolled

`async isBiometryEnrolled(): Promise<boolean>`

Checks if the user can authenticate with biometrics. This requires at least one biometric sensor to be present, enrolled, and available on the device.

### deviceSecurityLevel

`async deviceSecurityLevel(): Promise<SecurityLevel>`

Checks the devices security level.

| Return Value   | Description                                        |
| -------------- | -------------------------------------------------- |
| NOT_PROTECTED  | The device has no protection.                      |
| PIN_OR_PATTERN | The device is secured by pin or password.          |
| BIOMETRY       | The device is secured by biometric authentication. |

### getBiometryType

`async getBiometryType(): Promise<BiometryType>`

Gets the biometric scanner type if the device has biometric hardware.

| Return Value | Platform     | Description                                                   |
| ------------ | ------------ | ------------------------------------------------------------- |
| NONE         | All          | The device has no biometric hardware or could not determined. |
| TOUCH        | All          | The biometric hardware detects fingerprint                    |
| FACE         | All          | The biometric hardware performs face authentication           |
| IRIS         | Android only | The biometric hardware performs iris authentication           |

### authenticateWithBiometry

`async authenticateWithBiometry(options: BiometryParams): Promise<boolean>`

One method of protecting sensitive information or premium content within your app is to request biometric authentication, such as using face recognition or fingerprint recognition. To display a system prompt that requests the user to authenticate using biometric credentials.
After the user authenticates, you can check whether the user authenticated or not.

## Contributing

See the [contributing guide](CONTRIBUTING.md) to learn how to contribute to the repository and the development workflow.

## License

ISC
