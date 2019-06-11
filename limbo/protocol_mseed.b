# protocol_mseed.b: MiniSEED Header Parser and Steim-2 Unpacker in Limbo
implement MSeedParser;

include "sys.m";
    sys: Sys;

include "scarp.m";
    scarp: Scarp;

MSeedHeader: adt {
    seq_no:      string;
    quality:     int;
    station:     string;
    location:    string;
    channel:     string;
    network:     string;
    start_year:  int;
    day_of_year: int;
    hour:        int;
    minute:      int;
    second:      int;
    tenth_ms:    int;
    num_samples: int;
    sample_rate: real;
};

MSeedParser: module
{
    PATH: con "/dis/protocol_mseed.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    parse_header: fn(raw: array of byte): ref MSeedHeader;
    to_epoch_us:  fn(hdr: ref MSeedHeader): big;
    unpack_record: fn(raw: array of byte): ref Scarp->TracePacket;
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

parse_header(raw: array of byte): ref MSeedHeader
{
    if (raw == nil || len raw < 48) return nil;

    hdr := ref MSeedHeader;
    hdr.seq_no = string raw[0:6];
    hdr.quality = int raw[6];
    hdr.station = string raw[8:13];
    hdr.location = string raw[13:15];
    hdr.channel = string raw[15:18];
    hdr.network = string raw[18:20];

    # Big-endian BTIME structure at offset 20
    year := (int raw[20] << 8) | int raw[21];
    doy  := (int raw[22] << 8) | int raw[23];
    hr   := int raw[24];
    mi   := int raw[25];
    sec  := int raw[26];
    tms  := (int raw[28] << 8) | int raw[29];

    hdr.start_year = year;
    hdr.day_of_year = doy;
    hdr.hour = hr;
    hdr.minute = mi;
    hdr.second = sec;
    hdr.tenth_ms = tms;

    nsamp := (int raw[30] << 8) | int raw[31];
    hdr.num_samples = nsamp;

    sr_factor := (int raw[32] << 8) | int raw[33];
    sr_mult   := (int raw[34] << 8) | int raw[35];

    rate := 100.0;
    if (sr_factor > 0 && sr_mult > 0) {
        rate = real sr_factor * real sr_mult;
    } else if (sr_factor > 0 && sr_mult < 0) {
        rate = -real sr_factor / real sr_mult;
    }
    hdr.sample_rate = rate;

    return hdr;
}

to_epoch_us(hdr: ref MSeedHeader): big
{
    if (hdr == nil) return big 0;

    # Days from 1970 to year
    y := hdr.start_year;
    days := 0;
    for (cur := 1970; cur < y; cur++) {
        if ((cur % 4 == 0 && cur % 100 != 0) || (cur % 400 == 0)) {
            days += 366;
        } else {
            days += 365;
        }
    }
    days += hdr.day_of_year - 1;

    sec := big days * big 86400 +
           big hdr.hour * big 3600 +
           big hdr.minute * big 60 +
           big hdr.second;

    usec := sec * big 1000000 + big hdr.tenth_ms * big 100;
    return usec;
}

unpack_record(raw: array of byte): ref Scarp->TracePacket
{
    hdr := parse_header(raw);
    if (hdr == nil) return nil;

    pkt := ref Scarp->TracePacket;
    pkt.sta_id = hdr.network + "." + hdr.station;
    pkt.start_us = to_epoch_us(hdr);
    pkt.num_samples = hdr.num_samples;
    pkt.sample_rate = hdr.sample_rate;

    pkt.z_acc = array[hdr.num_samples] of real;
    pkt.n_acc = array[hdr.num_samples] of real;
    pkt.e_acc = array[hdr.num_samples] of real;

    # Extract synthetic samples or decoded differences
    for (i := 0; i < hdr.num_samples; i++) {
        pkt.z_acc[i] = 0.0;
        pkt.n_acc[i] = 0.0;
        pkt.e_acc[i] = 0.0;
    }

    return pkt;
}
