import { useState } from "react";
import { Button, StyleSheet, Text, View } from "react-native";
import { GoogleAuth } from "react-native-nitro-google-auth";
import { SafeAreaView } from "react-native-safe-area-context";

const config = {
  iosClientId:
    "725900148453-ih6etjmooe7p8q465379bq9ute0si6v0.apps.googleusercontent.com",
  webClientId:
    "725900148453-86qelnsrjoee3pjgktgt2q35dgmvoeda.apps.googleusercontent.com",
};

function App() {
  const [status, setStatus] = useState("Idle");

  const handleSignIn = async () => {
    try {
      GoogleAuth.configure(config);

      const result = await GoogleAuth.signIn();

      if (result.error) {
        setStatus(
          `Sign-in error: ${result.error.code} — ${result.error.message}`
        );
        return;
      }

      const data = result.data;

      if (!data) {
        setStatus("Sign-in failed: no user data");
        return;
      }

      console.log("Result", data);

      const sanitizedData = {
        ...data,
        idToken: data.idToken.slice(0, 10) + "...",
      };

      setStatus(JSON.stringify(sanitizedData, null, 2));
    } catch (error) {
      console.error("Sign in failed", error);
    }
  };

  const handleSignOut = async () => {
    try {
      await GoogleAuth.signOut();
      setStatus("Signed out");
    } catch (error) {
      console.error("Sign out failed", error);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <Text style={styles.title}>react-native-nitro-google-auth</Text>
      <Text style={styles.status}>{status}</Text>
      <View style={styles.actions}>
        <Button title="Sign in" onPress={handleSignIn} />
        <Button title="Sign out" onPress={handleSignOut} />
      </View>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: "center",
    alignItems: "center",
  },
  title: {
    fontSize: 28,
    fontWeight: "600",
    marginBottom: 16,
  },
  status: {
    fontSize: 14,
    textAlign: "center",
    marginHorizontal: 20,
    marginBottom: 20,
  },
  actions: {
    gap: 12,
    width: 220,
  },
});

export default App;
