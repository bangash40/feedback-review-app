import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  query,
  setDoc,
  Timestamp,
  updateDoc,
  where,
} from 'firebase/firestore';
import {
  asUser,
  createTestEnv,
  item,
  readRaw,
  seed,
  seedBaseWorld,
  signedOut,
} from './helpers.js';

let env;
before(async () => {
  env = await createTestEnv();
});
after(async () => {
  await env.cleanup();
});
beforeEach(async () => {
  await env.clearFirestore();
  await seedBaseWorld(env);
});

/** A brand-new item as the admin form creates it. */
const newItem = (id, overrides = {}) =>
  item(id, { createdBy: 'adm', title: 'New thing', ...overrides });

describe('items: reading', () => {
  it('lets any signed-in user read and list items', async () => {
    const db = asUser(env, 'alice');
    await assertSucceeds(getDoc(doc(db, 'items/i1')));
    await assertSucceeds(getDocs(collection(db, 'items')));
  });

  it('lets a user run the browse query (active items of one type)', async () => {
    const db = asUser(env, 'alice');
    await assertSucceeds(
      getDocs(
        query(
          collection(db, 'items'),
          where('isActive', '==', true),
          where('type', '==', 'course'),
        ),
      ),
    );
  });

  it('refuses reading while signed out', async () => {
    await assertFails(getDoc(doc(signedOut(env), 'items/i1')));
    await assertFails(getDocs(collection(signedOut(env), 'items')));
  });
});

describe('items: creating', () => {
  it('lets an admin create an item', async () => {
    await assertSucceeds(
      setDoc(doc(asUser(env, 'adm'), 'items/n1'), newItem('n1')),
    );
  });

  it('lets the super admin create an item', async () => {
    await assertSucceeds(
      setDoc(
        doc(asUser(env, 'boss'), 'items/n1'),
        newItem('n1', { createdBy: 'boss' }),
      ),
    );
  });

  it('lets an admin create each type, and an inactive item', async () => {
    const db = asUser(env, 'adm');
    for (const type of ['task', 'course', 'service']) {
      await assertSucceeds(
        setDoc(doc(db, `items/${type}`), newItem(type, { type })),
      );
    }
    await assertSucceeds(
      setDoc(doc(db, 'items/off'), newItem('off', { isActive: false })),
    );
  });

  it('refuses a regular user creating an item', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'alice'), 'items/n1'), newItem('n1', { createdBy: 'alice' })),
    );
  });

  it('refuses creating while signed out', async () => {
    await assertFails(setDoc(doc(signedOut(env), 'items/n1'), newItem('n1')));
  });

  it('refuses an item claiming another creator', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'adm'), 'items/n1'), newItem('n1', { createdBy: 'boss' })),
    );
  });

  it('refuses an id field that does not match the document id', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'adm'), 'items/n1'), newItem('other')),
    );
  });

  it('refuses invalid titles', async () => {
    const db = asUser(env, 'adm');
    await assertFails(setDoc(doc(db, 'items/n1'), newItem('n1', { title: '' })));
    await assertFails(
      setDoc(doc(db, 'items/n1'), newItem('n1', { title: 'x'.repeat(81) })),
    );
    await assertFails(setDoc(doc(db, 'items/n1'), newItem('n1', { title: 42 })));
  });

  it('accepts the longest allowed title', async () => {
    await assertSucceeds(
      setDoc(doc(asUser(env, 'adm'), 'items/n1'), newItem('n1', { title: 'x'.repeat(80) })),
    );
  });

  it('refuses an oversized description', async () => {
    await assertFails(
      setDoc(
        doc(asUser(env, 'adm'), 'items/n1'),
        newItem('n1', { description: 'x'.repeat(2001) }),
      ),
    );
  });

  it('refuses an unknown type', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'adm'), 'items/n1'), newItem('n1', { type: 'gadget' })),
    );
  });

  it('refuses a non-boolean isActive', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'adm'), 'items/n1'), newItem('n1', { isActive: 'yes' })),
    );
  });

  it('refuses an item that starts with ratings already', async () => {
    const db = asUser(env, 'adm');
    await assertFails(
      setDoc(doc(db, 'items/n1'), newItem('n1', { ratingCount: 5, ratingSum: 25, averageRating: 5 })),
    );
    await assertFails(setDoc(doc(db, 'items/n1'), newItem('n1', { averageRating: 4.9 })));
  });

  it('refuses extra or missing fields', async () => {
    const db = asUser(env, 'adm');
    await assertFails(setDoc(doc(db, 'items/n1'), { ...newItem('n1'), featured: true }));
    const { description, ...missing } = newItem('n1');
    await assertFails(setDoc(doc(db, 'items/n1'), missing));
  });

  it('refuses a createdAt that is not a timestamp', async () => {
    await assertFails(
      setDoc(doc(asUser(env, 'adm'), 'items/n1'), newItem('n1', { createdAt: 'now' })),
    );
  });
});

