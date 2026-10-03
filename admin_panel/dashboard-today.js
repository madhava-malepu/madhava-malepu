(function(root){
  const start = now => Math.floor((now + 19800000) / 86400000) * 86400000 - 19800000;
  function millis(v){if(v?.toMillis)return v.toMillis();if(v?.seconds!=null)return v.seconds*1000;if(v instanceof Date)return v.getTime();return typeof v==='number'?(v<1e12?v*1000:v):0;}
  function summary(orders,users,now=Date.now()){
    const from=start(now),to=from+86400000;
    const inDay=v=>{const t=millis(v);return t>=from&&t<to;};
    const today=orders.filter(o=>inDay(o.timestamp));
    const sum=fn=>today.reduce((n,o)=>n+Math.round(fn(o)*100),0)/100;
    return {date:new Date(now).toLocaleDateString('en-IN',{timeZone:'Asia/Kolkata',day:'numeric',month:'long',year:'numeric'}),
      orders:new Set(today.map(o=>o.orderGroupId||o.id||o)).size,
      sales:sum(o=>Number(o.amountPaid)||0),net:sum(o=>Number(o.surplRevenue)||0),
      commission:sum(o=>Number.isFinite(o.vendorPayout)?Math.max(0,(o.vendorBasePrice??o.bagPrice??0)*(o.quantity||1)-o.vendorPayout):0),
      customers:users.filter(u=>!u.isVendor&&inDay(u.createdAt)).length,
      standardPct:now>=Date.parse('2026-10-01T00:00:00+05:30')?10:0};
  }
  root.surplToday=summary;
  if(typeof module!=='undefined')module.exports=summary;
})(typeof window==='undefined'?globalThis:window);
