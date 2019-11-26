
import macros

from strutils import `%`, escape, splitLines, center, replace, parseInt, startsWith
import re
import tables

import private/core
import private/utils
import private/lr_dfa

export core.`$`


type
    TokenError* = object of Exception
    SyntaxError* = object of Exception


proc find_annon_and_nodekind(body: var NimNode): (seq[NimNode], seq[NimNode]) =
    var
        l: seq[NimNode] = @[body]
        top: NimNode
    while l != @[]:
        top = l.pop()
        if top.kind == nnkRStrLit:
            result[0].uadd top
        elif top.kind == nnkStrLit:
            error "Use raw string instead.; r\"$1\"." % @[$top], top
        elif top.kind == nnkIdent:
            if not ($top).isUpper(true) and not ($top in @["|", "*", "+"]):
                result[1].uadd top
        for e in top:
            l.add e

proc find_token_and_rstr(body: NimNode): seq[NimNode] =
    var
        stack: seq[NimNode]
        top: NimNode
    for e in body:
        if e.kind == nnkCall:
            stack.add e
    while stack != @[]:
        top = stack.pop()
        if top.kind == nnkIdent:
            if ($top).isUpper(true):
                result.uadd top
        for e in top:
            stack.add e

proc typedef(tkid, tid: NimNode, annons, tokens: seq[NimNode], nkid, nid: NimNode, nodekinds: seq[NimNode], pid: NimNode): seq[NimNode] =
    var
        typsec = nnkTypeSection.newNimNode()

    # defining type section
    var
        tks = tokens
        nks = nodekinds
        pure = nnkPragma.newTree(ident"pure")
    tks.insert newEmptyNode(), 0
    tks.add ident"EOF"
    nks.insert newEmptyNode(), 0
    for i in 0..<annons.len:
        tks.add ident("ANNON$1" % @[$i])
    # tokenkind
    typsec.add nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
            postfix(tkid, "*"),
            pure
        ),
        newEmptyNode(),
        nnkEnumTy.newTree(tks)
    )
    # token
    typsec.add nnkTypeDef.newTree(
        postfix(tid, "*"),
        newEmptyNode(),
        nnkBracketExpr.newTree(bindSym"TokenBase", tkid)
    )
    # nodekind
    typsec.add nnkTypeDef.newTree(
        nnkPragmaExpr.newTree(
            postfix(nkid, "*"),
            pure
        ),
        newEmptyNode(),
        nnkEnumTy.newTree(nks)
    )
    # node
    typsec.add nnkTypeDef.newTree(
        postfix(nid, "*"),
        newEmptyNode(),
        nnkBracketExpr.newTree(bindSym"NodeBase", nkid, tid)
    )
    # parser
    typsec.add nnkTypeDef.newTree(
        postfix(pid, "*"),
        newEmptyNode(),
        nnkRefTy.newTree(
            nnkObjectTy.newTree(
                newEmptyNode(),
                newEmptyNode(),
                nnkRecList.newTree(
                    newIdentDefs(ident"stack", nnkBracketExpr.newTree(bindSym"seq", bindSym"int")),
                    newIdentDefs(ident"program", bindSym"string"),
                    newIdentDefs(ident"i", bindSym"int"),
                    newIdentDefs(ident"pos", nnkPar.newTree(bindSym"int", bindSym"int"))

                )
            )
        )
    )

    result.add typsec

