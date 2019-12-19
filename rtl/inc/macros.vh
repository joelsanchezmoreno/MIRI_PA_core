// Some usefule macros
`ifndef _MACROS_
`define _MACROS_

    `define BYTE_SIZE        1 //bytes
    `define DWORD_SIZE       4 // bytes

    `define BYTE_BITS        (8*`BYTE_SIZE)
    `define DWORD_BITS       (8*`DWORD_SIZE)


    `define MAX(a,b) ((a)>(b) ? (a) : (b) )

    // Extensions
    `define ZX(SIZE, SIGNAL) \
        (((SIZE-$bits(SIGNAL)) == 0) ? SIGNAL : { {(SIZE-$bits(SIGNAL)){1'b0}}, SIGNAL })

    `define SX(SIZE, SIGNAL) \
        (((SIZE-$bits(SIGNAL)) == 0) ? SIGNAL : { {(SIZE-$bits(SIGNAL)){SIGNAL[$bits(SIGNAL)-1]}}, SIGNAL })

    // Flip flops
    `define FF(CLK, DATAOUT, DATAIN) \
        always @ (posedge CLK) \
            DATAOUT <= DATAIN;

    `define RST_FF(CLK, RST, DATAOUT, DATAIN, DEF) \
        always @ (posedge CLK) \
            if(RST) DATAOUT <= DEF; \
            else    DATAOUT <= DATAIN;

    `define EN_FF(CLK, EN, DATAOUT, DATAIN) \
        always @ (posedge CLK) \
            if(EN) DATAOUT <= DATAIN;

    `define RST_EN_FF(CLK, RST, EN, DATAOUT, DATAIN, DEF) \
        always @ (posedge CLK) \
            if(RST)     DATAOUT <= DEF; \
            else if(EN) DATAOUT <= DATAIN;

     `define ZX_BYTE(SIZE, SIGNAL) \
        (((SIZE-`BYTE_BITS) == 0) ? SIGNAL : { {(SIZE-`BYTE_BITS){1'b0}}, SIGNAL })

     `define ZX_DWORD(SIZE, SIGNAL) \
        (((SIZE-`DWORD_BITS) == 0) ? SIGNAL : { {(SIZE-`DWORD_BITS){1'b0}}, SIGNAL })


`endif // _MACROS_
