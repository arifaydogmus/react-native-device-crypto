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
#define kAccessLevel @"accessLevel"
#define kInvalidateOnNewBiometry @"invalidateOnNewBiometry"
#define kAuthenticatePrompt @"biometryDescription"
#define kAuthenticationRequired @"Authentication is required"

typedef NS_ENUM(NSUInteger, KeyType) {
    ASYMMETRIC = 0,
    SYMMETRIC = 1,
};

typedef NS_ENUM(NSUInteger, AccessLevel) {
  ALWAYS = 0,
  UNLOCKED_DEVICE = 1,
  AUTHENTICATION_REQUIRED = 2,
};

- (SecKeyRef) getPublicKeyRef:(nonnull NSData*) alias
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

- (NSData *) getPublicKeyBits:(nonnull NSData*) alias
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

- (NSString *) getPublicKeyAsString:(nonnull NSData*) alias
{
  NSString *returnVal = nil;
  NSData *publicKeyBits = [self getPublicKeyBits:alias];
  if (publicKeyBits){
    returnVal = [[NSString alloc]initWithData:publicKeyBits encoding:NSASCIIStringEncoding];
  }
  return returnVal;
}

- (NSString*) getPublicKeyAsPEM:(nonnull NSData*) alias
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

- (bool) savePublicKeyFromRef:(nonnull SecKeyRef)publicKeyRef withAlias:(nonnull NSData*) alias
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

- (bool) deletePublicKey:(nonnull NSData*) alias
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

- (SecKeyRef) getPrivateKeyRef:(nonnull NSData*)alias withMessage:(NSString *)authPromptMessage
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

- (bool) deletePrivateKey:(nonnull NSData*) alias
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

- (BOOL) hasBiometry {
  NSError *aerr = nil;
  LAContext *context = [[LAContext alloc] init];
  return [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&aerr];
}

- (BOOL) hasPassCode {
  NSError *aerr = nil;
  LAContext *context = [[LAContext alloc] init];
  return [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthentication error:&aerr];
}

- (NSString*) getOrCreateKey:(nonnull NSData*) alias withOptions:(nonnull NSDictionary *)options
{
  SecKeyRef privateKeyRef = [self getPrivateKeyRef:alias withMessage:kAuthenticationRequired];
  if (privateKeyRef != nil) {
    return [self getPublicKeyAsPEM:alias];
  }

  CFErrorRef error = nil;
  CFStringRef keyAccessLevel = kSecAttrAccessibleAfterFirstUnlock;
  SecAccessControlCreateFlags acFlag = kSecAccessControlPrivateKeyUsage;
  int accessLevel = [options[kAccessLevel] intValue];
  BOOL invalidateOnNewBiometry = options[kInvalidateOnNewBiometry] && [options[kInvalidateOnNewBiometry] boolValue];
  
  switch(accessLevel) {
    case UNLOCKED_DEVICE:
      if (![self hasPassCode]) {
        [NSException raise:@"E1771" format:@"The device cannot meet requirements. No passcode has been set."];
      }
      keyAccessLevel = kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
      acFlag = kSecAccessControlPrivateKeyUsage;
      break;
    case AUTHENTICATION_REQUIRED:
      if (![self hasBiometry]) {
        [NSException raise:@"E1771" format:@"The device cannot meet requirements. No biometry has been enrolled."];
      }
      keyAccessLevel = kSecAttrAccessibleWhenUnlockedThisDeviceOnly;
      if (@available(iOS 11.3, *)) {
          acFlag = invalidateOnNewBiometry ? kSecAccessControlBiometryCurrentSet | kSecAccessControlPrivateKeyUsage : kSecAccessControlBiometryAny | kSecAccessControlPrivateKeyUsage;
      } else {
        acFlag = kSecAccessControlPrivateKeyUsage;
      }
      break;
    default: // ALWAYS
      keyAccessLevel = kSecAttrAccessibleAfterFirstUnlock;
      acFlag = kSecAccessControlPrivateKeyUsage;
  }
  
  SecAccessControlRef acRef = SecAccessControlCreateWithFlags(kCFAllocatorDefault, keyAccessLevel, acFlag, &error);
  
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
         (id)kSecAttrAccessControl:  (__bridge id)acRef
       },
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

