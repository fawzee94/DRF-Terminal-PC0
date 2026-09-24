// Validates parsed config against a schema tree. Four node kinds — leaf,
// object, list, opaque — plus `inherits` on an object node. Warns and falls
// back rather than throwing; see architecture.md "Config Engine > Error
// handling" for why that is right here and wrong elsewhere.

const LEAF_TYPES = ['number', 'string', 'bool', 'color', 'enum'];

function warn(path, message) {
  console.warn(`[SchemaValidator] ${path || '(root)'}: ${message}`);
}

// lore.md L8: Array.isArray() answers false for a real array that has
// crossed a QML property boundary — it stays indexable, keeps a correct
// length, and map/filter work, but the type tag is gone. Module options
// arrive exactly that way, so duck-typing is the only reliable test.
function isArrayLike(value) {
  return !!value && typeof value === 'object' &&
    typeof value.length === 'number' && typeof value.map === 'function';
}

function describeType(value) {
  if (value === null) return 'null';
  if (isArrayLike(value)) return 'array';
  return typeof value;
}

function joinPath(base, key) {
  return base ? `${base}.${key}` : key;
}

function isPlainObject(value) {
  return typeof value === 'object' && value !== null && !isArrayLike(value);
}

// Missing or nulled means "never supplied" — every node kind falls back
// silently. Only a value that was written and doesn't fit its rule warns.
function isAbsent(value) {
  return value === undefined || value === null;
}

function isLeafNode(node) {
  return !!node && LEAF_TYPES.indexOf(node.type) !== -1;
}

// --- leaf ---

function isLiteralMatch(schemaNode, rawValue) {
  return isArrayLike(schemaNode.literal) && schemaNode.literal.indexOf(rawValue) !== -1;
}

function isValidLeafValue(schemaNode, rawValue) {
  switch (schemaNode.type) {
    case 'number':
      return typeof rawValue === 'number' && !Number.isNaN(rawValue) &&
        (schemaNode.min === undefined || rawValue >= schemaNode.min) &&
        (schemaNode.max === undefined || rawValue <= schemaNode.max);
    case 'string':
      return typeof rawValue === 'string';
    case 'bool':
      return typeof rawValue === 'boolean';
    case 'color':
      return typeof rawValue === 'string' && /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(rawValue);
    case 'enum':
      return typeof rawValue === 'string' && isArrayLike(schemaNode.values) &&
        schemaNode.values.indexOf(rawValue) !== -1;
    default:
      return false;
  }
}

// `wrap` marks min/max as a cyclic range (an angle), so an out-of-range
// number is a valid alternate spelling, not bad data: 370 is 10 at 0..360.
function wrapNumber(schemaNode, rawValue) {
  if (schemaNode.type !== 'number' || !schemaNode.wrap) return undefined;
  if (typeof rawValue !== 'number' || Number.isNaN(rawValue)) return undefined;
  const min = schemaNode.min;
  const max = schemaNode.max;
  if (min === undefined || max === undefined || max <= min) return undefined;
  const span = max - min;
  return min + (((rawValue - min) % span) + span) % span;
}

function validateLeaf(schemaNode, rawValue, path) {
  if (isLiteralMatch(schemaNode, rawValue) || isValidLeafValue(schemaNode, rawValue)) {
    return rawValue;
  }
  const wrapped = wrapNumber(schemaNode, rawValue);
  if (wrapped !== undefined) return wrapped;
  if (!isAbsent(rawValue)) {
    warn(path, `invalid ${schemaNode.type} value ${JSON.stringify(rawValue)}, using default ${JSON.stringify(schemaNode.default)}`);
  }
  return schemaNode.default;
}

// A bare string where an object or a list was expected is a reference to
// another file. There is no ambiguity to resolve: a real object or array can
// never legitimately be a string, so no new schema syntax is needed. The
// loader is injected because this file is pure and has no way to read
// anything itself.
function dereference(rawValue, path, root) {
  if (typeof rawValue !== 'string' || !root.loadFile) return rawValue;
  return root.loadFile(rawValue, path);
}

// --- object ---

function coerceToObject(rawValue, path) {
  if (isPlainObject(rawValue)) return rawValue;
  if (!isAbsent(rawValue)) warn(path, `expected object, got ${describeType(rawValue)}, using {}`);
  return {};
}

