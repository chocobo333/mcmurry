
#[
    rule:
        +or_expr

    or_expr:
        expr *("|" expr)

    expr:
        RULENAME
        TOKENNAME
        "*" expr
        "+" expr
        "?" expr
        "(" rule ")"
        "[" rule "]"


    r"[a-z_][a-z_0-9]*" = RULENAME
    r"[A-Z_][A-Z0-9]*" = TOKENNAME
]#

import sequtils
import strutils

import regex

type
    Rule = object
        left: string
        right: seq[string]


# TODO: implement
proc parse_rule*(src: string, annon_n: int): (seq[seq[string]], seq[Rule], int) =
    let
        tokens = splitIncl(src, re"([\w]+|""[[:print:]]+""|[\[\]+*?|()])").filter(proc(e:auto):bool=e.strip()!="")
    var
        nannon = annon_n
        # annons {.global.} : seq[Rule]
        i = 0
        tk: string
        ret_rules: seq[Rule]
        lpar = 0
        lcur = 0

    template getToken() =
        tk = tokens[i]
        inc i

    template isFinished(): bool =
        tokens.len == i

    template expect(c: string): bool =
        if tokens.len == i:
            false
        else:
            tokens[i] == c

    proc or_expr(): seq[seq[string]]
    proc expression(): seq[seq[string]]

    proc rule(): seq[seq[string]] =
        result = or_expr()
        while not isFinished():
            if lpar != 0 and expect(")"):
                dec lpar
                break
            if lcur != 0 and expect("]"):
                dec lcur
                break
            var
                tmp = result
            result = @[]
            for e in or_expr():
                var tmp2 = tmp
                for t in mitems(tmp2):
                    t.add e
                result.add tmp2
    
    proc or_expr(): seq[seq[string]] =
        result = expression()
        while expect("|"):
            getToken()
            result.add expression()

    proc expression(): seq[seq[string]] =
        getToken()
        var
            tk = tk
        case tk
        of "*":
            for e in expression():
                ret_rules.add Rule(left: "annon" & $nannon, right: e)
                ret_rules.add Rule(left: "annon" & $nannon, right: @["annon" & $nannon] & e)
            result = @[@["annon" & $nannon], @[]]
            inc nannon
        of "+":
            for e in expression():
                ret_rules.add Rule(left: "annon" & $nannon, right: e)
                ret_rules.add Rule(left: "annon" & $nannon, right: @["annon" & $nannon] & e)
            result = @[@["annon" & $nannon]]
            inc nannon
        of "?":
            result = expression() & @[newSeq[string]()]
        of "(":
            inc lpar
            result = rule()
            doAssert expect(")")
            getToken()
        of "[":
            inc lcur
            result = rule() & @[newSeq[string]()]
            doAssert expect("]")
            getToken()
        else:
            result = @[@[tk]]

    result = (rule(), ret_rules, nannon-annon_n)

let
    ret = parse_rule("a *(a b| c) d +e", 0)

for e in ret[0]:
    echo e
for e in ret[1]:
    echo e