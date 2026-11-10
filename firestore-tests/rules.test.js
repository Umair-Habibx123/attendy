// Runs ../firestore.rules in the Firestore emulator.  npm test
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { after, before, beforeEach, describe, test } from 'node:test';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';
import {
  collection, collectionGroup, deleteDoc, doc, getDoc, getDocs, query,
  serverTimestamp, setDoc, updateDoc, where, writeBatch,
} from 'firebase/firestore';

// Same calculation as the app and the rules: today's date in UTC+5.
const dayKey = (offsetDays = 0) => {
  const t = new Date(Date.now() + 5 * 3600e3 + offsetDays * 86400e3);
  return t.toISOString().slice(0, 10);
};

let env;
const db = (uid, { verified = true } = {}) =>
  env.authenticatedContext(uid, { email: `${uid}@example.com`, email_verified: verified }).firestore();

const day = (uid, date, by = uid, status = 'present') => ({
  uid, date, status, markedAt: serverTimestamp(), markedBy: by,
});

before(async () => {
  env = await initializeTestEnvironment({
    projectId: 'demo-attendy',
    firestore: { rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8') },
  });
});
after(async () => env?.cleanup());

beforeEach(async () => {
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const f = ctx.firestore();
    const profile = (name, role, active = true) => ({ name, email: '', role, active, photo: null, createdAt: new Date() });
    await setDoc(doc(f, 'users/admin'), profile('Admin', 'admin'));
    await setDoc(doc(f, 'users/alice'), profile('Alice', 'user'));
    await setDoc(doc(f, 'users/bob'), profile('Bob', 'user'));
    await setDoc(doc(f, 'users/inactive'), profile('Gone', 'user', false));
    await setDoc(doc(f, 'attendance/bob/days/2025-01-06'), { uid: 'bob', date: '2025-01-06', status: 'present', markedAt: new Date(), markedBy: 'bob' });
    await setDoc(doc(f, 'leaveRequests/pending1'), { uid: 'alice', name: 'Alice', from: dayKey(1), to: dayKey(2), reason: 'Family event', status: 'pending', createdAt: new Date() });
    await setDoc(doc(f, 'leaveRequests/approved1'), { uid: 'alice', name: 'Alice', from: dayKey(3), to: dayKey(3), reason: 'Doctor', status: 'approved', createdAt: new Date() });
  });
});

describe('users', () => {
  const newProfile = (uid, extra = {}) => ({
    name: 'New Person', email: `${uid}@example.com`, role: 'user', active: true, photo: null,
    createdAt: serverTimestamp(), ...extra,
  });

  test('anyone can sign up as a regular user', () =>
    assertSucceeds(setDoc(doc(db('carol'), 'users/carol'), newProfile('carol'))));

  test('nobody can sign up as an admin', () =>
    assertFails(setDoc(doc(db('carol'), 'users/carol'), newProfile('carol', { role: 'admin' }))));

  test("you can't create someone else's profile", () =>
    assertFails(setDoc(doc(db('carol'), 'users/dave'), newProfile('dave'))));

  test('users edit their own name, but not their role or status', async () => {
    await assertSucceeds(updateDoc(doc(db('alice'), 'users/alice'), { name: 'Alice A.' }));
    await assertFails(updateDoc(doc(db('alice'), 'users/alice'), { role: 'admin' }));
    await assertFails(updateDoc(doc(db('alice'), 'users/alice'), { active: false }));
  });

  test("users can't read other people's profiles; admins can", async () => {
    await assertFails(getDoc(doc(db('alice'), 'users/bob')));
    await assertSucceeds(getDoc(doc(db('admin'), 'users/bob')));
    await assertSucceeds(getDocs(collection(db('admin'), 'users')));
    await assertFails(getDocs(collection(db('alice'), 'users')));
  });

  test("admins promote or deactivate others, but can't change themselves", async () => {
    await assertSucceeds(updateDoc(doc(db('admin'), 'users/bob'), { role: 'admin' }));
    await assertSucceeds(updateDoc(doc(db('admin'), 'users/alice'), { active: false }));
    await assertFails(updateDoc(doc(db('admin'), 'users/admin'), { role: 'user' }));
    await assertFails(updateDoc(doc(db('admin'), 'users/bob'), { name: 'Renamed by admin' }));
  });

  test('profiles are never deleted', () => assertFails(deleteDoc(doc(db('admin'), 'users/bob'))));
});