proc def_lexer(ids: seq[NimNode], body: NimNode, annons: seq[NimNode], tokens: seq[NimNode]): seq[NimNode] =
    body.expectKind(nnkStmtList)
    var
        pid = ids[0]
        tkid = ids[1]
        tid = ids[2]
    var
        directive_signature = "%"
        directive_commands = @["ignore"]
        directives: Table[string, seq[NimNode]]
        typsec: NimNode = nnkTypeSection.newNimNode()
        letsec: NimNode = nnkLetSection.newNimNode()
        varsec: NimNode = nnkVarSection.newNimNode()
        reinit: seq[NimNode]
        rstrs: seq[(NimNode, NimNode)]

    # checking structure of body
    for e in body:
        case e.kind
        of nnkVarSection:
            result.add e
            reinit.add nnkAsgn.newTree(e[0][0], e[0][2])
        of nnkCall:
            if e[0].kind == nnkStrLit:
                error "Use raw string; r\"$1\"." % @[$e[0]], e
            e[0].expectKind(nnkRStrLit)
            e[1].expectKind(nnkStmtList)
            rstrs.add (e[0], e[1][0])
        of nnkPrefix:
            e[0].expectKind(nnkIdent)
            if $e[0] != directive_signature:
                error "Directive must start with \"$1\"" % @[directive_signature], e[0]
            e[1].expectKind(nnkIdent)
            if $e[1] notin directive_commands:
                error "Directive must be one of $1" % @[$directive_commands], e[1]
            e[2].expectKind(nnkStmtList)
            for id in e[2]:
                id.expectKind(nnkIdent)
                if $e[1] notin directives:
                    directives[$e[1]] = newSeq[NimNode]()
                directives[$e[1]].add id
        else:
            error "only allowed token of definition or directive.", e
            e.expectKind({nnkVarSection, nnkCall, nnkPrefix})

    # defining const section
    for i, e in rstrs:
        # TODO: implement pure re
        # if match("", re($e[0])):
        #     error "Lexer does not allowed regular expression that empty string matches.", e[0]
        letsec.add nnkIdentDefs.newTree(ident("re" & $pid & $i), newEmptyNode(), nnkCallStrLit.newTree(bindSym"re", e[0]))
    for i, e in annons:
        # TODO: implement pure re
        letsec.add nnkIdentDefs.newTree(ident("re" & $pid & "annon" & $i), newEmptyNode(), nnkCallStrLit.newTree(bindSym"re", e))
    result.add letsec

    # proc program
    result.add quote do:
        proc program*(self: `pid`): string =
            self.program
    var prasid = nnkAccQuoted.newTree(ident"program=")
    result.add quote do:
        proc `prasid`*(self: `pid`, val: string) =
            self.program = val
            self.i = 0
            self.pos = (1, 1)
    var
        self_preeq = result[^1].params[1][0]
        preq = result[^1].body
    for e in reinit:
        preq.add e

    # proc next
    result.add quote do:
        proc next*(self: `pid`): `tid` =
            if self.i >= self.program.len:
                return `tid`(kind: `tkid`.EOF, val: "$", pos: self.pos)
    var
        self_next = result[^1].params[1][0]
        next = result[^1].body
    for i, e in rstrs:
        var
            ml = newCall(bindSym"matchlen", newDotExpr(self_next, ident"program"), ident("re" & $pid & $i), nnkExprEqExpr.newTree(ident"start", newDotExpr(self_next, ident"i")))
        next[0].add nnkElifBranch.newTree(
            infix(ml, "!=", newLit(-1)),
            newStmtList(
                nnkVarSection.newTree(
                    newIdentDefs(ident"len", newEmptyNode(), ml),
                    newIdentDefs(ident"kind", newEmptyNode(), e[1]),
                    newIdentDefs(ident"str", newEmptyNode(),
                        nnkBracketExpr.newTree(
                            newDotExpr(self_next, ident"program"),
                            infix(newDotExpr(self_next, ident"i"), "..", infix(newDotExpr(self_next, ident"i"), "+", infix(ident"len", "-", newLit(1))))
                        )
                    ),
                    newIdentDefs(ident"lines", newEmptyNode(), newCall(bindSym"splitLines", ident"str"))
                ),
                nnkAsgn.newTree(
                    ident"result",
                    nnkObjConstr.newTree(
                        tid,
                        nnkExprColonExpr.newTree(ident"kind", ident"kind"),
                        nnkExprColonExpr.newTree(ident"val", ident"str"),
                        nnkExprColonExpr.newTree(ident"pos", newDotExpr(self_next, ident"pos"))
                    )
                ),
                infix(newDotExpr(self_next, ident"i"), "+=", ident"len"),
                infix(nnkBracketExpr.newTree(newDotExpr(self_next, ident"pos"), newLit(0)), "+=", infix(newDotExpr(ident"lines", bindSym"len"), "-", newLit(1))),
                nnkIfStmt.newTree(
                    nnkElifBranch.newTree(
                        infix(newDotExpr(ident"lines", bindSym"len"), "==", newLit(1)),
                        newStmtList(
                            infix(nnkBracketExpr.newTree(newDotExpr(self_next, ident"pos"), newLit(1)), "+=", ident"len")
                        )
                    ),
                    nnkElse.newTree(
                        newStmtList(
                            nnkAsgn.newTree(
                                nnkBracketExpr.newTree(newDotExpr(self_next, ident"pos"), newLit(1)),
                                infix(newLit(1), "+", newDotExpr(nnkBracketExpr.newTree(ident"lines", prefix(newLit(1), "^")), bindSym"len"))
                            )
                        )
                    )
                )
            )
        )
    for i, e in annons:
        var
            ml = newCall(bindSym"matchlen", newDotExpr(self_next, ident"program"), ident("re" & $pid & "annon" & $i), nnkExprEqExpr.newTree(ident"start", newDotExpr(self_next, ident"i")))
        next[0].add nnkElifBranch.newTree(
            infix(ml, "!=", newLit(-1)),
            newStmtList(
                nnkVarSection.newTree(
                    newIdentDefs(ident"len", newEmptyNode(), ml),
                    newIdentDefs(ident"kind", newEmptyNode(), ident("ANNON" & $i)),
                    newIdentDefs(ident"str", newEmptyNode(),
                        nnkBracketExpr.newTree(
                            newDotExpr(self_next, ident"program"),
                            infix(newDotExpr(self_next, ident"i"), "..", infix(newDotExpr(self_next, ident"i"), "+", infix(ident"len", "-", newLit(1))))
                        )
                    ),
                    newIdentDefs(ident"lines", newEmptyNode(), newCall(bindSym"splitLines", ident"str"))
                ),
                nnkAsgn.newTree(
                    ident"result",
                    nnkObjConstr.newTree(
                        tid,
                        nnkExprColonExpr.newTree(ident"kind", ident"kind"),
                        nnkExprColonExpr.newTree(ident"val", ident"str"),
                        nnkExprColonExpr.newTree(ident"pos", newDotExpr(self_next, ident"pos"))
                    )
                ),
                infix(newDotExpr(self_next, ident"i"), "+=", ident"len"),
                infix(nnkBracketExpr.newTree(newDotExpr(self_next, ident"pos"), newLit(0)), "+=", infix(newDotExpr(ident"lines", bindSym"len"), "-", newLit(1))),
                nnkIfStmt.newTree(
                    nnkElifBranch.newTree(
                        infix(newDotExpr(ident"lines", bindSym"len"), "==", newLit(1)),
                        newStmtList(
                            infix(nnkBracketExpr.newTree(newDotExpr(self_next, ident"pos"), newLit(1)), "+=", ident"len")
                        )
                    ),
                    nnkElse.newTree(
                        newStmtList(
                            nnkAsgn.newTree(
                                nnkBracketExpr.newTree(newDotExpr(self_next, ident"pos"), newLit(1)),
                                infix(newLit(1), "+", newDotExpr(nnkBracketExpr.newTree(ident"lines", prefix(newLit(1), "^")), bindSym"len"))
                            )
                        )
                    )
                )
            )
        )
    next[0].add nnkElse.newTree(
        newStmtList(
            nnkRaiseStmt.newTree(
                newCall(bindSym"newException", ident"TokenError", newLit"Unexpected characters.")
            )
        )
    )
    for e in directives["ignore"]:
        next.add quote do:
            if result.kind == `tkid`.`e`:
                return `self_next`.next()
    
    # proc lex
    result.add quote do:
        iterator lex*(self: `pid`, program: string): `tid` =
            `prasid`(self, program)
            var ret: `tid`
            while true:
                ret = self.next()
                yield ret
                if ret.kind == `tkid`.EOF:
                    break

