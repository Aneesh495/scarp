# sys.m: Inferno System Interface Module Declaration
Sys: module
{
    PATH: con "$Sys";

    # File open modes
    OREAD:   con 0;
    OWRITE:  con 1;
    ORDWR:   con 2;

    # Standard file descriptors
    FD: adt {
        fd: int;
    };

    Dir: adt {
        name:    string;
        uid:     string;
        gid:     string;
        qid:     big;
        mode:    int;
        atime:   int;
        mtime:   int;
        length:  big;
        dtype:   int;
        dev:     int;
    };

    open:    fn(s: string, mode: int): ref FD;
    create:  fn(s: string, mode: int, perm: int): ref FD;
    read:    fn(fd: ref FD, buf: array of byte, n: int): int;
    write:   fn(fd: ref FD, buf: array of byte, n: int): int;
    print:   fn(s: string, *): int;
    fprint:  fn(fd: ref FD, s: string, *): int;
    sprint:  fn(s: string, *): string;
    millisec: fn(): int;
    sleep:   fn(ms: int): int;
};
