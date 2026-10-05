/* FixPose marketing site — progressive enhancement only.
   The site is fully readable without JavaScript. */
(function () {
  "use strict";

  /* ---------- Mobile navigation ---------- */
  var toggle = document.querySelector(".nav__toggle");
  var links = document.getElementById("primary-navigation");

  if (toggle && links) {
    toggle.addEventListener("click", function () {
      var open = links.classList.toggle("is-open");
      toggle.setAttribute("aria-expanded", open ? "true" : "false");
      toggle.setAttribute("aria-label", open ? "Close menu" : "Open menu");
    });

    links.addEventListener("click", function (event) {
      if (event.target.tagName === "A") {
        links.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
        toggle.setAttribute("aria-label", "Open menu");
      }
    });

    document.addEventListener("keydown", function (event) {
      if (event.key === "Escape" && links.classList.contains("is-open")) {
        links.classList.remove("is-open");
        toggle.setAttribute("aria-expanded", "false");
        toggle.focus();
      }
    });
  }

  /* ---------- Current page highlight ---------- */
  var here = (window.location.pathname.split("/").pop() || "index.html").toLowerCase();
  if (here === "" || here === "/") { here = "index.html"; }

  Array.prototype.forEach.call(document.querySelectorAll("[data-nav]"), function (a) {
    var target = (a.getAttribute("href") || "").split("#")[0].toLowerCase();
    if (target === here) { a.setAttribute("aria-current", "page"); }
  });

  /* ---------- Footer year ---------- */
  Array.prototype.forEach.call(document.querySelectorAll("[data-year]"), function (el) {
    el.textContent = String(new Date().getFullYear());
  });

  /* ---------- Hero background video ----------
     Muted autoplay is allowed everywhere, but respect the user's data and
     motion preferences: no autoplay under Save-Data, and hold on the poster
     frame under prefers-reduced-motion. Also pause when the tab is hidden. */
  var heroVideo = document.getElementById("hero-video");
  if (heroVideo) {
    var conn = navigator.connection || navigator.mozConnection ||
      navigator.webkitConnection;
    var saveData = !!(conn && conn.saveData);
    var reduceHeroMotion = window.matchMedia &&
      window.matchMedia("(prefers-reduced-motion: reduce)").matches;

    if (saveData || reduceHeroMotion) {
      heroVideo.removeAttribute("autoplay");
      heroVideo.pause();
      heroVideo.addEventListener("loadeddata", function () {
        heroVideo.pause();
      });
    } else {
      heroVideo.addEventListener("error", function () {
        /* Broken/missing file — the poster image stays visible. */
        heroVideo.style.display = "none";
      });
      document.addEventListener("visibilitychange", function () {
        if (document.hidden) {
          heroVideo.pause();
        } else {
          var p = heroVideo.play();
          if (p && p.catch) { p.catch(function () {}); }
        }
      });
    }
  }

  /* ---------- Copy checksum ---------- */
  var copyBtn = document.querySelector("[data-copy]");
  if (copyBtn) {
    copyBtn.addEventListener("click", function () {
      var code = document.getElementById(copyBtn.getAttribute("data-copy"));
      if (!code) { return; }
      var text = code.textContent.trim();

      var confirm = function () {
        var original = copyBtn.getAttribute("data-label") || copyBtn.textContent;
        copyBtn.setAttribute("data-label", original);
        copyBtn.textContent = "Copied";
        window.setTimeout(function () { copyBtn.textContent = original; }, 1800);
      };

      var legacy = function () {
        try {
          var ta = document.createElement("textarea");
          ta.value = text;
          ta.setAttribute("readonly", "");
          ta.style.position = "fixed";
          ta.style.left = "-9999px";
          document.body.appendChild(ta);
          ta.select();
          var done = document.execCommand("copy");
          document.body.removeChild(ta);
          if (done) { confirm(); }
        } catch (err) { /* clipboard unavailable — the checksum is selectable text */ }
      };

      if (navigator.clipboard && navigator.clipboard.writeText) {
        navigator.clipboard.writeText(text).then(confirm, legacy);
      } else {
        legacy();
      }
    });
  }

  /* ---------- Scroll reveal ---------- */
  var revealables = document.querySelectorAll(".reveal");
  if (!revealables.length) { return; }

  var reduceMotion = window.matchMedia &&
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

  if (reduceMotion || !("IntersectionObserver" in window)) {
    Array.prototype.forEach.call(revealables, function (el) {
      el.classList.add("is-visible");
    });
    return;
  }

  var observer = new IntersectionObserver(function (entries) {
    entries.forEach(function (entry) {
      if (entry.isIntersecting) {
        entry.target.classList.add("is-visible");
        observer.unobserve(entry.target);
      }
    });
  }, { rootMargin: "0px 0px -8% 0px", threshold: 0.08 });

  Array.prototype.forEach.call(revealables, function (el) { observer.observe(el); });
})();

/* ---------- Contact form (about page) ----------
   Posts to the contact-messages edge function, which archives the row and
   emails the team a briefing. The publishable key is public by design; the
   recipient address lives only in a server secret. */
(function () {
  var form = document.getElementById("contact-form");
  if (!form) { return; }

  var statusEl = document.getElementById("cf-status");
  var fn = form.getAttribute("data-fn");
  var key = form.getAttribute("data-key");

  function setStatus(msg, cls) {
    statusEl.textContent = msg;
    statusEl.className = "contact-form__status" + (cls ? " " + cls : "");
  }

  form.addEventListener("submit", function (e) {
    e.preventDefault();

    var fd = new FormData(form);
    var honeypot = String(fd.get("website") || "");
    var name = String(fd.get("name") || "").trim();
    var email = String(fd.get("email") || "").trim();
    var topic = String(fd.get("topic") || "General enquiry");
    var message = String(fd.get("message") || "").trim();

    /* Bots fill the hidden field — fake success, send nothing. */
    if (honeypot) { setStatus("Sent — thanks!", "is-ok"); form.reset(); return; }

    if (!name || !email || !message) {
      setStatus("Please fill in your name, email and message.", "is-err");
      return;
    }
    if (!/^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(email)) {
      setStatus("That email doesn't look right — mind checking it?", "is-err");
      return;
    }
    if (message.length < 10) {
      setStatus("A little more detail, please (10+ characters).", "is-err");
      return;
    }

    var btn = form.querySelector('button[type="submit"]');
    btn.disabled = true;
    setStatus("Sending\u2026", "");

    fetch(fn, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": "Bearer " + key,
        "apikey": key
      },
      body: JSON.stringify({
        name: name,
        email: email,
        topic: topic,
        message: message,
        page: location.pathname
      })
    })
      .then(function (r) {
        return r.json().then(function (j) { return { ok: r.ok, status: r.status, body: j }; });
      })
      .then(function (x) {
        if (!x.ok || !x.body.ok) {
          throw new Error((x.body && x.body.error) || ("http_" + x.status));
        }
        setStatus("Sent \u2014 thanks! We'll reply to " + email + " within a day.", "is-ok");
        form.reset();
      })
      .catch(function (err) {
        if (String(err.message) === "slow_down") {
          setStatus("You just sent one — give it 30 seconds before the next.", "is-err");
        } else {
          setStatus("Couldn't send — please try again in a moment.", "is-err");
        }
      })
      .then(function () { btn.disabled = false; });
  });
})();