describe('items: admin edits', () => {
  it('lets an admin edit title, description, type and active state', async () => {
    const ref = doc(asUser(env, 'adm'), 'items/i1');
    await assertSucceeds(updateDoc(ref, { title: 'Renamed' }));
    await assertSucceeds(updateDoc(ref, { description: 'New text' }));
    await assertSucceeds(updateDoc(ref, { type: 'service' }));
    await assertSucceeds(updateDoc(ref, { isActive: false }));
    await assertSucceeds(
      updateDoc(ref, { title: 'All', description: 'at', type: 'task', isActive: true }),
    );
  });

  it('lets the super admin edit items too', async () => {
    await assertSucceeds(
      updateDoc(doc(asUser(env, 'boss'), 'items/i1'), { title: 'By boss' }),
    );
  });

  it('refuses invalid edits', async () => {
    const ref = doc(asUser(env, 'adm'), 'items/i1');
    await assertFails(updateDoc(ref, { title: '' }));
    await assertFails(updateDoc(ref, { title: 'x'.repeat(81) }));
    await assertFails(updateDoc(ref, { type: 'gadget' }));
    await assertFails(updateDoc(ref, { isActive: 'no' }));
    await assertFails(updateDoc(ref, { description: 'x'.repeat(2001) }));
  });

  it('refuses an admin touching the rating totals directly', async () => {
    const ref = doc(asUser(env, 'adm'), 'items/i1');
    await assertFails(updateDoc(ref, { averageRating: 5 }));
    await assertFails(updateDoc(ref, { ratingCount: 100, ratingSum: 500, averageRating: 5 }));
  });

  it('refuses an admin changing the totals alongside a legitimate edit', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'adm'), 'items/i1'), { title: 'Sneaky', averageRating: 5 }),
    );
  });

  it('refuses an admin changing creator, creation time or id', async () => {
    const ref = doc(asUser(env, 'adm'), 'items/i1');
    await assertFails(updateDoc(ref, { createdBy: 'boss' }));
    await assertFails(updateDoc(ref, { createdAt: Timestamp.now() }));
    await assertFails(updateDoc(ref, { id: 'hijacked' }));
  });

  it('refuses a regular user editing an item', async () => {
    const ref = doc(asUser(env, 'alice'), 'items/i1');
    await assertFails(updateDoc(ref, { title: 'Hacked' }));
    await assertFails(updateDoc(ref, { isActive: false }));
  });

  it('refuses edits while signed out', async () => {
    await assertFails(updateDoc(doc(signedOut(env), 'items/i1'), { title: 'X' }));
  });

  it('keeps an edit from changing the ratings already earned', async () => {
    await assertSucceeds(updateDoc(doc(asUser(env, 'adm'), 'items/i1'), { title: 'Same ratings' }));
    const saved = await readRaw(env, 'items/i1');
    if (saved.ratingCount !== 0) throw new Error('totals changed');
  });
});

describe('items: rating totals cannot be forged', () => {
  const forge = (uid, data) => updateDoc(doc(asUser(env, uid), 'items/i1'), data);

  it('refuses a user writing a fake average', async () => {
    await assertFails(forge('alice', { ratingCount: 1, ratingSum: 5, averageRating: 5 }));
  });

  it('refuses a user inflating the totals', async () => {
    await assertFails(forge('alice', { ratingCount: 1000, ratingSum: 5000, averageRating: 5 }));
  });

  it('refuses a user wiping out ratings an item already has', async () => {
    await seed(env, (db) =>
      updateDoc(doc(db, 'items/i1'), { ratingCount: 3, ratingSum: 12, averageRating: 4 }),
    );
    await assertFails(forge('alice', { ratingCount: 0, ratingSum: 0, averageRating: 0 }));
    await assertFails(forge('alice', { averageRating: 1 }));
  });

  it('refuses a fake average even on an item with no ratings', async () => {
    await assertFails(forge('alice', { averageRating: 5 }));
  });

  it('refuses an admin forging the totals as a "user" of the item', async () => {
    await assertFails(forge('adm', { ratingCount: 1, ratingSum: 5, averageRating: 5 }));
  });

  it('refuses forging while signed out', async () => {
    await assertFails(
      updateDoc(doc(signedOut(env), 'items/i1'), { ratingCount: 1, ratingSum: 5, averageRating: 5 }),
    );
  });
});

describe('items: deleting', () => {
  it('is never allowed, even for the super admin', async () => {
    for (const uid of ['alice', 'adm', 'boss']) {
      await assertFails(deleteDoc(doc(asUser(env, uid), 'items/i1')));
    }
  });
});
