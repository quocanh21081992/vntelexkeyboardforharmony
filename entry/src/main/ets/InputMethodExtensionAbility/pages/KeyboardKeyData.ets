// entry/src/main/ets/InputMethodExtensionAbility/pages/KeyboardKeyData.ets

export enum KeyKind {
  Char = 0,
  Shift = 1,
  Backspace = 2,
  Enter = 3,
  Space = 4,
  Num123 = 5,
  Spacer = 6,
  Abc = 7 // ✅ NEW: phím ABC để quay về layout chính
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

/**
 * ✅ Layout chính (KHÔNG có hàng số)
 * Row 0: qwertyuiop
 * Row 1: asdfghjkl (có spacer trái/phải để thụt vào giống bàn phím chuẩn)
 * Row 2: shift + zxcvbnm + backspace
 * Row 3: 123 , space . enter
 */
export const KEYBOARD_ROWS_MAIN: Array<Array<KeyData>> = [
  // row 0 (qwertyuiop): 10u
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

  // row 1 (asdfghjkl): 0.5 + 9 + 0.5 = 10u ✅ thụt lề
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

  // row 2 (shift zxcvbnm backspace): 1.5 + 7 + 1.5 = 10u
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

  // row 3 (bottom): 1.5 + 1 + 5 + 1 + 1.5 = 10u
  [
    k('num123', KeyKind.Num123, '123', '', 1.5),
    k('comma', KeyKind.Char, ',', ',', 1.0),
    k('space', KeyKind.Space, '', ' ', 5.0),
    k('dot', KeyKind.Char, '.', '.', 1.0),
    k('enter', KeyKind.Enter, '⏎', '\n', 1.5)
  ]
];

export const KEYBOARD_ROWS_CAPS: Array<Array<KeyData>> = [
  // row 0 (QWERTYUIOP)
  [
    k('q', KeyKind.Char, 'Q', 'Q', 1),
    k('w', KeyKind.Char, 'W', 'W', 1),
    k('e', KeyKind.Char, 'E', 'E', 1),
    k('r', KeyKind.Char, 'R', 'R', 1),
    k('t', KeyKind.Char, 'T', 'T', 1),
    k('y', KeyKind.Char, 'Y', 'Y', 1),
    k('u', KeyKind.Char, 'U', 'U', 1),
    k('i', KeyKind.Char, 'I', 'I', 1),
    k('o', KeyKind.Char, 'O', 'O', 1),
    k('p', KeyKind.Char, 'P', 'P', 1)
  ],

  // row 1 (ASDFGHJKL): 0.5 + 9 + 0.5 = 10u
  [
    sp('spacer_row2_l', 0.5),
    k('a', KeyKind.Char, 'A', 'A', 1),
    k('s', KeyKind.Char, 'S', 'S', 1),
    k('d', KeyKind.Char, 'D', 'D', 1),
    k('f', KeyKind.Char, 'F', 'F', 1),
    k('g', KeyKind.Char, 'G', 'G', 1),
    k('h', KeyKind.Char, 'H', 'H', 1),
    k('j', KeyKind.Char, 'J', 'J', 1),
    k('k', KeyKind.Char, 'K', 'K', 1),
    k('l', KeyKind.Char, 'L', 'L', 1),
    sp('spacer_row2_r', 0.5)
  ],

  // row 2 (CAPS zxcvbnm backspace): 1.5 + 7 + 1.5 = 10u
  [
    k('shift', KeyKind.Shift, '⇧', '', 1.5),
    k('z', KeyKind.Char, 'Z', 'Z', 1),
    k('x', KeyKind.Char, 'X', 'X', 1),
    k('c', KeyKind.Char, 'C', 'C', 1),
    k('v', KeyKind.Char, 'V', 'V', 1),
    k('b', KeyKind.Char, 'B', 'B', 1),
    k('n', KeyKind.Char, 'N', 'N', 1),
    k('m', KeyKind.Char, 'M', 'M', 1),
    k('backspace', KeyKind.Backspace, '⌫', '', 1.5)
  ],

  // row 3 (bottom)
  [
    k('num123', KeyKind.Num123, '123', '', 1.5),
    k('comma', KeyKind.Char, ',', ',', 1.0),
    k('space', KeyKind.Space, '', ' ', 5.0),
    k('dot', KeyKind.Char, '.', '.', 1.0),
    k('enter', KeyKind.Enter, '⏎', '\n', 1.5)
  ]
];


/**
 * ✅ Layout 123 / ký tự (giống bố cục ảnh, nhưng KHÔNG cần phím 1234/page2)
 * Row 0: 1..0
 * Row 1: @ # đ _ & - + ( ) /
 * Row 2: = * " ' : ; ! ? + backspace (weight 2)
 * Row 3: ABC , space . enter
 */
export const KEYBOARD_ROWS_123: Array<Array<KeyData>> = [
  // row 0: numbers
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

  // row 1: symbols
  [
    k('at', KeyKind.Char, '@', '@', 1),
    k('hash', KeyKind.Char, '#', '#', 1),
    k('dd', KeyKind.Char, 'đ', 'đ', 1),
    k('underscore', KeyKind.Char, '_', '_', 1),
    k('amp', KeyKind.Char, '&', '&', 1),
    k('dash', KeyKind.Char, '-', '-', 1),
    k('plus', KeyKind.Char, '+', '+', 1),
    k('lpar', KeyKind.Char, '(', '(', 1),
    k('rpar', KeyKind.Char, ')', ')', 1),
    k('slash', KeyKind.Char, '/', '/', 1)
  ],

  // row 2: punctuation + backspace
  [
    k('symMore', KeyKind.Shift, '=\\<', '', 1.5),
    k('star', KeyKind.Char, '*', '*', 1),
    k('dquote', KeyKind.Char, '"', '"', 1),
    k('squote', KeyKind.Char, '\'', '\'', 1),
    k('colon', KeyKind.Char, ':', ':', 1),
    k('semicolon', KeyKind.Char, ';', ';', 1),
    k('bang', KeyKind.Char, '!', '!', 1),
    k('qmark', KeyKind.Char, '?', '?', 1),
    k('backspace2', KeyKind.Backspace, '⌫', '', 1.5)
  ],

  // row 3: bottom
  [
    k('abc', KeyKind.Abc, 'ABC', '', 1.5),
    k('comma2', KeyKind.Char, ',', ',', 1.0),
    k('space2', KeyKind.Space, '', ' ', 5.0),
    k('dot2', KeyKind.Char, '.', '.', 1.0),
    k('enter2', KeyKind.Enter, '⏎', '\n', 1.5)
  ]
];

// ================= 123 MORE (page 2) =================
export const KEYBOARD_ROWS_123_MORE: Array<Array<KeyData>> = [
  // row 0
  [
    k('tilde', KeyKind.Char, '~', '~', 1),
    k('grave', KeyKind.Char, '`', '`', 1),
    k('pipe', KeyKind.Char, '|', '|', 1),
    k('middot', KeyKind.Char, '·', '·', 1),
    k('sqrt', KeyKind.Char, '√', '√', 1),
    k('pi', KeyKind.Char, 'π', 'π', 1),
    k('divide', KeyKind.Char, '÷', '÷', 1),
    k('times', KeyKind.Char, '×', '×', 1),
    k('section', KeyKind.Char, '§', '§', 1),
    k('delta', KeyKind.Char, 'Δ', 'Δ', 1)
  ],

  // row 1
  [
    k('pound', KeyKind.Char, '£', '£', 1),
    k('euro', KeyKind.Char, '€', '€', 1),
    k('dollar_more', KeyKind.Char, '$', '$', 1),
    k('cent', KeyKind.Char, '¢', '¢', 1),
    k('caret', KeyKind.Char, '^', '^', 1),
    k('deg', KeyKind.Char, '°', '°', 1),
    k('eq_more', KeyKind.Char, '=', '=', 1),
    k('lbrace', KeyKind.Char, '{', '{', 1),
    k('rbrace', KeyKind.Char, '}', '}', 1),
    k('bslash', KeyKind.Char, '\\', '\\', 1)
  ],

  // row 2
  [
    k('num123_more', KeyKind.Num123, '123', '', 1.5),
    k('percent_more', KeyKind.Char, '%', '%', 1),
    k('copy', KeyKind.Char, '©', '©', 1),
    k('reg', KeyKind.Char, '®', '®', 1),
    k('tm', KeyKind.Char, '™', '™', 1),
    k('check', KeyKind.Char, '✓', '✓', 1),
    k('lbrack', KeyKind.Char, '[', '[', 1),
    k('rbrack', KeyKind.Char, ']', ']', 1),
    k('backspace_more', KeyKind.Backspace, '⌫', '', 1.5)
  ],

  // row 3: bottom
  [
    k('abc_more', KeyKind.Abc, 'ABC', '', 1.5),
    k('comma_more', KeyKind.Char, '<', '<', 1.0),
    k('space_more', KeyKind.Space, '', ' ', 5.0),
    k('dot_more', KeyKind.Char, '>', '>', 1.0),
    k('enter_more', KeyKind.Enter, '⏎', '\n', 1.5)
  ]
];
