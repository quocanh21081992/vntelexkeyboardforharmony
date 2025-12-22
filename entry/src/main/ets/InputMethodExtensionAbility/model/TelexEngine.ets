// entry/src/main/ets/InputMethodExtensionAbility/model/TelexEngine.ets

export enum TelexActionKind {
  Insert = 0,
  Replace = 1,
  None = 2
}

export class TelexResult {
  kind: TelexActionKind = TelexActionKind.None;
  text: string = '';
  // COMPAT: KeyboardController đang dùng newWord
  newWord: string = '';
}

enum VowelGroup {
  A = 0,
  E = 1,
  I = 2,
  O = 3,
  U = 4,
  Y = 5,

  AA = 10, // â
  AW = 11, // ă
  EE = 12, // ê
  OO = 13, // ô
  OW = 14, // ơ
  UW = 15  // ư
}

class VowelInfo {
  base: string = '';
  group: VowelGroup = VowelGroup.A;
  tone: number = 0; // 0 none, 1..5
}

class VowelSpan {
  start: number = 0;
  end: number = 0;
}

export class TelexEngine {
  modernOrthography: boolean = true;
  private compatFlag: boolean = false;

  // COMPAT CONSTRUCTOR: KeyboardController gọi new TelexEngine(true, false)
  constructor(modernOrthography: boolean = true, compatFlag: boolean = false) {
    this.modernOrthography = modernOrthography;
    this.compatFlag = compatFlag;
  }

  // COMPAT METHOD: KeyboardController gọi this.telex.apply(word, keyChar)
  apply(currentWord: string, keyChar: string): TelexResult {
    if (this.compatFlag) {
      // no-op: tránh warning never read
    }
    return this.applyKey(currentWord, keyChar);
  }

  // ---------- Public API ----------
  applyKey(currentWord: string, keyChar: string): TelexResult {
    const out: TelexResult = new TelexResult();

    if (keyChar.length === 0) {
      out.kind = TelexActionKind.None;
      out.text = currentWord;
      out.newWord = currentWord;
      return out;
    }

    // ✅ dd => đ (kèm "late d": di + d => đi)
    if (this.isDKey(keyChar)) {
      const nextD: string = this.applyDKey(currentWord, keyChar);
      if (nextD === currentWord) {
        out.kind = TelexActionKind.Insert;
        out.text = keyChar;
        out.newWord = currentWord + keyChar;
      } else {
        out.kind = TelexActionKind.Replace;
        out.text = nextD;
        out.newWord = nextD;
      }
      return out;
    }

    // Shape keys: a/e/o/w
    if (this.isShapeKey(keyChar)) {
      const next: string = this.applyShapeKey(currentWord, keyChar);
      if (next === currentWord) {
        out.kind = TelexActionKind.Insert;
        out.text = keyChar;
        out.newWord = currentWord + keyChar;
      } else {
        out.kind = TelexActionKind.Replace;
        out.text = next;
        out.newWord = next;
      }
      return out;
    }

    // Tone keys: s f r x j
    if (this.isToneKey(keyChar)) {
      const next: string = this.applyToneKey(currentWord, keyChar);
      if (next === currentWord) {
        out.kind = TelexActionKind.Insert;
        out.text = keyChar;
        out.newWord = currentWord + keyChar;
      } else {
        out.kind = TelexActionKind.Replace;
        out.text = next;
        out.newWord = next;
      }
      return out;
    }

    // Normal char
    out.kind = TelexActionKind.Insert;
    out.text = keyChar;
    out.newWord = currentWord + keyChar;
    return out;
  }

  // ---------- Key classification ----------
  private isToneKey(ch: string): boolean {
    const c: string = ch.toLowerCase();
    return c === 's' || c === 'f' || c === 'r' || c === 'x' || c === 'j';
  }

  private isShapeKey(ch: string): boolean {
    const c: string = ch.toLowerCase();
    return c === 'a' || c === 'e' || c === 'o' || c === 'w';
  }

  private isDKey(ch: string): boolean {
    return ch.toLowerCase() === 'd';
  }

