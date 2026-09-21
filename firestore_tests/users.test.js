import { after, before, beforeEach, describe, it } from 'node:test';
import {
  assertFails,
  assertSucceeds,
} from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  updateDoc,
  setDoc,
  where,
} from 'firebase/firestore';
import {
  asUser,
  createTestEnv,
  profile,
  readRaw,
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

describe('users: creating a profile', () => {
  it('lets a new user create their own profile as a plain user', async () => {
    const db = asUser(env, 'carol');
    await assertSucceeds(
      setDoc(doc(db, 'users/carol'), profile('carol', { name: 'Carol' })),
    );
  });

  it('refuses to create a profile for someone else', async () => {
    const db = asUser(env, 'carol');
    await assertFails(setDoc(doc(db, 'users/dave'), profile('dave')));
  });

  it('refuses to create a profile while signed out', async () => {
    await assertFails(
      setDoc(doc(signedOut(env), 'users/carol'), profile('carol')),
    );
  });

  it('refuses a profile that claims to be an admin', async () => {
    const db = asUser(env, 'carol');
    await assertFails(
      setDoc(doc(db, 'users/carol'), profile('carol', { role: 'admin' })),
    );
  });

  it('refuses a profile that claims to be the super admin', async () => {
    const db = asUser(env, 'carol');
    await assertFails(
      setDoc(doc(db, 'users/carol'), profile('carol', { role: 'superAdmin' })),
    );
  });

  it('refuses a profile with an extra field', async () => {
    const db = asUser(env, 'carol');
    await assertFails(
      setDoc(doc(db, 'users/carol'), { ...profile('carol'), isAdmin: true }),
    );
  });

  it('refuses a profile with a missing field', async () => {
    const db = asUser(env, 'carol');
    const { createdAt, ...withoutDate } = profile('carol');
    await assertFails(setDoc(doc(db, 'users/carol'), withoutDate));
  });

  it('refuses a profile whose uid does not match', async () => {
    const db = asUser(env, 'carol');
    await assertFails(
      setDoc(doc(db, 'users/carol'), { ...profile('carol'), uid: 'someone-else' }),
    );
  });

  it('refuses an empty or oversized name', async () => {
    const db = asUser(env, 'carol');
    await assertFails(
      setDoc(doc(db, 'users/carol'), profile('carol', { name: '' })),
    );
    await assertFails(
      setDoc(doc(db, 'users/carol'), profile('carol', { name: 'x'.repeat(101) })),
    );
  });

  it('refuses a createdAt that is not a timestamp', async () => {
    const db = asUser(env, 'carol');
    await assertFails(
      setDoc(doc(db, 'users/carol'), { ...profile('carol'), createdAt: 'today' }),
    );
  });

  it('cannot overwrite an existing profile to seize a role', async () => {
    // A second "create" on an existing doc is an update, which forbids roles.
    const db = asUser(env, 'alice');
    await assertFails(
      setDoc(doc(db, 'users/alice'), profile('alice', { role: 'admin' })),
    );
  });
});

describe('users: reading', () => {
  it('lets you read your own profile', async () => {
    await assertSucceeds(getDoc(doc(asUser(env, 'alice'), 'users/alice')));
  });

  it('lets you look up your own profile even before it exists', async () => {
    // The app does this on sign-in to create a missing profile.
    await assertSucceeds(getDoc(doc(asUser(env, 'newcomer'), 'users/newcomer')));
  });

  it('refuses reading another user', async () => {
    await assertFails(getDoc(doc(asUser(env, 'alice'), 'users/bob')));
  });

  it('refuses a regular admin reading other users', async () => {
    await assertFails(getDoc(doc(asUser(env, 'adm'), 'users/alice')));
  });

  it('lets the super admin read any user', async () => {
    await assertSucceeds(getDoc(doc(asUser(env, 'boss'), 'users/alice')));
  });

  it('refuses reading while signed out', async () => {
    await assertFails(getDoc(doc(signedOut(env), 'users/alice')));
  });

  it('lets only the super admin list and search users', async () => {
    const search = (db) =>
      getDocs(
        query(
          collection(db, 'users'),
          orderBy('email'),
          where('email', '>=', 'a'),
          limit(20),
        ),
      );
    await assertSucceeds(search(asUser(env, 'boss')));
    await assertFails(search(asUser(env, 'adm')));
    await assertFails(search(asUser(env, 'alice')));
    await assertFails(search(signedOut(env)));
  });

  it('lets the super admin list admins by role', async () => {
    const admins = getDocs(
      query(collection(asUser(env, 'boss'), 'users'), where('role', 'in', ['admin', 'superAdmin'])),
    );
    await assertSucceeds(admins);
  });
});

describe('users: updating', () => {
  it('lets you change your own display name', async () => {
    await assertSucceeds(
      updateDoc(doc(asUser(env, 'alice'), 'users/alice'), { name: 'Alicia' }),
    );
  });

  it('refuses an empty or oversized new name', async () => {
    const ref = doc(asUser(env, 'alice'), 'users/alice');
    await assertFails(updateDoc(ref, { name: '' }));
    await assertFails(updateDoc(ref, { name: 'x'.repeat(101) }));
  });

  it('refuses changing your own role', async () => {
    const ref = doc(asUser(env, 'alice'), 'users/alice');
    await assertFails(updateDoc(ref, { role: 'admin' }));
    await assertFails(updateDoc(ref, { role: 'superAdmin' }));
  });

  it('refuses a regular admin changing their own role', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'adm'), 'users/adm'), { role: 'superAdmin' }),
    );
  });

  it('refuses changing your email or uid', async () => {
    const ref = doc(asUser(env, 'alice'), 'users/alice');
    await assertFails(updateDoc(ref, { email: 'other@example.com' }));
    await assertFails(updateDoc(ref, { uid: 'bob' }));
  });

  it('refuses changing your name and role in the same write', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'alice'), 'users/alice'), {
        name: 'Alicia',
        role: 'admin',
      }),
    );
  });

  it('refuses editing someone else\'s profile', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'alice'), 'users/bob'), { name: 'Hacked' }),
    );
  });

  it('lets the super admin promote a user to admin', async () => {
    await assertSucceeds(
      updateDoc(doc(asUser(env, 'boss'), 'users/alice'), { role: 'admin' }),
    );
    const saved = await readRaw(env, 'users/alice');
    if (saved.role !== 'admin') throw new Error(`role was ${saved.role}`);
  });

  it('lets the super admin demote an admin', async () => {
    await assertSucceeds(
      updateDoc(doc(asUser(env, 'boss'), 'users/adm'), { role: 'user' }),
    );
  });

  it('never lets anyone be made super admin', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'boss'), 'users/alice'), { role: 'superAdmin' }),
    );
  });

  it('refuses the super admin changing their own role', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'boss'), 'users/boss'), { role: 'user' }),
    );
  });

  it('refuses changing another super admin', async () => {
    await env.withSecurityRulesDisabled((context) =>
      setDoc(
        doc(context.firestore(), 'users/boss2'),
        profile('boss2', { role: 'superAdmin' }),
      ),
    );

    await assertFails(
      updateDoc(doc(asUser(env, 'boss'), 'users/boss2'), { role: 'user' }),
    );
  });

  it('lets the super admin change only the role, nothing else', async () => {
    const ref = doc(asUser(env, 'boss'), 'users/alice');
    await assertFails(updateDoc(ref, { name: 'Renamed' }));
    await assertFails(updateDoc(ref, { role: 'admin', name: 'Renamed' }));
    await assertFails(updateDoc(ref, { email: 'x@example.com' }));
  });

  it('refuses a regular admin changing anyone else\'s role', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'adm'), 'users/alice'), { role: 'admin' }),
    );
  });

  it('refuses a regular user changing anyone else\'s role', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'alice'), 'users/bob'), { role: 'admin' }),
    );
  });

  it('refuses role changes while signed out', async () => {
    await assertFails(
      updateDoc(doc(signedOut(env), 'users/alice'), { role: 'admin' }),
    );
  });

  it('refuses an invalid role value', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'boss'), 'users/alice'), { role: 'owner' }),
    );
  });
});

describe('users: deleting', () => {
  it('is never allowed, for anyone', async () => {
    for (const uid of ['alice', 'adm', 'boss']) {
      await assertFails(deleteDoc(doc(asUser(env, uid), 'users/alice')));
    }
    await assertFails(deleteDoc(doc(asUser(env, 'alice'), 'users/alice')));
  });
});
