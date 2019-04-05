# styx.m: Plan 9 / Inferno 9P2000 Styx Protocol Wire Format Specification

Styx: module
{
    PATH: con "/dis/styx.dis";

    # Protocol version string
    VERSION9P: con "9P2000";

    # Message Types (Opcodes)
    Tversion: con 100;
    Rversion: con 101;
    Tauth:    con 102;
    Rauth:    con 103;
    Tattach:  con 104;
    Rattach:  con 105;
    Terror:   con 106; # Illegal
    Rerror:   con 107;
    Tflush:   con 108;
    Rflush:   con 109;
    Twalk:    con 110;
    Rwalk:    con 111;
    Topen:    con 112;
    Ropen:    con 113;
    Tcreate:  con 114;
    Rcreate:  con 115;
    Tread:    con 116;
    Rread:    con 117;
    Twrite:   con 118;
    Rwrite:   con 119;
    Tclunk:   con 120;
    Rclunk:   con 121;
    Tremove:  con 122;
    Rremove:  con 123;
    Tstat:    con 124;
    Rstat:    con 125;
    Twstat:   con 126;
    Rwstat:   con 127;

    # Open Modes
    OREAD:   con 0;
    OWRITE:  con 1;
    ORDWR:   con 2;
    OEXEC:   con 3;
    OTRUNC:  con 16;

    # Qid Types
    QTDIR:   con 16r80; # Directory
    QTAPPEND: con 16r40; # Append only
    QTEXCL:  con 16r20; # Exclusive use
    QTMOUNT: con 16r10; # Mounted channel
    QTAUTH:  con 16r08; # Authentication file
    QTTMP:   con 16r04; # Non-backed-up file
    QTFILE:  con 16r00; # Plain data file

    # Unique Identifier
    Qid: adt {
        path: big;  # Unique 64-bit path
        vers: int;  # Version number for cache invalidation
        qtype: int; # Qid type (QTDIR, QTFILE)
    };

    # Directory Metadata Entry
    Dir: adt {
        dtype:   int;
        dev:     int;
        qid:     Qid;
        mode:    int;
        atime:   int;
        mtime:   int;
        length:  big;
        name:    string;
        uid:     string;
        gid:     string;
        muid:    string;
    };

    # Abstract Styx Message
    Tmsg: adt {
        tag: int;
        pick {
            Readversion =>
                msize:   int;
                version: string;
            Auth =>
                afid:    int;
                uname:   string;
                aname:   string;
            Attach =>
                fid:     int;
                afid:    int;
                uname:   string;
                aname:   string;
            Walk =>
                fid:     int;
                newfid:  int;
                names:   array of string;
            Open =>
                fid:     int;
                mode:    int;
            Read =>
                fid:     int;
                offset:  big;
                count:   int;
            Write =>
                fid:     int;
                offset:  big;
                data:    array of byte;
            Clunk =>
                fid:     int;
            Stat =>
                fid:     int;
        }
    };

    Rmsg: adt {
        tag: int;
        pick {
            Readversion =>
                msize:   int;
                version: string;
            Auth =>
                aqid:    Qid;
            Attach =>
                qid:     Qid;
            Error =>
                ename:   string;
            Walk =>
                qids:    array of Qid;
            Open =>
                qid:     Qid;
                iounit:  int;
            Read =>
                data:    array of byte;
            Write =>
                count:   int;
            Clunk =>
            Stat =>
                stat:    Dir;
        }
    };

    pack_tmsg:   fn(m: ref Tmsg): array of byte;
    unpack_tmsg: fn(buf: array of byte): ref Tmsg;
    pack_rmsg:   fn(m: ref Rmsg): array of byte;
    unpack_rmsg: fn(buf: array of byte): ref Rmsg;
};
