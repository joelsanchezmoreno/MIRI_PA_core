import sys
import random
if __name__== "__main__":
    n = 129
    a = [random.randint(0,10000) for i in range(n)]

    outputA = ""

    for i in range(1,129):
        valueA = hex(a[i]).replace('0x','').zfill(8)
        outputA += valueA
        if i%4==0:
            outputA += '\n'

    
    fnOutputA = open("data_in_buffer_A.hex","w")
    fnOutputA.write(outputA)
    fnOutputA.close()
