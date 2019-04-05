# styxlib.m: Styx 9P Server Connection and Dispatcher Library

StyxLib: module
{
    PATH: con "/dis/styxlib.dis";

    # Connection Handle
    Conn: adt {
        fd:       ref Sys->FD;
        msize:    int;
        version:  string;
        is_open:  int;

        read_msg:  fn(c: self ref Conn): ref Styx->Tmsg;
        write_msg: fn(c: self ref Conn, r: ref Styx->Rmsg): int;
        close:     fn(c: self ref Conn);
    };

    # Active File Identifier (Fid) Entry
    Fid: adt {
        fid:      int;
        qid:      Styx->Qid;
        path:     string;
        mode:     int;
        offset:   big;
        is_open:  int;
    };

    # Fid Table
    FidPool: adt {
        fids: list of ref Fid;

        get:    fn(p: self ref FidPool, fid: int): ref Fid;
        put:    fn(p: self ref FidPool, f: ref Fid);
        remove: fn(p: self ref FidPool, fid: int);
    };

    listen_tcp: fn(addr: string): ref Sys->FD;
    accept_conn: fn(listener: ref Sys->FD): ref Conn;
};
