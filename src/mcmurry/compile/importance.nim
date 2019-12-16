
import strutils
import strformat

type
    SyntaxError* = object of Exception
    TokenError* = object of Exception

# TODO: fix into pos:(int, int) version.
# proc raiseSyntaxError*(program: string, pos: (int, int), msg: string = "") =
#     var
#         str: string = "\n"
#         n: int = min(pos, 5)
#     for i, c in program[max(pos-5, 0)..pos]:
#         if c == '\n':
#             n = min(pos, 5)-i-1
#     str &= "$1\n$2^\n" % @[program[max(pos-5, 0)..min(pos+5, program.len-1)], ' '.repeat(n)]
#     raise newException(SyntaxError, str & msg)

proc raiseSyntaxError*(program: string, pos: (int, int), msg: string = "") =
    var
        str = '\n' & program.splitLines()[pos[0]-1]
    str &= "\n" & ' '.repeat(pos[1]-1) & "^\n"
    raise newException(SyntaxError, str & msg)

proc raiseTokenError*(program: string, pos: (int, int), msg: string = "") =
    var
        str = '\n' & program.splitLines()[pos[0]-1]
    str &= "\n" & ' '.repeat(pos[1]-1) & "^\n"
    raise newException(TokenError, str & msg)

proc maxlen*[E: enum](typ: typedesc[E]): int =
    for i in 0..<int(typ.high):
        if result < len($typ(i)):
            result = len($typ(i))

template tree2String*(treename: untyped, tokenname, nodename: untyped) =
    proc `tokenname String`(tk: `treename`): string =
        const len = `tokenname Kind`.maxlen()
        result = "[$1: $2]" % [center($(tk.tokenkind), len, ' '), tk.val.escape]
    proc `nodename String`(nd: `treename`, indent:int = 0): string =
        if nd.isNil:
            return
        result = $nd.nodekind
        for ch in nd.children:
            result &= ("\n" & "└---" & (if ch.kind==`tokenname`:`tokenname String`(ch)else: `nodename String`(ch, indent+1))).indent(4)
    proc `$`*(tr: `treename`): string =
        if tr.kind == tokenname:
            result = `tokenname String`(tr)
        elif tr.kind == nodename:
            result = `nodename String`(tr)