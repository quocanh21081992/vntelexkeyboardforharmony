// entry/src/main/ets/InputMethodExtensionAbility/model/SettingsStore.ets
// Settings store for the InputMethodExtensionAbility (keyboard).

import preferences from '@ohos.data.preferences';

export const PREF_NAME: string = 'vk_settings_ime';
export const KEY_KEYBOARD_HEIGHT_VP: string = 'keyboard_height_vp';
export const KEY_KEYBOARD_RELOAD_SEQ: string = 'keyboard_reload_seq';

// Input method: 'telex' | 'vni'
export const KEY_INPUT_METHOD: string = 'input_method';
export type InputMethodType = 'telex' | 'vni';
export const DEFAULT_INPUT_METHOD: InputMethodType = 'telex';

// Defaults / bounds (vp)
export const DEFAULT_KEYBOARD_HEIGHT_VP: number = 270;
export const MIN_KEYBOARD_HEIGHT_VP: number = 180;
export const MAX_KEYBOARD_HEIGHT_VP: number = 420;

export function clampKeyboardHeightVp(v: number): number {
  let n: number = Math.round(v);
  if (!isFinite(n)) {
    return DEFAULT_KEYBOARD_HEIGHT_VP;
  }
  if (n < MIN_KEYBOARD_HEIGHT_VP) n = MIN_KEYBOARD_HEIGHT_VP;
  if (n > MAX_KEYBOARD_HEIGHT_VP) n = MAX_KEYBOARD_HEIGHT_VP;
  return n;
}

// NOTE: Some projects enable strict lint rules for types.
// preferences.get() returns primitive types, so keep the conversion explicit here.
function toNumber(v: number | string | boolean, fallback: number): number {
  if (typeof v === 'number') return v;
  const n: number = Number(String(v));
  return Number.isFinite(n) ? n : fallback;
}

export async function readKeyboardHeightVp(context: object): Promise<number> {
  try {
    // Preferences instances are cached in-process. When the setting is changed in another
    // process (e.g., UIAbility), we must drop the cached instance to re-read from disk.
    // (This API may be unavailable on older SDKs; ignore if so.)
    try {
      await preferences.removePreferencesFromCache(context as never, PREF_NAME);
    } catch {
      // ignore
    }
    const pref = await preferences.getPreferences(context as never, PREF_NAME);
    // In current SDK typings, pref.get() returns Promise<ValueType>.
    // Keep this strictly typed (no any/unknown) and convert explicitly.
    const raw: number | string | boolean = (await pref.get(
      KEY_KEYBOARD_HEIGHT_VP,
      DEFAULT_KEYBOARD_HEIGHT_VP
    )) as number | string | boolean;
    return clampKeyboardHeightVp(toNumber(raw, DEFAULT_KEYBOARD_HEIGHT_VP));
  } catch {
    return DEFAULT_KEYBOARD_HEIGHT_VP;
  }
}

export async function writeKeyboardHeightVp(context: object, heightVp: number): Promise<void> {
  try {
    const pref = await preferences.getPreferences(context as never, PREF_NAME);
    const v: number = clampKeyboardHeightVp(heightVp);
    try {
      pref.put(KEY_KEYBOARD_HEIGHT_VP, v);
    } catch {
      // ignore
    }
    try {
      await pref.flush();
    } catch {
      // ignore
    }
  } catch {
    // ignore
  }
}

export async function readKeyboardReloadSeq(context: object): Promise<number> {
  try {
    try { await preferences.removePreferencesFromCache(context as never, PREF_NAME); } catch { /* ignore */ }
    const pref = await preferences.getPreferences(context as never, PREF_NAME);
    const raw: number | string | boolean = (await pref.get(
      KEY_KEYBOARD_RELOAD_SEQ,
      0
    )) as number | string | boolean;
    const n: number = toNumber(raw, 0);
    return Number.isFinite(n) ? Math.floor(n) : 0;
  } catch {
    return 0;
  }
}

export async function bumpKeyboardReloadSeq(context: object): Promise<number> {
  try {
    const pref = await preferences.getPreferences(context as never, PREF_NAME);
    const raw: number | string | boolean = (await pref.get(KEY_KEYBOARD_RELOAD_SEQ, 0)) as number | string | boolean;
    const cur: number = Number.isFinite(toNumber(raw, 0)) ? Math.floor(toNumber(raw, 0)) : 0;
    const next: number = cur + 1;
    try { pref.put(KEY_KEYBOARD_RELOAD_SEQ, next); } catch { /* ignore */ }
    try { await pref.flush(); } catch { /* ignore */ }
    return next;
  } catch {
    return 0;
  }
}

export async function readInputMethod(context: object): Promise<InputMethodType> {
  try {
    try {
      await preferences.removePreferencesFromCache(context as never, PREF_NAME);
    } catch {
      // ignore
    }
    const pref = await preferences.getPreferences(context as never, PREF_NAME);
    const raw: number | string | boolean = (await pref.get(KEY_INPUT_METHOD, DEFAULT_INPUT_METHOD)) as number | string | boolean;
    const v: string = String(raw).toLowerCase();
    if (v === 'vni') return 'vni';
    return 'telex';
  } catch {
    return DEFAULT_INPUT_METHOD;
  }
}

export async function writeInputMethod(context: object, method: InputMethodType): Promise<void> {
  try {
    const pref = await preferences.getPreferences(context as never, PREF_NAME);
    const v: InputMethodType = (method === 'vni') ? 'vni' : 'telex';
    try {
      pref.put(KEY_INPUT_METHOD, v);
    } catch {
      // ignore
    }
    try {
      await pref.flush();
    } catch {
      // ignore
    }
  } catch {
    // ignore
  }
}
