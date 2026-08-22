module boxdrawing;

struct BoxStyle
{
    string h, v;
    string tl, tr, bl, br;
    string tDown, tUp, tRight, tLeft;
    string cross;
}

immutable BoxStyle singleStyle = {
    h: "─", v: "│",
    tl: "┌", tr: "┐", bl: "└", br: "┘",
    tDown: "┬", tUp: "┴", tRight: "├", tLeft: "┤",
    cross: "┼"
};

immutable BoxStyle doubleStyle = {
    h: "═", v: "║",
    tl: "╔", tr: "╗", bl: "╚", br: "╝",
    tDown: "╦", tUp: "╩", tRight: "╠", tLeft: "╣",
    cross: "╬"
};

/// Double horizontal border with single vertical dividers (ideal for tables with distinct headers)
immutable BoxStyle doubleHorizSingleVertStyle = {
    h: "═", v: "│",
    tl: "╒", tr: "╕", bl: "╘", br: "╛",
    tDown: "╤", tUp: "╧", tRight: "╞", tLeft: "╡",
    cross: "╪"
};

/// Single horizontal dividers with double vertical border
immutable BoxStyle singleHorizDoubleVertStyle = {
    h: "─", v: "║",
    tl: "╓", tr: "╖", bl: "╙", br: "╜",
    tDown: "╥", tUp: "╨", tRight: "┠", tLeft: "┨",
    cross: "╫"
};
