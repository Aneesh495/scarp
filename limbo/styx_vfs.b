# styx_vfs.b: Synthetic /dev/scarp Filesystem Hierarchy in Limbo
implement StyxVFS;

include "sys.m";
    sys: Sys;

include "styx.m";
    styx: Styx;

include "styxlib.m";
    styxlib: StyxLib;

VNode: adt {
    path_id:  big;
    name:     string;
    is_dir:   int;
    mode:     int;
    size:     big;
    content:  string;
};

StyxVFS: module
{
    PATH: con "/dis/styx_vfs.dis";

    init: fn(ctxt: ref Sys->FD, argv: list of string);

    build_dev_tree: fn(): list of ref VNode;
    find_node:      fn(tree: list of ref VNode, name: string): ref VNode;
    read_node:      fn(node: ref VNode, offset: big, count: int): array of byte;
    write_ctl:      fn(node: ref VNode, cmd: string): string;
};

init(nil: ref Sys->FD, nil: list of string)
{
    sys = load Sys Sys->PATH;
}

build_dev_tree(): list of ref VNode
{
    tree: list of ref VNode = nil;

    # /dev/scarp root directory
    root := ref VNode;
    root.path_id = big 0;
    root.name = "scarp";
    root.is_dir = 1;
    root.mode = 8r555;
    tree = root :: tree;

    # /dev/scarp/ctl
    ctl := ref VNode;
    ctl.path_id = big 1;
    ctl.name = "ctl";
    ctl.is_dir = 0;
    ctl.mode = 8r666;
    ctl.content = "ready\n";
    tree = ctl :: tree;

    # /dev/scarp/feed
    feed := ref VNode;
    feed.path_id = big 2;
    feed.name = "feed";
    feed.is_dir = 0;
    feed.mode = 8r222; # Write-only streaming
    tree = feed :: tree;

    # /dev/scarp/picks
    picks := ref VNode;
    picks.path_id = big 3;
    picks.name = "picks";
    picks.is_dir = 0;
    picks.mode = 8r444; # Read-only streaming
    picks.content = "";
    tree = picks :: tree;

    # /dev/scarp/events
    events := ref VNode;
    events.path_id = big 4;
    events.name = "events";
    events.is_dir = 0;
    events.mode = 8r444;
    events.content = "[]\n";
    tree = events :: tree;

    # /dev/scarp/shakemap
    sm := ref VNode;
    sm.path_id = big 5;
    sm.name = "shakemap";
    sm.is_dir = 0;
    sm.mode = 8r444;
    sm.content = "{\"type\":\"FeatureCollection\",\"features\":[]}\n";
    tree = sm :: tree;

    # /dev/scarp/stats
    stats := ref VNode;
    stats.path_id = big 6;
    stats.name = "stats";
    stats.is_dir = 0;
    stats.mode = 8r444;
    stats.content = "uptime_s:0 packets:0 triggers:0 events:0\n";
    tree = stats :: tree;

    return tree;
}

find_node(tree: list of ref VNode, name: string): ref VNode
{
    for (cur := tree; cur != nil; cur = tl cur) {
        if ((hd cur).name == name) {
            return hd cur;
        }
    }
    return nil;
}

read_node(node: ref VNode, offset: big, count: int): array of byte
{
    if (node == nil || count <= 0) return array[0] of byte;
    bytes := array of byte node.content;
    total_len := len bytes;

    off := int offset;
    if (off >= total_len) return array[0] of byte;

    avail := total_len - off;
    n := (count < avail ? count : avail);
    return bytes[off:off + n];
}

write_ctl(node: ref VNode, cmd: string): string
{
    if (node == nil || cmd == "") return "ERR: Invalid node or empty command";
    # Parse control commands
    if (cmd == "reset\n" || cmd == "reset") {
        node.content = "OK: system state reset\n";
        return "OK";
    } else if (cmd == "freeze_depth on\n" || cmd == "freeze_depth on") {
        node.content = "OK: depth freezing active\n";
        return "OK";
    }
    node.content = "OK: " + cmd;
    return "OK";
}
