#import <Security/Security.h>
#import <React/RCTConvert.h>
#import <React/RCTBridge.h>
#import <React/RCTUtils.h>
#import <LocalAuthentication/LAContext.h>
#import <LocalAuthentication/LAError.h>
#import <UIKit/UIKit.h>
#import "DeviceCrypto.h"

@implementation DeviceCrypto
@synthesize bridge = _bridge;

RCT_EXPORT_MODULE()

#pragma mark - DeviceCrypto

#define kKeyType @"keyType"
#define kUnlockedDeviceRequired @"unlockedDeviceRequired"
#define kAuthenticationRequired @"authenticationRequired"
#define kInvalidateOnNewBiometry @"invalidateOnNewBiometry"

#define kAuthenticatePrompt @"iosAuthenticationPrompt"
#define eAuthenticationCancelled @"Please confirm your biometrics."



#define allTrim( object ) [object stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet] ]

typedef NS_ENUM(NSUInteger, KeyType) {
    ASYMMETRIC = 0,
    SYMMETRIC = 1,
};

- (NSString*) convertToString:(NSDictionary *) data {
  NSError * err;
  NSData * jsonData = [NSJSONSerialization  dataWithJSONObject:data options:0 error:&err];
  return [[NSString alloc] initWithData:jsonData   encoding:NSUTF8StringEncoding];
}

- (NSDictionary*) convertToDictionary:(NSString *) stringData
{
  NSError * err;
  NSData *data =[stringData dataUsingEncoding:NSUTF8StringEncoding];
  if(data!=nil){
    return (NSDictionary *)[NSJSONSerialization JSONObjectWithData:data options:NSJSONReadingMutableContainers error:&err];
  }
  return nil;
}

// Public key methods
- (SecKeyRef) getPublicKeyRef:(NSData*) alias
{
  NSDictionary *query = @{
    (id)kSecClass:               (id)kSecClassKey,
    (id)kSecAttrKeyClass:        (id)kSecAttrKeyClassPublic,
    (id)kSecAttrLabel:           @"publicKey",
    (id)kSecAttrApplicationTag:  (id)alias,
    (id)kSecReturnRef:           (id)kCFBooleanTrue,
  };
  
  CFTypeRef resultTypeRef = NULL;
  OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef) query, &resultTypeRef);
  if (status == errSecSuccess) {
    return (SecKeyRef)resultTypeRef;
  } else if (status == errSecItemNotFound) {
    return nil;
  } else
  [NSException raise:@"Unexpected OSStatus" format:@"Status: %i", (int)status];
  return nil;
}

- (NSData *) getPublicKeyBits:(NSData*) alias
{
  NSDictionary *query = @{
    (id)kSecClass:               (id)kSecClassKey,
    (id)kSecAttrKeyClass:        (id)kSecAttrKeyClassPublic,
    (id)kSecAttrLabel:           @"publicKey",
    (id)kSecAttrApplicationTag:  (id)alias,
    (id)kSecReturnData:          (id)kCFBooleanTrue,
    (id)kSecReturnRef:           (id)kCFBooleanTrue,
  };
  
  SecKeyRef keyRef;
  OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef) query, (CFTypeRef *)&keyRef);
  if (status == errSecSuccess) {
    return CFDictionaryGetValue((CFDictionaryRef)keyRef, kSecValueData);
  } else if (status == errSecItemNotFound) {
    return nil;
  } else {
    [NSException raise:@"Unexpected OSStatus" format:@"Status: %i", status];
  }
  return nil;
}

- (NSString *) getPublicKeyAsString:(NSData*) alias
{
  NSString *returnVal = nil;
  NSData *publicKeyBits = [self getPublicKeyBits:alias];
  if (publicKeyBits){
    returnVal = [[NSString alloc]initWithData:publicKeyBits encoding:NSASCIIStringEncoding];
  }
  return returnVal;
}

