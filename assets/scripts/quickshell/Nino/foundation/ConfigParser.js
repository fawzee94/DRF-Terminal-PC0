// Parses the config dialect: JSON plus `#` line comments and trailing
// commas. Both strippers are string-aware, so a hex colour like "#66282828"
// or a comma inside a string value survives untouched.
//
// Two passes, not one: a comment can sit between a trailing comma and its
// closing brace, so comments have to be gone before commas are judged.

function countBackslashesBefore(text, pos) {
  let count = 0;
  let i = pos - 1;
  while (i >= 0 && text[i] === '\\') {
    count++;
    i--;
  }
  return count;
}

function isQuoteEscaped(text, pos) {
  return countBackslashesBefore(text, pos) % 2 === 1;
}

function stripComments(text) {
  let result = '';
  let inString = false;
  let i = 0;

  while (i < text.length) {
    const char = text[i];

    if (char === '"' && !isQuoteEscaped(text, i)) {
      inString = !inString;
      result += char;
      i++;
    } else if (!inString && char === '#') {
      while (i < text.length && text[i] !== '\n') i++;
      if (i < text.length) {
        result += '\n';
        i++;
      }
    } else {
      result += char;
      i++;
    }
  }

  return result;
}

function stripTrailingCommas(text) {
  let result = '';
  let inString = false;
  let i = 0;

  while (i < text.length) {
    const char = text[i];

    if (char === '"' && !isQuoteEscaped(text, i)) {
      inString = !inString;
      result += char;
      i++;
    } else if (!inString && char === ',') {
      let j = i + 1;
      while (j < text.length && /\s/.test(text[j])) j++;
      if (j < text.length && (text[j] === '}' || text[j] === ']')) {
        i++;
      } else {
        result += char;
        i++;
      }
    } else {
      result += char;
      i++;
    }
  }

  return result;
}

function parseJson(text) {
  return JSON.parse(stripTrailingCommas(stripComments(text)));
}

if (typeof module !== 'undefined') {
  module.exports = { parseJson };
}
