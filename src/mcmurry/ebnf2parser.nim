
import macros

from sequtils import map, insert
from strutils import `%`, escape, splitLines, center, replace, parseInt, startsWith, repeat
import re
import tables

import private/core
import private/utils
import private/lr_dfa

export core.`$`

type
    TokenError* = object of Exception
    SyntaxError* = object of Exception


proc raiseSyntaxError*(program: string, pos: int, msg: string = "") =
    var
        str: string = "\n"
        n: int = min(pos, 5)
    for i, c in program[max(pos-5, 0)..pos]:
        if c == '\n':
            n = min(pos, 5)-i-1
    str &= "$1\n$2^\n" % @[program[max(pos-5, 0)..min(pos+5, program.len-1)], ' '.repeat(n)]
    raise newException(SyntaxError, str & msg)


proc find_annon_and_nodekind(body: var NimNode): (seq[NimNode], seq[NimNode]) =
    var
        l: seq[NimNode] = @[body]
        top: NimNode
    while l != @[]:
        top = l.pop()
        # FIXME: using re, make pattern not allow empty.
        if top.kind == nnkRStrLit:
            result[0].uadd top
        elif top.kind == nnkStrLit:
            error "Use raw string instead.; r\"$1\"." % [$top], top
        elif top.kind == nnkIdent:
            if ($top).startsWith("annon"):
                error "Rule's name must not start with `annon`.", top
            if not ($top).isUpper(true) and not ($top in @["*", "+"]):
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
            if ($top).startsWith("ANNON"):
                error "Token's name must not start with `ANNON`.", top
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
        tks.add ident("ANNON$1" % [$i])
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
                    # newIdentDefs(ident"stack", nnkBracketExpr.newTree(bindSym"seq", bindSym"int")),
                    newIdentDefs(ident"program", bindSym"string"),
                    newIdentDefs(ident"i", bindSym"int"),
                    newIdentDefs(ident"pos", nnkPar.newTree(bindSym"int", bindSym"int"))

                )
            )
        )
    )

    result.add typsec

    result.add quote do:
        template Node*(typ: typedesc[`pid`]): untyped = `nid`
    result.add quote do:
        template NodeKind*(typ: typedesc[`pid`]): untyped = `nkid`
    result.add quote do:
        template Token*(typ: typedesc[`pid`]): untyped = `tid`
    result.add quote do:
        template TokenKind*(typ: typedesc[`pid`]): untyped = `tkid`

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
                error "Use raw string; r\"$1\"." % [$e[0]], e
            e[0].expectKind(nnkRStrLit)
            e[1].expectKind(nnkStmtList)
            rstrs.add (e[0], e[1][0])
        of nnkPrefix:
            e[0].expectKind(nnkIdent)
            if $e[0] != directive_signature:
                error "Directive must start with \"$1\"" % [directive_signature], e[0]
            e[1].expectKind(nnkIdent)
            if $e[1] notin directive_commands:
                error "Directive must be one of $1" % [$directive_commands], e[1]
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
        # FIXME: using re, make pattern not allow empty.
        letsec.add nnkIdentDefs.newTree(ident("re" & $pid & $i), newEmptyNode(), nnkCallStrLit.newTree(bindSym"re", e[0], nnkCurly.newTree(bindSym"reStudy", bindSym"reDotAll")))
    for i, e in annons:
        # TODO: implement pure re
        letsec.add nnkIdentDefs.newTree(ident("re" & $pid & "annon" & $i), newEmptyNode(), nnkCallStrLit.newTree(bindSym"re", e))
    result.add letsec

    var kind_stack = ident"kind_stack"
    result.add quote do:
        var
            `kind_stack`: seq[`tkid`] = @[]

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
            if `kind_stack`.len != 0:
                return `tid`(kind: `kind_stack`.pop(), pos: self.pos)
            if self.i >= self.program.len:
                return `tid`(kind: `tkid`.EOF, val: "$", pos: self.pos)
    var
        self_next = result[^1].params[1][0]
        next = result[^1].body
    for i, e in annons:
        var
            ml = newCall(bindSym"matchlen", newDotExpr(self_next, ident"program"), ident("re" & $pid & "annon" & $i), nnkExprEqExpr.newTree(ident"start", newDotExpr(self_next, ident"i")))
        next[^1].add nnkElifBranch.newTree(
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
    for i, e in rstrs:
        var
            ml = newCall(bindSym"matchlen", newDotExpr(self_next, ident"program"), ident("re" & $pid & $i), nnkExprEqExpr.newTree(ident"start", newDotExpr(self_next, ident"i")))
        next[^1].add nnkElifBranch.newTree(
            infix(ml, "!=", newLit(-1)),
            newStmtList(
                nnkVarSection.newTree(
                    newIdentDefs(ident"len", newEmptyNode(), ml),
                    newIdentDefs(ident"str", newEmptyNode(),
                        nnkBracketExpr.newTree(
                            newDotExpr(self_next, ident"program"),
                            infix(newDotExpr(self_next, ident"i"), "..", infix(newDotExpr(self_next, ident"i"), "+", infix(ident"len", "-", newLit(1))))
                        )
                    ),
                    newIdentDefs(ident"lines", newEmptyNode(), newCall(bindSym"splitLines", ident"str")),
                    newIdentDefs(ident"kind", newEmptyNode(), e[1])

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

    next[^1].add nnkElse.newTree(
        newStmtList(
            nnkRaiseStmt.newTree(
                newCall(bindSym"newException", ident"TokenError", infix(newLit"Unexpected characters.", "&", nnkBracketExpr.newTree(newDotExpr(self_next, ident"program"), newDotExpr(self_next, ident"i"))))
            )
        )
    )
    if "ignore" in directives:
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

proc check_rule_structure(n: NimNode, rules, tokens: seq[string]) =
    case n.kind
    of nnkIdent:
        if isUpper($n, true):
            if $n notin tokens:
                error "Undefined token.", n
        elif not ($n).replace("_", "").isLower(true):
                error "Invalid name of rule"
        else:
            if $n notin rules:
                error "Undefined rule.", n
        return
    of nnkRStrLit:
        return
    of nnkPrefix:
        case $n[0]
        of "*", "+":
            check_rule_structure(n[1], rules, tokens)
            return
        else:
            error "Allowed prefix operators are only '+' and '*'.", n
    of nnkBracket:
        for e in n:
            check_rule_structure(e, rules, tokens)
    of nnkCommand:
        for e in n:
            check_rule_structure(e, rules, tokens)
    of nnkPar:
        for e in n:
            check_rule_structure(e, rules, tokens)
    else:
        error "Invalid rule. " & $n.kind, n

proc rewrite_annon(body: NimNode, annons: seq[NimNode]) =
    for j, e in body:
        if e.kind == nnkRStrLit:
            for i, annon in annons:
                if $e == $annon:
                    body[j] = ident("ANNON" & $i)
        else:
            rewrite_annon(e, annons)

# FIXME: implementation like @check_rule_structure.
proc parse_rule(body: NimNode, annons: seq[Nimnode], reset: int = 0): seq[Rule] =
    body.expectKind(nnkCall)
    var
        body = body
        nannon = reset
        left = $body[0]
    rewrite_annon(body, annons)
    for e in body[1]:
        var
            ret = @[Rule(left: left)]
            rep = repr(e)
            tmp: string
            i = 0
            c = rep[i]
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
                while c.isAlnum or c == '_':
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
    var
        rulenames: seq[string]
    for e in body:
        case e.kind
        of nnkCall:
            if isUpper($e[0], true):
                error "Upper case string is defined as token in Lexer section.", e
            elif not ($e[0]).replace("_", "").isLower(true):
                error "Invalid name of rule"

            rulenames.uadd $e[0]
        else:
            error "Invalid structure.", e
    for e in body:
        for ee in e[1]:
            check_rule_structure(ee, rulenames, tokens.map(proc (self: auto): string = $self))


    # parses rules
    var
        nannon = 0
        rules: seq[Rule]
        annonrules: seq[Rule]
    for e in body:
        for rule in parse_rule(e, annons, nannon):
            if rule.left.startsWith("annon"):
                if rule.right[0] != rule.left:
                    nannon += 1
                    # for r in annonrules:
                    #     if r.right == rule.right:
                    #         error "If you want to use a same pattern twice or more, you can make a new rule instead.", e
                    # annonrules.add rule
            rules.add rule
    var i = 0
    while i < rules.len:
        var k = -1
        if not rules[i].left.startsWith("annon"):
            i += 1
            continue
        for j, e in rules:
            if i == j:
                continue
            if not e.left.startsWith("annon"):
                continue
            if e.right == rules[i].right:
                k = j
                break
        if k == -1:
            i += 1
            continue
        for l, e in mpairs(rules):
            if l == k:
                continue
            if e.left == rules[k].left:
                e.left = rules[i].left
            for m, ee in e.right:
                if ee == rules[k].left:
                    e.right[m] = rules[i].left
        rules.delete(k)
        i = 0

    # echo rules

    # TODO: implement expansion of lr item set.
    var
        dfa = makeDFA(rules, toplevel)
    # echo rules
    # echo dfa
    # echo dfa.table
    var
        self = ident"self"
        src = ident"src"
        # cur_state = ident"cur_state"
        stack = ident"stack"
        token_stack = ident"token_stack"
        ret_stack = ident"ret_stack"
        state_case = nnkCaseStmt.newTree(nnkBracketExpr.newTree(stack, prefix(newLit(1), "^")))
        tk = ident"tk"
        t = ident"t"
        tmpt = ident"tmpt"
    result = newProc(postfix(ident"parse", "*"), [nid, newIdentDefs(ident"self", pid), newIdentDefs(ident"src", bindSym"string")])
    result.body = newStmtList()
    result.body.add nnkVarSection.newTree(
        # newIdentDefs(cur_state, bindSym"int"),
        newIdentDefs(stack, nnkBracketExpr.newTree(bindSym"seq", bindSym("int")), newLit(@[0])),
        newIdentDefs(token_stack, newCall("type", newDotExpr(ident"result", ident"tokens"))),
        newIdentDefs(ret_stack, newCall("type", newDotExpr(ident"result", ident"children")))
    )
    for i, table in dfa.table:
        var
            t_case = nnkCaseStmt.newTree(t)
        for key in table.keys:
            var
                op = table[key]
                stmtlist = newStmtList()
            case op.op
            of ACC:
                stmtlist.add nnkBreakStmt.newTree(newEmptyNode())
            of SHIFT:
                stmtlist.add newCall(newDotExpr(stack, bindSym"add"), newLit(op.val))
                stmtlist.add newCall(newDotExpr(token_stack, bindSym"add"), tk)
                stmtlist.add nnkBreakStmt.newTree(newEmptyNode())
            # TODO: implement case t of REDUCE:
            of REDUCE:
                var
                    rule: Rule = rules[op.val]
                stmtlist.add nnkAsgn.newTree(
                    ident"result",
                    newCall(nid)
                )
                for i in countdown(rule.right.len-1, 0):
                    var
                        e = rule.right[i]
                    stmtlist.add nnkDiscardStmt.newTree(newCall(newDotExpr(stack, bindSym"pop")))
                    if e.isUpper(true):
                        stmtlist.add newCall(newDotExpr(newDotExpr(ident"result", ident"tokens"), bindSym"insert"), newDotExpr(token_stack, bindSym"pop"), newLit(0))
                    elif e.startsWith("annon"):
                        stmtlist.add nnkVarSection.newTree(
                            newIdentDefs(ident"tmpannon", newEmptyNode(), newDotExpr(ret_stack, bindSym"pop"))
                        )
                        stmtlist.add newCall(newDotExpr(newDotExpr(ident"result", ident"children"), bindSym"insert"), newDotExpr(ident"tmpannon", ident"children"), newLit(0))
                        stmtlist.add newCall(newDotExpr(newDotExpr(ident"result", ident"tokens"), bindSym"insert"), newDotExpr(ident"tmpannon", ident"tokens"), newLit(0))
                    else:
                        stmtlist.add newCall(newDotExpr(newDotExpr(ident"result", ident"children"), bindSym"insert"), newDotExpr(ret_stack, bindSym"pop"), newLit(0))
                if rule.left.startsWith("annon"):
                    discard
                else:
                    stmtlist.add nnkAsgn.newTree(
                        newDotExpr(ident"result", ident"kind"),
                        ident(rule.left)
                    )
                stmtlist.add newCall(newDotExpr(ret_stack, bindSym"add"), ident"result")
                stmtlist.add nnkAsgn.newTree(
                    tmpt, 
                    t
                )
                stmtlist.add nnkAsgn.newTree(
                    t, 
                    newLit(rule.left)
                )
                # stmtlist.add newCall("echo", newLit(rule.left), newLit(rule.right.len))
            of GOTO:
                stmtlist.add newCall(newDotExpr(stack, bindSym"add"), newLit(op.val))
                stmtlist.add nnkAsgn.newTree(
                    t, 
                    tmpt
                )
            t_case.add nnkOfBranch.newTree(
                newLit(key),
                stmtlist
            )
        t_case.add nnkElse.newTree(
            newStmtList(
                nnkRaiseStmt.newTree(
                    newCall(bindSym"newException", ident"SyntaxError", infix(infix(newLit"Unexpected Token.", "&", t), "&", newDotExpr(tk, ident"val")))
                )
            )
        )
        state_case.add nnkOfBranch.newTree(
            newLit(i),
            newStmtList(
                t_case
            )
        )
    state_case.add nnkElse.newTree(
        newStmtList(
            nnkRaiseStmt.newTree(
                newCall(bindSym"newException", ident"SyntaxError", newLit"Error that is impossible to be occured.")
            )
        )
    )
    result.body.add nnkForStmt.newTree(
        tk,
        newCall(newDotExpr(self, ident"lex"), src),
        newStmtList(
            nnkVarSection.newTree(
                newIdentDefs(t, newEmptyNode(), prefix(newDotExpr(tk, ident"kind"), "$")),
                newIdentDefs(tmpt, newEmptyNode(), prefix(newDotExpr(tk, ident"kind"), "$"))
            ),
            nnkWhileStmt.newTree(
                bindSym"true",
                newStmtList(
                    # newCall("echo", t, nnkBracketExpr.newTree(stack, prefix(newLit(1), "^"))),
                    state_case
                )
            )
        )
    )
    # echo repr result
    # echo dfa
    # echo dfa.table
    # echo rules

macro Mcmurry*(id, toplevel, body: untyped): untyped =
    ##[
        Generating lexer/parser.
        ------------------------
        This parser generator generates parser and lexer at the same time.
        it accepts LR(1) grammar and supports ebnf (actually not all of).

        **Mcmurry**
        By using a macro named ``Mcmurry``, you can define a parser class includes a lexer.

        **Mcmurry arguments**
        
        * ``id``
            Set name of created parser class.
        * ``toplevel``
            Set starting rule.

        **Grammer Definitions** and **Patterns**

        * ``rule: ...``
            Define a rule.
            Name of rule matches re"[a-z][a-z0-9_]*"
        * ``[foo]``
            Match 0 or 1.
        * ``(foo bar)``
            Group together (for an operator).
        * ``*foo``
            Match 0 or more.
        * ``+bar``
            Match 1 or more.
        * .. code:: nim

            rule:
                foo
                bar

        Match foo or bar.

        **Token Definitions**
        * ``r"token": TOKEN``
            Define a token.
            right part is a raw string as a regular expression.
            left part is expression returns a sort of token.
            You can use ``block:`` in right part.

            Name of token matches re"[A-Z][A-Z0-9]*"
        * ``var variable``
            Define a variable used in deciding a sort of token that returned by the lexer.
            Used postlex.

            * Predefined variables

                * ``len``
                    Indicates the length of string that matched the regular expression.

        **Example**

        .. code:: nim
        
            Mcmurry(id=Parser, toplevel=expression):
                parser:
                    expression: arith_expr
                    arith_expr: term *(r"\+" term)
                    term: atom *(r"\*" atom)
                    atom:
                        INT
                        FLOAT
                lexer:
                    r"([0-9]*[\.])?[0-9]+": FLOAT
                    r"[1-9][0-9]*": INT
            var parser = Parser()
            echo parser.parse("3+4*2")
    ]##
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
    result.add def_parser(@[id, nkid, nid], toplevel, parser_argument, annons, tokens)
    
    # echo repr(result)
    # echo repr result[0]
    # echo repr result[1]
    # echo repr result[2]
    # echo repr result[3]
    # echo repr result[4]
    # echo repr result[5]
    # echo repr result[6]
    # echo repr result[7]
    # echo repr result[8]
    # echo repr result[9] # Lexer


when isMainModule:
    Mcmurry(id=Parser, toplevel=expression):
        parser:
            expression: arith_expr
            cond_expr: expression r"\?" expression r":" expression
            arith_expr: *(term OP1) term
            term: *(atom OP2) atom
            atom:
                NAME
                INT
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
