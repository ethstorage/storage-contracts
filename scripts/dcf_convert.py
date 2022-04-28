target = int(0.9 * (2 ** 128))

# Calculate high-resolution 0.xxx to Q128.128
def to_Q128x128(frac3, res=128):
    ipart = 0
    fpart = frac3
    for i in range(res):
        ipart = ipart * 2
        fpart = fpart * 2
        ipart = ipart + (fpart // 1000)
        fpart = fpart % 1000
    if fpart >= 500:
        ipart = ipart + 1
    return ipart

def pow(p, n):
    v = 1 << 128
    while n != 0:
        if (n & 1) == 1:
            v = (v * p) >> 128
        p = (p * p) >> 128
        n = n // 2
    return v

def find_root(v, nroot):
    l = v
    r = 1 << 128

    b = None
    bdiff = None

    while l < r:
        m = (l + r) // 2
        mv = pow(m, nroot)

        if b is None or abs(v - mv) < bdiff:
            b = m
            bdiff = abs(v - mv)

        if mv < v:
            l = m + 1
        else:
            r = m - 1
    return b

print(int(0.9 * (2 ** 128)))
print(to_Q128x128(900))

print(int(0.9 ** (1/365/24/3600) * (2 ** 128)))
print(find_root(to_Q128x128(900), 3600 * 24 * 365))