  // ---------- dd => đ (with "late d" heuristic) ----------
  private applyDKey(word: string, keyChar: string): string {
    if (word.length === 0) return word;

    const chars: Array<string> = word.split('');
    const lastIdx: number = chars.length - 1;
    const last: string = chars[lastIdx];
    const k: string = keyChar;

    // 1) Normal Telex dd at the end: d/D -> đ/Đ
    if (last === 'd') {
      chars[lastIdx] = 'đ';
      return chars.join('');
    }
    if (last === 'D') {
      chars[lastIdx] = 'Đ';
      return chars.join('');
    }

    // toggle off: đ/Đ -> d/D + append d/D
    if (last === 'đ') {
      chars[lastIdx] = 'd';
      return chars.join('') + k;
    }
    if (last === 'Đ') {
      chars[lastIdx] = 'D';
      return chars.join('') + k;
    }

    // 2) ✅ "late d": di + d => đi (đổi d đầu -> đ, không append d)
    const first: string = chars[0];
    const MAX_VI_SYLLABLE_LEN: number = 6; // có thể tăng lên 7-8 nếu muốn

    if (chars.length <= MAX_VI_SYLLABLE_LEN) {
      const startsWithD: boolean = (first === 'd' || first === 'D');
      const hasDDash: boolean = (word.indexOf('đ') >= 0 || word.indexOf('Đ') >= 0);

      if (startsWithD && !hasDDash) {
        let hasVowel: boolean = false;
        for (let i = 0; i < chars.length; i++) {
          if (this.isVowelChar(chars[i])) {
            hasVowel = true;
            break;
          }
        }

        if (hasVowel) {
          chars[0] = (first === 'D') ? 'Đ' : 'đ';
          return chars.join('');
        }
      }
    }

    return word;
  }

  // ---------- Vowel helpers ----------
  private toBaseLetter(ch: string): string {
    const info: VowelInfo | undefined = this.getVowelInfo(ch);
    if (!info) return ch.toLowerCase();
    return info.base;
  }

  // tone order: 1 sắc,2 huyền,3 hỏi,4 ngã,5 nặng
  private toneOfKey(k: string): number {
    const c: string = k.toLowerCase();
    if (c === 's') return 1;
    if (c === 'f') return 2;
    if (c === 'r') return 3;
    if (c === 'x') return 4;
    if (c === 'j') return 5;
    return 0;
  }