describe('attendance', () => {
  test('a verified user marks themselves present today', () =>
    assertSucceeds(setDoc(doc(db('alice'), `attendance/alice/days/${dayKey()}`), day('alice', dayKey()))));

  test("changing the phone's date doesn't help: yesterday and tomorrow are refused", async () => {
    await assertFails(setDoc(doc(db('alice'), `attendance/alice/days/${dayKey(-1)}`), day('alice', dayKey(-1))));
    await assertFails(setDoc(doc(db('alice'), `attendance/alice/days/${dayKey(1)}`), day('alice', dayKey(1))));
  });

  test("users can't record absence or leave themselves", async () => {
    await assertFails(setDoc(doc(db('alice'), `attendance/alice/days/${dayKey()}`), day('alice', dayKey(), 'alice', 'leave')));
  });

  test("users can't mark someone else, or edit or delete a day once marked", async () => {
    await assertFails(setDoc(doc(db('alice'), `attendance/bob/days/${dayKey()}`), day('bob', dayKey(), 'alice')));
    await assertFails(updateDoc(doc(db('bob'), 'attendance/bob/days/2025-01-06'), { status: 'absent' }));
    await assertFails(deleteDoc(doc(db('bob'), 'attendance/bob/days/2025-01-06')));
  });

  test('unverified and deactivated accounts cannot mark', async () => {
    await assertFails(setDoc(doc(db('alice', { verified: false }), `attendance/alice/days/${dayKey()}`), day('alice', dayKey())));
    await assertFails(setDoc(doc(db('inactive'), `attendance/inactive/days/${dayKey()}`), day('inactive', dayKey())));
  });

  test('the client must use the server clock for markedAt', () =>
    assertFails(setDoc(doc(db('alice'), `attendance/alice/days/${dayKey()}`), { ...day('alice', dayKey()), markedAt: new Date('2020-01-01') })));

  test('admins set any status on any day, signed with their own uid', async () => {
    await assertSucceeds(setDoc(doc(db('admin'), 'attendance/bob/days/2025-01-07'), day('bob', '2025-01-07', 'admin', 'absent')));
    await assertSucceeds(updateDoc(doc(db('admin'), 'attendance/bob/days/2025-01-06'), { status: 'leave', markedAt: serverTimestamp(), markedBy: 'admin' }));
    await assertFails(setDoc(doc(db('admin'), 'attendance/bob/days/2025-01-08'), day('bob', '2025-01-08', 'bob', 'absent')));
    await assertSucceeds(deleteDoc(doc(db('admin'), 'attendance/bob/days/2025-01-06')));
  });

  test("users only read their own days; only admins query across everyone", async () => {
    await assertSucceeds(getDoc(doc(db('bob'), 'attendance/bob/days/2025-01-06')));
    await assertFails(getDoc(doc(db('alice'), 'attendance/bob/days/2025-01-06')));
    await assertFails(getDocs(query(collectionGroup(db('alice'), 'days'), where('date', '==', '2025-01-06'))));
    await assertSucceeds(getDocs(query(collectionGroup(db('admin'), 'days'), where('date', '==', '2025-01-06'))));
  });
});

describe('work schedule (settings/organization)', () => {
  const schedule = (by, extra = {}) => ({ workingDays: [1, 2, 3, 4, 5, 6], holidays: ['2026-12-25'], holidayNames: { '2026-12-25': 'Quaid-e-Azam Day' }, updatedAt: serverTimestamp(), updatedBy: by, ...extra });

  test('admins set the schedule; members only read it', async () => {
    await assertSucceeds(setDoc(doc(db('admin'), 'settings/organization'), schedule('admin')));
    await assertSucceeds(getDoc(doc(db('alice'), 'settings/organization')));
    await assertFails(setDoc(doc(db('alice'), 'settings/organization'), schedule('alice')));
  });

  test('the schedule must be well-formed', async () => {
    await assertFails(setDoc(doc(db('admin'), 'settings/organization'), schedule('admin', { workingDays: [] })));
    await assertFails(setDoc(doc(db('admin'), 'settings/organization'), schedule('admin', { workingDays: [1, 8] })));
    await assertFails(setDoc(doc(db('admin'), 'settings/other'), schedule('admin')));
    await assertFails(setDoc(doc(db('admin'), 'settings/organization'), schedule('admin', { extra: true })));
    await assertFails(setDoc(doc(db('admin'), 'settings/organization'), schedule('admin', { holidayNames: 'not a map' })));
  });
});

