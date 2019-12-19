
import tables
import sets
import hashes

import strutils
import sequtils

import utils

const log {.booldefine.} = false

template clog*(arg: untyped) =
    when log:
        stdout.write arg


type
    Rule* = object
        left*: string
        right*: seq[string]

proc `$`*(self: Rule): string =
    result = self.left & ": "
    for e in self.right:
        result.add e & ' '

proc `$`*(self: seq[Rule]): string =
    for e in self:
        result.add $e & '\n'

proc toRule*(self: seq[string]): Rule =
    result.left = self[0]
    result.right = self[1..^1]

const top* = "top$"
const eof* = "EOF"

type
    LRItem* = object
        rule*: Rule
        index*: int
        la*: HashSet[string]
    LRItemSet* = seq[LRItem]
    Edge* = (int, int, string)
    DFA* = object
        nodes*: seq[LRItemSet]
        edges*: seq[Edge]
        table*: LRTable

    LRopenum* = enum
        SHIFT
        REDUCE
        GOTO
        ACC
    LRop* = object
        op*: LRopenum
        val*: int
    LRTable* = seq[Table[string, LRop]]

proc `$`*(self: LRItem): string =
    result = self.rule.left & ": "
    for i, e in self.rule.right:
        if i == self.index:
            result.add "* "
        result.add e & ' '
    if self.index == self.rule.right.len:
        result.add "* "
    result.add "[ "
    for e in self.la:
        result.add e & ' '
    result.add ']'

proc `$`*(self: LRItemSet): string =
    var self = self
    while self.len != 0:
        result.add $self[0] & '\n'
        var i = 1
        while i < self.len:
            if self[i].rule.left == self[0].rule.left:
                result.add $self[i] & '\n'
                self.delete(i)
                continue
            i += 1
        self.delete(0)

proc `$`*(self: DFA): string =
    for i, e in self.nodes:
        var
            inn: seq[int]
            ou: seq[int]
            key: string
        for e in self.edges:
            if e[1] == i:
                inn.add e[0]
                key = e[2]
            if e[0] == i:
                ou.add e[1]
            
        result &= "($3)[$2] -> $1 -> ($4)\n" % [$i, key, ($inn)[2..^2], ($ou)[2..^2]]
        result &= $e & '\n'

proc `$`*(self: LRop): string =
    if self.op == ACC:
        return "ACC"
    result = ($self.op)[0..0] & $self.val

proc `$`*(self: LRTable): string =
    var
        tmp: seq[string]
        l: int
        s: string
    result = "   |"
    for node in self:
        for key in node.keys:
            if key notin tmp:
                tmp.add key
                result &= "$1|" % [center(key, 4, ' ')]
    result &= '\n'
    for i, node in self:
        result &= "$1|" % [center($i, 3, ' ')]
        for key in tmp:
            l = max(key.len, 4)
            s = if key in node: $node[key] else: ""
            result &= "$1|" % [center(s, l, ' ')]
        result &= '\n'

proc hash*(self: LRItem): Hash =
    result = self.index
    # result = result !& hash(self.rule.left)
    result = result !& hash(self.rule.right)
    # result = result !& hash(self.la)
    result = !$result
    

proc ad(self: var LRItemSet, val: LRItem) =
    for e in mitems(self):
        if e.rule == val.rule and e.index == val.index:
            e.la.incl val.la
            return
    self.add val

proc ad(self: var LRItemSet, val: LRItemSet) =
    for e in val:
        self.ad e

proc compression(self: var LRItemSet) =
    var
        tmp = self
    self = @[]
    for e in tmp:
        self.ad e