- (NSString*) getPublicKeyAsPEM:(NSData*) alias
{
  const char asnHeader[] = {
    0x30, 0x59, 0x30, 0x13,
    0x06, 0x07, 0x2A, 0x86,
    0x48, 0xCE, 0x3D, 0x02,
    0x01, 0x06, 0x08, 0x2A,
    0x86, 0x48, 0xCE, 0x3D,
    0x03, 0x01, 0x07, 0x03,
    0x42, 0x00};
  NSData *asnHeaderData = [NSData dataWithBytes:asnHeader length:sizeof(asnHeader)];
  NSData *publicKeyBits = [self getPublicKeyBits:alias];
  
  if (publicKeyBits == nil){
    return nil;
  }
  NSMutableData *payload;
  payload = [[NSMutableData alloc] init];
  [payload appendData:asnHeaderData];
  [payload appendData:publicKeyBits];
  
  NSData *immutablePEM = [NSData dataWithData:payload];
  NSString* base64EncodedString = [(NSData*)immutablePEM base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
  NSString* pemString = [NSString stringWithFormat:@"-----BEGIN PUBLIC KEY-----\n%@\n-----END PUBLIC KEY-----", base64EncodedString];
  return pemString;
}

- (bool) savePublicKeyFromRef:(SecKeyRef)publicKeyRef withAlias:(NSData*) alias
{
  NSDictionary* attributes =
  @{
    (id)kSecClass:              (id)kSecClassKey,
    (id)kSecAttrKeyClass:       (id)kSecAttrKeyClassPublic,
    (id)kSecAttrLabel:          @"publicKey",
    (id)kSecAttrApplicationTag: (id)alias,
    (id)kSecValueRef:           (__bridge id)publicKeyRef,
    (id)kSecAttrIsPermanent:    (id)kCFBooleanTrue,
  };
  
  OSStatus status = SecItemAdd((CFDictionaryRef)attributes, nil);
  while (status == errSecDuplicateItem)
  {
    status = SecItemDelete((CFDictionaryRef)attributes);
  }
  status = SecItemAdd((CFDictionaryRef)attributes, nil);
  
  return true;
}

- (bool) deletePublicKey:(NSData*) alias
{
  NSDictionary *query = @{
    (id)kSecClass:               (id)kSecClassKey,
    (id)kSecAttrKeyClass:        (id)kSecAttrKeyClassPublic,
    (id)kSecAttrLabel:           @"publicKey",
    (id)kSecAttrApplicationTag:  (id)alias,
  };
  OSStatus status = SecItemDelete((CFDictionaryRef) query);
  while (status == errSecDuplicateItem)
  {
    status = SecItemDelete((CFDictionaryRef) query);
  }
  return true;
}

// Private key methods
- (SecKeyRef) getPrivateKeyRef:(NSData*)alias withMessage:(NSString *)authPromptMessage
{
  NSString *authenticationPrompt = @"Authenticate to retrieve secret";
  if (authPromptMessage) {
    authenticationPrompt = authPromptMessage;
  }
  NSDictionary *query = @{
    (id)kSecClass:               (id)kSecClassKey,
    (id)kSecAttrKeyClass:        (id)kSecAttrKeyClassPrivate,
    (id)kSecAttrLabel:           @"privateKey",
    (id)kSecAttrApplicationTag:  (id)alias,
    (id)kSecReturnRef:           (id)kCFBooleanTrue,
    (id)kSecUseOperationPrompt:  authenticationPrompt,
  };
  
  CFTypeRef resultTypeRef = NULL;
  OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef) query,  (CFTypeRef *)&resultTypeRef);
  if (status == errSecSuccess)
    return (SecKeyRef)resultTypeRef;
  else if (status == errSecItemNotFound)
    return nil;
  else
    [NSException raise:@"E1715: Unexpected OSStatus" format:@"Status: %i", (int)status];
  return nil;
}