  private getVowelInfo(ch: string): VowelInfo | undefined {
    // ✅ Hỗ trợ chữ HOA (A, Â, Á, ...): normalize để lookup,
    // còn việc giữ hoa/thường sẽ do setTone/setGroupKeepTone quyết định.
    const c: string = ch.toLowerCase();

    const make = (base: string, group: VowelGroup, tone: number): VowelInfo => {
      const v: VowelInfo = new VowelInfo();
      v.base = base;
      v.group = group;
      v.tone = tone;
      return v;
    };

    switch (c) {
      // a
      case 'a': return make('a', VowelGroup.A, 0);
      case 'á': return make('a', VowelGroup.A, 1);
      case 'à': return make('a', VowelGroup.A, 2);
      case 'ả': return make('a', VowelGroup.A, 3);
      case 'ã': return make('a', VowelGroup.A, 4);
      case 'ạ': return make('a', VowelGroup.A, 5);

      // ă
      case 'ă': return make('a', VowelGroup.AW, 0);
      case 'ắ': return make('a', VowelGroup.AW, 1);
      case 'ằ': return make('a', VowelGroup.AW, 2);
      case 'ẳ': return make('a', VowelGroup.AW, 3);
      case 'ẵ': return make('a', VowelGroup.AW, 4);
      case 'ặ': return make('a', VowelGroup.AW, 5);

      // â
      case 'â': return make('a', VowelGroup.AA, 0);
      case 'ấ': return make('a', VowelGroup.AA, 1);
      case 'ầ': return make('a', VowelGroup.AA, 2);
      case 'ẩ': return make('a', VowelGroup.AA, 3);
      case 'ẫ': return make('a', VowelGroup.AA, 4);
      case 'ậ': return make('a', VowelGroup.AA, 5);

      // e
      case 'e': return make('e', VowelGroup.E, 0);
      case 'é': return make('e', VowelGroup.E, 1);
      case 'è': return make('e', VowelGroup.E, 2);
      case 'ẻ': return make('e', VowelGroup.E, 3);
      case 'ẽ': return make('e', VowelGroup.E, 4);
      case 'ẹ': return make('e', VowelGroup.E, 5);

      // ê
      case 'ê': return make('e', VowelGroup.EE, 0);
      case 'ế': return make('e', VowelGroup.EE, 1);
      case 'ề': return make('e', VowelGroup.EE, 2);
      case 'ể': return make('e', VowelGroup.EE, 3);
      case 'ễ': return make('e', VowelGroup.EE, 4);
      case 'ệ': return make('e', VowelGroup.EE, 5);

      // i
      case 'i': return make('i', VowelGroup.I, 0);
      case 'í': return make('i', VowelGroup.I, 1);
      case 'ì': return make('i', VowelGroup.I, 2);
      case 'ỉ': return make('i', VowelGroup.I, 3);
      case 'ĩ': return make('i', VowelGroup.I, 4);
      case 'ị': return make('i', VowelGroup.I, 5);

      // o
      case 'o': return make('o', VowelGroup.O, 0);
      case 'ó': return make('o', VowelGroup.O, 1);
      case 'ò': return make('o', VowelGroup.O, 2);
      case 'ỏ': return make('o', VowelGroup.O, 3);
      case 'õ': return make('o', VowelGroup.O, 4);
      case 'ọ': return make('o', VowelGroup.O, 5);

      // ô
      case 'ô': return make('o', VowelGroup.OO, 0);
      case 'ố': return make('o', VowelGroup.OO, 1);
      case 'ồ': return make('o', VowelGroup.OO, 2);
      case 'ổ': return make('o', VowelGroup.OO, 3);
      case 'ỗ': return make('o', VowelGroup.OO, 4);
      case 'ộ': return make('o', VowelGroup.OO, 5);

      // ơ
      case 'ơ': return make('o', VowelGroup.OW, 0);
      case 'ớ': return make('o', VowelGroup.OW, 1);
      case 'ờ': return make('o', VowelGroup.OW, 2);
      case 'ở': return make('o', VowelGroup.OW, 3);
      case 'ỡ': return make('o', VowelGroup.OW, 4);
      case 'ợ': return make('o', VowelGroup.OW, 5);

      // u
      case 'u': return make('u', VowelGroup.U, 0);
      case 'ú': return make('u', VowelGroup.U, 1);
      case 'ù': return make('u', VowelGroup.U, 2);
      case 'ủ': return make('u', VowelGroup.U, 3);
      case 'ũ': return make('u', VowelGroup.U, 4);
      case 'ụ': return make('u', VowelGroup.U, 5);

      // ư
      case 'ư': return make('u', VowelGroup.UW, 0);
      case 'ứ': return make('u', VowelGroup.UW, 1);
      case 'ừ': return make('u', VowelGroup.UW, 2);
      case 'ử': return make('u', VowelGroup.UW, 3);
      case 'ữ': return make('u', VowelGroup.UW, 4);
      case 'ự': return make('u', VowelGroup.UW, 5);

      // y
      case 'y': return make('y', VowelGroup.Y, 0);
      case 'ý': return make('y', VowelGroup.Y, 1);
      case 'ỳ': return make('y', VowelGroup.Y, 2);
      case 'ỷ': return make('y', VowelGroup.Y, 3);
      case 'ỹ': return make('y', VowelGroup.Y, 4);
      case 'ỵ': return make('y', VowelGroup.Y, 5);

      default:
        return undefined;
    }
  }

  private isVowelChar(ch: string): boolean {
    return this.getVowelInfo(ch) !== undefined;
  }

  private setTone(ch: string, tone: number): string {
    const info: VowelInfo | undefined = this.getVowelInfo(ch);
    if (!info) return ch;

    const isUpper: boolean = (ch.toUpperCase() === ch);
    const out: string = this.composeVowel(info.base, info.group, tone);
    return isUpper ? out.toUpperCase() : out;
  }

  private setGroupKeepTone(ch: string, newGroup: VowelGroup): string {
    const info: VowelInfo | undefined = this.getVowelInfo(ch);
    if (!info) return ch;

    const isUpper: boolean = (ch.toUpperCase() === ch);
    const out: string = this.composeVowel(info.base, newGroup, info.tone);
    return isUpper ? out.toUpperCase() : out;
  }

  private findLastIndexByBaseInSpan(chars: Array<string>, span: VowelSpan, base: string): number {
    for (let i = span.end; i >= span.start; i--) {
      const info: VowelInfo | undefined = this.getVowelInfo(chars[i]);
      if (info && info.base === base) return i;
    }
    return -1;
  }

