1000:   ADDI R0,R0,0x0          // iterator i
1004:   ADDI R3,R3, 0x80        // num_iter
1008:   ADDI R10,R10,0x3000     // base addr C = 0x3000
100C:   ADDI R11,R11,0x13       // base addr A  
1010:   SLL  R11,R11,0xC        // base addr A = 0x13000
1014:   ADDI R12,R12,0x23       // base addr B
1018:   SLL  R12,R12,0xC        // base addr B = 0x23000

101C:   BEQ  R0,R3,0x108C   // while(i != 128)
    1020:   SLL R21,R0,0x7      // R21 = 128*i      -- compute address c[i][j]
    1024:   SUB R1,R1,R1        //  j = 0
    1028:   BEQ R1,R3,0x1084    // while(j != 128) 
        102C:   SUB R2,R2,R2      // k = 0
        1030:   SUB R4,R4,R4      // R4 = 0; (c[i][j])
        1034:   BEQ R2,R3,0x106C    //while(k != 128) 
            1038:   ADD  R22,R21,R2     // R22 = R21 + k                -- compute address a[i][k]
            103C:   SLL  R22,R22,0x2    // R22 = 4*R22                  -- compute address a[i][k]
            1040:   ADD  R22,R22,R11    // R22 = base_addrA + R22       -- compute address a[i][k]
            1044:   LDW  R5,0(R22)      // R5 = a[i][k]           
            1048:   SLL  R24,R2,0x7     // R24 = 128*k                  -- compute address b[k][j]
            104C:   ADD  R24,R24,R1     // R24 = R24 + j                -- compute address b[k][j]
            1050:   SLL  R24,R24,0x2    // R24 = 4*R24                  -- compute address b[k][j]
            1054:   ADD  R24,R24,R12    // R24 = base_addrA + R24       -- compute address b[k][j]
            1058:   LDW  R6,0(R24)      // R6 = b[k][j]       
            105C:   MUL  R7,R5,R6       // R7 = a[i][k]*b[k][j]
            1060:   ADD  R4,R4,R7       // R4 = c[i][j] + a[i][k]*b[k][j]
            1064:   ADDI R2,R2,0x1      // ++k
            1068:   JUMP 0x1034

        106C:   ADD  R20,R21,R1     // R20 = R20 + j            -- compute address c[i][j]
        1070:   SLL  R20,R20,0x2    // R20 = 4*R20              -- compute address c[i][j]
        1074:   ADD  R20,R20,R10    // R20 = R20 + base_addrC   -- compute address c[i][j]
        1078:   STW  R4, 0(R20)     // c[i][j] = R4
        107C:   ADDI R1,R1,0x1      // ++j
        1080:   JUMP 0x1028

    1084:   ADDI R0,R0,0x1      //++i
    1088:   JUMP 0x101C       

108C:   ADDI R31,R31,0x7EAD     // execution finished

// Compute addressment of matrix
// a[i][j] -- @[i][j] = base_addr + 4*(i*num_col + j) = base_addr + 4*(128*i + j)
//

// OPTIMIZED COMPUTE ADDRESS c[i][j]
ADDI R10,R10,0x0000  // base addr C

SLL R21,R0,0x7      // R21 = 128*i
ADD R20,R21,R1      // R20 = R21 + j
SLL R20,R20,0x2     // R20 = 4*R20
ADDI R20,R20,R10    // R20 = base_addrC + R20

// OPTIMIZED COMPUTE ADDRESS a[i][k]
ADDI R11,R11,0x0000  // base addr A

SLL R21,R0,0x7      // R21 = 128*i
ADD R22,R21,R2      // R22 = R21 + k
SLL R22,R22,0x2     // R22 = 4*R22
ADDI R22,R22,R11    // R22 = base_addrA + R22

// OPTIMIZED COMPUTE ADDRESS a[k][j]
ADDI R12,R12,0x0000  // base addr B





