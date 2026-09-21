// Shared setup for the Firestore rules tests.
//
// The document shapes and the transaction steps below mirror what the Flutter
// app writes (lib/repositories/*.dart), so a passing test means the real app
// passes the rules too.

import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { initializeTestEnvironment } from '@firebase/rules-unit-testing';
import {
  doc,
  getDoc,
  runTransaction,
  serverTimestamp,
  setDoc,
  Timestamp,
} from 'firebase/firestore';

const here = dirname(fileURLToPath(import.meta.url));

export const PROJECT_ID = 'demo-feedback-review';

export async function createTestEnv() {
  return initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(join(here, '..', 'firestore.rules'), 'utf8'),
    },
  });
}

/** Firestore handle for a signed-in user. */
export const asUser = (env, uid) => env.authenticatedContext(uid).firestore();

/** Firestore handle for someone who is not signed in. */
export const signedOut = (env) => env.unauthenticatedContext().firestore();

/** Writes seed data bypassing the rules. */
export const seed = (env, fn) =>
  env.withSecurityRulesDisabled((context) => fn(context.firestore()));

// ---------------------------------------------------------------------------
// Document shapes (what the app writes)
// ---------------------------------------------------------------------------

export const profile = (uid, { name = uid, email, role = 'user' } = {}) => ({
  uid,
  name,
  email: email ?? `${uid}@example.com`,
  role,
  createdAt: Timestamp.now(),
});

export const item = (id, overrides = {}) => ({
  id,
  title: `Item ${id}`,
  description: 'About this item',
  type: 'course',
  isActive: true,
  createdBy: 'adm',
  createdAt: Timestamp.now(),
  ratingCount: 0,
  ratingSum: 0,
  averageRating: 0.0,
  ...overrides,
});

/** The rating totals the app writes for a count and a sum. */
export const totals = (count, sum) => ({
  ratingCount: count,
  ratingSum: sum,
  averageRating: count === 0 ? 0.0 : sum / count,
});

export const feedbackId = (itemId, uid) => `${itemId}_${uid}`;

/** A new feedback document as the app builds it. */
export const feedbackDoc = (itemRecord, uid, name, rating, extra = {}) => ({
  id: feedbackId(itemRecord.id, uid),
  itemId: itemRecord.id,
  itemTitle: itemRecord.title,
  itemType: itemRecord.type,
  userId: uid,
  userName: name,
  rating,
  review: '',
  suggestion: '',
  createdAt: serverTimestamp(),
  updatedAt: serverTimestamp(),
  ...extra,
});

/**
 * The base world every test starts from:
 *   alice, bob   regular users
 *   adm          admin
 *   boss         super admin
 *   i1           an active course, i2 an inactive task (both with no ratings)
 */
export async function seedBaseWorld(env) {
  await seed(env, async (db) => {
    await setDoc(doc(db, 'users/alice'), profile('alice', { name: 'Alice' }));
    await setDoc(doc(db, 'users/bob'), profile('bob', { name: 'Bob' }));
    await setDoc(
      doc(db, 'users/adm'),
      profile('adm', { name: 'Adam', role: 'admin' }),
    );
    await setDoc(
      doc(db, 'users/boss'),
      profile('boss', { name: 'Boss', role: 'superAdmin' }),
    );
    await setDoc(doc(db, 'items/i1'), item('i1', { title: 'Flutter Basics' }));
    await setDoc(
      doc(db, 'items/i2'),
      item('i2', { title: 'Old Task', type: 'task', isActive: false }),
    );
  });
}

// ---------------------------------------------------------------------------
// The app's feedback transactions (see FeedbackRepository)
// ---------------------------------------------------------------------------

/** Creates or edits a review, adjusting the item's totals, like the app. */
export async function submitFeedback(
  db,
  { itemId, uid, name, rating, review = '', suggestion = '' },
) {
  const itemRef = doc(db, 'items', itemId);
  const feedbackRef = doc(db, 'feedback', feedbackId(itemId, uid));

  await runTransaction(db, async (tx) => {
    const itemSnap = await tx.get(itemRef);
    const feedbackSnap = await tx.get(feedbackRef);
    const current = itemSnap.data();
    let count = current.ratingCount;
    let sum = current.ratingSum;

    if (!feedbackSnap.exists()) {
      count += 1;
      sum += rating;
      tx.set(
        feedbackRef,
        feedbackDoc(current, uid, name, rating, { review, suggestion }),
      );
    } else {
      sum += rating - feedbackSnap.data().rating;
      tx.update(feedbackRef, {
        itemTitle: current.title,
        itemType: current.type,
        userName: name,
        rating,
        review,
        suggestion,
        updatedAt: serverTimestamp(),
      });
    }
    tx.update(itemRef, totals(count, sum));
  });
}

/** Deletes a review and takes its rating out of the item, like the app. */
export async function deleteFeedback(db, itemId, uid) {
  const feedbackRef = doc(db, 'feedback', feedbackId(itemId, uid));
  const itemRef = doc(db, 'items', itemId);

  await runTransaction(db, async (tx) => {
    const feedbackSnap = await tx.get(feedbackRef);
    const itemSnap = await tx.get(itemRef);
    const rating = feedbackSnap.data().rating;
    const current = itemSnap.data();
    tx.delete(feedbackRef);
    tx.update(itemRef, totals(current.ratingCount - 1, current.ratingSum - rating));
  });
}

/** Reads a document with the rules bypassed, for checking what was saved. */
export async function readRaw(env, path) {
  let data;
  await seed(env, async (db) => {
    data = (await getDoc(doc(db, path))).data();
  });
  return data;
}
