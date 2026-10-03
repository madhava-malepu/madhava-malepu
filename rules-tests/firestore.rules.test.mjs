// Firestore rules tests — run against the real rules engine in the emulator.
//   cd rules-tests && npm install && npm test
// Every attack below must be DENIED; every real app/website action must still be ALLOWED.
import { readFileSync } from 'node:fs';
import { initializeTestEnvironment, assertFails, assertSucceeds } from '@firebase/rules-unit-testing';
import { doc, setDoc, getDoc, updateDoc, addDoc, collection, getDocs, query, where, serverTimestamp, increment } from 'firebase/firestore';

const env = await initializeTestEnvironment({
  projectId: 'surpl-rules-test',
  firestore: { rules: readFileSync(process.env.RULES_FILE || new URL('../firestore.rules', import.meta.url), 'utf8'), host: '127.0.0.1', port: 8080 }
});
const nowS = () => Math.floor(Date.now() / 1000);
await env.withSecurityRulesDisabled(async ctx => {
  const db = ctx.firestore();
  await setDoc(doc(db, 'users/alice'), { uid: 'alice', walletBalance: 50, lastStreakReward: nowS() - 8 * 86400, referralCount: 0, isVendor: false, vendorStatus: '', name: '' });
  await setDoc(doc(db, 'users/bob'), { uid: 'bob', walletBalance: 0, referralCount: 0, isVendor: false, vendorStatus: '' });
  await setDoc(doc(db, 'users/vendor1'), { uid: 'vendor1', isVendor: true, vendorStatus: 'approved', walletBalance: 0 });
  await setDoc(doc(db, 'bags/b1'), { merchantId: 'vendor1', isActive: true, price: 89, originalPrice: 220, availableQuantity: 5, title: 'Bag' });
  await setDoc(doc(db, 'orders/o1'), { customerId: 'alice', merchantId: 'vendor1', status: 'confirmed', pickupCode: 'ABC123', listingType: 'surplus', bagPrice: 89, platformFee: 5, amountPaid: 94 });
  await setDoc(doc(db, 'vendorNotifications/n1'), { vendorUid: 'vendor1', type: 'new_order', title: 'New Order! Code: ABC123', body: 'x', orderId: 'o1', pickupCode: 'ABC123', read: false });
});
const as = uid => (uid ? env.authenticatedContext(uid) : env.unauthenticatedContext()).firestore();
const alice = as('alice'), bob = as('bob'), vendor = as('vendor1'), anon = as(null);

let pass = 0, fail = 0;
async function t(name, expectAllowed, fn) {
  try { await (expectAllowed ? assertSucceeds(fn()) : assertFails(fn())); pass++; console.log(`✓ ${expectAllowed ? 'allows' : 'blocks'}: ${name}`); }
  catch (e) { fail++; console.log(`✗ ${expectAllowed ? 'should allow' : 'should block'}: ${name} — ${e.message.split('\n')[0]}`); }
}

console.log('\n— Attacks (must be blocked) —');
await t('customer writes their own "confirmed" order with no payment', false, () => setDoc(doc(alice, 'orders/fake'), { customerId: 'alice', merchantId: 'vendor1', status: 'confirmed', pickupCode: 'FREE01', bagPrice: 89, quantity: 1, platformFee: 5, vendorPayout: 89, surplRevenue: 5 }));
await t('customer adds ₹25 to their own wallet', false, () => updateDoc(doc(alice, 'users/alice'), { walletBalance: 75 }));
await t('customer adds ₹10 without the streak timestamp', false, () => updateDoc(doc(alice, 'users/alice'), { walletBalance: increment(10) }));
await t('customer resets their streak timer to claim again', false, () => updateDoc(doc(alice, 'users/alice'), { lastStreakReward: 0 }));
await t('user raises someone else\'s referral count', false, () => updateDoc(doc(bob, 'users/alice'), { referralCount: increment(1) }));
await t('customer raises their own referral count', false, () => updateDoc(doc(alice, 'users/alice'), { referralCount: 5 }));
await t('any user changes another shop\'s bag stock', false, () => updateDoc(doc(bob, 'bags/b1'), { availableQuantity: 0 }));
await t('user reads another vendor\'s notification (pickup code)', false, () => getDoc(doc(bob, 'vendorNotifications/n1')));
await t('user lists all vendor notifications', false, () => getDocs(collection(bob, 'vendorNotifications')));
await t('user fakes a notification for someone else\'s order', false, () => addDoc(collection(bob, 'vendorNotifications'), { vendorUid: 'vendor1', type: 'new_order', title: 't', body: 'b', orderId: 'o1', pickupCode: 'ZZZ999', read: false, createdAt: serverTimestamp() }));
await t('user reads someone else\'s order', false, () => getDoc(doc(bob, 'orders/o1')));
await t('customer fakes a ₹500 wallet credit record', false, () => addDoc(collection(alice, 'wallet_transactions'), { userId: 'alice', type: 'credit', amount: 500, note: 'x', createdAt: serverTimestamp() }));
await t('anyone stuffs junk fields into deal alerts', false, () => addDoc(collection(anon, 'dealAlertSignups'), { phone: '9876543210', createdAt: serverTimestamp(), spam: 'x'.repeat(5000) }));
await t('anyone saves an invalid phone to deal alerts', false, () => addDoc(collection(anon, 'dealAlertSignups'), { phone: 'not-a-phone', createdAt: serverTimestamp() }));
await t('anyone saves a vendor lead marked approved', false, () => addDoc(collection(anon, 'vendorLeads'), { shopName: 'Shop', ownerName: 'Ravi', whatsapp: '9876543210', shopType: 'Bakery', area: 'Main Rd', address: '', status: 'approved', createdAt: serverTimestamp() }));
await t('anyone adds extra fields to a vendor lead', false, () => addDoc(collection(anon, 'vendorLeads'), { shopName: 'Shop', ownerName: 'Ravi', whatsapp: '9876543210', shopType: 'Bakery', area: 'Main Rd', address: '', status: 'pending', createdAt: serverTimestamp(), isVendor: true }));
await t('customer makes themselves a vendor', false, () => updateDoc(doc(alice, 'users/alice'), { isVendor: true }));
await t('customer marks their own order completed', false, () => updateDoc(doc(alice, 'orders/o1'), { status: 'completed' }));