template rule_functions(rules: seq[Rule]) =
    proc first(self: varargs[string]): HashSet[string] =
        var
            rett {.global.} : Table[string, HashSet[string]]
            e = self[0]
        if e.isUpper(true):
            return @[e].toHashSet
        elif e == eof:
            return @[eof].toHashSet
        else:
            if e in rett:
                return rett[e]
            else:
                rett[e] = initHashSet[string]()
                for rule in rules:
                    if rule.left == e:
                        for f in first(rule.right):
                            if f notin rett[e]:
                                rett[e].incl f
                return rett[e]
    
    proc ref_rule(item: LRItem): LRItemSet =
        var
            rett {.global.}: Table[LRItem, LRItemSet]
            rettmp: LRItemSet

        if item in rett:
            result = rett[item]
        else:
            var
                la = if item.index + 1 < item.rule.right.len: first(item.rule.right[item.index+1]) else: item.la
                rulename = item.rule.right[item.index]
            for rule in rules:
                if rule.left == rulename:
                    rettmp.add LRItem(rule: rule, la: la)
            for e in rettmp:
                if e.rule.right[0] == rulename:
                    for ee in mitems(rettmp):
                        if ee.index == 0:
                            ee.la.incl (if e.rule.right.len == 1: e.la else: first(e.rule.right[1]))
            for e in rettmp:
                result.ad e
                if e.rule.right[0] == rulename:
                    continue
                if not e.rule.right[0].isUpper(true):
                    result.ad ref_rule(e)
            rett[item] = result

    proc expansion(self: var LRItemSet) =
        var
            tmp: LRItemSet
        for e in filter(self, proc(self:auto):bool=self.index < self.rule.right.len):
            tmp.ad ref_rule(e)
        self.ad tmp
    
    proc expansion(self: var DFA) =
        clog "Starting to make a dfa.\n"
        var
            i = 0
            state_table: Table[LRItemSet, int]
        self.nodes[0].expansion()
        while i < self.nodes.len:
            var
                cur_itemset = self.nodes[i]
                next_states: Table[string, LRItemSet]
            state_table[cur_itemset] = i
            for item in cur_itemset:
                var
                    varitem = item
                    key: string
                if varitem.index == varitem.rule.right.len:
                    continue
                key = varitem.rule.right[varitem.index]
                varitem.index += 1
                if key notin next_states:
                    next_states[key] = @[]
                next_states[key].ad varitem
            for key in next_states.keys:
                var
                    n_state = next_states[key]
                if n_state in state_table:
                    self.edges.add (i, state_table[n_state], key)
                else:
                    var l = self.nodes.len
                    state_table[n_state] = l
                    n_state.expansion()
                    self.edges.add (i, l, key)
                    self.nodes.add n_state
            clog "Number of states: " & $i & "\r"
            i += 1
        clog "\n"

        clog "Starting to make the LR table.\n"
        when log:
            var
                log_i = 0
                log_j = 0
                
        var
            key: string
            op: LRop
        self.table = newSeq[Table[string, LRop]](self.nodes.len)
        for edge in self.edges:
            key = edge[2]
            op = LRop(op: if key.isUpper(true): SHIFT else: GOTO, val: edge[1])
            self.table[edge[0]][key] = op

            clog "Connecting edge " & repeat('.', log_i mod 3) & repeat(' ', 3-(log_i mod 3)) & '\r'
            when log:
                log_i += 1

        for nn, node in self.nodes:
            for item in node:
                if item.rule.right.len == item.index:
                    if item.rule.left == top:
                        self.table[nn][eof] = LRop(op: ACC)
                        continue
                    for nr, rule in rules:
                        if rule.left == item.rule.left and rule.right == item.rule.right:
                            for key in item.la:
                                # if there is shift/reduce conflict, raise error
                                if key in self.table[nn]:
                                        raise newException(ValueError, "not lr(1) for $1" % [item.rule.left])
                                self.table[nn][key] = LRop(op: LRopenum.REDUCE, val: nr)

                                clog "Sucking on candy " & repeat('.', log_j mod 3) & repeat(' ', 3-(log_j mod 3)) & '\r'
                                when log:
                                    log_j += 1
        clog "\n"


proc makeDFA*(rules: seq[Rule], toplevel: string): DFA =
    var
        lefts = rules.map(proc(self: Rule): string = self.left)
    if toplevel notin lefts:
        raise newException(ValueError, "There is not a rule of toplevel.")
    rule_functions(rules)
    discard first($toplevel)
    discard ref_rule(LRItem(rule: Rule(left: top, right: @[$toplevel]), la: toHashSet([eof])))

    # initialize DFA
    result.nodes.add @[LRItem(rule: Rule(left: top, right: @[$toplevel]), la: toHashSet([eof]))]

    expansion(result)
    # echo first("module")
    