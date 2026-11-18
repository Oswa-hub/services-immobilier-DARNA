'use strict';

/**
 * Minimal in-memory stand-in for the firebase-admin Firestore API used by the
 * notification code: doc get/set/create/delete, add, where('==')/limit, and
 * collectionGroup. Enough to test handlers without the emulator.
 */
class FakeFirestore {
  constructor(seed = {}) {
    this.docs = new Map(Object.entries(seed).map(([k, v]) => [k, { ...v }]));
    this._auto = 0;
  }

  collection(path) {
    return new CollectionRef(this, path);
  }

  collectionGroup(id) {
    return new Query(this, (path) => {
      const parts = path.split('/');
      return parts.length >= 2 && parts[parts.length - 2] === id;
    });
  }

  /** All documents whose path starts with `collectionPath/`. */
  dump(collectionPath) {
    const out = {};
    for (const [p, d] of this.docs) {
      const parts = p.split('/');
      if (parts.slice(0, -1).join('/') === collectionPath) out[parts[parts.length - 1]] = d;
    }
    return out;
  }
}

class DocSnapshot {
  constructor(db, path) {
    this._db = db;
    this.ref = new DocRef(db, path);
    this.id = this.ref.id;
    this._data = db.docs.has(path) ? { ...db.docs.get(path) } : undefined;
    this.exists = this._data !== undefined;
  }
  data() {
    return this._data;
  }
  get(field) {
    return this._data ? this._data[field] : undefined;
  }
}

class DocRef {
  constructor(db, path) {
    this._db = db;
    this.path = path;
    const parts = path.split('/');
    this.id = parts[parts.length - 1];
    this.parent = new CollectionRef(db, parts.slice(0, -1).join('/'));
  }
  collection(name) {
    return new CollectionRef(this._db, `${this.path}/${name}`);
  }
  async get() {
    return new DocSnapshot(this._db, this.path);
  }
  async set(data) {
    this._db.docs.set(this.path, { ...data });
  }
  async create(data) {
    if (this._db.docs.has(this.path)) {
      const e = new Error('already exists');
      e.code = 6;
      throw e;
    }
    this._db.docs.set(this.path, { ...data });
  }
  async delete() {
    this._db.docs.delete(this.path);
  }
}

class Query {
  constructor(db, match, filters = [], max = Infinity) {
    this._db = db;
    this._match = match;
    this._filters = filters;
    this._max = max;
  }
  where(field, op, value) {
    if (op !== '==') throw new Error(`FakeFirestore: unsupported op ${op}`);
    return new Query(this._db, this._match, [...this._filters, [field, value]], this._max);
  }
  limit(n) {
    return new Query(this._db, this._match, this._filters, n);
  }
  async get() {
    const docs = [];
    for (const [path, data] of this._db.docs) {
      if (!this._match(path)) continue;
      if (!this._filters.every(([f, v]) => data[f] === v)) continue;
      docs.push(new DocSnapshot(this._db, path));
      if (docs.length >= this._max) break;
    }
    return { docs, size: docs.length, empty: docs.length === 0 };
  }
}

class CollectionRef extends Query {
  constructor(db, path) {
    super(db, (p) => p.split('/').slice(0, -1).join('/') === path);
    this.path = path;
    const parts = path.split('/');
    this.id = parts[parts.length - 1];
    this.parent = parts.length > 1 ? new DocRef(db, parts.slice(0, -1).join('/')) : null;
  }
  doc(id) {
    const docId = id || `auto${++this._db._auto}`;
    return new DocRef(this._db, `${this.path}/${docId}`);
  }
  async add(data) {
    const ref = this.doc();
    await ref.set(data);
    return ref;
  }
}

/** Records multicast sends; tokens listed in `dead` fail as unregistered. */
class FakeMessaging {
  constructor(dead = []) {
    this.dead = new Set(dead);
    this.sent = [];
  }
  async sendEachForMulticast(msg) {
    this.sent.push(msg);
    const responses = msg.tokens.map((t) =>
      this.dead.has(t)
        ? { success: false, error: { code: 'messaging/registration-token-not-registered' } }
        : { success: true },
    );
    return { successCount: responses.filter((r) => r.success).length, responses };
  }
}

const silentLogger = { info() {}, warn() {}, error() {} };

module.exports = { FakeFirestore, FakeMessaging, silentLogger };
