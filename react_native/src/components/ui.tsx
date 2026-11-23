import { ActivityIndicator, Pressable, StyleSheet, Text, TextInput, View, type TextInputProps, type ViewStyle } from 'react-native';

import { colors, radius } from '../lib/theme';

export function Button({ title, onPress, loading, variant = 'primary', disabled, style }: {
  title: string; onPress: () => void; loading?: boolean; variant?: 'primary' | 'outline' | 'danger'; disabled?: boolean; style?: ViewStyle;
}) {
  const filled = variant !== 'outline';
  const bg = variant === 'danger' ? colors.danger : colors.primary;
  return (
    <Pressable
      onPress={onPress}
      disabled={disabled || loading}
      style={({ pressed }) => [
        styles.btn,
        filled ? { backgroundColor: bg } : { borderWidth: 1.5, borderColor: colors.primary, backgroundColor: 'white' },
        (pressed || disabled) && { opacity: 0.7 },
        style,
      ]}
    >
      {loading ? <ActivityIndicator color={filled ? 'white' : colors.primary} />
        : <Text style={[styles.btnText, { color: filled ? 'white' : colors.primary }]}>{title}</Text>}
    </Pressable>
  );
}

export function Field({ label, error, ...props }: TextInputProps & { label: string; error?: string | null }) {
  return (
    <View style={{ marginBottom: 12 }}>
      <Text style={styles.label}>{label}</Text>
      <TextInput placeholderTextColor={colors.muted} {...props} style={[styles.input, props.multiline && { minHeight: 110, textAlignVertical: 'top' }, props.style]} />
      {error ? <Text style={styles.error}>{error}</Text> : null}
    </View>
  );
}

export function Chip({ label, selected, onPress }: { label: string; selected?: boolean; onPress: () => void }) {
  return (
    <Pressable onPress={onPress} style={[styles.chip, selected && { backgroundColor: colors.primary, borderColor: colors.primary }]}>
      <Text style={{ color: selected ? 'white' : colors.text, fontWeight: '600', fontSize: 13 }}>{label}</Text>
    </Pressable>
  );
}

export function Empty({ title, message, action }: { title: string; message?: string; action?: React.ReactNode }) {
  return (
    <View style={styles.empty}>
      <Text style={styles.emptyTitle}>{title}</Text>
      {message ? <Text style={styles.emptyMsg}>{message}</Text> : null}
      {action}
    </View>
  );
}

export function Loading() {
  return <View style={styles.empty}><ActivityIndicator size="large" color={colors.primary} /></View>;
}

export const styles = StyleSheet.create({
  btn: { height: 50, borderRadius: radius, alignItems: 'center', justifyContent: 'center', paddingHorizontal: 18 },
  btnText: { fontSize: 16, fontWeight: '700' },
  label: { fontSize: 13, fontWeight: '600', color: colors.muted, marginBottom: 6 },
  input: { backgroundColor: 'white', borderWidth: 1, borderColor: colors.line, borderRadius: 12, paddingHorizontal: 14, paddingVertical: 12, fontSize: 15, color: colors.text },
  error: { color: colors.danger, fontSize: 12, marginTop: 4 },
  chip: { paddingHorizontal: 14, paddingVertical: 8, borderRadius: 20, borderWidth: 1, borderColor: colors.line, backgroundColor: 'white', marginRight: 8, marginBottom: 8 },
  empty: { flex: 1, alignItems: 'center', justifyContent: 'center', padding: 32, gap: 10 },
  emptyTitle: { fontSize: 18, fontWeight: '700', color: colors.text, textAlign: 'center' },
  emptyMsg: { fontSize: 14, color: colors.muted, textAlign: 'center', lineHeight: 20 },
  screen: { flex: 1, backgroundColor: colors.background },
  h2: { fontSize: 17, fontWeight: '700', color: colors.text, marginBottom: 10 },
});