  private composeVowel(base: string, group: VowelGroup, tone: number): string {
    const b: string = base.toLowerCase();
    const t: number = tone;

    if (b === 'a') {
      if (group === VowelGroup.A) return ['a', 'á', 'à', 'ả', 'ã', 'ạ'][t];
      if (group === VowelGroup.AW) return ['ă', 'ắ', 'ằ', 'ẳ', 'ẵ', 'ặ'][t];
      if (group === VowelGroup.AA) return ['â', 'ấ', 'ầ', 'ẩ', 'ẫ', 'ậ'][t];
    }

    if (b === 'e') {
      if (group === VowelGroup.E) return ['e', 'é', 'è', 'ẻ', 'ẽ', 'ẹ'][t];
      if (group === VowelGroup.EE) return ['ê', 'ế', 'ề', 'ể', 'ễ', 'ệ'][t];
    }

    if (b === 'i') return ['i', 'í', 'ì', 'ỉ', 'ĩ', 'ị'][t];

    if (b === 'o') {
      if (group === VowelGroup.O) return ['o', 'ó', 'ò', 'ỏ', 'õ', 'ọ'][t];
      if (group === VowelGroup.OO) return ['ô', 'ố', 'ồ', 'ổ', 'ỗ', 'ộ'][t];
      if (group === VowelGroup.OW) return ['ơ', 'ớ', 'ờ', 'ở', 'ỡ', 'ợ'][t];
    }

    if (b === 'u') {
      if (group === VowelGroup.U) return ['u', 'ú', 'ù', 'ủ', 'ũ', 'ụ'][t];
      if (group === VowelGroup.UW) return ['ư', 'ứ', 'ừ', 'ử', 'ữ', 'ự'][t];
    }

    if (b === 'y') return ['y', 'ý', 'ỳ', 'ỷ', 'ỹ', 'ỵ'][t];

    return base;
  }

  // ---------- Tone key ----------
  private applyToneKey(word: string, keyChar: string): string {
    const tone: number = this.toneOfKey(keyChar);
    if (tone === 0) return word;

    const chars: Array<string> = word.split('');
    const span: VowelSpan | undefined = this.findVowelSpan(chars);
    if (!span) return word;

    let vsi: number = span.start;
    const vei: number = span.end;

    // special case qu/gi
    if (vsi + 1 <= vei) {
      const b0: string = this.toBaseLetter(chars[vsi]);

      if (b0 === 'u' && vsi - 1 >= 0) {
        const prev: string = chars[vsi - 1].toLowerCase();
        if (prev === 'q') vsi = vsi + 1;
      }

      if (b0 === 'i' && vsi - 1 >= 0) {
        const prev2: string = chars[vsi - 1].toLowerCase();
        if (prev2 === 'g') vsi = vsi + 1;
      }
    }

    const markPos: number = this.findToneMarkPosition(chars, vsi, vei);
    if (markPos < 0) return word;

    const vowelInfo: VowelInfo | undefined = this.getVowelInfo(chars[markPos]);
    if (!vowelInfo) return word;

    const isToggleOff: boolean = (vowelInfo.tone === tone);
    chars[markPos] = this.setTone(chars[markPos], isToggleOff ? 0 : tone);

    // double-press tone key: bỏ dấu + vẫn thêm chữ
    if (isToggleOff) return chars.join('') + keyChar;

    return chars.join('');
  }

