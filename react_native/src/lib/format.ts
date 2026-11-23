export function formatPrice(price: number, currency = 'TND', rent = false): string {
  const n = Math.round(price).toString().replace(/\B(?=(\d{3})+(?!\d))/g, ' ');
  return `${n} ${currency}${rent ? ' / mois' : ''}`;
}

export function timeAgo(date?: Date | null): string {
  if (!date) return '';
  const s = Math.max(0, (Date.now() - date.getTime()) / 1000);
  if (s < 60) return 'à l’instant';
  if (s < 3600) return `il y a ${Math.floor(s / 60)} min`;
  if (s < 86400) return `il y a ${Math.floor(s / 3600)} h`;
  if (s < 86400 * 7) return `il y a ${Math.floor(s / 86400)} j`;
  return date.toLocaleDateString('fr-FR');
}

export function toDate(v: unknown): Date | null {
  if (!v) return null;
  if (v instanceof Date) return v;
  const t = v as { toDate?: () => Date };
  return typeof t.toDate === 'function' ? t.toDate() : null;
}

/** French message for a Firebase error code. */
export function errorMessage(e: unknown): string {
  const code = (e as { code?: string })?.code ?? '';
  switch (code) {
    case 'auth/invalid-email': return 'Adresse e-mail invalide.';
    case 'auth/invalid-credential':
    case 'auth/wrong-password':
    case 'auth/user-not-found': return 'E-mail ou mot de passe incorrect.';
    case 'auth/email-already-in-use': return 'Cet e-mail est déjà utilisé.';
    case 'auth/weak-password': return 'Mot de passe trop faible (6 caractères minimum).';
    case 'auth/too-many-requests': return 'Trop de tentatives. Réessayez plus tard.';
    case 'auth/network-request-failed':
    case 'unavailable': return 'Problème de réseau. Vérifiez votre connexion.';
    case 'permission-denied': return 'Action non autorisée.';
    default: {
      const msg = (e as { message?: string })?.message;
      return msg && !code ? msg : 'Une erreur est survenue. Réessayez.';
    }
  }
}
