/* ===========================================================================

Header file for PKI-M assembler and simulator.

There are several things of note here. In particular, the "yystype"
below is used for both the assembler and the simulator command line
parsers, and in fact some things like "int_val" are accessed in both
grammars.

=========================================================================== */

// --------------------------------------------------------------------------
// Types
// --------------------------------------------------------------------------
typedef unsigned char      BYTE;         // Match these to the particular machine
typedef unsigned short     TWO_BYTE;     // you are running the simulator on.
typedef unsigned long      FOUR_BYTE;
typedef unsigned long long EIGHT_BYTE;

// --------------------------------------------------------------------------
// Constants
// --------------------------------------------------------------------------
const bool TRUE = 1;
const bool FALSE = 0;
const int  SYM_LEN = 32; // Assembler symbols and other places.

// --------------------------------------------------------------------------
// Parser stack type (for assembler and simulator both)
// --------------------------------------------------------------------------
struct  yystype
{
    int       int_val;
    char      *str_ptr;
    char      str_val[ SYM_LEN + 1 ];
    TWO_BYTE  two_byte;
    TWO_BYTE  partial_opcode;
    FOUR_BYTE instruction_addr;
    FOUR_BYTE long_opcode;
};

#ifdef  YYSTYPE
#undef  YYSTYPE
#endif
#define YYSTYPE struct yystype

// --------------------------------------------------------------------------
// Machine constants
// --------------------------------------------------------------------------

const int REGISTERS             = 16;
const FOUR_BYTE HIGH_ADDR_BYTE  = 0x00ff0000;
const FOUR_BYTE LOW_ADDR_BYTES  = 0x0000ffff;
const FOUR_BYTE HIGH_ADDR_SHIFT = 16;

#define PC_INCREMENT(opcode)    (((opcode & 0xc000) == 0xc000) ? 4 : 2)
#define IS_JUMP_OR_CALL(opcode) ((opcode & 0xf000) == 0xf000)

#define ONLY_64K 0 // If you are short on memory in your Linux box, set to 1

#if ONLY_64K
const FOUR_BYTE memory_size = 0x10000;   // Memory to allocate
const FOUR_BYTE memory_mask =  0xffff;   // Mask for above.
#else
const FOUR_BYTE memory_size = 0x1000000; // Memory to allocate
const FOUR_BYTE memory_mask =  0xffffff; // Mask for above.
#endif

const TWO_BYTE INSTRUCTION_MASK  = 0xf000; // The portion with the op code
const TWO_BYTE INSTRUCTION_SHIFT = 12;     // Shift the opcode into low nibble
const TWO_BYTE FLAG_MASK         = 0x0f00; // Part of instruction with jump flags
const TWO_BYTE FLAG_SHIFT        = 8;      // Shift the flags into the low nibble
const TWO_BYTE R1_MASK           = 0x0f00; // Part of the instruction with R1
const TWO_BYTE R2_MASK           = 0x00f0; // With R2
const TWO_BYTE R3_MASK           = 0x000f; // With R3
const TWO_BYTE R1_SHIFT          = 8;      // Shift the R1 part to the low nibble
const TWO_BYTE R2_SHIFT          = 4;      // Shift for the R2 part
const TWO_BYTE R3_SHIFT          = 0;      // Shift for the R3 part
inline TWO_BYTE decode_R1( TWO_BYTE instruction ) { return( ( instruction & R1_MASK ) >> R1_SHIFT ); }
inline TWO_BYTE decode_R2( TWO_BYTE instruction ) { return( ( instruction & R2_MASK ) >> R2_SHIFT ); }
inline TWO_BYTE decode_R3( TWO_BYTE instruction ) { return( ( instruction & R3_MASK ) >> R3_SHIFT ); }

// --------------------------------------------------------------------------
// Assembler symbol table
// --------------------------------------------------------------------------

