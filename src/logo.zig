const color = @import("color.zig");

pub const Logo = struct {
    art: []const u8,
    height: usize,
    width: usize,
};

pub const alpine = Logo{
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

pub const arch = Logo{
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

pub const nix = Logo{
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