console.log('\n— Real app and website actions (must still work) —');
await t('website: new customer profile on first sign-in', true, () => setDoc(doc(as('newbie'), 'users/newbie'), { uid: 'newbie', phoneNumber: '+919876500000', name: '', email: '', isVendor: false, vendorStatus: '', savedBags: [], walletBalance: 0, referralCode: 'NEWBIE00', referralCount: 0, referredBy: '', firstOrderDiscountPct: 0, createdAt: serverTimestamp() }));
await t('website profile: customer saves name + email', true, () => updateDoc(doc(alice, 'users/alice'), { name: 'Alice', email: 'a@example.com' }));
await t('app: weekly streak reward (₹10, once a week)', true, () => updateDoc(doc(alice, 'users/alice'), { walletBalance: 60, lastStreakReward: nowS() }));
await t('app: a second streak reward the same week is refused', false, () => updateDoc(doc(alice, 'users/alice'), { walletBalance: 70, lastStreakReward: nowS() }));
await t('app: streak reward wallet record', true, () => addDoc(collection(alice, 'wallet_transactions'), { userId: 'alice', type: 'credit', amount: 10, note: '🔥 Weekly streak reward — 3 bags this week!', createdAt: serverTimestamp() }));
await t('customer reads their own order', true, () => getDoc(doc(alice, 'orders/o1')));
await t('app: customer notifies the vendor about their own order', true, () => addDoc(collection(alice, 'vendorNotifications'), { vendorUid: 'vendor1', type: 'new_order', title: 'New Order! Code: ABC123', body: '"Bag" — Rs.94. Pickup code: ABC123', orderId: 'o1', pickupCode: 'ABC123', read: false, createdAt: serverTimestamp() }));
await t('vendor reads their own notifications', true, () => getDocs(query(collection(vendor, 'vendorNotifications'), where('vendorUid', '==', 'vendor1'), where('read', '==', false))));
await t('vendor marks a notification read', true, () => updateDoc(doc(vendor, 'vendorNotifications/n1'), { read: true }));
await t('vendor updates stock on their own bag', true, () => updateDoc(doc(vendor, 'bags/b1'), { availableQuantity: 3, price: 89 }));
await t('vendor accepts an order', true, () => updateDoc(doc(vendor, 'orders/o1'), { vendorAcknowledged: true, vendorAcknowledgedAt: 1 }));
await t('vendor confirms pickup (completed)', true, () => updateDoc(doc(vendor, 'orders/o1'), { status: 'completed', completedAt: 2 }));
await t('customer rates a completed order', true, () => updateDoc(doc(alice, 'orders/o1'), { ratedAt: 3 }));
await t('website: WhatsApp deal alert signup', true, () => addDoc(collection(anon, 'dealAlertSignups'), { phone: '9876543210', createdAt: serverTimestamp() }));
await t('website: town waitlist signup', true, () => addDoc(collection(anon, 'dealAlertSignups'), { phone: '+919876543211', city: 'Korutla', source: 'city-waitlist', createdAt: serverTimestamp() }));
await t('website: vendor application', true, () => addDoc(collection(anon, 'vendorLeads'), { shopName: 'Test Tiffins', ownerName: 'Ravi', whatsapp: '98765 43210', shopType: 'Bakery', area: 'Bus Stand Road', address: '', status: 'pending', createdAt: serverTimestamp() }));
await t('app: customer files their own account deletion request', true, () => setDoc(doc(alice, 'accountDeletionRequests/alice'), { uid: 'alice', phoneNumber: '+919800000000', source: 'app', requestedAt: serverTimestamp() }));
await t('user files a deletion request for someone else', false, () => setDoc(doc(bob, 'accountDeletionRequests/alice'), { uid: 'alice', phoneNumber: '+919800000000', source: 'app', requestedAt: serverTimestamp() }));
await t('anyone browses active bags', true, () => getDoc(doc(anon, 'bags/b1')));

await env.cleanup();
console.log(`\n${pass}/${pass + fail} rule checks passed`);
process.exit(fail ? 1 : 0);
