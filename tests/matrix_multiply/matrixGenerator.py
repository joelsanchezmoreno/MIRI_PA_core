import sys
import random
if __name__== "__main__":
    n = 129
    a = [[random.randint(0,10000) for j in range(n)] for i in range(n)]
    b = [[random.randint(0,10000) for j in range(n)] for i in range(n)]
    c = [[random.randint(0,0) for j in range(n)] for i in range(n)]

    outputA = ""
    outputB = ""
    outputC = ""

    for i in range(1,129):
        for j in range(1,129):
            valueA = hex(a[i][j]).replace('0x','').zfill(8)
            valueB = hex(b[i][j]).replace('0x','').zfill(8)
            valueC = hex(c[i][j]).replace('0x','').zfill(8)
            outputA += valueA
            outputB += valueB
            outputC += valueC
            if j%4==0:
                outputA += '\n'
                outputB += '\n'
                outputC += '\n'

    
    # outputHex += hex(int(l[i:i+4], 2)).replace('0x','')

    fnOutputA = open("data_in_MxM_A.hex","w")
    fnOutputB = open("data_in_MxM_B.hex","w")
    fnOutputC = open("data_in_MxM_C.hex","w")
    fnOutputA.write(outputA)
    fnOutputA.close()
    fnOutputB.write(outputB)
    fnOutputB.close()
    fnOutputC.write(outputC)
    fnOutputC.close()
