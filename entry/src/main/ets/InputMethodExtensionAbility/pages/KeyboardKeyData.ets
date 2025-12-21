// entry/src/main/ets/InputMethodExtensionAbility/pages/KeyboardKeyData.ets

export enum KeyKind {
  Char = 0,
  Shift = 1,
  Backspace = 2,
  Enter = 3,
  Space = 4,
  Num123 = 5,
  Spacer = 6 // ✅ spacer ẩn để căn lề như bàn phím chuẩn
}

export class KeyData {
  id: string = '';
  kind: KeyKind = KeyKind.Char;
  label: string = '';
  value: string = '';
  weight: number = 1;
}

// helper tạo key để tránh object-literal typing issues
function k(id: string, kind: KeyKind, label: string, value: string, weight: number): KeyData {
  const d: KeyData = new KeyData();
  d.id = id;
  d.kind = kind;
  d.label = label;
  d.value = value;
  d.weight = weight;
  return d;
}

function sp(id: string, weight: number): KeyData {
  return k(id, KeyKind.Spacer, '', '', weight);
}

// Quy ước: 1u ~ 1 phím chữ thường. Mỗi row cố gắng tổng ~ 10u để không bị giãn bất thường.
export const KEYBOARD_ROWS: Array<Array<KeyData>> = [
  // row 0 (Number row): 10u
  [
    k('1', KeyKind.Char, '1', '1', 1),
    k('2', KeyKind.Char, '2', '2', 1),
    k('3', KeyKind.Char, '3', '3', 1),
    k('4', KeyKind.Char, '4', '4', 1),
    k('5', KeyKind.Char, '5', '5', 1),
    k('6', KeyKind.Char, '6', '6', 1),
    k('7', KeyKind.Char, '7', '7', 1),
    k('8', KeyKind.Char, '8', '8', 1),
    k('9', KeyKind.Char, '9', '9', 1),
    k('0', KeyKind.Char, '0', '0', 1)
  ],

  // row 1 (qwertyuiop): 10u
  [
    k('q', KeyKind.Char, 'q', 'q', 1),
    k('w', KeyKind.Char, 'w', 'w', 1),
    k('e', KeyKind.Char, 'e', 'e', 1),
    k('r', KeyKind.Char, 'r', 'r', 1),
    k('t', KeyKind.Char, 't', 't', 1),
    k('y', KeyKind.Char, 'y', 'y', 1),
    k('u', KeyKind.Char, 'u', 'u', 1),
    k('i', KeyKind.Char, 'i', 'i', 1),
    k('o', KeyKind.Char, 'o', 'o', 1),
    k('p', KeyKind.Char, 'p', 'p', 1)
  ],

  // row 2 (asdfghjkl): 9u + 0.5u + 0.5u = 10u  ✅ thụt lề như bàn phím chuẩn
  [
    sp('spacer_row2_l', 0.5),
    k('a', KeyKind.Char, 'a', 'a', 1),
    k('s', KeyKind.Char, 's', 's', 1),
    k('d', KeyKind.Char, 'd', 'd', 1),
    k('f', KeyKind.Char, 'f', 'f', 1),
    k('g', KeyKind.Char, 'g', 'g', 1),
    k('h', KeyKind.Char, 'h', 'h', 1),
    k('j', KeyKind.Char, 'j', 'j', 1),
    k('k', KeyKind.Char, 'k', 'k', 1),
    k('l', KeyKind.Char, 'l', 'l', 1),
    sp('spacer_row2_r', 0.5)
  ],

  // row 3 (shift zxcvbnm backspace): 1.5 + 7 + 1.5 = 10u
  [
    k('shift', KeyKind.Shift, '⇧', '', 1.5),
    k('z', KeyKind.Char, 'z', 'z', 1),
    k('x', KeyKind.Char, 'x', 'x', 1),
    k('c', KeyKind.Char, 'c', 'c', 1),
    k('v', KeyKind.Char, 'v', 'v', 1),
    k('b', KeyKind.Char, 'b', 'b', 1),
    k('n', KeyKind.Char, 'n', 'n', 1),
    k('m', KeyKind.Char, 'm', 'm', 1),
    k('backspace', KeyKind.Backspace, '⌫', '', 1.5)
  ],

  // row 4 (Space row): 1.5 + 1 + 5 + 1 + 1.5 = 10u
  [
    k('num123', KeyKind.Num123, '123', '', 1.5),
    k('comma', KeyKind.Char, ',', ',', 1.0),
    k('space', KeyKind.Space, '', ' ', 5.0),
    k('dot', KeyKind.Char, '.', '.', 1.0),
    k('enter', KeyKind.Enter, '⏎', '\n', 1.5)
  ]
];
