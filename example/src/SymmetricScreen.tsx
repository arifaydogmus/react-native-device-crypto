import * as React from 'react';

import {
  SafeAreaView,
  ScrollView,
  View,
  TextInput,
  Button,
  Text,
} from 'react-native';
import { Dropdown } from 'react-native-element-dropdown';
import DeviceCrypto, {
  KeyTypes,
  AccessLevel,
} from 'react-native-device-crypto';
import SwitchBox from './components/SwitchBox';
import { accessLevelOptions } from './AsymmetricScreen';
import styles from './styles';

const SymmetricScreen = () => {
  const [error, setError] = React.useState<string>('');
  const [isKeyExists, setIsKeyExists] = React.useState<boolean>(false);
  const [accessLevel, setAccessLevel] = React.useState<AccessLevel>(0);
  const [invalidateOnNewBiometry, setInvalidateOnNewBiometry] =
    React.useState<boolean>(false);
  const [alias, setAlias] = React.useState<string>('test');
  const [textToBeEncrypted, setTextToBeEncrypted] = React.useState<string>(
    'simple text to encrypt'
  );
  const [decryptedText, setDecryptedText] = React.useState<string>('');
  const [encryptedText, setEncryptedText] = React.useState<string>('');
  const [ivText, setIvText] = React.useState<string>('');

  const createKey = async () => {
    setError('');
    try {
      const res = await DeviceCrypto.getOrCreateSymmetricKey(alias, {
        accessLevel,
        invalidateOnNewBiometry,
      });
      setIsKeyExists(res);
      return res;
    } catch (err: any) {
      setError(err.message);
      return false;
    }
  };

  const encrypt = async () => {
    setError('');
    setEncryptedText('');
    setDecryptedText('');
    try {
      const res = await DeviceCrypto.encrypt(alias, textToBeEncrypted, {
        biometryTitle: 'Authentication is required',
        biometrySubTitle: 'Encryption',
        biometryDescription: 'Authenticate your self to encrypt given text.',
      });
      setIvText(res.iv);
      setEncryptedText(res.encryptedText);
    } catch (err: any) {
      setError(err.message);
    }
  };

  const decrypt = async () => {
    setError('');
    try {
      const res = await DeviceCrypto.decrypt(alias, encryptedText, ivText, {
        biometryTitle: 'Authentication is required',
        biometrySubTitle: 'Encryption',
        biometryDescription: 'Authenticate your self to encrypt given text.',
      });
      setDecryptedText(res);
    } catch (err: any) {
      setError(err.message);
    }
  };

  const deleteKey = async () => {
    setError('');
    try {
      await DeviceCrypto.deleteKey(alias);
      setIsKeyExists(false);
    } catch (err: any) {
      setError(err.message);
    }
  };

  React.useEffect(() => {
    DeviceCrypto.isKeyExists(alias, KeyTypes.SYMMETRIC).then(setIsKeyExists);
  }, [isKeyExists, alias]);

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView>
        {error ? (
          <React.Fragment>
            <View style={styles.errorBox}>
              <Text>ERROR: {error}</Text>
            </View>
          </React.Fragment>
        ) : null}

        <Text>Key alias</Text>
        <TextInput style={styles.input} onChangeText={setAlias} value={alias} />

        <Text>Key accessibility</Text>
        <Dropdown
          data={accessLevelOptions}
          search={false}
          searchPlaceholder="Search"
          labelField="label"
          valueField="value"
          placeholder="Select item"
          value={accessLevel}
          onChange={(item) => {
            setAccessLevel(item.value);
            console.log(item);
          }}
          style={styles.dropdown}
        />

        <SwitchBox
          onChange={setInvalidateOnNewBiometry}
          text="Invalidate key on new biometry/remove"
        />
        <Button onPress={createKey} title="Create key" color="#007eb7" />
        <Text style={styles.hint}>
          That will create a new key or return public key of the existing key.
        </Text>

        {isKeyExists ? (
          <React.Fragment>
            <View style={styles.separator} />
            <Text>Text to be encrypted</Text>
            <TextInput
              style={styles.input}
              onChangeText={setTextToBeEncrypted}
              value={textToBeEncrypted}
            />
            <Button
              onPress={encrypt}
              title="Encrypt the text"
              color="#007eb7"
            />
          </React.Fragment>
        ) : null}

        {isKeyExists ? (
          <React.Fragment>
            <View style={styles.separator} />
            <Text>Encrypted text to decrypt</Text>
            <TextInput
              style={styles.input}
              onChangeText={setEncryptedText}
              value={encryptedText}
            />
            <Text>Initialization Vector</Text>
            <TextInput
              style={styles.input}
              onChangeText={setIvText}
              value={ivText}
            />
            <Button
              onPress={decrypt}
              title="Decrypt the text"
              color="#007eb7"
            />
            <Text>Decrypted message</Text>
            <Text>{decryptedText}</Text>
          </React.Fragment>
        ) : null}

        {isKeyExists ? (
          <React.Fragment>
            <View style={styles.separator} />
            <Button
              onPress={deleteKey}
              title="Delete the key"
              color="#007eb7"
            />
          </React.Fragment>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
};

export default SymmetricScreen;