// React-Native methods
#if TARGET_OS_IOS

RCT_EXPORT_METHOD(createKey:(nonnull NSData *)alias withOptions:(nonnull NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    NSString *keyType = options[kKeyType];
    NSString* publicKey = [self getOrCreateKey:alias withOptions:options];
    
    if (keyType.intValue == ASYMMETRIC) {
      resolve(publicKey);
    } else {
      resolve(publicKey != nil ? @(YES) : @(NO));
    }
  } @catch(NSException *err) {
    reject(err.name, err.reason, nil);
  }
}

RCT_EXPORT_METHOD(deleteKey:(nonnull NSData *)alias resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  [self deletePublicKey:alias];
  [self deletePrivateKey:alias];
  
  return resolve(@(YES));
}

RCT_EXPORT_METHOD(sign:(nonnull NSData *)alias withPlainText:(nonnull NSString *)plainText withOptions:(nonnull NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    CFErrorRef aerr = nil;
    NSData *textToBeSigned = [plainText dataUsingEncoding:NSUTF8StringEncoding];
    NSString *authMessage = options[kAuthenticatePrompt];
    SecKeyRef privateKeyRef = [self getPrivateKeyRef:alias withMessage:authMessage];
    
    bool canSign = SecKeyIsAlgorithmSupported(privateKeyRef, kSecKeyOperationTypeSign, kSecKeyAlgorithmECDSASignatureMessageX962SHA256);
    if (!canSign) {
      [NSException raise:@"E1719 - Device cannot sign." format:@"%@", nil];
    }
    
    NSData *signatureBytes = (NSData*)CFBridgingRelease(SecKeyCreateSignature(privateKeyRef, kSecKeyAlgorithmECDSASignatureMessageX962SHA256, (CFDataRef)textToBeSigned, &aerr));
    if (aerr) {
      [NSException raise:@"E1720 - Signature creation." format:@"%@", aerr];
    }
    
    if (privateKeyRef) { CFRelease(privateKeyRef); }
    if (aerr) { CFRelease(aerr); }
    
    resolve([signatureBytes base64EncodedStringWithOptions:0]);
  } @catch(NSException *err) {
    reject(err.name, err.description, nil);
  }
}

RCT_EXPORT_METHOD(encrypt:(nonnull NSData *)alias withPlainText:(nonnull NSString *)plainText withOptions:(nonnull NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    CFErrorRef aerr = NULL;
    NSData* cipherText = nil;
    NSData *textToBeEncrypted = [plainText dataUsingEncoding:NSUTF8StringEncoding];
    SecKeyRef publicKey = [self getPublicKeyRef:alias];
    
    BOOL canEncrypt = SecKeyIsAlgorithmSupported(publicKey, kSecKeyOperationTypeEncrypt, kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM);
    if (!canEncrypt) {
      [NSException raise:@"E1759 - Device cannot encrypt." format:@"%@", nil];
    }
    
    cipherText = (NSData*)CFBridgingRelease(
                                            SecKeyCreateEncryptedData(publicKey,
                                                                      kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM,
                                                                      (__bridge CFDataRef)textToBeEncrypted,
                                                                      &aerr));
    if (!cipherText || aerr) {
      [NSException raise:@"E1760 - Encryption error." format:@"%@", aerr];
    }
    
    if (publicKey) { CFRelease(publicKey); }
    if (aerr) { CFRelease(aerr); }
    
    resolve(@{
      @"iv": @"NotRequired",
      @"encryptedText": [cipherText base64EncodedStringWithOptions:0],
    });
  } @catch(NSException *err) {
    reject(err.name, err.description, nil);
  }
}

