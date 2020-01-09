import sys

if __name__== "__main__":
    fnInput1  = open("a.hex","r")
    fnInput2  = open("b.hex","r")
    lines1 = fnInput1.readlines()
    lines2 = fnInput2.readlines()
    
    row = 1
    column = 1
    n = 129
    a = [[0] * n for i in range(n)]
    for i, l in enumerate(lines1):
        if column == 129:
            row += 1
            column = 1
        a[row][column]   = int(l[0:4], 16)
        a[row][column+1] = int(l[4:8], 16)
        a[row][column+2] = int(l[8:12], 16)
        a[row][column+3] = int(l[12:16], 16)
        column += 4

    row = 1
    column = 1
    b = [[0] * n for i in range(n)]
    for i, l in enumerate(lines1):
        if column == 129:
            row += 1
            column = 1
        b[row][column]   = int(l[0:4], 16)
        b[row][column+1] = int(l[4:8], 16)
        b[row][column+2] = int(l[8:12], 16)
        b[row][column+3] = int(l[12:16], 16)
        column += 4

    fnInput1.close()
    fnInput2.close()

    c = [[0] * n for i in range(n)]

    
    for i in range(n):
        for j in range(n):
            c[i][j] = 0
            for k in range(n):
                c[i][j] = c[i][j] + a[i][k]*b[k][j]


    output = ""

    for i in range(1,129):
        for j in range(1,129):
            value = hex(c[i][j]).replace('0x','').zfill(8)
            if len(value) > 8:
                print("Value bigger than 32 bits")
            output += value
            if j%4==0:
                output += '\n'

    
    # outputHex += hex(int(l[i:i+4], 2)).replace('0x','')

    fnOutput = open("c.hex","w")
    fnOutput.write(output)
    fnOutput.close()