- (bool) deletePrivateKey:(NSData*) alias
{
  NSDictionary *query = @{
    (id)kSecClass:               (id)kSecClassKey,
    (id)kSecAttrKeyClass:        (id)kSecAttrKeyClassPrivate,
    (id)kSecAttrLabel:           @"privateKey",
    (id)kSecAttrApplicationTag:  (id)alias,
  };
  OSStatus status = SecItemDelete((CFDictionaryRef) query);
  while (status == errSecDuplicateItem)
  {
    status = SecItemDelete((CFDictionaryRef) query);
  }
  return true;
}

- (NSString*) getOrCreateAsymmetricKey:(nonnull NSData*) alias withUnlockedDeviceRequired:(BOOL) unlockedDeviceRequired withAuthenticationRequired: (BOOL) authenticationRequired withInvalidateOnNewBiometry: (BOOL) invalidateOnNewBiometry
{
  SecKeyRef privateKeyRef = [self getPrivateKeyRef:alias withMessage:kAuthenticationRequired];
  if (privateKeyRef != nil) {
    return [self getPublicKeyAsPEM:alias];
  }

  CFErrorRef error = nil;
  CFStringRef accessLevel = kSecAttrAccessibleAfterFirstUnlock;
  SecAccessControlCreateFlags acFlag = kSecAccessControlPrivateKeyUsage;
  
  if (unlockedDeviceRequired) {
    accessLevel = kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
  }
  
  if (authenticationRequired) {
    accessLevel = kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
    if (invalidateOnNewBiometry) {
      if (@available(iOS 11.3, *)) {
        acFlag = kSecAccessControlBiometryCurrentSet | kSecAccessControlPrivateKeyUsage;
      } else {
        acFlag = kSecAccessControlPrivateKeyUsage;
      }
    } else {
      if (@available(iOS 11.3, *)) {
        acFlag = kSecAccessControlBiometryAny | kSecAccessControlPrivateKeyUsage;
      } else {
        acFlag = kSecAccessControlPrivateKeyUsage;
      }
    }
  }
  
  SecAccessControlRef acRef = SecAccessControlCreateWithFlags(kCFAllocatorDefault, accessLevel, acFlag, &error);
  
  if (!acRef) {
    [NSException raise:@"E1711" format:@"Could not create access control."];
  }
  
  NSDictionary* attributes =
  @{ (id)kSecAttrKeyType:        (id)kSecAttrKeyTypeECSECPrimeRandom,
     (id)kSecAttrTokenID:        (id)kSecAttrTokenIDSecureEnclave,
     (id)kSecAttrKeySizeInBits:  @256,
     (id)kSecPrivateKeyAttrs:
       @{
         (id)kSecAttrLabel:          @"privateKey",
         (id)kSecAttrApplicationTag: alias,
         (id)kSecAttrIsPermanent:    (id)kCFBooleanTrue,
         (id)kSecAttrAccessControl:  (__bridge id)acRef },
         (id)kSecPublicKeyAttrs:
            @{
              (id)kSecAttrIsPermanent:    (id)kCFBooleanFalse,
            },
  };
  
  privateKeyRef = SecKeyCreateRandomKey((__bridge CFDictionaryRef)attributes, &error);
  if (!privateKeyRef){
    [NSException raise:@"E1712" format:@"SecKeyCreate could not create key."];
  }
  SecKeyRef publicKeyRef = SecKeyCopyPublicKey(privateKeyRef);
  [self savePublicKeyFromRef:publicKeyRef withAlias:alias];
  return [self getPublicKeyAsPEM:alias];
}





- (NSString *) getBiometryType
{
  NSError *aerr = nil;
  LAContext *context = [[LAContext alloc] init];
  BOOL canBeProtected = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&aerr];
  
  if (aerr || !canBeProtected) {
    return @"ERROR";
  }
  
  if (@available(iOS 11, *)) {
    if (context.biometryType == LABiometryTypeFaceID) {
      return @"FACE";
    }
    else if (context.biometryType == LABiometryTypeTouchID) {
      return @"TOUCH";
    }
    else if (context.biometryType == LABiometryNone) {
      return @"NONE";
    } else {
      return @"TOUCH";
    }
  }
  
  return @"TOUCH";
}

