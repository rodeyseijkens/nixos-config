import QtQuick

// Audio spectrum canvas: one of `styles` (wave default) from cava barValues.
// Inputs: barValues 0..barMax, barCount, barMax, foreground, visualStyle, dead.
// Paint errors degrade to wave — a bad frame can never crash the bar.
Canvas {
  id: viz

  readonly property var styles: [
    "wave", "bars", "bloom", "blocks", "dots", "blob",
    "radar", "tide", "stars", "helix", "aurora", "lightning",
    "orbit", "particles", "comet", "pulse", "ecg", "waveform"
  ]

  property var barValues: []
  property int barCount: 12
  property int barMax: 7
  property color foreground: "transparent"
  property string visualStyle: "wave"
  property bool dead: false
  property int frameRate: 30
  // Display gain from the sensitivity setting (0.6 calm .. 1.6 wild).
  property real sensitivity: 1.0

  // Animation clock (seconds) for the motion styles.
  property real phase: 0
  // Per-style scratch state, lazily seeded by the painters that need it.
  property var particles: []
  property real pulseEnv: 0
  property real pulseFlash: 0
  property real pulseLastBeat: -10
  // Spectrogram history (newest last): music-gated scroll + kick flash.
  property var specHist: []
  property real specAcc: 0
  property real specFlash: 0
  property real specLastKick: -10
  // Auto-gain ceiling: quiet passages bloom, never murky.
  property real specMax: 0
  // ECG sweep 0..1, incremental so speed glides with the music.
  property real ecgHead: 0
  // Helix twist angle, incremental: faster when loud.
  property real helixTwist: 0
  // Kick recoil: 1 on downbeats, decays; twist surges back through it.
  property real helixRecoil: 0
  property real helixLastKick: -10
  // Four ball state: independent elastic motion with beat-driven bounce.
  property var cometBalls: []
  property real cometLastKick: -10
  // Stars kick flash: 1 per downbeat, decays; sparkles ignite through it.
  property real starFlash: 0
  property real starLastKick: -10
  // Starfield lifecycle: positions + ages; old stars reborn elsewhere.
  property var starPos: []
  property var starAge: []
  // Lightning flash: white-out on every downbeat, fast decay.
  property real lightFlash: 0
  property real lightLastKick: -10
  // Strike mode 0 jagged / 2 spear + flow dir; rolled per strike.
  property int lightMode: 0
  property int lightModeLeft: 0
  property real lightTilt: 0
  property int lightFlow: 1
  // Orbit spin (incremental whirl) + kick flash/front + groove envelope.
  property real orbitSpin: 0
  property real orbitFlash: 0
  property real orbitLastKick: -10
  property real orbitEnv: 0
  // Dots spring memory: one position + velocity per dot.
  property var dotY: []
  property var dotV: []
  // Tide offsets + spring recoil (kicks knock back, spring returns).
  property var tideOff: [0, 0]
  property real tideRD: 0
  property real tideRV: 0
  property real tideLastKick: -10
  // Groove envelope (fast attack, slow release) + kick flash.
  property real tideEnv: 0
  property real tideFlash: 0
  property real blobPhase: 0

  onBarValuesChanged: {
    if (!viz.isAnimatedStyle(viz.visualStyle)) viz.requestPaint()
  }
  onVisualStyleChanged: viz.requestPaint()

  function isAnimatedStyle(s) {
    return s === "particles" || s === "blob" || s === "pulse" || s === "comet"
      || s === "ecg" || s === "stars" || s === "aurora" || s === "orbit"
      || s === "helix" || s === "waveform" || s === "dots" || s === "bloom"
      || s === "tide" || s === "lightning"
  }

  // Motion clock (~30fps) for the motion styles: cava-fed styles repaint on
  // each audio frame; the others keep animating in silence.
  Timer {
    interval: Math.max(16, Math.round(1000 / Math.max(1, viz.frameRate)))
    repeat: true
    running: viz.visible && !viz.dead
    onTriggered: {
      viz.phase += 0.05
      var s = viz.visualStyle
      // ECG head: crawls in silence, races loud (incremental = smooth).
      if (s === "ecg") {
        try {
          viz.ecgHead = (viz.ecgHead + 0.004 + viz.average() * 0.016 + viz.bassLevel() * 0.010) % 1
        } catch (e) { viz.ecgHead = (viz.ecgHead + 0.004) % 1 }
      }
      // Stars kick flash: one clean trigger per downbeat, fast decay.
      if (s === "stars") {
        try {
          if (viz.bassLevel() > 0.55 && (viz.phase - viz.starLastKick) > 0.5) {
            viz.starLastKick = viz.phase
            viz.starFlash = 1
          }
          viz.starFlash = (viz.starFlash || 0) * 0.88
        } catch (e) { viz.starFlash = (viz.starFlash || 0) * 0.88 }
      }
      // Lightning flash: white-out on every downbeat, fast decay.
      if (s === "lightning") {
        try {
          if (viz.bassLevel() > 0.55 && (viz.phase - viz.lightLastKick) > 0.5) {
            viz.lightLastKick = viz.phase
            viz.lightFlash = 1
          }
          viz.lightFlash = (viz.lightFlash || 0) * 0.85
        } catch (e) { viz.lightFlash = (viz.lightFlash || 0) * 0.85 }
      }
      // Tide: one shared kick trigger drives recoil + swell; blob breathes slow.
      if (s === "tide" || s === "blob") {
        try {
          var te = Math.max(viz.average(), viz.bassLevel())
          if (s === "tide") {
            var tenv = viz.tideEnv || 0
            tenv += (te - tenv) * (te > tenv ? 0.5 : 0.08)
            viz.tideEnv = tenv
            if (te > 0.55 && (viz.phase - viz.tideLastKick) > 0.6) {
              viz.tideLastKick = viz.phase
              viz.tideRV = (viz.tideRV || 0) - (0.15 + te * 0.15)
              viz.tideFlash = 1
            }
            viz.tideFlash = (viz.tideFlash || 0) * 0.86
            var tRx = viz.tideRD || 0, tRv = viz.tideRV || 0
            tRv += (-0.06 * tRx - 0.14 * tRv)
            tRx += tRv
            viz.tideRD = tRx
            viz.tideRV = tRv
            for (var to = 0; to < 2; to++)
              viz.tideOff[to] += (0.028 + tenv * 0.05) * (to === 0 ? 0.55 : 1.55) + tRv
          } else {
            viz.blobPhase = viz.blobPhase + 0.05 + te * 0.08
          }
        } catch (e) {}
      }
      // Orbit: whirl/drift glide with music; shared kick trigger fires pulse.
      if (s === "orbit") {
        try {
          var oe = Math.max(viz.average(), viz.bassLevel())
          var oenv = viz.orbitEnv || 0
          oenv += (oe - oenv) * (oe > oenv ? 0.5 : 0.08)
          viz.orbitEnv = oenv
          viz.orbitSpin = viz.orbitSpin + 0.02 + oenv * 0.07
            + (viz.orbitFlash || 0) * 0.05
          if (viz.bassLevel() > 0.55 && (viz.phase - viz.orbitLastKick) > 0.5) {
            viz.orbitLastKick = viz.phase
            viz.orbitFlash = 1
          }
          viz.orbitFlash = (viz.orbitFlash || 0) * 0.88
        } catch (e) { viz.orbitSpin = viz.orbitSpin + 0.02 }
      }
      // Waveform history: music-gated snapshots on timer clock only.
      if (s === "waveform") {
        try {
          var se = Math.max(viz.average(), viz.bassLevel())
          viz.specAcc = (viz.specAcc || 0) + 0.4 + se * 1.6
          if (viz.specAcc >= 1) {
            viz.specAcc = 0
            var snap = []
            var smx = 0
            var prev = viz.specHist.length > 0 ? viz.specHist[viz.specHist.length - 1] : null
            for (var sh = 0; sh < viz.barCount; sh++) {
              var nv = viz.barValues[sh] || 0
              var pv = prev ? (prev[sh] || 0) : nv
              var bv = pv + (nv - pv) * 0.5
              snap.push(bv)
              if (bv > smx) smx = bv
            }
            var sgm = viz.specMax || 0
            sgm += (smx - sgm) * (smx > sgm ? 0.5 : 0.02)
            viz.specMax = sgm
            viz.specHist.push(snap)
            while (viz.specHist.length > 38) viz.specHist.shift()
          }
          if (viz.bassLevel() > 0.55 && (viz.phase - viz.specLastKick) > 0.5) {
            viz.specLastKick = viz.phase
            viz.specFlash = 1
          }
          viz.specFlash = (viz.specFlash || 0) * 0.86
        } catch (e) {}
      }
      // Helix: drifts in silence, spins up loud, recoils on kicks.
      if (s === "helix") {
        try {
          var hb = viz.bassLevel()
          if (hb > 0.55 && (viz.phase - viz.helixLastKick) > 0.6) {
            viz.helixLastKick = viz.phase
            viz.helixRecoil = 1
          }
          viz.helixRecoil = (viz.helixRecoil || 0) * 0.90
          viz.helixTwist = viz.helixTwist
            + (0.03 + viz.average() * 0.10 + hb * 0.06) * (1 - 2.2 * viz.helixRecoil)
        } catch (e) { viz.helixTwist = viz.helixTwist + 0.03 }
      }
      if (viz.isAnimatedStyle(s))
        viz.requestPaint()
    }
  }

  // Level 0..1 per bin (pow 0.7 lifts mids); sensitivity gain first.
  function level(i) {
    try {
      var f = Math.min(1, (barValues[i] || 0) / barMax * (sensitivity || 1))
      return Math.pow(f, 0.7)
    } catch (e) { return 0 }
  }
  function average() {
    var sum = 0
    for (var i = 0; i < barCount; i++) sum += level(i)
    return sum / Math.max(1, barCount)
  }
  function bassLevel() {
    try { return (level(0) + level(1) + level(2)) / 3 } catch (e) { return 0 }
  }

  onPaint: {
    var ctx = getContext("2d")
    ctx.reset()
    ctx.clearRect(0, 0, width, height)
    var vals = barValues
    if (!vals || vals.length < 2) return
    try {
      if (visualStyle === "bars") paintBars(ctx)
      else if (visualStyle === "bloom") paintBloom(ctx)
      else if (visualStyle === "blocks") paintBlocks(ctx)
      else if (visualStyle === "dots") paintDots(ctx)
      else if (visualStyle === "blob") paintBlob(ctx)
      else if (visualStyle === "radar") paintRadar(ctx)
      else if (visualStyle === "tide") paintTide(ctx)
      else if (visualStyle === "stars") paintStars(ctx)
      else if (visualStyle === "helix") paintHelix(ctx)
      else if (visualStyle === "aurora") paintAurora(ctx)
      else if (visualStyle === "lightning") paintLightning(ctx)
      else if (visualStyle === "orbit") paintOrbit(ctx)
      else if (visualStyle === "particles") paintParticles(ctx)
      else if (visualStyle === "comet") paintComet(ctx)
      else if (visualStyle === "pulse") paintPulse(ctx)
      else if (visualStyle === "ecg") paintEcg(ctx)
      else if (visualStyle === "waveform") paintWaveform(ctx)
      else paintWave(ctx)
    } catch (e) { try { paintWave(ctx) } catch (e2) {} }
  }

  // The original smooth wave ribbon (default style).
  function paintWave(ctx) {
    var n = barCount
    var mid = height / 2
    var amp = (height / 2) - 1.5
    var top = [{ x: 1, y: mid }]
    for (var i = 0; i < n; i++) {
      var f = level(i)
      top.push({ x: 1 + (width - 2) * (i / (n - 1)), y: mid - amp * f })
    }
    top.push({ x: width - 1, y: mid })
    // Mirrored bottom half, traced back right-to-left.
    var bottom = []
    for (var j = top.length - 1; j >= 0; j--)
      bottom.push({ x: top[j].x, y: 2 * mid - top[j].y })

    ctx.beginPath()
    ctx.moveTo(top[0].x, top[0].y)
    for (var k = 1; k < top.length - 1; k++) {
      var xc = (top[k].x + top[k + 1].x) / 2
      var yc = (top[k].y + top[k + 1].y) / 2
      ctx.quadraticCurveTo(top[k].x, top[k].y, xc, yc)
    }
    ctx.lineTo(top[top.length - 1].x, top[top.length - 1].y)
    for (var m = 1; m < bottom.length - 1; m++) {
      var xb = (bottom[m].x + bottom[m + 1].x) / 2
      var yb = (bottom[m].y + bottom[m + 1].y) / 2
      ctx.quadraticCurveTo(bottom[m].x, bottom[m].y, xb, yb)
    }
    ctx.closePath()
    ctx.globalAlpha = 0.45
    ctx.fillStyle = foreground
    ctx.fill()
    ctx.globalAlpha = 1.0
    ctx.lineWidth = 1.6
    ctx.strokeStyle = foreground
    ctx.stroke()
  }

  // Classic mirrored bars.
  function paintBars(ctx) {
    var n = barCount
    var mid = height / 2
    var amp = (height / 2) - 1.5
    var slot = (width - 2) / n
    var bw = Math.max(1.5, slot * 0.55)
    ctx.fillStyle = foreground
    for (var i = 0; i < n; i++) {
      var h = Math.max(1, amp * level(i))
      var x = 1 + slot * i + (slot - bw) / 2
      ctx.globalAlpha = 0.9
      ctx.fillRect(x, mid - h, bw, h * 2)
    }
    ctx.globalAlpha = 1.0
  }

  // Bloom: a slow-turning flower whose petals stretch with the music.
  function paintBloom(ctx) {
    var cx = width / 2
    var cy = height / 2
    var maxR = Math.min(width, height) / 2 - 1
    var petals = 12
    ctx.fillStyle = foreground
    for (var i = 0; i < petals; i++) {
      var a = (i / petals) * Math.PI * 2 + phase * 0.12
      var f = level(i % barCount)
      var len = 2 + maxR * (0.35 + 0.65 * f)
      var wdt = 1.2 + 1.6 * f
      ctx.save()
      ctx.translate(cx, cy)
      ctx.rotate(a)
      ctx.scale(2.0, 1)
      ctx.globalAlpha = 0.30 + 0.60 * f
      ctx.beginPath()
      ctx.arc(len / 2, 0, len / 2, 0, Math.PI * 2)
      ctx.fill()
      ctx.restore()
    }
    // glowing heart breathing with the average
    ctx.globalAlpha = 0.85
    ctx.beginPath()
    ctx.arc(cx, cy, 1.6 + average() * 2.2, 0, Math.PI * 2)
    ctx.fill()
    ctx.globalAlpha = 1.0
  }

  // Segmented LED ladder, mirrored around the center line.
  function paintBlocks(ctx) {
    var n = barCount
    var mid = height / 2
    var amp = (height / 2) - 1.5
    var slot = (width - 2) / n
    var bw = Math.max(1.5, slot * 0.55)
    var segH = 2.4
    var gap = 1.1
    var segs = Math.max(1, Math.floor(amp / (segH + gap)))
    ctx.fillStyle = foreground
    for (var i = 0; i < n; i++) {
      var lit = Math.round(level(i) * segs)
      var x = 1 + slot * i + (slot - bw) / 2
      for (var s = 0; s < segs; s++) {
        if (s >= lit) break
        ctx.globalAlpha = 0.35 + 0.65 * (s / Math.max(1, segs - 1))
        var y0 = mid - (s + 1) * (segH + gap) + gap
        ctx.fillRect(x, y0, bw, segH)
        ctx.fillRect(x, 2 * mid - y0 - segH, bw, segH)
      }
    }
    ctx.globalAlpha = 1.0
  }

  // Dots: spring beads swinging both ways (ECG-like deviation) with
  // trails, halos, squash, kick pops. Silence settles to center.
  function paintDots(ctx) {
    var n = barCount
    var mid = height / 2
    var amp = (height / 2) - 2.5
    var bass = bassLevel()
    var avg = average()
    if (!dotY || dotY.length !== n || !dotV || dotV.length !== n) {
      dotY = []
      dotV = []
      for (var z = 0; z < n; z++) { dotY.push(mid); dotV.push(0) }
    }
    ctx.fillStyle = foreground
    for (var i = 0; i < n; i++) {
      var f = level(i)
      // Swing both ways: deviation from average, clamped to strip.
      var target = mid - (f - avg) * amp * 2
      if (target < 2.5) target = 2.5
      if (target > height - 2.5) target = height - 2.5
      var v = dotV[i] + (target - dotY[i]) * 0.25
      v *= 0.70
      dotV[i] = v
      var y = dotY[i] + v
      dotY[i] = y
      var x = 1 + (width - 2) * (n === 1 ? 0.5 : (i / (n - 1)))
        + Math.sin(phase * 1.5 + i * 0.7) * (1 + f * 2)
      var r = 1.2 + 2.2 * f + bass * 1.0
      // trail: fading stamps back along the motion
      var alphas = [0, 0.08, 0.15, 0.25]
      for (var t = 3; t >= 1; t--) {
        ctx.globalAlpha = alphas[t]
        ctx.beginPath()
        ctx.arc(x, y - v * t, Math.max(0.5, r * (1 - t * 0.22)), 0, Math.PI * 2)
        ctx.fill()
      }
      // halo: soft glow around the bead
      ctx.globalAlpha = 0.10 + 0.10 * f
      ctx.beginPath()
      ctx.arc(x, y, r * 2.1, 0, Math.PI * 2)
      ctx.fill()
      // squash & stretch along the motion
      var stretch = 1 + Math.min(0.6, Math.abs(v) * 0.25)
      ctx.globalAlpha = Math.min(1, 0.55 + 0.45 * f + bass * 0.3)
      ctx.save()
      ctx.translate(x, y)
      ctx.scale(1 / stretch, stretch)
      ctx.beginPath()
      ctx.arc(0, 0, r, 0, Math.PI * 2)
      ctx.fill()
      ctx.restore()
    }
    ctx.globalAlpha = 1.0
  }

  // Blob: spectrum wobble, breathing slow in silence, quicker loud.
  function paintBlob(ctx) {
    var n = barCount
    var cx = width / 2
    var cy = height / 2
    var base = Math.max(2, Math.min(width, height) / 2 - 2.5)
    var pts = []
    var steps = 24
    for (var s = 0; s < steps; s++) {
      var a = (s / steps) * Math.PI * 2
      var bin = Math.floor(((s / steps) * n)) % n
      var wobble = level(bin) * base * 0.55
      // Calm musical breathing, never fully frozen.
      wobble += Math.sin(blobPhase + s * 1.3) * base * 0.06
      var r = base * 0.55 + wobble
      pts.push({ x: cx + Math.cos(a) * r * 1.6, y: cy + Math.sin(a) * r })
    }
    ctx.beginPath()
    ctx.moveTo((pts[0].x + pts[steps - 1].x) / 2, (pts[0].y + pts[steps - 1].y) / 2)
    for (var k = 0; k < steps; k++) {
      var p = pts[k]
      var q = pts[(k + 1) % steps]
      ctx.quadraticCurveTo(p.x, p.y, (p.x + q.x) / 2, (p.y + q.y) / 2)
    }
    ctx.closePath()
    ctx.globalAlpha = 0.4
    ctx.fillStyle = foreground
    ctx.fill()
    ctx.globalAlpha = 1.0
    ctx.lineWidth = 1.4
    ctx.strokeStyle = foreground
    ctx.stroke()
  }

  // Reactive particles: drift always, energize with the music.
  function paintParticles(ctx) {
    var avg = average()
    if (!particles || particles.length === 0) {
      var seed = []
      for (var i = 0; i < 42; i++) {
        seed.push({
          x: Math.random(), y: Math.random(),
          vx: (Math.random() - 0.5) * 0.02, vy: (Math.random() - 0.5) * 0.02,
          r: 0.6 + Math.random() * 1.4
        })
      }
      particles = seed
    }
    var ps = particles
    var energy = 0.4 + avg * 2.2
    ctx.fillStyle = foreground
    for (var k = 0; k < ps.length; k++) {
      var p = ps[k]
      p.x += p.vx * energy
      p.y += p.vy * energy
      if (p.x < 0) p.x += 1
      if (p.x > 1) p.x -= 1
      if (p.y < 0) p.y += 1
      if (p.y > 1) p.y -= 1
      ctx.globalAlpha = 0.25 + Math.min(0.75, avg * 1.2)
      ctx.beginPath()
      ctx.arc(p.x * width, p.y * height, p.r * (0.7 + avg), 0, Math.PI * 2)
      ctx.fill()
    }
    ctx.globalAlpha = 1.0
  }

  // Pulse: tile grid shattering outward per kick (smoothed bass
  // envelope + beat flash with cooldown).
  function paintPulse(ctx) {
    var bass = bassLevel()
    var env = pulseEnv || 0
    env += (bass - env) * (bass > env ? 0.6 : 0.10)
    pulseEnv = env
    // Beat flash with cooldown so kicks emit one clean burst each.
    var flash = pulseFlash || 0
    if (bass > 0.5 && (phase - pulseLastBeat) > 0.3) {
      pulseLastBeat = phase
      flash = 1
    }
    flash *= 0.86
    pulseFlash = flash
    var cols = 12
    var rows = 3
    var cw = (width - 2) / cols
    var ch = height / rows
    ctx.fillStyle = foreground
    for (var c = 0; c < cols; c++) {
      for (var r = 0; r < rows; r++) {
        var f = level((c + r) % barCount)
        var jump = env * 3 + flash * 4 * (((c * 7 + r * 13) % 5) / 4)
        var dx = (c - (cols - 1) / 2) * jump * 0.35
        var dy = (r - (rows - 1) / 2) * jump * 0.5
        var s = Math.max(1, Math.min(cw, ch) * 0.42 * (0.6 + 0.4 * f) + flash * 0.8)
        var x = 1 + c * cw + cw / 2 + dx - s / 2
        var y = r * ch + ch / 2 + dy - s / 2
        ctx.globalAlpha = 0.25 + 0.75 * Math.min(1, f + flash * 0.7)
        ctx.fillRect(x, y, s, s)
      }
    }
    ctx.globalAlpha = 1.0
  }

  // Circular sunburst: spectrum spokes around the center.
  function paintRadar(ctx) {
    var n = barCount
    var cx = width / 2
    var cy = height / 2
    var maxR = Math.min(width, height) / 2 - 1
    var inner = 2.5
    ctx.strokeStyle = foreground
    ctx.lineWidth = 1.2
    ctx.lineCap = "round"
    for (var i = 0; i < n; i++) {
      var a = (i / n) * Math.PI * 2 - Math.PI / 2 + phase * 0.15
      var r1 = inner
      var r2 = inner + (maxR - inner) * level(i)
      ctx.globalAlpha = 0.35 + 0.65 * level(i)
      ctx.beginPath()
      // Elliptical squash so it fits the wide strip.
      ctx.moveTo(cx + Math.cos(a) * r1 * 2.2, cy + Math.sin(a) * r1)
      ctx.lineTo(cx + Math.cos(a) * r2 * 2.2, cy + Math.sin(a) * r2)
      ctx.stroke()
    }
    ctx.globalAlpha = 0.5
    ctx.lineWidth = 1
    ctx.beginPath()
    ctx.arc(cx, cy, inner, 0, Math.PI * 2)
    ctx.stroke()
    ctx.globalAlpha = 1.0
  }

  // Tide: two ribbons morphing with music; kick spring shoves sideways.
  function paintTide(ctx) {
    var layers = 2
    ctx.fillStyle = foreground
    if (!tideOff || tideOff.length !== 2) tideOff = [0, 0]
    var tfl = tideFlash || 0
    var avg = average()
    var tr = 0
    for (var tb = 6; tb < barCount; tb++) tr += level(tb)
    tr /= Math.max(1, barCount - 6)
    var shove = (tideRD || 0) * 8
    for (var L = 0; L < layers; L++) {
      var freq = (1.6 + L * 0.9) * Math.PI * 2 / width * (1 + avg * 0.8 + tfl * 0.5)
      var amp = (height / 2 - 2) * (0.34 + 0.45 * avg) * (1 + tfl * 0.6) * (1 - L * 0.25)
      var mid = height / 2 + (L - 0.5) * 3
      var off = (tideOff[L] || 0)
      ctx.beginPath()
      ctx.moveTo(1, mid)
      for (var x = 1; x <= width - 1; x += 2) {
        var sx = x + shove
        var f = level(Math.floor((x / width) * barCount) % barCount)
        var y = mid + Math.sin(sx * freq + off + L * 2.4) * amp * (0.4 + 0.6 * f)
          + Math.sin(sx * freq * 2.7 + off * 1.7 + L) * amp * 0.25 * tr
        ctx.lineTo(x, y)
      }
      ctx.lineWidth = 1.6 - L * 0.4
      ctx.globalAlpha = 0.75 - L * 0.25
      ctx.strokeStyle = foreground
      ctx.stroke()
    }
    ctx.globalAlpha = 1.0
  }

  // Stars: blinking field; downbeats reshuffle + burst crosses.
  function paintStars(ctx) {
    var avg = average()
    var flash = starFlash || 0
    var count = 36
    if (!starPos || starPos.length !== count || !starAge || starAge.length !== count) {
      starPos = []
      starAge = []
      for (var z = 0; z < count; z++) {
        starPos.push({ x: Math.random(), y: Math.random() })
        starAge.push(Math.random())
      }
    }
    // Fresh kicks read flash > 0.9 for a frame or two.
    if (flash > 0.9) {
      for (var q = 0; q < 5; q++) {
        var idx = Math.floor(Math.random() * count)
        starPos[idx] = { x: Math.random(), y: Math.random() }
        starAge[idx] = 0
      }
    }
    var sparkles = 0
    ctx.fillStyle = foreground
    ctx.strokeStyle = foreground
    for (var i = 0; i < count; i++) {
      starAge[i] += 0.008 + avg * 0.02 + flash * 0.03
      if (starAge[i] >= 1) {
        starPos[i] = { x: Math.random(), y: Math.random() }
        starAge[i] = 0
      }
      var fade = Math.sin(Math.min(1, starAge[i]) * Math.PI)
      var x = 1 + starPos[i].x * (width - 2)
      var y = 1 + starPos[i].y * (height - 2)
      var tw = Math.abs(Math.sin(phase * (0.8 + avg * 2.5 + flash * 3.0) + i * 2.39996))
      var f = level(i % barCount)
      var a = (0.15 + 0.75 * tw * (0.35 + 0.65 * Math.max(avg, f)) + flash * 0.45) * (0.15 + 0.85 * fade)
      var r = 0.7 + 1.1 * tw * (0.4 + 0.6 * f) + flash * 1.2 * (0.5 + f)
      ctx.globalAlpha = Math.min(1, a)
      ctx.beginPath()
      ctx.arc(x, y, r, 0, Math.PI * 2)
      ctx.fill()
      // Crosses ignite on kicks through warm stars (capped at 8).
      if (flash > 0.35 && f > 0.30 && sparkles < 8) {
        sparkles++
        var s = r + 1.5 + flash * 2
        ctx.globalAlpha = Math.min(1, a + 0.2)
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(x - s, y); ctx.lineTo(x + s, y)
        ctx.moveTo(x, y - s); ctx.lineTo(x, y + s)
        ctx.stroke()
      }
    }
    ctx.globalAlpha = 1.0
  }

  // Helix: flowing DNA strand — smooth rails, beaded rungs at crossings;
  // twist + beads pump with the music.
  function paintHelix(ctx) {
    var mid = height / 2
    var avg = average()
    var bass = bassLevel()
    var amp = Math.max(2.5, (height / 2) - 3) * (0.55 + 0.45 * Math.max(avg, bass))
    var step = 4
    ctx.fillStyle = foreground
    ctx.strokeStyle = foreground
    ctx.lineCap = "round"
    var top = []
    var bot = []
    var x, s
    for (x = 2; x <= width - 2; x += step) {
      s = Math.sin(x * 0.22 + helixTwist)
      top.push({ x: x, y: mid + s * amp, s: s })
      bot.push({ x: x, y: mid - s * amp, s: s })
    }
    var n = top.length
    // flowing backbones first (behind everything)
    ctx.lineWidth = 1.4
    for (var R = 0; R < 2; R++) {
      var pts = (R === 0) ? top : bot
      ctx.globalAlpha = 0.45 + 0.35 * Math.max(avg, 0.3)
      ctx.beginPath()
      ctx.moveTo(pts[0].x, pts[0].y)
      for (var k = 1; k < n - 1; k++) {
        var xc = (pts[k].x + pts[k + 1].x) / 2
        var yc = (pts[k].y + pts[k + 1].y) / 2
        ctx.quadraticCurveTo(pts[k].x, pts[k].y, xc, yc)
      }
      ctx.lineTo(pts[n - 1].x, pts[n - 1].y)
      ctx.stroke()
    }
    // rungs + beads per column
    for (var i = 0; i < n; i++) {
      var f = level(Math.floor((top[i].x / width) * barCount) % barCount)
      var si = top[i].s
      if (Math.abs(si) < 0.42) {
        ctx.globalAlpha = Math.min(1, 0.35 + 0.5 * f + bass * 0.25)
        ctx.lineWidth = 1.2
        ctx.beginPath()
        ctx.moveTo(top[i].x, top[i].y)
        ctx.lineTo(bot[i].x, bot[i].y)
        ctx.stroke()
      }
      var r = 1.0 + 1.4 * f + bass * 1.0
      var frontTop = si >= 0
      ctx.globalAlpha = frontTop ? (0.7 + 0.3 * f) : (0.45 + 0.3 * f)
      ctx.beginPath()
      ctx.arc(top[i].x, top[i].y, frontTop ? r : Math.max(0.8, r * 0.85), 0, Math.PI * 2)
      ctx.fill()
      ctx.globalAlpha = frontTop ? (0.45 + 0.3 * f) : (0.7 + 0.3 * f)
      ctx.beginPath()
      ctx.arc(bot[i].x, bot[i].y, frontTop ? Math.max(0.8, r * 0.85) : r, 0, Math.PI * 2)
      ctx.fill()
    }
    ctx.globalAlpha = 1.0
  }

  // Aurora: bass/mid/treble ribbons — spaced, distinct speeds and glow.
  function paintAurora(ctx) {
    var avg = average()
    var bass = bassLevel()
    var tr = 0
    for (var bb = 6; bb < barCount; bb++) tr += level(bb)
    tr /= Math.max(1, barCount - 6)
    var energies = [Math.max(avg, bass), avg, Math.max(avg, tr)]
    var speeds = [0.6, 1.1, 1.9]
    var freqs = [1.6, 2.6, 4.0]
    var widths = [1.0, 0.8, 0.6]
    var glows = [0.14, 0.20, 0.30]
    var layers = 3
    ctx.fillStyle = foreground
    for (var L = 0; L < layers; L++) {
      var energy = energies[L]
      var freq = freqs[L] * Math.PI * 2 / width
      var amp = (height / 2 - 2) * (0.30 + 0.55 * energy) * widths[L]
      var mid = height / 2 + (L - 1) * 3.5
      ctx.beginPath()
      ctx.moveTo(1, height - 1)
      for (var x = 1; x <= width - 1; x += 2) {
        var f = level(Math.floor((x / width) * barCount) % barCount)
        var y = mid + Math.sin(x * freq + phase * speeds[L] + L * 2.1) * amp * (0.35 + 0.65 * f)
        ctx.lineTo(x, y)
      }
      ctx.lineTo(width - 1, height - 1)
      ctx.closePath()
      ctx.globalAlpha = glows[L] * (0.75 + 0.5 * energy)
      ctx.fill()
    }
    ctx.globalAlpha = 1.0
  }

  // Lightning: jagged/spear strikes, random flow; beat forks; kick white-out.
  function paintLightning(ctx) {
    var avg = average()
    var bass = bassLevel()
    var flash = lightFlash || 0
    var mid = height / 2
    var amp = Math.max(2, (height / 2) - 2.5)
    var energy = 0.25 + 0.75 * Math.max(avg, bass)
    // Strike roll: jagged leads, spears punctuate, flow either way.
    if (!lightModeLeft || lightModeLeft <= 0) {
      var roll = Math.random()
      lightMode = (roll < 0.72) ? 0 : 2
      lightFlow = (Math.random() < 0.5) ? 1 : -1
      if (lightMode === 2) {
        lightModeLeft = 4 + Math.floor(Math.random() * 5)
        lightTilt = (Math.random() - 0.5) * 0.14
      } else {
        lightModeLeft = 6 + Math.floor(Math.random() * 11)
      }
    }
    lightModeLeft--
    // kicks force wild jagged with a freshly rolled flow
    if (flash > 0.5) {
      lightMode = 0
      lightModeLeft = 6
      lightFlow = (Math.random() < 0.5) ? 1 : -1
    }
    var straight = (lightMode === 2)
    var backward = (lightFlow < 0)
    // joints: music deviation + fresh jitter (near-clean for spears)
    var jx = [], jy = [], jf = []
    for (var i = 0; i < barCount; i++) {
      var f = level(i)
      var x = 1 + (width - 2) * (barCount === 1 ? 0.5 : (i / (barCount - 1)))
      var y
      if (straight) {
        y = mid + (x - width / 2) * lightTilt
          - (f - avg) * amp * 0.5
          + (Math.random() - 0.5) * 0.6
      } else {
        y = mid - (f - avg) * amp * 1.6
          + (Math.random() - 0.5) * (1.5 + energy * 3.5)
      }
      if (y < 1) y = 1
      if (y > height - 1) y = height - 1
      jx.push(x); jy.push(y); jf.push(f)
    }
    ctx.strokeStyle = foreground
    ctx.fillStyle = foreground
    ctx.lineCap = "round"
    ctx.lineJoin = "round"
    // faint full-path wash behind everything — breathes up on kicks
    ctx.globalAlpha = 0.05 + 0.08 * energy + flash * 0.30
    ctx.lineWidth = 2.5 + flash * 2
    ctx.beginPath()
    ctx.moveTo(jx[0], jy[0])
    for (var w = 1; w < barCount; w++) ctx.lineTo(jx[w], jy[w])
    ctx.stroke()
    // Core highlight lives for the beat: dim bolt calm, bright surge.
    var coreA = Math.min(1, (straight ? 0.30 : 0.12) + 0.30 * energy + flash * 0.60)
    var coreW = (straight ? 1.0 : 1.1) + flash * 1.2
    var fracs = [1.0, 0.6, 0.32]
    var zalpha = [0.35, 0.7, 1.0]
    for (var zi = 0; zi < 3; zi++) {
      var cnt = Math.max(2, Math.floor(barCount * fracs[zi]))
      var lo = backward ? 0 : barCount - cnt
      ctx.globalAlpha = coreA * zalpha[zi]
      ctx.lineWidth = coreW
      ctx.beginPath()
      ctx.moveTo(jx[lo], jy[lo])
      for (var zj = lo + 1; zj < lo + cnt; zj++) ctx.lineTo(jx[zj], jy[zj])
      ctx.stroke()
    }
    // Forks are beat events at random hot spots, glowing with hits.
    var cands = []
    for (var cb = 0; cb < barCount; cb++) {
      var cf = level(cb)
      if (cf > 0.5 || (flash > 0.3 && cf > 0.35)) cands.push(cb)
    }
    var maxForks = flash > 0.5 ? 2 : (flash > 0.2 ? 1 : 0)
    var forks = 0
    while (forks < maxForks && cands.length > 0) {
      var ci = Math.floor(Math.random() * cands.length)
      var b = cands.splice(ci, 1)[0]
      {
        forks++
        var bf = level(b)
        var bx = 1 + (width - 2) * (barCount === 1 ? 0.5 : (b / (barCount - 1)))
        var by = mid - (bf - avg) * amp * 1.6
        var dir = (by >= mid) ? 1 : -1
        var px = bx, py = by
        ctx.globalAlpha = Math.min(1, 0.30 + 0.35 * bf + flash * 0.5)
        ctx.lineWidth = 1
        ctx.beginPath()
        ctx.moveTo(px, py)
        var steps = 3 + Math.floor(Math.random() * 2)
        for (var k = 0; k < steps; k++) {
          px += (Math.random() - 0.5) * 10
          py += dir * (2 + Math.random() * 3 + bf * 2)
          ctx.lineTo(px, py)
        }
        ctx.stroke()
      }
    }
    ctx.globalAlpha = 1.0
  }

  // Galaxy: spiral arms around the beating heart; kicks cascade arm to arm.
  function paintOrbit(ctx) {
    var cx = width / 2
    var cy = height / 2
    var maxR = Math.min(width, height) / 2 - 1
    var avg = average()
    var bass = bassLevel()
    var ofl = orbitFlash || 0
    var oenv = orbitEnv || 0
    var arms = 3
    var sweep = 4.2
    var dots = 6
    ctx.fillStyle = foreground
    ctx.strokeStyle = foreground
    ctx.lineCap = "round"
    // Core: keep the heart clearly dominant over the orbiting beads.
    var heartR = 2.6 + bass * 1.3 + ofl * 1.5
    ctx.globalAlpha = Math.min(1, 0.68 + 0.20 * avg + ofl * 0.32)
    ctx.beginPath()
    ctx.arc(cx, cy, heartR, 0, Math.PI * 2)
    ctx.fill()
    // Kick front cascades arm to arm, racing faster on drops.
    var kickAge = phase - orbitLastKick
    var frontSpeed = 1.2 + Math.max(avg, bass) * 1.2
    for (var r = 0; r < arms; r++) {
      // Arms span core to edge; radius breathes on the envelope.
      var base = Math.max(2, maxR * (0.55 + 0.45 * oenv) + bass * 1.2)
      var armPhase = orbitSpin + (r / arms) * Math.PI * 2
      var front = (kickAge - r * 0.15) * frontSpeed
      // guide spiral first so beads read as one wheeling arm
      ctx.globalAlpha = 0.16 + 0.25 * ofl + oenv * 0.06
      ctx.lineWidth = 1
      ctx.save()
      ctx.translate(cx, cy)
      ctx.scale(2.2, 1)
      ctx.beginPath()
      for (var g = 0; g <= 20; g++) {
        var gt = 0.08 + 0.92 * (g / 20)
        var ga = armPhase + gt * sweep
        var gr = base * (0.30 + 0.70 * gt)
        var gx = Math.cos(ga) * gr, gy = Math.sin(ga) * gr
        if (g === 0) ctx.moveTo(gx, gy)
        else ctx.lineTo(gx, gy)
      }
      ctx.stroke()
      ctx.restore()
      // Beads: positional sizes + fixed character; shared beat lights them.
      for (var k = 0; k < dots; k++) {
        var t = 0.08 + 0.92 * ((k + 0.7) / dots)
        var a = armPhase + t * sweep
        var rr = base * (0.30 + 0.70 * t)
        var px = cx + Math.cos(a) * rr * 2.2
        var py = cy + Math.sin(a) * rr
        var hv = 0.9 + 0.2 * (Math.abs(Math.sin((r * dots + k) * 12.9898) * 43758.5453) % 1)
        // Beads rest small in silence (smoothed), full size with groove.
        var bscale = 0.42 + 0.30 * Math.min(1, oenv * 1.5)
        var shimmer = 0.5 + 0.5 * Math.sin(t * 12.0 - (phase - orbitLastKick) * 3.0)
        var dt = t - front
        var glow = (front > -0.5 ? Math.exp(-(dt * dt) / (0.012 + ofl * 0.02)) : 0) * ofl
        ctx.globalAlpha = Math.min(1, (0.30 + 0.40 * (1 - t)) * hv * (0.55 + 0.25 * shimmer) + glow * 0.8)
        ctx.beginPath()
        ctx.arc(px, py, (0.45 + 1.05 * (1 - t)) * hv * bscale + glow * 0.9, 0, Math.PI * 2)
        ctx.fill()
      }
    }
    // Redraw the star above the arms so nearby planets never eclipse it.
    ctx.globalAlpha = Math.min(1, 0.86 + ofl * 0.14)
    ctx.beginPath()
    ctx.arc(cx, cy, 1.9 + bass * 0.9 + ofl * 1.1, 0, Math.PI * 2)
    ctx.fill()
    ctx.globalAlpha = 1.0
  }

  // Waveform: auto-gain waterfall; flow + kicks follow music. Pure field.
  function paintWaveform(ctx) {
    var hist = specHist || []
    var cols = hist.length
    if (cols < 2) return
    var n = barCount
    var cw = 2
    var ch = height / n
    var sfl = specFlash || 0
    var ceil = Math.max(1.5, specMax || 0)
    // Only music-hot cells draw: silence empties, drops fill.
    ctx.fillStyle = foreground
    for (var c = 0; c < cols; c++) {
      var snap = hist[c] || []
      var fresh = c / (cols - 1)
      var x = width - (cols - c) * cw
      for (var b = 0; b < n; b++) {
        var raw = Math.pow(Math.min(1, (snap[b] || 0) / barMax), 0.8)
        if (raw <= 0.18) continue
        var f = Math.pow(Math.min(1, (snap[b] || 0) / ceil), 0.8)
        ctx.globalAlpha = Math.min(1, (0.20 + 0.40 * f * (0.6 + 0.4 * fresh)) * (1 + sfl * 0.25))
        ctx.fillRect(x, height - (b + 1) * ch, cw - 0.5, ch - 0.4)
      }
    }
    ctx.globalAlpha = 1.0
  }

  // Bouncy balls: independent elastic motion with beat-driven impulses.
  function paintComet(ctx) {
    var avg = average()
    var bass = bassLevel()
    if (!cometBalls || cometBalls.length !== 4) {
      cometBalls = [
        { x: width * 0.25, y: height * 0.30, vx: 0.42, vy: 0.10, phase: 0.7, bounce: 0 },
        { x: width * 0.75, y: height * 0.70, vx: -0.36, vy: -0.14, phase: 2.4, bounce: 0 },
        { x: width * 0.72, y: height * 0.26, vx: -0.24, vy: 0.28, phase: 4.1, bounce: 0 },
        { x: width * 0.28, y: height * 0.74, vx: 0.30, vy: -0.22, phase: 5.6, bounce: 0 }
      ]
    }
    if (bass > 0.55 && (phase - cometLastKick) > 0.5) {
      cometLastKick = phase
      for (var kick = 0; kick < cometBalls.length; kick++) {
        cometBalls[kick].bounce = 1
        cometBalls[kick].vy -= 0.22 + bass * 0.18
      }
    }
    ctx.fillStyle = foreground
    for (var i = 0; i < cometBalls.length; i++) {
      var c = cometBalls[i]
      var wander = 0.035 + avg * 0.05
      c.bounce = (c.bounce || 0) * 0.88
      c.vx += Math.sin(phase * 0.7 + c.phase) * wander * 0.08
      c.vy += 0.012 + Math.cos(phase * 0.6 + c.phase) * wander * 0.08
      var speed = Math.sqrt(c.vx * c.vx + c.vy * c.vy)
      if (speed > 0.9) { c.vx *= 0.9 / speed; c.vy *= 0.9 / speed }
      var size = 2.3 + avg * 1.2 + c.bounce * 1.8
      c.x += c.vx * (1 + avg * 1.8 + c.bounce * 0.9)
      c.y += c.vy * (1 + avg * 1.8 + c.bounce * 0.9)
      if (c.x < size || c.x > width - size) {
        c.x = Math.max(size, Math.min(width - size, c.x))
        c.vx *= -0.92
        c.bounce = Math.max(c.bounce, 0.7)
      }
      if (c.y < size || c.y > height - size) {
        c.y = Math.max(size, Math.min(height - size, c.y))
        c.vy *= -0.92
        c.bounce = Math.max(c.bounce, 0.7)
      }
      ctx.globalAlpha = 0.78 + avg * 0.20 + c.bounce * 0.2
      ctx.beginPath()
      ctx.arc(c.x, c.y, size, 0, Math.PI * 2)
      ctx.fill()
    }
    ctx.globalAlpha = 1.0
  }

  // ECG: monitor sweep; live-spectrum trace flicks both ways, flat in silence.
  function paintEcg(ctx) {
    var mid = height / 2
    var amp = Math.max(2, (height / 2) - 2)
    var avg = average()
    var bass = bassLevel()
    var W = Math.max(8, width - 2)
    var head = (((ecgHead % 1) + 1) % 1) * W + 1
    var energy = Math.max(avg, bass)
    // Trace: raw bins, sharp joints, oldest fading; flat when quiet.
    ctx.strokeStyle = foreground
    ctx.lineWidth = 1.4
    ctx.lineCap = "round"
    var prevX = -1, prevY = 0
    for (var x = 1; x <= width - 1; x += 1) {
      var age = (((head - x) % W) + W) % W
      if (age > W - 10) { prevX = -1; continue } // erase gap ahead of head
      var f = level(Math.floor(((x - 1) / W) * barCount) % barCount)
      // Deviation from average: loud up, quiet down, flat in silence.
      var y = mid - (f - avg) * amp * 2
      if (y < 1) y = 1
      if (y > height - 1) y = height - 1
      if (prevX >= 0) {
        ctx.globalAlpha = 0.25 + 0.75 * (1 - age / W)
        ctx.beginPath()
        ctx.moveTo(prevX, prevY)
        ctx.lineTo(x, y)
        ctx.stroke()
      }
      prevX = x
      prevY = y
    }
    // Head: dim crawl-dot in silence, flash on bass.
    ctx.globalAlpha = Math.min(1, 0.35 + energy * 0.4 + bass * 0.5)
    ctx.fillStyle = foreground
    ctx.beginPath()
    ctx.arc(head, mid, 1.2 + energy * 1.2 + bass * 1.4, 0, Math.PI * 2)
    ctx.fill()
    ctx.globalAlpha = 1.0
  }
}
