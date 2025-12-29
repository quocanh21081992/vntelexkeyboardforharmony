// entry/src/main/ets/InputMethodExtensionAbility/model/VniEngine.ets

import { TelexActionKind, TelexEngine, TelexResult } from './TelexEngine';

interface VowelInfo {
  base: string; // vowel without tone (but keeps shape â/ă/ê/ô/ơ/ư)
  tone: number; // 0..5
}


interface StripToneResult {
  baseWord: string;
  tone: number;
}
// tone order: 0 none, 1 sắc, 2 huyền, 3 hỏi, 4 ngã, 5 nặng
const TONE_TABLE: Record<string, Array<string>> = {
  'a': ['a', 'á', 'à', 'ả', 'ã', 'ạ'],
  'ă': ['ă', 'ắ', 'ằ', 'ẳ', 'ẵ', 'ặ'],
  'â': ['â', 'ấ', 'ầ', 'ẩ', 'ẫ', 'ậ'],
  'e': ['e', 'é', 'è', 'ẻ', 'ẽ', 'ẹ'],
  'ê': ['ê', 'ế', 'ề', 'ể', 'ễ', 'ệ'],
  'i': ['i', 'í', 'ì', 'ỉ', 'ĩ', 'ị'],
  'o': ['o', 'ó', 'ò', 'ỏ', 'õ', 'ọ'],
  'ô': ['ô', 'ố', 'ồ', 'ổ', 'ỗ', 'ộ'],
  'ơ': ['ơ', 'ớ', 'ờ', 'ở', 'ỡ', 'ợ'],
  'u': ['u', 'ú', 'ù', 'ủ', 'ũ', 'ụ'],
  'ư': ['ư', 'ứ', 'ừ', 'ử', 'ữ', 'ự'],
  'y': ['y', 'ý', 'ỳ', 'ỷ', 'ỹ', 'ỵ'],

  'A': ['A', 'Á', 'À', 'Ả', 'Ã', 'Ạ'],
  'Ă': ['Ă', 'Ắ', 'Ằ', 'Ẳ', 'Ẵ', 'Ặ'],
  'Â': ['Â', 'Ấ', 'Ầ', 'Ẩ', 'Ẫ', 'Ậ'],
  'E': ['E', 'É', 'È', 'Ẻ', 'Ẽ', 'Ẹ'],
  'Ê': ['Ê', 'Ế', 'Ề', 'Ể', 'Ễ', 'Ệ'],
  'I': ['I', 'Í', 'Ì', 'Ỉ', 'Ĩ', 'Ị'],
  'O': ['O', 'Ó', 'Ò', 'Ỏ', 'Õ', 'Ọ'],
  'Ô': ['Ô', 'Ố', 'Ồ', 'Ổ', 'Ỗ', 'Ộ'],
  'Ơ': ['Ơ', 'Ớ', 'Ờ', 'Ở', 'Ỡ', 'Ợ'],
  'U': ['U', 'Ú', 'Ù', 'Ủ', 'Ũ', 'Ụ'],
  'Ư': ['Ư', 'Ứ', 'Ừ', 'Ử', 'Ữ', 'Ự'],
  'Y': ['Y', 'Ý', 'Ỳ', 'Ỷ', 'Ỹ', 'Ỵ']
};

const CHAR_TO_INFO: Map<string, VowelInfo> = new Map<string, VowelInfo>();

function initMapsOnce(): void {
  if (CHAR_TO_INFO.size > 0) return;

  const keys: Array<string> = Object.keys(TONE_TABLE);
  for (let ki = 0; ki < keys.length; ki++) {
    const base: string = keys[ki];
    const forms: Array<string> = TONE_TABLE[base];
    for (let tone = 0; tone < forms.length; tone++) {
      const info: VowelInfo = { base: base, tone: tone };
      CHAR_TO_INFO.set(forms[tone], info);
    }
  }
}

function getVowelInfo(ch: string): VowelInfo | undefined {
  initMapsOnce();
  return CHAR_TO_INFO.get(ch);
}

function toneKeyFromDigit(digit: string): string | undefined {
  // VNI: 1..5 => sắc/huyền/hỏi/ngã/nặng
  if (digit === '1') return 's';
  if (digit === '2') return 'f';
  if (digit === '3') return 'r';
  if (digit === '4') return 'x';
  if (digit === '5') return 'j';
  return undefined;
}

function digitFromTone(tone: number): string {
  if (tone === 1) return '1';
  if (tone === 2) return '2';
  if (tone === 3) return '3';
  if (tone === 4) return '4';
  if (tone === 5) return '5';
  return '';
}