// signData
- (void) signData:(NSData *)alias withPlainText:(NSString *)plainText withOptions:(NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject
{
  NSError *error = nil;
  NSData *incomingData = [plainText dataUsingEncoding:NSUTF8StringEncoding];
  NSString *authMessage = nil;
  
  if (options && options[kAuthenticatePrompt]){
    authMessage = options[kAuthenticatePrompt];
  }
  
  SecKeyRef privateKeyRef = [self getPrivateKeyRef:alias withMessage:authMessage];
  
  if (privateKeyRef == nil){
    error = [NSError errorWithDomain:@"Private key not found" code:1718 userInfo:nil];
    reject(@"", @"", nil);
    return;
  }
  
  bool canSign = SecKeyIsAlgorithmSupported(privateKeyRef, kSecKeyOperationTypeSign, kSecKeyAlgorithmECDSASignatureMessageX962SHA256);
  
  if (!canSign){
    error = [NSError errorWithDomain:@"The private key cannot sign" code:1719 userInfo:nil];
    
    reject(@"", @"", nil);
    return;
  }
  
  CFErrorRef errorRef = NULL;
  NSData *signatureBytes = nil;
  
  signatureBytes = (NSData*)CFBridgingRelease(
                                              SecKeyCreateSignature(
                                                                    privateKeyRef,
                                                                    kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                                                    (CFDataRef)incomingData,
                                                                    &errorRef)
                                              );
  
  if (privateKeyRef) {CFRelease(privateKeyRef);}
  if (errorRef) {
    CFRelease(errorRef);
    // This will throw when user delete the biometry and passcode on the device and re-set
    error = [NSError errorWithDomain:@"Unable to sign digest." code:1730 userInfo:nil];
    reject(@"", @"", nil);
    return;
  }
  
  if (signatureBytes == nil){
    error = [NSError errorWithDomain:@"The data not signed" code:1731 userInfo:nil];
    reject(@"", @"", nil);
    return;
  }
  
  NSString *signatureText = [signatureBytes base64EncodedStringWithOptions:0];
  resolve(signatureText);
}

// verifySignature
- (void) verifySignature:(NSData *)alias withSignedText:(NSString *)signedText withSignature:(NSString *)signature withOptions:(NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject
{
  NSError *error = nil;
  NSData *signatureData = [[NSData alloc] initWithBase64EncodedString:signature options:0];
  NSData *signedData = [signedText dataUsingEncoding:NSUTF8StringEncoding];
  
  SecKeyRef publicKeyRef = [self getPublicKeyRef:alias];
  
  if (publicKeyRef == nil){
    error = [NSError errorWithDomain:@"Public key not found" code:1733 userInfo:nil];
    reject(@"", @"", nil);
    return;
  }
  
  bool canVerify = SecKeyIsAlgorithmSupported(publicKeyRef, kSecKeyOperationTypeVerify, kSecKeyAlgorithmECDSASignatureMessageX962SHA256);
  if (!canVerify){
    error = [NSError errorWithDomain:@"The public key cannot verify" code:1734 userInfo:nil];
    reject(@"", @"", nil);
    return;
  }
  
  CFErrorRef errorRef = NULL;
  bool isVerified = SecKeyVerifySignature(publicKeyRef,
                                          kSecKeyAlgorithmECDSASignatureMessageX962SHA256,
                                          (CFDataRef)signedData,
                                          (CFDataRef)signatureData,
                                          &errorRef);
  if (publicKeyRef) {CFRelease(publicKeyRef);}
  if (errorRef) {CFRelease(errorRef);}
  resolve(isVerified ? @(YES) : @(NO));
}


// React-Native methods
#if TARGET_OS_IOS

RCT_EXPORT_METHOD(createKey:(nonnull NSData *)alias withOptions:(nonnull NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    NSString *keyType = options[kKeyType];
    BOOL unlockedDeviceRequired = [options[kUnlockedDeviceRequired] boolValue];
    BOOL authenticationRequired = [options[kAuthenticationRequired] boolValue];
    BOOL invalidateOnNewBiometry = [options[kInvalidateOnNewBiometry] boolValue];
    
    if (keyType.intValue == ASYMMETRIC) {
      NSString* publicKey = [self getOrCreateAsymmetricKey:alias withUnlockedDeviceRequired:unlockedDeviceRequired withAuthenticationRequired:authenticationRequired withInvalidateOnNewBiometry:invalidateOnNewBiometry];
      return resolve(publicKey);
    } else {
      // getOrCreateSymmetricKey
    }
  } @catch(NSException *err) {
    reject(err.name, err.reason, nil);
  }
}

// deletePairingKeys
RCT_EXPORT_METHOD(deletePairingKeys:(NSData *)alias resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  [self deletePublicKey:alias];
  [self deletePrivateKey:alias];
  
  return resolve(@(YES));
}

// getPairingPublicKey
RCT_EXPORT_METHOD(getPairingPublicKey:(NSData *)alias resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString *pkeyString = [self getPublicKeyAsPEM:alias];
  return resolve(pkeyString);
}

// signWithPairingKey
RCT_EXPORT_METHOD(signWithPairingKey:(NSData *)alias withPlainText:(NSString *)plainText withOptions:(NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  [self signData:alias withPlainText:plainText withOptions:options resolver:resolve rejecter:reject];
}

// HELPERS
// ______________________________________________

RCT_EXPORT_METHOD(isKeyExists:(nonnull NSData *)alias withKeyType:(nonnull NSNumber *) keyType resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    if (keyType == ASYMMETRIC) {
      SecKeyRef privateKeyRef = [self getPrivateKeyRef:alias withMessage:nil];
      return resolve((privateKeyRef == nil) ? @(NO) : @(YES));
    } else {
      // getOrCreateSymmetricKey
    }
  } @catch(NSException *err) {
    reject(err.name, err.reason, nil);
  }
}

RCT_EXPORT_METHOD(isBiometryEnrolled:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    NSError *aerr = nil;
    LAContext *context = [[LAContext alloc] init];
    BOOL canBeProtected = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&aerr];
    
    if (aerr) {
      [NSException raise:@"Unexpected OSStatus" format:@"%@", aerr];
    }
    
    return resolve(canBeProtected ? @(YES) : @(NO));
  } @catch(NSException *err) {
    reject(err.name, err.reason, nil);
  }
}

