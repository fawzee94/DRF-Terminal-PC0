// Pure click vocabulary, shared by Module Base (a module's own clicks),
// Module Slot (the fall-through) and Body (the background surface). No
// imports, no QML — the button codes are Qt::MouseButton's own values, so
// this file can be driven by a check without a desktop under it.

const BUTTON_NAMES = { 1: 'left', 2: 'right', 4: 'middle' };

function nameOf(button) {
  return BUTTON_NAMES[button] || '';
}

// A configured action is either a bare command name or the whole message.
// The long form is what lets a click carry a value, which is the only way
// to reach switchMode, setPinned or takeover. Returns null for a button
// nothing claims, which is how a caller knows to pass the click on.
function messageFor(action) {
  if (typeof action === 'string' && action) return { command: action };
  if (action && typeof action === 'object' && typeof action.command === 'string') return action;
  return null;
}

if (typeof module !== 'undefined') {
  module.exports = { nameOf, messageFor };
}
