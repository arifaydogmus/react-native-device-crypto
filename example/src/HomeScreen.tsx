import * as React from 'react';

import { View, Text } from 'react-native';
import Icon from 'react-native-vector-icons/Ionicons';
import DeviceCrypto from 'react-native-device-crypto';
import styles from './styles';

const HomeScreen = () => {
  const [error, setError] = React.useState<string | undefined>('');
  const [isBiometryEnrolled, setIsBiometryEnrolled] = React.useState<
    boolean | undefined
  >();
  const [deviceSecurityLevel, setDeviceSecurityLevel] = React.useState<
    string | undefined
  >();
  const [biometryType, setBiometryType] = React.useState<string | undefined>();

  const deviceStatus = async () => {
    try {
      setIsBiometryEnrolled(await DeviceCrypto.isBiometryEnrolled());
      setBiometryType(await DeviceCrypto.getBiometryType());
      setDeviceSecurityLevel(await DeviceCrypto.deviceSecurityLevel());
    } catch (err: any) {
      setError(err.message);
    }
  };

  React.useEffect(() => {
    deviceStatus();
  }, []);

  const getBiometryType = () => {
    let biometryTypeIcon = 'close-circle';
    let biometryTypeName = 'None';

    switch (biometryType) {
      case 'TOUCH':
        biometryTypeName = 'Fingerprint';
        biometryTypeIcon = 'finger-print';
        break;
      case 'FACE':
        biometryTypeName = 'Face';
        biometryTypeIcon = 'happy';
        break;
      case 'IRIS':
        biometryTypeName = 'Iris';
        biometryTypeIcon = 'eye';
        break;
    }
    return (
      <View style={styles.box}>
        <Text>Biometry scanner</Text>
        <Icon name={biometryTypeIcon} size={64} />
        <Text>{biometryTypeName}</Text>
      </View>
    );
  };

  const getSecurityLevelComponent = () => {
    let securityLevelIcon = 'close-circle';
    let securityLevelName = 'None';

    switch (deviceSecurityLevel) {
      case 'PIN_OR_PATTERN':
        securityLevelName = 'Pin or Password';
        securityLevelIcon = 'code-working';
        break;
      case 'BIOMETRY':
        securityLevelName = 'Biometry';
        securityLevelIcon = 'finger-print';
        break;
    }
    return (
      <View style={styles.box}>
        <Text>Security level:</Text>
        <Icon name={securityLevelIcon} size={64} />
        <Text>{securityLevelName}</Text>
      </View>
    );
  };

  return (
    <View style={styles.container}>
      {error ? (
        <View style={styles.errorBox}>
          <Text>ERROR: {error}</Text>
        </View>
      ) : null}
      <View style={styles.infoBoxes}>
        {getBiometryType()}

        {getSecurityLevelComponent()}
      </View>
      <View style={styles.infoBoxes}>
        <View style={styles.box}>
          <Text>Biometry enrolled</Text>
          <Icon
            name={isBiometryEnrolled ? 'checkmark-done-circle' : 'close-circle'}
            size={64}
            color={isBiometryEnrolled ? '#057623' : '#ce3a04'}
          />
        </View>
      </View>
    </View>
  );
};

export default HomeScreen;