proc parse_rule(body: NimNode, annons: seq[Nimnode], reset: int = 0): seq[Rule] =
    body.expectKind(nnkCall)
    var
        nannon = reset
        left = $body[0]
    for e in body[1]:
        
        var
            ret = @[Rule(left: left)]
            rep = repr(e)
            tmp: string
            i = 0
            c = rep[i]
        echo rep
        proc p() =
            if c.isAlpha:
                tmp = ""
                tmp.add c
                i += 1
                if i >= rep.len:
                    for ee in mitems(ret):
                        if ee.left == left:
                            ee.right.add tmp
                    return
                c = rep[i]
                while c.isAlpha:
                    tmp.add c
                    i += 1
                    if i >= rep.len:
                        break
                    c = rep[i]
                for ee in mitems(ret):
                    if ee.left == left:
                        ee.right.add tmp
                return
            elif c == '[':
                var
                    rettmp = ret
                i += 1; c = rep[i]
                while c != ']':
                    p()
                ret.uadd rettmp
            elif c == '(':
                i += 1; c = rep[i]
                while c != ')':
                    p()
            elif c == '*':
                var
                    rettmp = ret
                    lefttmp = left
                ret.add rettmp
                for i, ee in mpairs(ret):
                    if i >= (ret.len) div 2:
                        break
                    if ee.left == left:
                        ee.right.add "annon" & $nannon
                rettmp = ret
                left = "annon" & $nannon
                nannon += 1
                ret = @[Rule(left: left), Rule(left: left, right: @[left])]
                i += 1; c = rep[i]
                p()
                ret.uadd rettmp
                left = lefttmp
                return
            elif c == '+':
                var
                    rettmp = ret
                    lefttmp = left
                for ee in mitems(ret):
                    if ee.left == left:
                        ee.right.add "annon" & $nannon
                rettmp = ret
                left = "annon" & $nannon
                nannon += 1
                ret = @[Rule(left: left), Rule(left: left, right: @[left])]
                i += 1; c = rep[i]
                p()
                ret.uadd rettmp
                left = lefttmp
                return
            elif c == '?':
                discard
            elif c == '|':
                discard
            i += 1
            if i >= rep.len:
                return
            c = rep[i]
        while i < len(rep):
            p()
        result.add ret

    for e in result:
        if e.right == @[]:
            error "pattern that allows empty is invalid.", body