const int SYMBOLS = 10000;
struct sym_s
{
    char       str_val[ SYM_LEN + 1 ];
    FOUR_BYTE  location;
};

// --------------------------------------------------------------------------
// Source code lines for interactive debugging
// --------------------------------------------------------------------------

const int MAX_SOURCE_LINE = 80;
struct asm_source_line
{
    int pc;
    int line_num;
    char source[ MAX_SOURCE_LINE + 1 ];
};

typedef struct asm_source_line * ASM_SOURCE_PTR;
typedef struct asm_source_line ASM_SOURCE_LINE;

// --------------------------------------------------------------------------
// The pki_run.cpp file defines EXTERN to actually allocate the globals.
// --------------------------------------------------------------------------

#ifndef EXTERN
#define EXTERN extern
#endif

EXTERN struct sym_s   symbol_table[ SYMBOLS ];  // The assembler symbol table
EXTERN int            symbols;                  // Number of symbols in the above
EXTERN BYTE           *memory;                  // Assembler uses this name
EXTERN BYTE           *ram_image;               // Simulator uses this name
EXTERN FOUR_BYTE      ram_image_size;           // Set to "memory_size" at startup.
EXTERN ASM_SOURCE_PTR *asm_source_lines;        // For listing source code lines
EXTERN ASM_SOURCE_PTR *asm_source_by_pc;        // Same, but by PC
EXTERN int            asm_source_line_count;    // How many we have
EXTERN bool           interactive_flag;         // True for interactive mode
EXTERN unsigned long  clock_cycles;             // Total clocks executed
EXTERN bool           listing;                  // True creates assembly listing
EXTERN char           *filename;                // Name of the .s file
EXTERN unsigned long  maxsim;                   // Maximum instructions to simulate
EXTERN bool           verbose;                  // Not interactive, but show instructions
EXTERN bool           execute_pipeline;         // True for a pipeline CPU
extern int            yydebug;                  // int and not bool - Bison generated.

int pki_asm( void );
int pki_sim( void );

// --------------------------------------------------------------------------
// All the various instruction constants and flags.
// --------------------------------------------------------------------------

const TWO_BYTE SYSCALL_OP = 0x0000;
const TWO_BYTE RETURN_OP  = 0x1000;
const TWO_BYTE MUL_OP     = 0x2000;
const TWO_BYTE DIV_OP     = 0x3000;
const TWO_BYTE ADD_OP     = 0x4000;
const TWO_BYTE SUB_OP     = 0x5000;
const TWO_BYTE AND_OP     = 0x6000;
const TWO_BYTE OR_OP      = 0x7000;
const TWO_BYTE XOR_OP     = 0x8000;
const TWO_BYTE LSC_OP     = 0x9000;
const TWO_BYTE LDI_OP     = 0xa000;
const TWO_BYTE STI_OP     = 0xb000;
const TWO_BYTE LOAD_OP    = 0xc000;
const TWO_BYTE STORE_OP   = 0xd000;
const TWO_BYTE LLC_OP     = 0xe000;
const TWO_BYTE JUMP_OP    = 0xf000;
const TWO_BYTE CALL_OP    = 0xf100;

const TWO_BYTE C_FLAG     = 0x0400;
const TWO_BYTE EQ_FLAG    = 0x0800;
const TWO_BYTE N_FLAG     = 0x0e00;
const TWO_BYTE NE_FLAG    = 0x0900;
const TWO_BYTE NZ_FLAG    = 0x0900;
const TWO_BYTE OV_FLAG    = 0x0f00;
const TWO_BYTE P_FLAG     = 0x0d00;
const TWO_BYTE SLE_FLAG   = 0x0300;
const TWO_BYTE SLT_FLAG   = 0x0200;
const TWO_BYTE ULE_FLAG   = 0x0500;
const TWO_BYTE ULT_FLAG   = 0x0400;
const TWO_BYTE Z_FLAG     = 0x0800;

