# telemetry_buf.b: High-Throughput Circular Waveform Ring Buffer in Limbo
implement TelemetryBuf;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

TelemetryBuf: module
{
    PATH: con "/dis/telemetry_buf.dis";

    RingBuffer: adt {
        capacity:    int;
        head:        int;
        tail:        int;
        count:       int;
        timestamps:  array of big;
        values:      array of real;

        create:      fn(cap: int): ref RingBuffer;
        push:        fn(b: self ref RingBuffer, ts: big, val: real);
        pop:         fn(b: self ref RingBuffer): (big, real);
        peek_latest: fn(b: self ref RingBuffer): (big, real);
        get_window:  fn(b: self ref RingBuffer, n: int): (array of big, array of real);
        clear:       fn(b: self ref RingBuffer);
    };

    init: fn(ctxt: ref Sys->FD, argv: list of string);
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

RingBuffer.create(cap: int): ref RingBuffer
{
    if (cap <= 0) cap = 1024;
    rb := ref RingBuffer;
    rb.capacity = cap;
    rb.head = 0;
    rb.tail = 0;
    rb.count = 0;
    rb.timestamps = array[cap] of big;
    rb.values = array[cap] of real;
    return rb;
}

RingBuffer.push(b: self ref RingBuffer, ts: big, val: real)
{
    b.timestamps[b.tail] = ts;
    b.values[b.tail] = val;
    b.tail = (b.tail + 1) % b.capacity;

    if (b.count < b.capacity) {
        b.count++;
    } else {
        # Overwrite oldest entry; advance head pointer
        b.head = (b.head + 1) % b.capacity;
    }
}

RingBuffer.pop(b: self ref RingBuffer): (big, real)
{
    if (b.count == 0) {
        return (big 0, 0.0);
    }
    ts := b.timestamps[b.head];
    val := b.values[b.head];
    b.head = (b.head + 1) % b.capacity;
    b.count--;
    return (ts, val);
}

RingBuffer.peek_latest(b: self ref RingBuffer): (big, real)
{
    if (b.count == 0) {
        return (big 0, 0.0);
    }
    latest_idx := (b.tail - 1 + b.capacity) % b.capacity;
    return (b.timestamps[latest_idx], b.values[latest_idx]);
}

RingBuffer.get_window(b: self ref RingBuffer, n: int): (array of big, array of real)
{
    if (n > b.count) n = b.count;
    if (n <= 0) return (array[0] of big, array[0] of real);

    out_ts := array[n] of big;
    out_val := array[n] of real;

    # Extract the most recent n samples
    start_pos := (b.tail - n + b.capacity) % b.capacity;
    for (i := 0; i < n; i++) {
        idx := (start_pos + i) % b.capacity;
        out_ts[i] = b.timestamps[idx];
        out_val[i] = b.values[idx];
    }
    return (out_ts, out_val);
}

RingBuffer.clear(b: self ref RingBuffer)
{
    b.head = 0;
    b.tail = 0;
    b.count = 0;
}