proc def_parser(ids: seq[NimNode], toplevel, body: NimNode, annons: seq[NimNode], tokens: seq[NimNode]): NimNode =
    var
        pid = ids[0]
        nkid = ids[1]
        nid = ids[2]
    body.expectKind(nnkStmtList)

    # checking structure of body

    # parse rules
    for e in body:
        discard parse_rule(e, annons)

macro make*(id, toplevel, body: untyped): untyped =
    result = nnkStmtList.newNimNode()
    body.expectKind(nnkStmtList)
    body.expectLen(2)
    for e in body:
        e.expectKind(nnkCall)
        if $e[0] notin @["parser", "lexer"]:
            error "allowed `parser` or `lexer` section.", e[0]
    var
        tkid = ident($id & "TokenKind")
        tid = ident($id & "Token")
        pid = id
        nkid = ident($id & "NodeKind")
        nid = ident($id & "Node")
    var
        lexer_section = body.findChild(it[0].kind==nnkIdent and $it[0]=="lexer")
        parser_section = body.findChild(it[0].kind==nnkIdent and $it[0]=="parser")
        lexer_argument = lexer_section[1]
        parser_argument = parser_section[1]
        annons: seq[NimNode]
        tokens: seq[NimNode]
        nodekinds: seq[NimNode]
        rstrs: seq[NimNode]
    lexer_argument.expectKind(nnkStmtList)
    parser_argument.expectKind(nnkStmtList)

    (annons, nodekinds) = find_annon_and_nodekind(parser_argument)
    tokens = find_token_and_rstr(lexer_argument)
    result.add typedef(tkid, tid, annons, tokens, nkid, nid, nodekinds, pid)
    result.add def_lexer(@[id, tkid, tid], lexer_argument, annons, tokens)
    discard def_parser(@[id, nkid, nid], toplevel, parser_argument, annons, tokens)
    
    # echo repr(result)


when isMainModule:
    make(id=Parser, toplevel=expression):
        parser:
            expression: arith_expr
            cond_expr: expression r"\?" expression r":" expression
            arith_expr: *(term OP1) term
            term: *(atom_expr OP2) atom_expr
            atom_expr:
                atom *trailer
            atom:
                NAME
                NUMBER
                r"nil"
                r"false"
                r"true"
        lexer:
            r"[\+\-]": OP1
            r"[\*/]": OP2
            r"[a-zA-Z_][a-zA-z_0-9]*": NAME
            r"[1-9][0-9]*": INT
            r"("").*("")": STRING
            var
                nIndent = 0
            r"\n[ ]*":
                block:
                    if len-1 > nIndent:
                        nIndent = len-1
                        INDENT
                    elif len-1 < nIndent:
                        nIndent = len-1
                        DEDENT
                    else:
                        LF
            r"\s+": SPACE
            r"\n?\s*#[^\n]*": COMMENT
            %ignore:
                SPACE
                COMMENT
