/*
 * app.js: Interactive Seismic Wavefield & Telemetry Visualizer
 * Zero external dependencies: pure vanilla Canvas 2D & Web APIs.
 */

(function () {
  'use strict';

  // Map canvas and context
  const mapCanvas = document.getElementById('map-canvas');
  const mapCtx = mapCanvas ? mapCanvas.getContext('2d') : null;

  // Waveform canvas contexts
  const traceZ = document.getElementById('trace-z');
  const traceN = document.getElementById('trace-n');
  const traceE = document.getElementById('trace-e');

  const ctxZ = traceZ ? traceZ.getContext('2d') : null;
  const ctxN = traceN ? traceN.getContext('2d') : null;
  const ctxE = traceE ? traceE.getContext('2d') : null;

  // Alert banner elements
  const alertTti = document.getElementById('alert-tti');
  const alertMag = document.getElementById('alert-mag');
  const alertPga = document.getElementById('alert-pga');

  // Network station definitions (Southern / Northern California array)
  const stations = [
    { id: 'CI.PAS', name: 'Pasadena', x: 420, y: 260, dist: 14.2, p_time: 2.37, s_time: 4.06, state: 'standby' },
    { id: 'CI.USC', name: 'Univ Southern Calif', x: 390, y: 310, dist: 22.5, p_time: 3.75, s_time: 6.43, state: 'standby' },
    { id: 'CI.GSC', name: 'Goldstone', x: 620, y: 110, dist: 148.0, p_time: 24.6, s_time: 42.3, state: 'standby' },
    { id: 'CI.SVD', name: 'Seven Oaks Dam', x: 560, y: 280, dist: 64.0, p_time: 10.6, s_time: 18.3, state: 'standby' },
    { id: 'CI.DEV', name: 'Devore Cutoff', x: 500, y: 220, dist: 48.0, p_time: 8.00, s_time: 13.7, state: 'standby' },
    { id: 'CI.WTT', name: 'Whittier Narrows', x: 450, y: 330, dist: 31.0, p_time: 5.16, s_time: 8.86, state: 'standby' }
  ];

  // Epicenter coordinates on canvas
  const hypo = {
    x: 400,
    y: 250,
    mw: 6.0,
    depth_km: 12.0,
    strike_deg: 325.0
  };

  let simTime = 0.0;
  const vp_px = 24.0; // P-wave velocity in canvas pixels/sec
  const vs_px = 14.0; // S-wave velocity in canvas pixels/sec

  // Generate synthetic waveform series
  const numSamples = 500;
  const samplesZ = new Float32Array(numSamples);
  const samplesN = new Float32Array(numSamples);
  const samplesE = new Float32Array(numSamples);

  function generateWaveforms() {
    for (let i = 0; i < numSamples; i++) {
      const t = (i / numSamples) * 20.0; // 20 seconds total
      // Microseismic ambient noise
      let z = 0.04 * Math.sin(t * 1.5) + 0.02 * Math.cos(t * 4.2);
      let n = 0.03 * Math.sin(t * 1.8 + 0.5);
      let e = 0.03 * Math.cos(t * 2.1 + 0.2);

      // P-wave arrival at t = 4.8s
      if (t >= 4.8) {
        const tauP = t - 4.8;
        const envP = Math.exp(-0.7 * tauP);
        z += 0.55 * envP * Math.sin(tauP * 25.0);
        n += 0.25 * envP * Math.sin(tauP * 22.0);
        e += 0.20 * envP * Math.sin(tauP * 24.0);
      }

      // S-wave arrival at t = 8.2s
      if (t >= 8.2) {
        const tauS = t - 8.2;
        const envS = Math.exp(-0.4 * tauS);
        z += 0.35 * envS * Math.sin(tauS * 12.0);
        n += 0.85 * envS * Math.sin(tauS * 14.0);
        e += 0.95 * envS * Math.sin(tauS * 13.0);
      }

      samplesZ[i] = z;
      samplesN[i] = n;
      samplesE[i] = e;
    }
  }

  generateWaveforms();

  function drawTrace(ctx, samples, canvas, triggerIdx, sIdx, color) {
    if (!ctx || !canvas) return;
    const w = canvas.width;
    const h = canvas.height;
    ctx.clearRect(0, 0, w, h);

    // Draw center zero-line
    ctx.strokeStyle = '#1f2937';
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(0, h / 2);
    ctx.lineTo(w, h / 2);
    ctx.stroke();

    // Draw P and S pick markers
    if (triggerIdx >= 0 && triggerIdx < numSamples) {
      const px = (triggerIdx / numSamples) * w;
      ctx.strokeStyle = '#f59e0b';
      ctx.setLineDash([3, 3]);
      ctx.beginPath();
      ctx.moveTo(px, 0);
      ctx.lineTo(px, h);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#f59e0b';
      ctx.font = '10px monospace';
      ctx.fillText('P-Pick: 4.82s', px + 4, 14);
    }

    if (sIdx >= 0 && sIdx < numSamples) {
      const sx = (sIdx / numSamples) * w;
      ctx.strokeStyle = '#ef4444';
      ctx.setLineDash([3, 3]);
      ctx.beginPath();
      ctx.moveTo(sx, 0);
      ctx.lineTo(sx, h);
      ctx.stroke();
      ctx.setLineDash([]);
      ctx.fillStyle = '#ef4444';
      ctx.font = '10px monospace';
      ctx.fillText('S-Arrival: 8.24s', sx + 4, 14);
    }

    // Draw continuous waveform
    ctx.strokeStyle = color;
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    for (let i = 0; i < numSamples; i++) {
      const x = (i / numSamples) * w;
      const y = (h / 2) - samples[i] * (h * 0.42);
      if (i === 0) ctx.moveTo(x, y);
      else ctx.lineTo(x, y);
    }
    ctx.stroke();
  }

  function drawMap() {
    if (!mapCtx || !mapCanvas) return;
    const w = mapCanvas.width;
    const h = mapCanvas.height;
    mapCtx.clearRect(0, 0, w, h);

    // Draw GIS Background Grid
    mapCtx.strokeStyle = '#111827';
    mapCtx.lineWidth = 1;
    for (let x = 0; x < w; x += 40) {
      mapCtx.beginPath();
      mapCtx.moveTo(x, 0);
      mapCtx.lineTo(x, h);
      mapCtx.stroke();
    }
    for (let y = 0; y < h; y += 40) {
      mapCtx.beginPath();
      mapCtx.moveTo(0, y);
      mapCtx.lineTo(w, y);
      mapCtx.stroke();
    }

    // Draw ShakeMap MMI Intensity Rings
    const mmiRadii = [
      { r: 240, color: 'rgba(128, 255, 255, 0.05)', stroke: '#80ffff' }, // IV Light
      { r: 170, color: 'rgba(125, 255, 125, 0.08)', stroke: '#7dff7d' }, // V Moderate
      { r: 110, color: 'rgba(255, 255, 0, 0.12)',   stroke: '#ffff00' }, // VI Strong
      { r: 65,  color: 'rgba(255, 170, 0, 0.18)',   stroke: '#ffaa00' }, // VII Very Strong
      { r: 35,  color: 'rgba(255, 85, 0, 0.25)',    stroke: '#ff5500' }  // VIII Severe
    ];

    mmiRadii.forEach(function (ring) {
      mapCtx.fillStyle = ring.color;
      mapCtx.strokeStyle = ring.stroke;
      mapCtx.lineWidth = 1;
      mapCtx.beginPath();
      mapCtx.arc(hypo.x, hypo.y, ring.r, 0, 2 * Math.PI);
      mapCtx.fill();
      mapCtx.stroke();
    });

    // Draw Fault Rupture Trace (Line segment through hypocenter)
    const faultLen = 60;
    const strikeRad = (hypo.strike_deg - 90) * Math.PI / 180.0;
    const fx1 = hypo.x - Math.cos(strikeRad) * faultLen * 0.5;
    const fy1 = hypo.y - Math.sin(strikeRad) * faultLen * 0.5;
    const fx2 = hypo.x + Math.cos(strikeRad) * faultLen * 0.5;
    const fy2 = hypo.y + Math.sin(strikeRad) * faultLen * 0.5;

    mapCtx.strokeStyle = '#f87171';
    mapCtx.lineWidth = 3.5;
    mapCtx.beginPath();
    mapCtx.moveTo(fx1, fy1);
    mapCtx.lineTo(fx2, fy2);
    mapCtx.stroke();

    // Draw Expanding P-Wavefront (Blue Ring)
    const pRadius = (simTime * vp_px) % 360;
    mapCtx.strokeStyle = 'rgba(6, 182, 212, 0.85)';
    mapCtx.lineWidth = 2;
    mapCtx.beginPath();
    mapCtx.arc(hypo.x, hypo.y, pRadius, 0, 2 * Math.PI);
    mapCtx.stroke();

    // Draw Expanding S-Wavefront (Red/Orange Ring)
    const sRadius = (simTime * vs_px) % 220;
    mapCtx.strokeStyle = 'rgba(239, 68, 68, 0.95)';
    mapCtx.lineWidth = 2.5;
    mapCtx.beginPath();
    mapCtx.arc(hypo.x, hypo.y, sRadius, 0, 2 * Math.PI);
    mapCtx.stroke();

    // Draw Hypocenter Star & Error Ellipse
    mapCtx.strokeStyle = '#eab308';
    mapCtx.lineWidth = 1.5;
    mapCtx.setLineDash([4, 4]);
    mapCtx.beginPath();
    mapCtx.ellipse(hypo.x, hypo.y, 22, 14, Math.PI / 4, 0, 2 * Math.PI);
    mapCtx.stroke();
    mapCtx.setLineDash([]);

    // Hypocenter Star
    mapCtx.fillStyle = '#ef4444';
    mapCtx.strokeStyle = '#ffffff';
    mapCtx.lineWidth = 1.5;
    mapCtx.beginPath();
    mapCtx.arc(hypo.x, hypo.y, 7, 0, 2 * Math.PI);
    mapCtx.fill();
    mapCtx.stroke();

    // Draw Seismic Station Array
    stations.forEach(function (sta) {
      // Station triangle icon
      mapCtx.fillStyle = (sta.state === 'shaking') ? '#ef4444' :
                         (sta.state === 'triggered') ? '#f59e0b' : '#10b981';
      mapCtx.strokeStyle = '#ffffff';
      mapCtx.lineWidth = 1;

      mapCtx.beginPath();
      mapCtx.moveTo(sta.x, sta.y - 7);
      mapCtx.lineTo(sta.x + 6, sta.y + 5);
      mapCtx.lineTo(sta.x - 6, sta.y + 5);
      mapCtx.closePath();
      mapCtx.fill();
      mapCtx.stroke();

      // Station ID label
      mapCtx.fillStyle = '#e5e7eb';
      mapCtx.font = '10px monospace';
      mapCtx.fillText(sta.id, sta.x + 8, sta.y + 4);
    });
  }

  function updateSimulation() {
    simTime += 0.05;

    // Update countdown timer in alert banner
    const targetDistKm = 48.0;
    const sArrival = targetDistKm / 3.5;
    let tti = sArrival - (simTime % sArrival);
    if (tti < 0) tti = 0.0;

    if (alertTti) {
      alertTti.textContent = tti.toFixed(1);
    }

    // Update station triggering states
    stations.forEach(function (sta) {
      const curDistPx = Math.hypot(sta.x - hypo.x, sta.y - hypo.y);
      const curP = (simTime * vp_px) % 360;
      const curS = (simTime * vs_px) % 220;

      if (curS >= curDistPx) {
        sta.state = 'shaking';
      } else if (curP >= curDistPx) {
        sta.state = 'triggered';
      } else {
        sta.state = 'standby';
      }
    });

    drawMap();
    drawTrace(ctxZ, samplesZ, traceZ, 120, 205, '#06b6d4');
    drawTrace(ctxN, samplesN, traceN, 120, 205, '#3b82f6');
    drawTrace(ctxE, samplesE, traceE, 120, 205, '#10b981');

    requestAnimationFrame(updateSimulation);
  }

  // Setup button listeners
  const btnNapa = document.getElementById('btn-replay-napa');
  if (btnNapa) {
    btnNapa.addEventListener('click', function () {
      hypo.mw = 6.0;
      if (alertMag) alertMag.textContent = '6.0';
      if (alertPga) alertPga.textContent = '28.4';
      simTime = 0.0;
    });
  }

  const btnRidgecrest = document.getElementById('btn-replay-ridgecrest');
  if (btnRidgecrest) {
    btnRidgecrest.addEventListener('click', function () {
      hypo.mw = 7.1;
      if (alertMag) alertMag.textContent = '7.1';
      if (alertPga) alertPga.textContent = '68.2';
      simTime = 0.0;
    });
  }

  const btnTrigger = document.getElementById('btn-trigger-synthetic');
  if (btnTrigger) {
    btnTrigger.addEventListener('click', function () {
      hypo.mw = 6.7;
      if (alertMag) alertMag.textContent = '6.7';
      if (alertPga) alertPga.textContent = '44.8';
      simTime = 0.0;
    });
  }

  // Launch animation loop
  requestAnimationFrame(updateSimulation);
})();
