(function (root) {
  function isPaidOrder(o) {
    if (!['confirmed', 'preparing', 'ready', 'completed', 'missed'].includes(o.status) ||
        o.paymentStatus === 'refunded' || o.refundStatus === 'processed') return false;
    return o.status !== 'missed' || !!o.paymentVerifiedAt ||
      /^pay_/.test(o.razorpayPaymentId || o.paymentId || '') ||
      (o.paymentMethod === 'wallet' && o.paymentId === 'WALLET');
  }
  function vendorEarned(o) {
    return isPaidOrder(o) && o.vendorAtFault !== true && typeof o.vendorPayout === 'number' &&
      Number.isFinite(o.vendorPayout) && o.vendorPayout >= 0 ? Math.round(o.vendorPayout * 100) / 100 : 0;
  }
  root.isPaidOrder = isPaidOrder;
  root.vendorEarned = vendorEarned;
  const money = value => Math.round(Number(value || 0) * 100) / 100;
  const balanceDue = (earned, paid) => Math.max(0, (Math.round(earned * 100) - Math.round((paid || 0) * 100)) / 100);
  root.money = money;
  root.balanceDue = balanceDue;
  if (typeof module !== 'undefined') module.exports = {isPaidOrder, vendorEarned, money, balanceDue};
})(typeof window === 'undefined' ? globalThis : window);
