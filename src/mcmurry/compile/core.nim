
import strutils
import sequtils
import strformat

import macros
import ast_pattern_matching

import private/utils
export utils

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
            result &= ("\n" & "└── " & (if ch.kind==`tokenname`:`tokenname String`(ch)else: `nodename String`(ch, indent+1))).indent(4)
    proc `$`*(tr: `treename`): string =
        if tr.kind == tokenname:
            result = `tokenname String`(tr)
        elif tr.kind == nodename:
            result = `nodename String`(tr)

template node_utils*(treename: untyped, tokenname, nodename: untyped) =
    proc getKind*(self: `treename`): string =
        if self.kind == tokenname:
            result = $self.tokenkind
        elif self.kind == nodename:
            result = $self.nodekind
    proc simplify*(self: `treename`): `treename` =
        ##[
            Simplify tree node.
            Nodes that have only one child and no tokens are removed through this proc.
            And then, return simplified node.
        ]##
        if self.kind == `tokenname`:
            return self
        for i, e in self.children:
            self.children[i] = simplify(e)
        if self.children.len == 1:
            return self.children[0]
        else:
            return self

type
    Parser = concept p
        p.i is int
        p.program is string
        p.programlen is int
        p.pos is (int, int)

    Tree = concept t
        t.kind is enum
        t.getKind is string


macro Visitor*(tree: typedesc[Tree], visitorname: untyped, visitfuncs: untyped): untyped =
    var
        treedef = tree.getImpl()
        treekinds: seq[string]
        kinds: seq[NimNode]

    # check varidation of `tree` and get kind of node and token
    try:
        treedef[2][0][2][0][0][1].matchAst(MatchingErrors):
        of `sym`@nnkSym:
            var
                treekind = sym.getImpl()[2]
            for i in 1..<treekind.len:
                treekinds.add treekind[i].strVal & "Kind"
        else:
            error fmt"{tree} is invalid type.", visitorname
    except:
        error fmt"{tree} is invalid type.", visitorname

    treedef[2][0][2][0].matchAstRecursive:
    of `name`@nnkSym:
        if name.strVal in treekinds:
            var
                kindenum = name.getImpl()[2]
            for i in 1..<kindenum.len:
                kinds.add kindenum[i]

    
    # Definition of procs
    result = newStmtList()
    var
        funcname = genSym(nskProc, "p")
        self = genSym(nskParam, "self")
        kind = genSym(nskLet, "kind")
        funcstmt = newStmtList()
        casestmt = nnkCaseStmt.newTree(kind)
        elsestmt = nnkElse.newNimNode()
        b_default: bool = false
        default = ident"default"

    funcstmt.add quote do:
        let
            `kind` = `self`.getKind()

    visitfuncs.expectKind(nnkStmtList)
    for e in visitfuncs:
        e.matchAst(MatchingErrors):
        of `procname`@nnkProcDef:
            let
                name = procname.name
            if name in kinds:
                casestmt.add nnkOfBranch.newTree(
                    newLit(name.strVal),
                    quote do:
                        `name`(`self`)
                )
            elif name.strVal == "default":
                b_default = true
        else:
            error $MatchingErrors, e
    if not b_default:
        visitfuncs.add quote do:
            proc `default`(`self`: `tree`) =
                discard
    casestmt.add nnkElse.newTree quote do:
        `default`(`self`)
    funcstmt.add casestmt
    # funcstmt.add quote do:
    #     if not `kind`.isUpperAscii(true):
    #         for e in `self`.children:
    #             `funcname`(e)
    funcstmt.add nnkIfStmt.newTree(
        nnkElifBranch.newTree(
            prefix(newCall(newDotExpr(kind, bindSym"isUpper"), bindSym"true"), "not"),
            quote do:
                for e in `self`.children:
                    `funcname`(e)
        )
    )

    
    # Generate codes
    result.add quote do:
        let
            `visitorname`: proc(`self`: `tree`) = block:
                `visitfuncs`
                proc `funcname`(`self`: `tree`) =
                    `funcstmt`
                `funcname`
                
macro Transformer*(tree: typedesc[Tree], visitorname: untyped, visitfuncs: untyped): untyped =
    var
        treedef = tree.getImpl()
        treekinds: seq[string]
        kinds: seq[NimNode]

    # check varidation of `tree` and get kind of node and token
    try:
        treedef[2][0][2][0][0][1].matchAst(MatchingErrors):
        of `sym`@nnkSym:
            var
                treekind = sym.getImpl()[2]
            for i in 1..<treekind.len:
                treekinds.add treekind[i].strVal & "Kind"
        else:
            error fmt"{tree} is invalid type.", visitorname
    except:
        error fmt"{tree} is invalid type.", visitorname

    treedef[2][0][2][0].matchAstRecursive:
    of `name`@nnkSym:
        if name.strVal in treekinds:
            var
                kindenum = name.getImpl()[2]
            for i in 1..<kindenum.len:
                kinds.add kindenum[i]

    
    # Definition of procs
    result = newStmtList()
    var
        funcname = genSym(nskProc, "p")
        self = genSym(nskParam, "self")
        kind = genSym(nskLet, "kind")
        funcstmt = newStmtList()
        casestmt = nnkCaseStmt.newTree(kind)
        elsestmt = nnkElse.newNimNode()
        b_default: bool = false
        default = ident"default"

    funcstmt.add quote do:
        let
            `kind` = `self`.getKind()

    visitfuncs.expectKind(nnkStmtList)
    for e in visitfuncs:
        e.matchAst(MatchingErrors):
        of `procname`@nnkProcDef:
            let
                name = procname.name
            if name in kinds:
                casestmt.add nnkOfBranch.newTree(
                    newLit(name.strVal),
                    quote do:
                        result = `name`(`self`)
                )
            elif name.strVal == "default":
                b_default = true
        else:
            error $MatchingErrors, e
    if b_default:
        casestmt.add nnkElse.newTree quote do:
            result = `default`(`self`)
    else:
        casestmt.add nnkElse.newTree quote do:
            result = `self`            
    funcstmt.add nnkIfStmt.newTree(
        nnkElifBranch.newTree(
            prefix(newCall(newDotExpr(kind, bindSym"isUpper"), bindSym"true"), "not"),
            newStmtList(
                quote do:
                    for i, e in `self`.children:
                        `self`.children[i] = `funcname`(e)
            )
        )
    )
    funcstmt.add casestmt


    # Generate codes
    result.add quote do:
        let
            `visitorname`: proc(`self`: `tree`): `tree` = block:
                `visitfuncs`
                proc `funcname`(`self`: `tree`): `tree` =
                    `funcstmt`
                `funcname`
