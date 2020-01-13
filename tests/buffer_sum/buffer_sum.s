1000:   ADDI R3,R3, 0x80        0   // num_iter
1004:   ADDI R10,R10,0x3000     1   // base addr A = 0x3000

1008:   BEQ  R0,R3,0x1020       2   0   6   4   2   0               // while(i != 128)
    100C:   LDW  R2, 0(R10)     3   1   7   5   3   1    // R2 = a[i]
    1010:   ADD  R1,R1,R2       4   2   0   6   4   2   // sum+=a[i]
    1014:   ADDI R0,R0,0x1      5   3   1   7   5   3   // ++i
    1018:   ADDI R10,R10,0x4    6   4   2   0   6   4   // @A+=4
    101C:   JUMP 0x1008         7   5   3   1   7   5   

1020:   ADDI R31,R31,0x7EAD     // execution finished


/*
CODE
------
    sum = 0
    for k in range(n)
        sum += int(a[k]) 
REGS
------
i --> R0
sum --> R1

All registers are initialized to 0

*/
