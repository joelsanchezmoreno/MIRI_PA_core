import sys
import random

if __name__== "__main__":

    # Read input buffer A
    fnInput1  = open("data_in_buffer_A.hex","r")
    lines1 = fnInput1.readlines()
    
    column = 1
    n = 129
    a = [random.randint(0,0) for i in range(n)]

    for i, l in enumerate(lines1):
        a[column]   = int(l[24:32],16)
        a[column+1] = int(l[16:24],16)
        a[column+2] = int(l[8:16], 16)
        a[column+3] = int(l[0:8],  16)
        column += 4

    fnInput1.close()

    # Computer buffer sum
    sum = 0
    for k in range(n):
        sum += int(a[k])    

    print("Buffer sum result is ", sum)
