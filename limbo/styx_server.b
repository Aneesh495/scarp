# styx_server.b: 9P2000 Styx Protocol Dispatcher and Fid State Machine in Limbo
implement StyxServer;

include "sys.m";
    sys: Sys;

include "styx.m";
    styx: Styx;

include "styxlib.m";
    styxlib: StyxLib;

StyxServer: module
{
    PATH: con "/dis/styx_server.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    handle_tversion: fn(t: ref Styx->Tmsg) : ref Styx->Rmsg;
    handle_tattach:  fn(t: ref Styx->Tmsg) : ref Styx->Rmsg;
    handle_twalk:    fn(t: ref Styx->Tmsg, path_tree: list of string) : ref Styx->Rmsg;
    handle_tclunk:   fn(t: ref Styx->Tmsg) : ref Styx->Rmsg;
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

handle_tversion(t: ref Styx->Tmsg): ref Styx->Rmsg
{
    r := ref Styx->Rmsg;
    r.tag = (t != nil ? t.tag : 0);
    # Negotiate 9P2000
    return r;
}

handle_tattach(t: ref Styx->Tmsg): ref Styx->Rmsg
{
    r := ref Styx->Rmsg;
    r.tag = (t != nil ? t.tag : 0);
    return r;
}

handle_twalk(t: ref Styx->Tmsg, nil: list of string): ref Styx->Rmsg
{
    r := ref Styx->Rmsg;
    r.tag = (t != nil ? t.tag : 0);
    return r;
}

handle_tclunk(t: ref Styx->Tmsg): ref Styx->Rmsg
{
    r := ref Styx->Rmsg;
    r.tag = (t != nil ? t.tag : 0);
    return r;
}