  // ---------- Shape keys ----------
  private applyShapeKey(word: string, keyChar: string): string {
    const k: string = keyChar;
    const kl: string = k.toLowerCase();
    const chars: Array<string> = word.split('');
    if (chars.length === 0) return word;

    const lastIdx: number = chars.length - 1;
    const last: string = chars[lastIdx];

    const toggleAt = (idx: number, groupOn: VowelGroup, groupOff: VowelGroup): string => {
      const info: VowelInfo | undefined = this.getVowelInfo(chars[idx]);
      if (!info) return word;

      if (info.group === groupOn) {
        chars[idx] = this.setGroupKeepTone(chars[idx], groupOff);
        return chars.join('') + k; // toggle OFF + insert typed key
      }
      if (info.group === groupOff) {
        chars[idx] = this.setGroupKeepTone(chars[idx], groupOn);
        return chars.join(''); // toggle ON, không insert
      }
      return word;
    };

    const span: VowelSpan | undefined = this.findVowelSpan(chars);

    if (kl === 'w') {
      // uo + w <-> ươ (scan inside last vowel span)
      if (span) {
        for (let i = span.end; i - 1 >= span.start; i--) {
          const b2: string = this.toBaseLetter(chars[i]);
          const b1: string = this.toBaseLetter(chars[i - 1]);
          if (b1 === 'u' && b2 === 'o') {
            const i1: VowelInfo | undefined = this.getVowelInfo(chars[i - 1]);
            const i2: VowelInfo | undefined = this.getVowelInfo(chars[i]);
            if (!i1 || !i2) break;

            if (i1.group === VowelGroup.UW && i2.group === VowelGroup.OW) {
              const toneKeep: number = i2.tone;
              const uBase: string = (chars[i - 1].toUpperCase() === chars[i - 1]) ? 'U' : 'u';
              const oBase: string = (chars[i].toUpperCase() === chars[i]) ? 'O' : 'o';
              chars[i - 1] = uBase;
              chars[i] = this.setTone(oBase, toneKeep);
              return chars.join('') + k;
            }

            const toneKeep2: number = i2.tone;
            const uNew: string = this.composeVowel('u', VowelGroup.UW, 0);
            const oNew: string = this.composeVowel('o', VowelGroup.OW, toneKeep2);
            chars[i - 1] = (chars[i - 1].toUpperCase() === chars[i - 1]) ? uNew.toUpperCase() : uNew;
            chars[i] = (chars[i].toUpperCase() === chars[i]) ? oNew.toUpperCase() : oNew;
            return chars.join('');
          }
        }
      }

      const infoLast: VowelInfo | undefined = this.getVowelInfo(last);
      if (infoLast) {
        if (infoLast.base === 'a') return toggleAt(lastIdx, VowelGroup.AW, VowelGroup.A);
        if (infoLast.base === 'o') return toggleAt(lastIdx, VowelGroup.OW, VowelGroup.O);
        if (infoLast.base === 'u') return toggleAt(lastIdx, VowelGroup.UW, VowelGroup.U);
      }

      if (span) {
        const idxA: number = this.findLastIndexByBaseInSpan(chars, span, 'a');
        if (idxA >= 0) {
          const rA: string = toggleAt(idxA, VowelGroup.AW, VowelGroup.A);
          if (rA !== word) return rA;
        }
        const idxO: number = this.findLastIndexByBaseInSpan(chars, span, 'o');
        if (idxO >= 0) {
          const rO: string = toggleAt(idxO, VowelGroup.OW, VowelGroup.O);
          if (rO !== word) return rO;
        }
        const idxU: number = this.findLastIndexByBaseInSpan(chars, span, 'u');
        if (idxU >= 0) {
          const rU: string = toggleAt(idxU, VowelGroup.UW, VowelGroup.U);
          if (rU !== word) return rU;
        }
      }

      return word;
    }

    if (kl === 'a') {
      const infoLast: VowelInfo | undefined = this.getVowelInfo(last);
      if (infoLast && infoLast.base === 'a') {
        const r: string = toggleAt(lastIdx, VowelGroup.AA, VowelGroup.A);
        if (r !== word) return r;
      }
      if (span) {
        const idx: number = this.findLastIndexByBaseInSpan(chars, span, 'a');
        if (idx >= 0) return toggleAt(idx, VowelGroup.AA, VowelGroup.A);
      }
      return word;
    }

    if (kl === 'e') {
      const infoLast: VowelInfo | undefined = this.getVowelInfo(last);
      if (infoLast && infoLast.base === 'e') {
        const r: string = toggleAt(lastIdx, VowelGroup.EE, VowelGroup.E);
        if (r !== word) return r;
      }
      if (span) {
        const idx: number = this.findLastIndexByBaseInSpan(chars, span, 'e');
        if (idx >= 0) return toggleAt(idx, VowelGroup.EE, VowelGroup.E);
      }
      return word;
    }

    if (kl === 'o') {
      const infoLast: VowelInfo | undefined = this.getVowelInfo(last);
      if (infoLast && infoLast.base === 'o') {
        const r: string = toggleAt(lastIdx, VowelGroup.OO, VowelGroup.O);
        if (r !== word) return r;
      }
      if (span) {
        const idx: number = this.findLastIndexByBaseInSpan(chars, span, 'o');
        if (idx >= 0) return toggleAt(idx, VowelGroup.OO, VowelGroup.O);
      }
      return word;
    }

    return word;
  }

  // ---------- Vowel span ----------
  private findVowelSpan(chars: Array<string>): VowelSpan | undefined {
    let endIdx: number = -1;
    for (let i = chars.length - 1; i >= 0; i--) {
      if (this.isVowelChar(chars[i])) {
        endIdx = i;
        break;
      }
    }
    if (endIdx < 0) return undefined;

    let startIdx: number = endIdx;
    for (let i = endIdx - 1; i >= 0; i--) {
      if (this.isVowelChar(chars[i])) startIdx = i;
      else break;
    }

    const span: VowelSpan = new VowelSpan();
    span.start = startIdx;
    span.end = endIdx;
    return span;
  }

