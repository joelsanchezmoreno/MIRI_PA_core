import sys

rtype = {"ADD":"00000000", "SUB":"00000001", "MUL":"00000010","ADDI":"00000011"}
mtype = {"LDB":"00010000", "LDW":"00010001", "STB":"00010010", "STW":"00010011", "MOV":"00010100"}
btype = {"BEQ":"00110000", "JUMP":"00110001", "TLBWRITE":"00110010", "IRET":"00110011", "BNE":"00110100", "BLT":"00110101", "BGT":"00110110", "BLE":"00110111", "BGE":"00111000", }


if __name__== "__main__":
    arg = sys.argv[1]
    fnInput  = open(arg,"r")
    lines = fnInput.readlines()
    output = ""
    j = 0
    for i,l in enumerate(lines):
        if j == 4:
            output += '\n'
            j = 0

        inst, args = l.split(" ")

        if inst in rtype.keys():
            if inst == "ADDI":
                rd, ra, imm = args.replace('$', '').split(",")
                output += rtype[inst] + "{0:05b}".format(int(rd)) + "{0:05b}".format(int(ra)) + "{0:014b}".format(int(imm))
            else:
                rd, ra, rb = args.replace('$', '').split(",")
                output += rtype[inst] + "{0:05b}".format(int(rd)) + "{0:05b}".format(int(ra)) + "{0:05b}".format(int(rb)) + "000000000"

        elif inst in mtype.keys():
            if inst == "MOV": #Pel que possa a l'enunciat, el mov nomes s'utilitza per mv rm0 -> rd
                rm0, rd = args.replace('$', '').split(',')
                output += mtype[inst] + "{0:05b}".format(int(rd)) + "0000000000000000000"
            else:
                rd, raOffset = args.replace('$', '').split(",")
                offset, ra = raOffset.replace('(', ',').replace(')','').split(',')
                output += mtype[inst] + "{0:05b}".format(int(rd)) + "{0:05b}".format(int(ra)) + "{0:014b}".format(int(offset))

        elif inst in btype.keys():
                #BEQ
                #JUMP
                if inst == 'IRET':
                    output += btype[inst] + + '000000000000000000000000'
                #TLBWRITE
                if inst == 'TLBWRITE':
                    r0, r1 = args.replace('$', '').split(',')
                    output += btype[inst] + '00000' + "{0:05b}".format(int(r0)) + "{0:05b}".format(int(r1)) + '000000000' #dtlb 1 itlb 0 how we know it?
        else:
            print("Instruction on line ", i, " not recognised")
            j -= 1

        j += 1
    outputHex = ''
    for l in output.split('\n'):
        i = 0
        while i < len(l):
            #print(len(l), i, i+4, l[i:i+4], int(l[i:i+4], 2), hex(int(l[i:i+3], 2)))
            outputHex += hex(int(l[i:i+4], 2)).replace('0x','')
            i += 4
        outputHex += '\n'

    print(outputHex)
    fnOutput = open(arg + ".b","w")
    fnOutput.write(outputHex)
    fnOutput.close()