RCT_EXPORT_METHOD(deviceSecurityLevel:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  NSError *aerr = nil;
  LAContext *context = [[LAContext alloc] init];
  BOOL canBeProtected = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&aerr];
  
  // has enrolled biometry
  if (!aerr && canBeProtected) {
    resolve(@"BIOMETRY");
    return;
  }
  
  canBeProtected = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&aerr];
  // has passcode
  if (!aerr && canBeProtected) {
    resolve(@"PIN_OR_PATTERN");
    return;
  }
  
  resolve(@"NOT_PROTECTED");
}

RCT_EXPORT_METHOD(getBiometryType:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  NSString *biometryType = [self getBiometryType];
  return resolve(biometryType);
}

RCT_EXPORT_METHOD(authenticateWithBiometry:(NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSString *authMessage = kAuthenticationRequired;
    if (options && options[kAuthenticatePrompt]){
      authMessage = options[kAuthenticatePrompt];
    }
    
    LAContext *context = [[LAContext alloc] init];
    context.localizedFallbackTitle = @"";
    
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:authMessage reply:^(BOOL success, NSError *biometricError) {
      if (success) {
        resolve(@(YES));
      } else if (biometricError.code == LAErrorUserCancel) {
        resolve(@(NO));
      } else {
        reject(@"biometric_error", [NSString stringWithFormat:@"Error: code: %li  reason: %@ description: %@", (long)biometricError.code, biometricError.localizedFailureReason, biometricError.localizedDescription], nil);
      }
    }];
  });
}

#endif

@end