  // ---------- Tone placement ----------
  private findToneMarkPosition(chars: Array<string>, vsi: number, vei: number): number {
    if (vsi > vei) return -1;

    // ✅ FIX: cụm "ươ" (ư + ơ) luôn đặt dấu ở "ơ" (OW), không phải "ư" (UW)
    for (let i = vsi; i < vei; i++) {
      const a: VowelInfo | undefined = this.getVowelInfo(chars[i]);
      const b: VowelInfo | undefined = this.getVowelInfo(chars[i + 1]);
      if (a && b && a.base === 'u' && a.group === VowelGroup.UW && b.base === 'o' && b.group === VowelGroup.OW) {
        return i + 1; // index của "ơ"
      }
    }

    // ưu tiên nguyên âm đặc biệt trước
    for (let i = vsi; i <= vei; i++) {
      const info: VowelInfo | undefined = this.getVowelInfo(chars[i]);
      if (info && info.group === VowelGroup.EE) return i;
    }
    for (let i = vsi; i <= vei; i++) {
      const info: VowelInfo | undefined = this.getVowelInfo(chars[i]);
      if (info && info.group === VowelGroup.AA) return i;
    }
    for (let i = vsi; i <= vei; i++) {
      const info: VowelInfo | undefined = this.getVowelInfo(chars[i]);
      if (info && info.group === VowelGroup.AW) return i;
    }
    // (giữ UW ở đây vẫn OK vì đã special-case ươ ở trên)
    for (let i = vsi; i <= vei; i++) {
      const info: VowelInfo | undefined = this.getVowelInfo(chars[i]);
      if (info && info.group === VowelGroup.UW) return i;
    }
    for (let i = vsi; i <= vei; i++) {
      const info: VowelInfo | undefined = this.getVowelInfo(chars[i]);
      if (info && info.group === VowelGroup.OW) return i;
    }
    for (let i = vsi; i <= vei; i++) {
      const info: VowelInfo | undefined = this.getVowelInfo(chars[i]);
      if (info && info.group === VowelGroup.OO) return i;
    }

    return this.modernOrthography ? this.pickModern(chars, vsi, vei) : this.pickOld(vsi, vei);
  }

  private pickOld(vsi: number, vei: number): number {
    let pos: number = vsi;
    const count: number = vei - vsi + 1;
    if (count >= 3) pos = Math.min(vsi + 1, vei);
    return pos;
  }

  private pickModern(chars: Array<string>, vsi: number, vei: number): number {
    const count: number = vei - vsi + 1;

    const b0: string = this.toBaseLetter(chars[vsi]);
    const b1: string = (vsi + 1 <= vei) ? this.toBaseLetter(chars[vsi + 1]) : '';
    const b2: string = (vsi + 2 <= vei) ? this.toBaseLetter(chars[vsi + 2]) : '';

    let pos: number = vei;

    if (count === 3) {
      const p: string = b0 + b1 + b2;

      // các cụm hay gặp đặt dấu ở nguyên âm giữa
      if (p === 'oai' || p === 'oeo' || p === 'uyu' || p === 'uya'
        || p === 'uoi' || p === 'uou' || p === 'uay'
        || p === 'ieu' || p === 'yeu') {
        pos = vsi + 1;
      } else {
        pos = vei;
      }
      return pos;
    }

    if (count === 2) {
      // oa/oe/uy: mark vowel 2
      if ((b0 === 'o' && (b1 === 'a' || b1 === 'e')) || (b0 === 'u' && b1 === 'y')) {
        pos = vsi + 1;
      }
      // uo: mark vowel 2
      if (b0 === 'u' && b1 === 'o') {
        pos = vsi + 1;
      }
      // ia/iu/io: thường mark i
      if (b0 === 'i' && (b1 === 'a' || b1 === 'u' || b1 === 'o')) {
        pos = vsi;
      }
      // ua: thường mark u
      if (b0 === 'u' && b1 === 'a') {
        pos = vsi;
      }
      // ao/au/ay/eo/eu: đặt dấu ở nguyên âm đầu (fix "nào")
      if ((b0 === 'a' || b0 === 'e') && (b1 === 'o' || b1 === 'u' || b1 === 'y')) {
        pos = vsi;
      }

      return pos;
    }

    return vsi;
  }
}