function stripToneAll(word: string): StripToneResult {
  let tone: number = 0;
  const chars: Array<string> = word.split('');
  for (let i = 0; i < chars.length; i++) {
    const info: VowelInfo | undefined = getVowelInfo(chars[i]);
    if (!info) continue;
    if (info.tone > 0 && tone === 0) tone = info.tone;
    // replace with tone=0 form, keeping shape
    const baseForms: Array<string> | undefined = TONE_TABLE[info.base];
    if (baseForms && baseForms.length > 0) {
      chars[i] = baseForms[0];
    }
  }
  const res: StripToneResult = { baseWord: chars.join(''), tone: tone };
  return res;
}

interface StripAllResult {
  text: string;
  changed: boolean;
}

function plainFromVowelBase(base: string): string {
  // convert vowel shape (â/ă/ê/ô/ơ/ư) to plain vowel (a/e/o/u)
  if (base === 'ă' || base === 'â') return 'a';
  if (base === 'Ă' || base === 'Â') return 'A';
  if (base === 'ê') return 'e';
  if (base === 'Ê') return 'E';
  if (base === 'ô' || base === 'ơ') return 'o';
  if (base === 'Ô' || base === 'Ơ') return 'O';
  if (base === 'ư') return 'u';
  if (base === 'Ư') return 'U';
  return base;
}

function stripAllMarks(word: string): StripAllResult {
  let changed: boolean = false;
  const chars: Array<string> = word.split('');
  for (let i = 0; i < chars.length; i++) {
    const ch: string = chars[i];

    if (ch === 'đ') {
      chars[i] = 'd';
      changed = true;
      continue;
    }
    if (ch === 'Đ') {
      chars[i] = 'D';
      changed = true;
      continue;
    }

    const info: VowelInfo | undefined = getVowelInfo(ch);
    if (!info) continue;

    const baseForms: Array<string> | undefined = TONE_TABLE[info.base];
    const base0: string = (baseForms && baseForms.length > 0) ? baseForms[0] : info.base;
    const plain: string = plainFromVowelBase(base0);

    if (plain !== ch) {
      chars[i] = plain;
      changed = true;
    }
  }
  const res: StripAllResult = { text: chars.join(''), changed: changed };
  return res;
}

function replaceLastChar(word: string, newChar: string): string {
  if (word.length === 0) return newChar;
  const chars: Array<string> = word.split('');
  chars[chars.length - 1] = newChar;
  return chars.join('');
}

function setToneByBase(base: string, tone: number): string | undefined {
  const forms: Array<string> | undefined = TONE_TABLE[base];
  if (!forms) return undefined;
  if (tone < 0 || tone >= forms.length) return undefined;
  return forms[tone];
}

function tryShapeToggle(base: string, digit: string): string | undefined {
  // digit6: a<->â, e<->ê, o<->ô
  if (digit === '6') {
    if (base === 'a') return 'â';
    if (base === 'â') return 'a';
    if (base === 'e') return 'ê';
    if (base === 'ê') return 'e';
    if (base === 'o') return 'ô';
    if (base === 'ô') return 'o';
    if (base === 'A') return 'Â';
    if (base === 'Â') return 'A';
    if (base === 'E') return 'Ê';
    if (base === 'Ê') return 'E';
    if (base === 'O') return 'Ô';
    if (base === 'Ô') return 'O';
    return undefined;
  }

  // digit7: o<->ơ, u<->ư
  if (digit === '7') {
    if (base === 'o') return 'ơ';
    if (base === 'ơ') return 'o';
    if (base === 'u') return 'ư';
    if (base === 'ư') return 'u';
    if (base === 'O') return 'Ơ';
    if (base === 'Ơ') return 'O';
    if (base === 'U') return 'Ư';
    if (base === 'Ư') return 'U';
    return undefined;
  }

  // digit8: a<->ă
  if (digit === '8') {
    if (base === 'a') return 'ă';
    if (base === 'ă') return 'a';
    if (base === 'A') return 'Ă';
    if (base === 'Ă') return 'A';
    return undefined;
  }

  return undefined;
}

function tryToggleD9(word: string): string | undefined {
  if (word.length === 0) return undefined;
  const last: string = word[word.length - 1];
  if (last === 'd') return replaceLastChar(word, 'đ');
  if (last === 'đ') return replaceLastChar(word, 'd');
  if (last === 'D') return replaceLastChar(word, 'Đ');
  if (last === 'Đ') return replaceLastChar(word, 'D');
  return undefined;
}

function isDigit(ch: string): boolean {
  return ch === '0' || ch === '1' || ch === '2' || ch === '3' || ch === '4' || ch === '5' || ch === '6' || ch === '7' || ch === '8' || ch === '9';
}

/**
 * VNI Engine:
 * - digits 1..5: tone
 * - digit 6: â/ê/ô
 * - digit 7: ơ/ư
 * - digit 8: ă
 * - digit 9: đ
 * - normal letters: do NOT Telex-transform, but auto reflow tone when word changes.
 */
export class VniEngine {
  // only used as a "tone placement helper" (s/f/r/x/j) so we don't have to re-implement vowel position rules
  private toneHelper: TelexEngine = new TelexEngine(true, false);

