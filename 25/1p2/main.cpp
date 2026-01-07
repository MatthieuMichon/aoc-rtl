#include <verilated.h>
#include <verilated_vcd_c.h>
#include "Vuser_logic_tb.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(true);

    VerilatedVcdC* tfp = new VerilatedVcdC;
    Vuser_logic_tb* tb = new Vuser_logic_tb;

    tb->trace(tfp, 99);
    tfp->open("wave.vcd");
    while (!Verilated::gotFinish()) {
        tb->eval();
        tfp->dump(Verilated::time());
        Verilated::timeInc(1);
    }

    tfp->close();
    return 0;
}