describe('leave requests', () => {
  const request = (uid, extra = {}) => ({
    uid, name: 'Alice', from: dayKey(1), to: dayKey(2), reason: 'Wedding', status: 'pending',
    createdAt: serverTimestamp(), ...extra,
  });

  test('users request leave from today onward', async () => {
    await assertSucceeds(setDoc(doc(db('alice'), 'leaveRequests/r1'), request('alice')));
    await assertSucceeds(setDoc(doc(db('alice'), 'leaveRequests/r2'), request('alice', { from: dayKey(), to: dayKey() })));
  });

  test("users can't backdate, self-approve, or file for someone else", async () => {
    await assertFails(setDoc(doc(db('alice'), 'leaveRequests/r3'), request('alice', { from: dayKey(-1) })));
    await assertFails(setDoc(doc(db('alice'), 'leaveRequests/r4'), request('alice', { status: 'approved' })));
    await assertFails(setDoc(doc(db('alice'), 'leaveRequests/r5'), request('bob')));
    await assertFails(setDoc(doc(db('alice'), 'leaveRequests/r6'), request('alice', { from: dayKey(3), to: dayKey(1) })));
  });

  test('only admins decide, and only pending requests', async () => {
    const decision = (by, status = 'approved') => ({ status, decidedAt: serverTimestamp(), decidedBy: by });
    await assertFails(updateDoc(doc(db('alice'), 'leaveRequests/pending1'), decision('alice')));
    await assertSucceeds(updateDoc(doc(db('admin'), 'leaveRequests/pending1'), decision('admin')));
    await assertFails(updateDoc(doc(db('admin'), 'leaveRequests/approved1'), decision('admin', 'rejected')));
  });

  test('users withdraw their own pending requests only', async () => {
    await assertFails(deleteDoc(doc(db('bob'), 'leaveRequests/pending1')));
    await assertFails(deleteDoc(doc(db('alice'), 'leaveRequests/approved1')));
    await assertSucceeds(deleteDoc(doc(db('alice'), 'leaveRequests/pending1')));
  });

  test('approving writes leave days that both the admin and the member can read', async () => {
    const admin = db('admin');
    const from = dayKey(1), to = dayKey(2);
    const batch = writeBatch(admin);
    batch.update(doc(admin, 'leaveRequests/pending1'), { status: 'approved', decidedAt: serverTimestamp(), decidedBy: 'admin' });
    for (const d of [from, to]) batch.set(doc(admin, `attendance/alice/days/${d}`), day('alice', d, 'admin', 'leave'));
    await assertSucceeds(batch.commit());

    // The month query used by the People calendar (admin) and History (member).
    const monthQuery = (f) => query(collection(f, 'attendance/alice/days'),
      where('date', '>=', dayKey(-40)), where('date', '<=', dayKey(40)));
    const asAdmin = await assertSucceeds(getDocs(monthQuery(admin)));
    const asMember = await assertSucceeds(getDocs(monthQuery(db('alice'))));
    const leaveDays = (snap) => snap.docs.filter((d) => d.data().status === 'leave').map((d) => d.id).sort();
    assert.deepEqual(leaveDays(asAdmin), [from, to]);
    assert.deepEqual(leaveDays(asMember), [from, to]);
  });

  test("users list their own requests; only admins list everyone's", async () => {
    await assertSucceeds(getDocs(query(collection(db('alice'), 'leaveRequests'), where('uid', '==', 'alice'))));
    await assertFails(getDocs(collection(db('alice'), 'leaveRequests')));
    await assertSucceeds(getDocs(query(collection(db('admin'), 'leaveRequests'), where('status', '==', 'pending'))));
  });
});
