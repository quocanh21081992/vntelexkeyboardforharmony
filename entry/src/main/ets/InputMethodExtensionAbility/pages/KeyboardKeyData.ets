// entry/src/main/ets/InputMethodExtensionAbility/pages/KeyboardKeyData.ets

export enum KeyKind {
  Char = 0,
  Shift = 1,
  Backspace = 2,
  Space = 3,
  Enter = 4
}

export class KeyData {
  id: string;
  kind: KeyKind;
  label: string;
  value: string;
  weight: number;

  constructor(id: string, kind: KeyKind, label: string, value: string, weight: number = 1) {
    this.id = id;
    this.kind = kind;
    this.label = label;
    this.value = value;
    this.weight = weight;
  }
}

export const KEYBOARD_ROWS: Array<Array<KeyData>> = [
  // Row 1
  [
    new KeyData('q', KeyKind.Char, 'q', 'q'),
    new KeyData('w', KeyKind.Char, 'w', 'w'),
    new KeyData('e', KeyKind.Char, 'e', 'e'),
    new KeyData('r', KeyKind.Char, 'r', 'r'),
    new KeyData('t', KeyKind.Char, 't', 't'),
    new KeyData('y', KeyKind.Char, 'y', 'y'),
    new KeyData('u', KeyKind.Char, 'u', 'u'),
    new KeyData('i', KeyKind.Char, 'i', 'i'),
    new KeyData('o', KeyKind.Char, 'o', 'o'),
    new KeyData('p', KeyKind.Char, 'p', 'p')
  ],
  // Row 2
  [
    new KeyData('a', KeyKind.Char, 'a', 'a'),
    new KeyData('s', KeyKind.Char, 's', 's'),
    new KeyData('d', KeyKind.Char, 'd', 'd'),
    new KeyData('f', KeyKind.Char, 'f', 'f'),
    new KeyData('g', KeyKind.Char, 'g', 'g'),
    new KeyData('h', KeyKind.Char, 'h', 'h'),
    new KeyData('j', KeyKind.Char, 'j', 'j'),
    new KeyData('k', KeyKind.Char, 'k', 'k'),
    new KeyData('l', KeyKind.Char, 'l', 'l')
  ],
  // Row 3
  [
    new KeyData('shift', KeyKind.Shift, 'Shift', '', 1.5),
    new KeyData('z', KeyKind.Char, 'z', 'z'),
    new KeyData('x', KeyKind.Char, 'x', 'x'),
    new KeyData('c', KeyKind.Char, 'c', 'c'),
    new KeyData('v', KeyKind.Char, 'v', 'v'),
    new KeyData('b', KeyKind.Char, 'b', 'b'),
    new KeyData('n', KeyKind.Char, 'n', 'n'),
    new KeyData('m', KeyKind.Char, 'm', 'm'),
    new KeyData('bksp', KeyKind.Backspace, '⌫', '', 1.5)
  ],
  // Row 4
  [
    new KeyData('space', KeyKind.Space, 'Space', ' ', 4),
    new KeyData('enter', KeyKind.Enter, 'Enter', '\n', 2)
  ]
];
