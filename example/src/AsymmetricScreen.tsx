import * as React from 'react';

import {
  SafeAreaView,
  ScrollView,
  View,
  Text,
  Button,
  TextInput,
} from 'react-native';
import DeviceCrypto, { KeyTypes } from 'react-native-device-crypto';
import SwitchBox from './components/SwitchBox';
import styles from './styles';

const AsymmetricScreen = () => {
  const [error, setError] = React.useState<string>('');
  const [signature, setSignature] = React.useState<string>('');
  const [textToBeSigned, setTextToBeSigned] =
    React.useState<string>('text to be signed');
  const [publicKey, setPublicKey] = React.useState<string>('');
  const [alias, setAlias] = React.useState<string>('test');
  const [unlockedDeviceRequired, setUnlockedDeviceRequired] =
    React.useState<boolean>(false);
  const [authenticationRequired, setAuthenticationRequired] =
    React.useState<boolean>(false);
  const [invalidateOnNewBiometry, setInvalidateOnNewBiometry] =
    React.useState<boolean>(false);
  const [isKeyExists, setIsKeyExists] = React.useState<boolean>(false);
  const [showSignature, setShowSignature] = React.useState<boolean>(false);

  const createKey = async () => {
    try {
      const res = await DeviceCrypto.getOrcreateAsymmetricKey(alias, {
        unlockedDeviceRequired,
        authenticationRequired,
        invalidateOnNewBiometry,
      });
      setPublicKey(res);
      setSignature('');
      setShowSignature(false);
    } catch (err: any) {
      console.log(err);
      setError(err.message);
    }
  };

  const sign = async () => {
    try {
      setShowSignature(false);
      const res = await DeviceCrypto.sign(alias, textToBeSigned, {
        biometryTitle: 'Authenticate',
        biometrySubTitle: 'Signing',
        biometryDescription: 'Authenticate your self to sign the text',
      });
      setSignature(res);
      setShowSignature(true);
    } catch (err: any) {
      setError(err.message);
    }
  };

  const deleteKey = async () => {
    try {
      await DeviceCrypto.deleteKey(alias);
      const res = await DeviceCrypto.isKeyExists(alias, KeyTypes.ASYMMETRIC);
      setIsKeyExists(res);
      setShowSignature(false);
    } catch (err: any) {
      setError(err.message);
    }
  };

  React.useEffect(() => {
    DeviceCrypto.isKeyExists(alias, KeyTypes.ASYMMETRIC).then(
      (exist: boolean) => {
        setIsKeyExists(exist);
        if (exist) {
          DeviceCrypto.getPublicKey(alias).then(setPublicKey);
        }
      }
    );
  }, [alias, isKeyExists, publicKey]);

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
        <SwitchBox
          onChange={setUnlockedDeviceRequired}
          text="Unlocked device required"
        />
        <SwitchBox
          onChange={setAuthenticationRequired}
          text="Authentication required"
        />
        <SwitchBox
          onChange={setInvalidateOnNewBiometry}
          text="Invalidate key on new biometry/remove"
        />
        <Button onPress={createKey} title="Create key" color="#841584" />
        <Text style={styles.hint}>
          That will create a new key or return public key of the existing key.
        </Text>

        {isKeyExists ? (
          <React.Fragment>
            <View style={styles.separator} />
            <Text>Public Key</Text>
            <Text style={styles.hint}>{publicKey}</Text>
          </React.Fragment>
        ) : null}

        {isKeyExists ? (
          <React.Fragment>
            <View style={styles.separator} />
            <Text>Text to be signed</Text>
            <TextInput
              style={styles.input}
              onChangeText={setTextToBeSigned}
              value={textToBeSigned}
            />
            <Button onPress={sign} title="Sign the text" color="#841584" />
          </React.Fragment>
        ) : null}

        {showSignature ? (
          <React.Fragment>
            <Text>Signature</Text>
            <Text>{signature}</Text>
          </React.Fragment>
        ) : null}

        {isKeyExists ? (
          <React.Fragment>
            <View style={styles.separator} />
            <Button
              onPress={deleteKey}
              title="Delete the key"
              color="#841584"
            />
          </React.Fragment>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
};

export default AsymmetricScreen;
