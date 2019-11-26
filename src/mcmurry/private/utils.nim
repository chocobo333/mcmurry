
import asciitype
export asciitype

proc enum_maxlen*(t: typedesc[enum]): int =
    for i in 0..<int(t.high):
        if result < len($t(i)):
            result = len($t(i))

template uadd*[T](self: seq[T], val: T) =
    if val notin self:
        self.add val

template uadd*[T](self: seq[T], val: seq[T]) =
    for e in val:
        self.uadd e