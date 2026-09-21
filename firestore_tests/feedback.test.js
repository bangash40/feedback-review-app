import { after, before, beforeEach, describe, it } from 'node:test';
import { assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import {
  collection,
  deleteDoc,
  doc,
  getDoc,
  getDocs,
  limit,
  orderBy,
  query,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
  updateDoc,
  where,
  writeBatch,
} from 'firebase/firestore';
import {
  asUser,
  createTestEnv,
  deleteFeedback,
  feedbackDoc,
  feedbackId,
  readRaw,
  seed,
  seedBaseWorld,
  signedOut,
  submitFeedback,
  totals,
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

const NAMES = { alice: 'Alice', bob: 'Bob', adm: 'Adam', boss: 'Boss' };

/** Submits like the app does, as [uid], on item i1 unless told otherwise. */
const submit = (uid, rating, extra = {}) =>
  submitFeedback(asUser(env, uid), {
    itemId: 'i1',
    uid,
    name: NAMES[uid],
    rating,
    ...extra,
  });

const item = async (id = 'i1') => readRaw(env, `items/${id}`);
const feedback = async (uid, itemId = 'i1') =>
  readRaw(env, `feedback/${feedbackId(itemId, uid)}`);

describe('feedback: submitting through the app\'s transaction', () => {
  it('lets a user leave a review, updating the item totals', async () => {
    await assertSucceeds(submit('alice', 4, { review: 'Great', suggestion: 'More labs' }));

    const saved = await feedback('alice');
    if (saved.rating !== 4 || saved.userName !== 'Alice') throw new Error('bad doc');
    const current = await item();
    if (current.ratingCount !== 1 || current.ratingSum !== 4 || current.averageRating !== 4) {
      throw new Error(`totals were ${JSON.stringify(current)}`);
    }
  });

  it('lets several users review the same item', async () => {
    await assertSucceeds(submit('alice', 5));
    await assertSucceeds(submit('bob', 4));
    await assertSucceeds(submit('adm', 3));
    const current = await item();
    if (current.ratingCount !== 3 || current.ratingSum !== 12 || current.averageRating !== 4) {
      throw new Error(`totals were ${JSON.stringify(current)}`);
    }
  });

  it('lets admins and the super admin review like anyone else', async () => {
    await assertSucceeds(submit('adm', 5));
    await assertSucceeds(submit('boss', 4));
  });

  it('accepts every rating from 1 to 5', async () => {
    for (const [index, rating] of [1, 2, 3, 4, 5].entries()) {
      const uid = `user${index}`;
      await seed(env, (db) =>
        setDoc(doc(db, `users/${uid}`), {
          uid, name: uid, email: `${uid}@x.com`, role: 'user', createdAt: Timestamp.now(),
        }),
      );
      await assertSucceeds(
        submitFeedback(asUser(env, uid), { itemId: 'i1', uid, name: uid, rating }),
      );
    }
  });

  it('accepts a review and suggestion at the length limit', async () => {
    await assertSucceeds(
      submit('alice', 5, { review: 'r'.repeat(1000), suggestion: 's'.repeat(1000) }),
    );
  });

  it('lets a user edit their review, moving only the sum', async () => {
    await submit('alice', 5, { review: 'first' });
    await submit('bob', 3);

    await assertSucceeds(submit('alice', 1, { review: 'changed my mind' }));

    const current = await item();
    if (current.ratingCount !== 2 || current.ratingSum !== 4 || current.averageRating !== 2) {
      throw new Error(`totals were ${JSON.stringify(current)}`);
    }
    if ((await feedback('alice')).review !== 'changed my mind') throw new Error('not edited');
  });

  it('lets a user edit just the text without changing the rating', async () => {
    await submit('alice', 4, { review: 'one' });
    await assertSucceeds(submit('alice', 4, { review: 'two' }));
    const current = await item();
    if (current.ratingCount !== 1 || current.ratingSum !== 4) throw new Error('totals moved');
  });

  it('lets a user delete their review, reversing the totals', async () => {
    await submit('alice', 5);
    await submit('bob', 3);

    await assertSucceeds(deleteFeedback(asUser(env, 'alice'), 'i1', 'alice'));

    const current = await item();
    if (current.ratingCount !== 1 || current.ratingSum !== 3 || current.averageRating !== 3) {
      throw new Error(`totals were ${JSON.stringify(current)}`);
    }
    if (await feedback('alice')) throw new Error('still there');
  });

  it('resets to zero when the last review is deleted', async () => {
    await submit('alice', 5);
    await assertSucceeds(deleteFeedback(asUser(env, 'alice'), 'i1', 'alice'));
    const current = await item();
    if (current.ratingCount !== 0 || current.ratingSum !== 0 || current.averageRating !== 0) {
      throw new Error(`totals were ${JSON.stringify(current)}`);
    }
  });

  it('lets a user review again after deleting', async () => {
    await submit('alice', 5);
    await deleteFeedback(asUser(env, 'alice'), 'i1', 'alice');
    await assertSucceeds(submit('alice', 2));
  });

  it('lets a user edit their review after the item was deactivated', async () => {
    await submit('alice', 5);
    await seed(env, (db) => updateDoc(doc(db, 'items/i1'), { isActive: false }));
    await assertSucceeds(submit('alice', 3));
    await assertSucceeds(deleteFeedback(asUser(env, 'alice'), 'i1', 'alice'));
  });

  it('follows an item rename when editing', async () => {
    await submit('alice', 5);
    await seed(env, (db) => updateDoc(doc(db, 'items/i1'), { title: 'Renamed' }));
    await assertSucceeds(submit('alice', 4));
    if ((await feedback('alice')).itemTitle !== 'Renamed') throw new Error('title not refreshed');
  });
});

describe('feedback: creating is tightly controlled', () => {
  /** Runs a hand-built create in the same shape as the app, with tweaks. */
  const createWith = async ({ uid = 'alice', docId, mutate = (d) => d, totalsFor } = {}) => {
    const db = asUser(env, uid);
    const current = await item();
    const data = mutate(feedbackDoc(current, uid, NAMES[uid], 4));
    const id = docId ?? feedbackId('i1', uid);
    return runTransaction(db, async (tx) => {
      tx.set(doc(db, 'feedback', id), data);
      tx.update(doc(db, 'items/i1'), totalsFor ?? totals(1, 4));
    });
  };

  it('accepts the hand-built baseline (so the tweaks below are meaningful)', async () => {
    await assertSucceeds(createWith());
  });

  it('refuses a document id that is not itemId_userId', async () => {
    await assertFails(createWith({ docId: 'random-id' }));
  });

  it('refuses posting under another user\'s id', async () => {
    await assertFails(
      createWith({ docId: feedbackId('i1', 'bob'), mutate: (d) => ({ ...d, userId: 'bob', id: feedbackId('i1', 'bob') }) }),
    );
  });

  it('refuses a userId that is not the caller', async () => {
    await assertFails(createWith({ mutate: (d) => ({ ...d, userId: 'bob' }) }));
  });

  it('refuses an id field that does not match the document', async () => {
    await assertFails(createWith({ mutate: (d) => ({ ...d, id: 'other' }) }));
  });

  it('refuses ratings outside 1 to 5 or not whole numbers', async () => {
    for (const bad of [0, 6, -1, 2.5, '4', null]) {
      await assertFails(
        createWith({ mutate: (d) => ({ ...d, rating: bad }), totalsFor: totals(1, Number(bad) || 0) }),
      );
    }
  });

  it('refuses text over the length limits', async () => {
    await assertFails(createWith({ mutate: (d) => ({ ...d, review: 'r'.repeat(1001) }) }));
    await assertFails(createWith({ mutate: (d) => ({ ...d, suggestion: 's'.repeat(1001) }) }));
  });

  it('refuses text that is not a string', async () => {
    await assertFails(createWith({ mutate: (d) => ({ ...d, review: 123 }) }));
  });

  it('refuses extra fields', async () => {
    await assertFails(createWith({ mutate: (d) => ({ ...d, featured: true }) }));
  });

  it('refuses missing fields', async () => {
    await assertFails(
      createWith({ mutate: ({ suggestion, ...rest }) => rest }),
    );
  });

  it('refuses timestamps the client chose itself', async () => {
    await assertFails(createWith({ mutate: (d) => ({ ...d, createdAt: Timestamp.fromDate(new Date('2020-01-01')) }) }));
    await assertFails(createWith({ mutate: (d) => ({ ...d, updatedAt: Timestamp.now() }) }));
  });

  it('refuses a made-up item title or type (spoofed display data)', async () => {
    await assertFails(createWith({ mutate: (d) => ({ ...d, itemTitle: 'Something else' }) }));
    await assertFails(createWith({ mutate: (d) => ({ ...d, itemType: 'service' }) }));
  });

  it('refuses posting under someone else\'s display name', async () => {
    await assertFails(createWith({ mutate: (d) => ({ ...d, userName: 'Bob' }) }));
  });

  it('refuses feedback about an item that does not exist', async () => {
    const db = asUser(env, 'alice');
    await assertFails(
      runTransaction(db, async (tx) => {
        tx.set(
          doc(db, 'feedback', feedbackId('ghost', 'alice')),
          feedbackDoc({ id: 'ghost', title: 'Ghost', type: 'course' }, 'alice', 'Alice', 4),
        );
      }),
    );
  });

  it('refuses new feedback on an inactive item', async () => {
    const db = asUser(env, 'alice');
    await assertFails(
      submitFeedback(db, { itemId: 'i2', uid: 'alice', name: 'Alice', rating: 4 }),
    );
  });

  it('refuses feedback that does not update the item totals', async () => {
    const db = asUser(env, 'alice');
    const current = await item();
    await assertFails(
      setDoc(doc(db, 'feedback', feedbackId('i1', 'alice')), feedbackDoc(current, 'alice', 'Alice', 4)),
    );
  });

  it('refuses feedback whose totals were changed by the wrong amount', async () => {
    await assertFails(createWith({ totalsFor: totals(1, 5) })); // sum too high
    await assertFails(createWith({ totalsFor: totals(2, 4) })); // count too high
    await assertFails(createWith({ totalsFor: totals(0, 4) })); // count not raised
    await assertFails(createWith({ totalsFor: totals(1, 0) })); // sum not raised
  });

  it('refuses feedback while signed out', async () => {
    const db = signedOut(env);
    const current = await item();
    await assertFails(
      setDoc(doc(db, 'feedback', feedbackId('i1', 'alice')), feedbackDoc(current, 'alice', 'Alice', 4)),
    );
  });

  it('refuses a user with no profile', async () => {
    const db = asUser(env, 'ghost-user');
    const current = await item();
    await assertFails(
      runTransaction(db, async (tx) => {
        tx.set(
          doc(db, 'feedback', feedbackId('i1', 'ghost-user')),
          feedbackDoc(current, 'ghost-user', 'Ghost', 4),
        );
        tx.update(doc(db, 'items/i1'), totals(1, 4));
      }),
    );
  });

  it('cannot count one user twice by resubmitting as a create', async () => {
    await submit('alice', 5);
    const db = asUser(env, 'alice');
    const current = await item();
    // A second "set" on the same id is an update; claiming a new count fails.
    await assertFails(
      runTransaction(db, async (tx) => {
        tx.set(
          doc(db, 'feedback', feedbackId('i1', 'alice')),
          feedbackDoc(current, 'alice', 'Alice', 5),
        );
        tx.update(doc(db, 'items/i1'), totals(2, 10));
      }),
    );
  });
});

describe('feedback: editing and deleting are limited to the author', () => {
  beforeEach(async () => {
    await submit('alice', 4, { review: 'original' });
  });

  const updateReview = (uid, changes, totalsFor) => {
    const db = asUser(env, uid);
    return runTransaction(db, async (tx) => {
      tx.update(doc(db, 'feedback', feedbackId('i1', 'alice')), {
        updatedAt: serverTimestamp(),
        ...changes,
      });
      if (totalsFor) tx.update(doc(db, 'items/i1'), totalsFor);
    });
  };

  it('refuses another user editing the review', async () => {
    await assertFails(updateReview('bob', { review: 'hijacked' }, totals(1, 4)));
  });

  it('refuses an admin editing a user\'s review', async () => {
    await assertFails(updateReview('adm', { review: 'moderated' }, totals(1, 4)));
  });

  it('refuses the super admin editing a user\'s review', async () => {
    await assertFails(updateReview('boss', { review: 'moderated' }, totals(1, 4)));
  });

  it('lets the author edit text without touching totals', async () => {
    await assertSucceeds(updateReview('alice', { review: 'better' }, totals(1, 4)));
  });

  it('refuses changing whose review it is or what it is about', async () => {
    await assertFails(updateReview('alice', { userId: 'bob' }, totals(1, 4)));
    await assertFails(updateReview('alice', { itemId: 'i2' }, totals(1, 4)));
    await assertFails(updateReview('alice', { id: 'other' }, totals(1, 4)));
  });

  it('refuses rewriting the creation time', async () => {
    await assertFails(updateReview('alice', { createdAt: Timestamp.now() }, totals(1, 4)));
  });

  it('refuses an updatedAt the client chose', async () => {
    await assertFails(updateReview('alice', { updatedAt: Timestamp.fromDate(new Date('2001-01-01')) }, totals(1, 4)));
  });

  it('refuses an invalid new rating or text', async () => {
    await assertFails(updateReview('alice', { rating: 0 }, totals(1, 0)));
    await assertFails(updateReview('alice', { rating: 6 }, totals(1, 6)));
    await assertFails(updateReview('alice', { review: 'x'.repeat(1001) }, totals(1, 4)));
  });

  it('refuses an edit whose totals do not follow the rating change', async () => {
    await assertFails(updateReview('alice', { rating: 5 }, totals(1, 4))); // sum not raised
    await assertFails(updateReview('alice', { rating: 5 }, totals(1, 9))); // sum too high
    await assertFails(updateReview('alice', { rating: 5 }, totals(2, 5))); // count changed
  });

  it('refuses an edit that leaves the totals out entirely', async () => {
    await assertFails(updateReview('alice', { rating: 5 }));
  });

  it('refuses changing your display name to someone else\'s', async () => {
    await assertFails(updateReview('alice', { userName: 'Bob' }, totals(1, 4)));
  });

  it('refuses another user deleting the review', async () => {
    const db = asUser(env, 'bob');
    await assertFails(
      runTransaction(db, async (tx) => {
        tx.delete(doc(db, 'feedback', feedbackId('i1', 'alice')));
        tx.update(doc(db, 'items/i1'), totals(0, 0));
      }),
    );
  });

  it('refuses even an admin deleting a user\'s review', async () => {
    const db = asUser(env, 'adm');
    await assertFails(
      runTransaction(db, async (tx) => {
        tx.delete(doc(db, 'feedback', feedbackId('i1', 'alice')));
        tx.update(doc(db, 'items/i1'), totals(0, 0));
      }),
    );
  });

  it('refuses deleting without reversing the totals', async () => {
    await assertFails(deleteDoc(doc(asUser(env, 'alice'), 'feedback', feedbackId('i1', 'alice'))));
  });

  it('refuses deleting while reversing the totals by the wrong amount', async () => {
    const db = asUser(env, 'alice');
    await assertFails(
      runTransaction(db, async (tx) => {
        tx.delete(doc(db, 'feedback', feedbackId('i1', 'alice')));
        tx.update(doc(db, 'items/i1'), totals(0, 1));
      }),
    );
  });

  it('refuses deleting while signed out', async () => {
    await assertFails(deleteDoc(doc(signedOut(env), 'feedback', feedbackId('i1', 'alice'))));
  });
});

describe('feedback: totals can only move with the caller\'s own feedback', () => {
  it('refuses raising totals with no feedback write at all', async () => {
    await assertFails(
      updateDoc(doc(asUser(env, 'alice'), 'items/i1'), totals(1, 5)),
    );
  });

  it('refuses moving totals using someone else\'s feedback change', async () => {
    const db = asUser(env, 'bob');
    // Bob writes ALICE's review document and bumps the totals in one batch.
    const current = await item();
    const batch = writeBatch(db);
    batch.set(doc(db, 'feedback', feedbackId('i1', 'alice')), feedbackDoc(current, 'alice', 'Alice', 5));
    batch.update(doc(db, 'items/i1'), totals(1, 5));
    await assertFails(batch.commit());
  });

  it('refuses changing totals for an item other than the reviewed one', async () => {
    const db = asUser(env, 'alice');
    const current = await item();
    const batch = writeBatch(db);
    batch.set(doc(db, 'feedback', feedbackId('i1', 'alice')), feedbackDoc(current, 'alice', 'Alice', 5));
    batch.update(doc(db, 'items/i1'), totals(1, 5));
    batch.update(doc(db, 'items/i2'), totals(1, 5)); // an unrelated item
    await assertFails(batch.commit());
  });
});

describe('feedback: reading', () => {
  beforeEach(async () => {
    await submit('alice', 5, { review: 'Alice review' });
    await submit('bob', 2, { review: 'Bob review' });
  });

  it('lets the author read their own review', async () => {
    await assertSucceeds(getDoc(doc(asUser(env, 'alice'), 'feedback', feedbackId('i1', 'alice'))));
  });

  it('refuses reading someone else\'s review', async () => {
    await assertFails(getDoc(doc(asUser(env, 'alice'), 'feedback', feedbackId('i1', 'bob'))));
  });

  it('lets an admin and the super admin read any review', async () => {
    await assertSucceeds(getDoc(doc(asUser(env, 'adm'), 'feedback', feedbackId('i1', 'alice'))));
    await assertSucceeds(getDoc(doc(asUser(env, 'boss'), 'feedback', feedbackId('i1', 'bob'))));
  });

  it('lets anyone signed in look up a review that does not exist yet', async () => {
    // The app checks for an existing review before creating one.
    await assertSucceeds(getDoc(doc(asUser(env, 'alice'), 'feedback', feedbackId('i1', 'carol'))));
    await assertSucceeds(getDoc(doc(asUser(env, 'alice'), 'feedback', feedbackId('i2', 'alice'))));
  });

  it('refuses reading while signed out', async () => {
    await assertFails(getDoc(doc(signedOut(env), 'feedback', feedbackId('i1', 'alice'))));
  });

  it('lets a user list only their own feedback (My feedback)', async () => {
    const mine = getDocs(
      query(collection(asUser(env, 'alice'), 'feedback'), where('userId', '==', 'alice')),
    );
    const snapshot = await assertSucceeds(mine);
    if (snapshot.size !== 1) throw new Error(`expected 1, got ${snapshot.size}`);
  });

  it('refuses a user listing everyone\'s feedback', async () => {
    await assertFails(getDocs(collection(asUser(env, 'alice'), 'feedback')));
  });

  it('refuses a user listing another user\'s feedback', async () => {
    await assertFails(
      getDocs(query(collection(asUser(env, 'alice'), 'feedback'), where('userId', '==', 'bob'))),
    );
  });

  it('refuses a user listing by item (they would see other people\'s reviews)', async () => {
    await assertFails(
      getDocs(query(collection(asUser(env, 'alice'), 'feedback'), where('itemId', '==', 'i1'))),
    );
  });

  it('lets an admin run the dashboard query', async () => {
    const dashboard = getDocs(
      query(collection(asUser(env, 'adm'), 'feedback'), orderBy('createdAt', 'desc'), limit(500)),
    );
    const snapshot = await assertSucceeds(dashboard);
    if (snapshot.size !== 2) throw new Error(`expected 2, got ${snapshot.size}`);
  });

  it('lets the super admin run the dashboard query too', async () => {
    await assertSucceeds(
      getDocs(query(collection(asUser(env, 'boss'), 'feedback'), orderBy('createdAt', 'desc'), limit(500))),
    );
  });

  it('refuses the dashboard query for regular users', async () => {
    await assertFails(
      getDocs(query(collection(asUser(env, 'bob'), 'feedback'), orderBy('createdAt', 'desc'), limit(500))),
    );
  });

  it('refuses the dashboard query while signed out', async () => {
    await assertFails(getDocs(collection(signedOut(env), 'feedback')));
  });
});

describe('everything else is denied', () => {
  it('refuses reading or writing unknown collections', async () => {
    for (const uid of ['alice', 'adm', 'boss']) {
      const db = asUser(env, uid);
      await assertFails(getDoc(doc(db, 'secrets/one')));
      await assertFails(setDoc(doc(db, 'secrets/one'), { x: 1 }));
      await assertFails(getDocs(collection(db, 'secrets')));
    }
  });

  it('refuses nested collections under known documents', async () => {
    const db = asUser(env, 'boss');
    await assertFails(setDoc(doc(db, 'users/alice/notes/n1'), { text: 'x' }));
    await assertFails(setDoc(doc(db, 'items/i1/comments/c1'), { text: 'x' }));
  });
});
