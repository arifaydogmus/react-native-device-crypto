import { StyleSheet } from 'react-native';

const styles = StyleSheet.create({
  container: {
    marginHorizontal: 10,
    marginVertical: 5,
    flex: 1,
    flexDirection: 'column',
    justifyContent: 'flex-start',
    alignItems: 'stretch',
  },
  info: {
    padding: 5,
  },
  result: {
    marginTop: 8,
    padding: 10,
    backgroundColor: '#996600',
  },
  errorBox: {
    marginTop: 8,
    padding: 10,
    backgroundColor: '#FF6644',
  },
  switchBox: {
    flexDirection: 'row',
    marginVertical: 4,
  },
  switchBoxText: {
    flex: 0.85,
  },
  switchBoxSwitch: {
    flex: 0.15,
  },
  separator: {
    marginVertical: 4,
    borderBottomColor: '#434343',
    borderBottomWidth: StyleSheet.hairlineWidth,
  },
  input: {
    marginBottom: 4,
    borderWidth: 1,
    borderColor: '#A8A8A8',
    backgroundColor: '#F8F8F8',
    paddingVertical: 5,
    paddingHorizontal: 10,
  },
  hint: {
    fontSize: 10,
    color: '#666666',
    fontStyle: 'italic',
  },
});

export default styles;
