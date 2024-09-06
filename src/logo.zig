const std = @import("std");
const color = @import("color.zig");

pub const Logo = struct {
    name: []const u8,
    art: []const u8,
    height: usize,
    width: usize,
};

pub fn getLogo(nodename: []const u8) !Logo {
    if (std.mem.eql(u8, nodename, alpine.name)) {
        return alpine;
    } else if (std.mem.eql(u8, nodename, arch.name)) {
        return arch;
    } else if (std.mem.eql(u8, nodename, nix.name)) {
        return nix;
    }

    return generic;
}

const alpine = Logo{
    .name = "alpine",
    .art = color.BLUE ++
        \\      /\ /\
        \\     /  \  \
        \\    /    \  \
        \\   /      \  \
        \\           \
    ++ color.RESET,
    .height = 5,
    .width = 14,
};

const arch = Logo{
    .name = "arch",
    .art = color.CYAN ++
        \\       /\
        \\      /  \
        \\     /\   \
    ++ color.BLUE ++
        \\
        \\    /      \
        \\   /   ,,   \
        \\  /   |  |  -\
        \\ /_-''    ''-_\
    ++ color.RESET,
    .height = 7,
    .width = 15,
};

const nix = Logo{
    .name = "nix",
    .art = color.BLUE ++
        \\   \\   \\ //
        \\  ==\\___\\/ //
        \\    //    \\//
        \\ ==//     //==
        \\  //\\___//
        \\ // /\\  \\==
        \\   // \\  \\
    ++ color.RESET,
    .height = 7,
    .width = 15,
};

const generic = Logo{
    .name = "generic",
    .art = color.RESET ++
        \\     .--.
        \\    |o_o |
        \\    |
    ++ color.YELLOW ++
        \\:_/
    ++ color.RESET ++
        \\ |
        \\   //   \ \
        \\  (|     | )
        \\ /'\_   _/`\
        \\ \___)=(___/
    ++ color.RESET,
    .height = 7,
    .width = 12,
};
