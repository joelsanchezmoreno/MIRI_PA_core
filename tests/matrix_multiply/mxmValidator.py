import sys

if __name__== "__main__":
    fnInput1  = open("data_in_MxM_A.hex","r")
    fnInput2  = open("data_in_MxM_B.hex","r")
    lines1 = fnInput1.readlines()
    lines2 = fnInput2.readlines()
    
    row = 1
    column = 1
    n = 129
    a = [[0 for x in range(n)] for i in range(n)] 

    for i, l in enumerate(lines1):
        if column == 129:
            row += 1
            column = 1
        a[row][column]   = int(l[24:32],16)
        a[row][column+1] = int(l[16:24],16)
        a[row][column+2] = int(l[8:16], 16)
        a[row][column+3] = int(l[0:8],  16)
        column += 4

    row = 1
    column = 1
    b = [[0 for x in range(n)] for i in range(n)] 

    for i, l in enumerate(lines2):
        if column == 129:
            row += 1
            column = 1
        b[row][column]   =int(l[24:32],16)
        b[row][column+1] =int(l[16:24],16)
        b[row][column+2] =int(l[8:16], 16)
        b[row][column+3] =int(l[0:8],  16)
        column += 4

    fnInput1.close()
    fnInput2.close()

    print("PRINT MATRIX A")
    print("a[1][1] =",a[1][1])
    print("a[1][2] =",a[1][2])
    print("a[1][3] =",a[1][3])
    print("a[1][4] =",a[1][4])
    print("-----------------")
    print("PRINT MATRIX B")
    print("b[1][1] =",b[1][1])
    print("b[1][2] =",b[1][2])
    print("b[1][3] =",b[1][3])
    print("b[1][4] =",b[1][4])
    print("-----------------")

    c = [[0 for x in range(n)] for i in range(n)] 
    
    for i in range(n):
        for j in range(n):
            c[i][j] = 0
            for k in range(n):
                c[i][j] = c[i][j] + a[i][k]*b[k][j]

    output = ""

    for i in range(1,129):
        for j in range(1,33):

            value0 = hex(c[i][j]).replace('0x','').zfill(8)
            value1 = hex(c[i][j+1]).replace('0x','').zfill(8)
            value2 = hex(c[i][j+2]).replace('0x','').zfill(8)
            value3 = hex(c[i][j+3]).replace('0x','').zfill(8)

            # Check overflow
            if  len(value0) > 8  or len(value1) > 8  or len(value2) > 8  or len(value3) > 8  :
                print("Value bigger than 32 bits")

            output += value3 + value2 + value1 + value0
            output += '\n'

            if i == 1 and j == 1:
                print("PRINT MATRIX C")
                print("c[1][1] = ",hex(c[1][1]))
                print("c[1][2] = ",hex(c[1][2]))
                print("c[1][3] = ",hex(c[1][3]))
                print("c[1][4] = ",hex(c[1][4]))

    
    fnOutput = open("data_golden_MxM_C.hex","w")
    fnOutput.write(output)
    fnOutput.close()
