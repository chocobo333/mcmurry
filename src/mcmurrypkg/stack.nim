
type
    Stack*[T] = object
        val: seq[T]

proc pop*[T](self: var Stack[T]): T {.discardable.} =
    self.val.pop()

proc push*[T](self: var Stack[T], val: T) =
    self.val.add val

proc top*[T](self: var Stack[T]): T =
    self.val[^1]

proc len*(self: Stack): int =
    self.val.len

iterator items*[T](self: Stack[T]): T =
    for e in self.val:
        yield e