
from strutils import center, escape, `%`

import utils

type
    TokenBase*[TK: enum] = ref object
        kind*: TK
        val*: string
        pos*: (int, int)

    NodeBase*[NK: enum, T] = ref object
        kind*: NK
        children*: seq[NodeBase[NK, T]]
        tokens*: seq[T]
        pos*: (int, int)


proc `$`*[TK: enum](self: TokenBase[TK]): string =
    const l = enum_maxlen(TK)
    "[$1: $2]" % [center(($self.kind), l, ' '), self.val.escape]