  apply(currentWord: string, keyChar: string): TelexResult {
    const out: TelexResult = new TelexResult();

    if (keyChar.length === 0) {
      out.kind = TelexActionKind.None;
      out.text = currentWord;
      out.newWord = currentWord;
      return out;
    }

    // --- handle VNI digits ---
    if (keyChar.length === 1 && isDigit(keyChar)) {
      // 0 => remove all marks (tone + vowel shape + đ)
      if (keyChar === '0') {
        const removed: StripAllResult = stripAllMarks(currentWord);
        if (removed.changed) {
          out.kind = TelexActionKind.Replace;
          out.text = removed.text;
          out.newWord = removed.text;
          return out;
        }
        // allow typing 0 normally
        out.kind = TelexActionKind.Insert;
        out.text = keyChar;
        out.newWord = currentWord + keyChar;
        return out;
      }

      // 9 => đ toggle
      if (keyChar === '9') {
        const toggled: string | undefined = tryToggleD9(currentWord);
        if (toggled !== undefined) {
          out.kind = TelexActionKind.Replace;
          out.text = toggled;
          out.newWord = toggled;
          return out;
        }
        out.kind = TelexActionKind.Insert;
        out.text = keyChar;
        out.newWord = currentWord + keyChar;
        return out;
      }

      // 6/7/8 => vowel shape toggles on LAST CHAR (only when last char is a vowel)
      if (keyChar === '6' || keyChar === '7' || keyChar === '8') {
        if (currentWord.length === 0) {
          out.kind = TelexActionKind.Insert;
          out.text = keyChar;
          out.newWord = currentWord + keyChar;
          return out;
        }

        const last: string = currentWord[currentWord.length - 1];
        const info: VowelInfo | undefined = getVowelInfo(last);
        if (!info) {
          out.kind = TelexActionKind.Insert;
          out.text = keyChar;
          out.newWord = currentWord + keyChar;
          return out;
        }

        const targetBase: string | undefined = tryShapeToggle(info.base, keyChar);
        if (!targetBase) {
          out.kind = TelexActionKind.Insert;
          out.text = keyChar;
          out.newWord = currentWord + keyChar;
          return out;
        }

        // keep tone when changing shape: á + 6 => ấ, ấ + 6 => á
        const newCh: string | undefined = setToneByBase(targetBase, info.tone);
        if (!newCh) {
          out.kind = TelexActionKind.Insert;
          out.text = keyChar;
          out.newWord = currentWord + keyChar;
          return out;
        }

        const next: string = replaceLastChar(currentWord, newCh);
        const relocated: string = this.relocateToneIfNeeded(next);

        out.kind = TelexActionKind.Replace;
        out.text = relocated;
        out.newWord = relocated;
        return out;
      }

      // 1..5 => tone (gõ lặp để tắt dấu)
      const desiredTone: number = Number.parseInt(keyChar, 10);
      if (desiredTone >= 1 && desiredTone <= 5) {
        const stripped: StripToneResult = stripToneAll(currentWord);

        // press same tone digit again => remove tone
        if (stripped.tone === desiredTone) {
          out.kind = TelexActionKind.Replace;
          out.text = stripped.baseWord;
          out.newWord = stripped.baseWord;
          return out;
        }

        const tKey: string | undefined = toneKeyFromDigit(keyChar);
        if (tKey) {
          const r = this.toneHelper.apply(stripped.baseWord, tKey);
          if (r.kind === TelexActionKind.Replace) {
            out.kind = TelexActionKind.Replace;
            out.text = r.newWord;
            out.newWord = r.newWord;
            return out;
          }
        }

        // no vowel => keep digit as literal
        out.kind = TelexActionKind.Insert;
        out.text = keyChar;
        out.newWord = currentWord + keyChar;
        return out;
      }

      // other digits (should not happen here) => literal
      out.kind = TelexActionKind.Insert;
      out.text = keyChar;
      out.newWord = currentWord + keyChar;
      return out;
    }

    out.kind = TelexActionKind.Insert;
    out.text = keyChar;
    out.newWord = raw;
    return out;
  }

  /**
   * Auto reflow tone after user adds more letters (like UniKey behavior):
   * - detect existing tone in the word
   * - strip the tone
   * - re-apply the same tone key using TelexEngine (it knows vowel position rules)
   */
  private relocateToneIfNeeded(word: string): string {
    const stripped = stripToneAll(word);
    if (stripped.tone <= 0) return word;

    const digit: string = digitFromTone(stripped.tone);
    const tKey: string | undefined = toneKeyFromDigit(digit);
    if (!tKey) return word;

    const r = this.toneHelper.apply(stripped.baseWord, tKey);
    if (r.kind === TelexActionKind.Replace) return r.newWord;
    return word;
  }
}