// Leaves first. Inheritable values are the root object's own leaf fields, so
// resolving leaves ahead of nested objects means an `inherits` anywhere in
// the tree always reads a finished value — without depending on where the
// field happens to sit in the schema file.
function orderedFieldKeys(fields) {
  const keys = Object.keys(fields);
  return keys.filter(k => isLeafNode(fields[k])).concat(keys.filter(k => !isLeafNode(fields[k])));
}

function applyKnownFields(fields, source, path, root, target) {
  for (const key of orderedFieldKeys(fields)) {
    target[key] = validate(fields[key], source[key], joinPath(path, key), root);
  }
}

// An inherited key is validated by the top-level node's own rule, but falls
// back to whatever that top level resolved to rather than to a restated
// literal. Omitting the key is how you inherit it.
function applyInheritedFields(inherits, source, path, root, target) {
  for (const key of inherits) {
    const topNode = (root.schema.fields || {})[key];
    if (!topNode) {
      warn(joinPath(path, key), `inherits "${key}", which is not a top-level field`);
      continue;
    }
    const topValue = root.data[key];
    target[key] = isAbsent(source[key])
      ? topValue
      : validate(Object.assign({}, topNode, { default: topValue }), source[key], joinPath(path, key), root);
  }
}

// A key the schema doesn't declare is dropped either way, but how differs: an
// `additional` rule means a deliberately open shape (moduleOptions), so it's
// kept; without one the key is most likely a typo, so it says so.
function applyAdditionalFields(additionalSchema, declared, source, path, root, target) {
  for (const key of Object.keys(source)) {
    if (declared.indexOf(key) !== -1) continue;
    if (additionalSchema) {
      target[key] = validate(additionalSchema, source[key], joinPath(path, key), root);
    } else {
      warn(joinPath(path, key), 'unrecognized key not declared in schema, dropping');
    }
  }
}

function validateObject(schemaNode, rawValue, path, root) {
  const source = coerceToObject(dereference(rawValue, path, root), path);
  const fields = schemaNode.fields || {};
  const inherits = schemaNode.inherits || [];
  // Identity, not structure: only the outermost node accumulates straight
  // into root.data, which is what lets applyInheritedFields read resolved
  // top-level values out of it.
  const target = root.schema === schemaNode ? root.data : {};
  applyKnownFields(fields, source, path, root, target);
  applyInheritedFields(inherits, source, path, root, target);
  applyAdditionalFields(schemaNode.additional, Object.keys(fields).concat(inherits), source, path, root, target);
  return target;
}

// --- list ---

function entryPathLabel(path, entry, idField, index) {
  const id = entry && typeof entry === 'object' ? entry[idField] : undefined;
  return `${path}[${id !== undefined ? id : index}]`;
}

function validateList(schemaNode, rawValue, path, root) {
  rawValue = dereference(rawValue, path, root);
  if (!isArrayLike(rawValue)) {
    if (!isAbsent(rawValue)) warn(path, `expected list, got ${describeType(rawValue)}, using []`);
    return [];
  }
  return rawValue.map((entry, index) =>
    validate(schemaNode.entry, entry, entryPathLabel(path, entry, schemaNode.idField, index), root)
  );
}

// --- opaque ---

function validateOpaque(schemaNode, rawValue) {
  return isAbsent(rawValue) ? {} : rawValue;
}

// --- dispatcher ---

// A leaf node carries no "leaf" tag — its type field IS the primitive kind.
const HANDLERS = {
  number: validateLeaf,
  string: validateLeaf,
  bool: validateLeaf,
  color: validateLeaf,
  enum: validateLeaf,
  object: validateObject,
  list: validateList,
  opaque: validateOpaque,
};

function validate(schemaNode, rawValue, path, root) {
  path = path || '';
  root = root || { schema: schemaNode, data: {} };
  const handler = schemaNode && HANDLERS[schemaNode.type];
  if (!handler) {
    warn(path, `unrecognized schema node type ${JSON.stringify(schemaNode && schemaNode.type)}`);
    return schemaNode && 'default' in schemaNode ? schemaNode.default : undefined;
  }
  return handler(schemaNode, rawValue, path, root);
}

if (typeof module !== 'undefined') {
  module.exports = { validate };
}
