// Trivial cart stub. Not wired to anything server-side; the lab's focus is the
// vulnerabilities, not the shopping flow.
(function () {
  "use strict";
  var KEY = "wdg_cart";
  function read() { try { return JSON.parse(localStorage.getItem(KEY)) || []; } catch (e) { return []; } }
  function write(c) { try { localStorage.setItem(KEY, JSON.stringify(c)); } catch (e) {} }
  window.wdgCart = {
    add: function (id) { var c = read(); c.push(id); write(c); return c.length; },
    count: function () { return read().length; },
    clear: function () { write([]); }
  };
})();