RCT_EXPORT_METHOD(decrypt:(nonnull NSData *)alias withPlainText:(nonnull NSString *)plainText withIvDecoded:(nonnull NSString *)ivDecoded withOptions:(nonnull NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    NSData* clearText = nil;
    CFErrorRef aerr = NULL;
    NSData *textToBeDecrypted = [[NSData alloc] initWithBase64EncodedString:plainText options:0];
    NSString *authMessage = options[kAuthenticatePrompt];
    SecKeyRef privateKeyRef = [self getPrivateKeyRef:alias withMessage:authMessage];
    
    BOOL canDecrypt = SecKeyIsAlgorithmSupported(privateKeyRef, kSecKeyOperationTypeDecrypt, kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM);
    
    if (!canDecrypt) {
      [NSException raise:@"E1759 - Device cannot encrypt." format:@"%@", nil];
    }
    
    clearText = (NSData*)CFBridgingRelease(
                                           SecKeyCreateDecryptedData(privateKeyRef,
                                                                     kSecKeyAlgorithmECIESEncryptionCofactorX963SHA256AESGCM,
                                                                     (__bridge CFDataRef)textToBeDecrypted,
                                                                     &aerr));
    
    if (!clearText || aerr) {
      [NSException raise:@"E1760 - Decryption error." format:@"%@", aerr];
    }
    
    if (privateKeyRef) { CFRelease(privateKeyRef); }
    if (aerr) { CFRelease(aerr); }
    
    resolve([[NSString alloc] initWithData:clearText   encoding:NSUTF8StringEncoding]);
  } @catch(NSException *err) {
    reject(err.name, err.description, nil);
  }
}

// HELPERS
// ______________________________________________
RCT_EXPORT_METHOD(getPublicKey:(nonnull NSData *)alias resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  return resolve([self getPublicKeyAsPEM:alias]);
}

RCT_EXPORT_METHOD(isKeyExists:(nonnull NSData *)alias withKeyType:(nonnull NSNumber *) keyType resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    SecKeyRef privateKeyRef = [self getPrivateKeyRef:alias withMessage:nil];
    resolve((privateKeyRef == nil) ? @(NO) : @(YES));
  } @catch(NSException *err) {
    reject(err.name, err.description, nil);
  }
}

RCT_EXPORT_METHOD(isBiometryEnrolled:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    resolve([self hasBiometry] ? @(YES) : @(NO));
  } @catch(NSException *err) {
    reject(err.name, err.reason, nil);
  }
}

RCT_EXPORT_METHOD(deviceSecurityLevel:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    if ([self hasBiometry]) {
      resolve(@"BIOMETRY");
      return;
    }
    if ([self hasPassCode]) {
      resolve(@"PIN_OR_PATTERN");
      return;
    }
    
    resolve(@"NOT_PROTECTED");
  } @catch(NSException *err) {
    reject(err.name, err.reason, nil);
  }
}

RCT_EXPORT_METHOD(getBiometryType:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  @try {
    NSError *aerr = nil;
    LAContext *context = [[LAContext alloc] init];
    BOOL canBeProtected = [context canEvaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics error:&aerr];
    
    if (aerr || !canBeProtected) {
      [NSException raise:@"Couldn't get biometry type" format:@"%@", aerr];
    }
    
    if (@available(iOS 11, *)) {
      if (context.biometryType == LABiometryTypeFaceID) {
        resolve(@"FACE");
        return;
      }
      else if (context.biometryType == LABiometryTypeTouchID) {
        resolve(@"TOUCH");
        return;
      }
      else if (context.biometryType == LABiometryNone) {
        resolve(@"NONE");
        return;
      } else {
        resolve(@"TOUCH");
        return;
      }
    }
    
    resolve(@"TOUCH");
  } @catch (NSException *err) {
    reject(err.name, err.description, nil);
  }
}

RCT_EXPORT_METHOD(authenticateWithBiometry:(nonnull NSDictionary *)options resolver:(RCTPromiseResolveBlock)resolve rejecter:(RCTPromiseRejectBlock)reject)
{
  dispatch_async(dispatch_get_global_queue( DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSString *authMessage = kAuthenticationRequired;
    if (options && options[kAuthenticatePrompt]){
      authMessage = options[kAuthenticatePrompt];
    }
    
    LAContext *context = [[LAContext alloc] init];
    context.localizedFallbackTitle = @"";
    [context evaluatePolicy:LAPolicyDeviceOwnerAuthenticationWithBiometrics localizedReason:authMessage reply:^(BOOL success, NSError *aerr) {
      if (success) {
        resolve(@(YES));
      } else if (aerr.code == LAErrorUserCancel) {
        resolve(@(NO));
      } else {
        reject(@"Biometry error", aerr.localizedDescription, nil);
      }
    }];
  });
}

#endif

@end
