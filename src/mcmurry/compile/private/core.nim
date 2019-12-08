

type
    TreeKind {.pure.} = enum
        TK
        ND

    TokenKind {.pure.} = enum
        INT
        FLOAT

    NodeKind {.pure.} = enum
        integer
        floating

    TreeObj = object
        case kind: TreeKind
        of TK:
            val: string
            pos: (int, int)
            case tokenkind: TokenKind
            of INT:
                tkintval: int
            else:
                discard
        of ND:
            children: seq[Tree]
            case nodekind: NodeKind
            of integer:
                ndintval: int
            of floating:
                floatval: float
    Tree = ref TreeObj


proc kind(self: Tree): TreeKind = self.kind
proc nodekind(self: Tree): NodeKind =
    self.nodekind

proc intval(self: Tree): auto =
    if self.kind == TK:
        result = self.tkintval
    elif self.kind == ND:
        result = self.ndintval

proc `intval=`(self: Tree, val: auto) =
    if self.kind == TK:
        self.tkintval = val
    elif self.kind == ND:
        self.ndintval = val

when isMainModule:
    var
        a = Tree(kind: TK, val: "fff")
        b = Tree(kind: ND, nodekind: integer, ndintval: 3)
    echo sizeof(a[])
    echo sizeof(b[])
    echo a[]
    echo b[]
    b = Tree(kind: ND, nodekind: floating)
    echo b[]
    echo b.nodekind
    b.intval = 3

    var
        c: seq[string]
    c.add "fff"

when nimvm:
    when nimvm:
        discard
    else:
        echo "dd"
else:
    discard

# when nimvm:
#     import strutils
#     when nimvm:
#         import sequtils
#     else:
#         import sequtils
# else:
#     import strutils

import macros
dumpTree:
    type
        a = object
            case tokenkind: TokenKind
                    of INT:
                        tkintval: int
                    else:
                        discard