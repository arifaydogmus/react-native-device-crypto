import * as React from 'react';

import { SafeAreaView, ScrollView, View, Text, Button } from 'react-native';
import DeviceCrypto from 'react-native-device-crypto';
import styles from './styles';

const BiometryScreen = () => {
  const [error, setError] = React.useState<string | undefined>('');
  const [isAuthenticated, setIsAuthenticated] = React.useState<boolean>();

  const simpleAuthentication = async () => {
    try {
      const res = await DeviceCrypto.authenticateWithBiometry({
        biometryDescription: 'Description',
        biometrySubTitle: 'Sub title',
        biometryTitle: ' Title',
      });
      setIsAuthenticated(res);
      setError('');
    } catch (err: any) {
      setError(err.message);
      setIsAuthenticated(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <ScrollView>
        <Text>Confirm with biometry</Text>
        <Button
          onPress={simpleAuthentication}
          title="Fire Biometric Authentication"
          color="#841584"
        />

        {isAuthenticated ? (
          <Text style={styles.positive}>SUCCESS</Text>
        ) : (
          <Text style={styles.negative}>FAILED</Text>
        )}

        {error ? (
          <React.Fragment>
            <View style={styles.errorBox}>
              <Text>ERROR: {error}</Text>
            </View>
          </React.Fragment>
        ) : null}
      </ScrollView>
    </SafeAreaView>
  );
};

export default BiometryScreen;
