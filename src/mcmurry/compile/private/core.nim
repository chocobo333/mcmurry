
type
    Rule* = object
        left*: string
        right*: seq[string]

proc toRule*(self: seq[string]): Rule =
    result.left = self[0]
    result.right = self[1..^1]