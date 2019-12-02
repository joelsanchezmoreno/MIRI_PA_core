// Some usefule macros
`ifndef _ET_MACROS_
`define _ET_MACROS_

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

`endif // _ET_MACROS_
