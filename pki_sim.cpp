/* ===========================================================================

PKI Machine Simulator

Note that we really should make a class pki_machine that has all of
this functionality in it, but then again... when would we ever need to
reuse that class? So I did not bother. ALso, RAM and such is global,
becaue the parser (generated from Bison) won't let me pass param's to
it willy nilly... Really, this is a thrown together program, where
most of the CPU functionality is just global variables. Hey, it's a
throw-away.

Did I mention that it REALY needs to be rewritten as a class and one
that makes sense? The function "do_step" in particular is messy.

Author: Bill Mahoney
Date:   June 3, 2001
For:    CS 4350 and others...

Modifications: Updated July 2005 for the 1.4 version of the
machine. There are a few opcode changes and now the machine is a
32-bit one...

Updated May 2008, merger of assembler and simulator into single
program.  Provide pki_sim() interface routine instead of
main(). Call/return now push and pop 4 bytes instead of 3, which was
just plain strange. Added pipeline support. How this works is that
there are three pipeline stages, and things flow from stage to
stage. See below...

=========================================================================== */

#include <iostream>
#include <fstream>
#include <iomanip>
#include <stdlib.h>
#include <ctype.h>
#include "pki_machine.h"

using namespace std; // Tired of this C++-ism, myself.

/* ===========================================================================
   Important const's.
   =========================================================================== */

const int       int_bits   = 32;           // Obvious...
const FOUR_BYTE sign_bit   = 0x80000000;   // Most significant bit
const FOUR_BYTE all_ones   = 0xffffffff;   // All ones, get it?
const FOUR_BYTE big_signed = 0x7fffffff;   // Signed integer max

/* ===========================================================================
   globals - I didn't bother doing this "throw away" the right way.
   =========================================================================== */

const TWO_BYTE       max_reg = 16;               // Number of registers, obviously.
const TWO_BYTE       max_breaks = 1024;          // Woah! That's a buttload of breakpoints!
      TWO_BYTE       breakpoints[ max_breaks ];  // Breakpoint of 0x0000 is unavailable
      unsigned short max_break;                  // How many are now set?
      FOUR_BYTE      registers[ max_reg ];       // The registers for the CPU
      FOUR_BYTE      pc, temp_pc;                // The program counter
      bool           zero_flag, carry_flag;      // CPU flags
      bool           overflow_flag, sign_flag;   // CPU flags

struct pipeline_s {
    TWO_BYTE front_2;     // The instruction part
    TWO_BYTE back_2;      // For LOAD, CALL, JUMP, ...
} pipeline[ 3 ] =         // [0]==Fetch, [1]==Decode, [2]==Execute
  { { 0x4000, 0x0000 },   // ADD R0,R0,R0
    { 0x4000, 0x0000 },   // ADD R0,R0,R0
    { 0x4000, 0x0000 } }; // ADD R0,R0,R0

TWO_BYTE &instruction = pipeline[ 2 ].front_2; // Note: by reference

/* ===========================================================================
   Proto's here...
   =========================================================================== */

int sim_yyparse( void );
void sim_reset_input( void );
void show_next( void );
bool do_step( void );
static bool match_flags( TWO_BYTE cond );
int stalls();

/* ===========================================================================
   pki_sim -- entry point to simulator
   =========================================================================== */

int pki_sim( void )
{
    int        i;
    char       *filename = NULL;
    int        bytes;
    extern int sim_yydebug;

    // Note: ram_image already loaded by assembler

    if ( interactive_flag )
    {
        show_next();
        while ( true )
        {
            cout << "pki_sim> ";
            // Returns 0 for OK, 1 for parse error.
            // We force a return of 2 for "QUIT".
            if ( sim_yyparse() == 2 )
                break;
            else
                sim_reset_input();
        }
    }
    else
    {
        while ( true )
        {
            if ( ! do_step() )
                break;
            else
                if ( verbose )
                    show_next();
        }
    }

    cout << "Executed " << dec << clock_cycles << " total clock cycles." << endl;

    return( 0 );
}

/* ===========================================================================

dm_command

Display memory so that we can see what's up. This "remembers" where we
are at so that if the address passed in happens to be -1 we continue
where we were last time.

uses the global "memory_bytes" - we can't pass this into sim_yyparse as a
parameter, so we have to make it global.

Inputs:  starting_point - the address (not subscript) to start at
Outputs: None
Returns: None

=========================================================================== */

void dm_command( const int starting_point )
{
    static FOUR_BYTE start;
    FOUR_BYTE        finish;

    if ( starting_point != -1 )
        start = starting_point;

    finish = start + 128; // can wrap around 64K

    start  &= memory_mask;
    finish &= memory_mask;

    while ( start != finish )
    {
        cout << hex  << "0x" << setw( 6 ) << setfill( '0' ) << start;
        cout << " -";
        for( FOUR_BYTE i = 0; i < 16; i++ )
            cout << " " << setw( 2 ) << setfill( '0' ) << hex 
                 << ( (int) ( ram_image[ ( start + i ) & memory_mask ] & 0xff ) );

        cout << " - ";

        for( FOUR_BYTE i = 0; i < 16; i++ )
            if ( isprint( ram_image[ start + i ] ) )
                cout << (char) ram_image[ ( start + i ) & memory_mask ];
            else
                cout << '.';
            
        cout << "\n";
        start += 16;
        start &= memory_mask;
    }
}

/* ===========================================================================

sm_command

Set memory words to something. In other words, poke a value in there
while the simulation is stopped. Kind of like setting front panel
toggles. Or maybe wiring interface cards. Or maybe mercury delay
lines. OK, I digress back in time.

Inputs:  location - the address to change (not the subscript!)
value - the value to put there
Outputs: None, but memory changes
Returns: None

=========================================================================== */

void sm_command( const int location, const BYTE value )
{
    ram_image[ location ] = value & 0x00ff;
    cout << "RAM at address 0x" << hex 
         << setw( 4 ) << setfill( '0' ) << location
         << " set to 0x" << setw( 2 ) << (int) value 
         << " (" << dec << (int) value << " decimal)\n";
}

/* ===========================================================================

do_break

Set a breakpoint. Note that we don't currently support break counts,
but that can be added in the future if you want them.

Inputs:  point - the place to set the break
bOutputs: None, but the global breakpoint list is modified
Returns: Void

=========================================================================== */

void list_breakpoints()
{
    int count = 0;

    for( int i = 0; i < max_break; i++ )
        if ( breakpoints[ i ] )
        {
            count++;
            if (count == 1)
                cout << "Current breakpoint list:" << endl;
            cout << hex 
                 << "    0x" << setw( 4 ) << setfill( '0' ) 
                 << breakpoints[ i ] << dec << endl;
        }
    if (count == 0)
        cout << "No breakpoints set" << endl;
}

void do_break( const int point )
{
    if (point == -1)  /* no address given */
    {
        list_breakpoints();
        return;
    }
    if ( max_break < max_breaks - 1 )
    {
        breakpoints[ max_break++ ] = point;
        cout << hex 
             << "Breakpoint set at 0x" << setw( 4 ) 
             << setfill( '0' ) << point << endl;
        list_breakpoints();
    }
    else
        cout << "Maximum breakpoints already set...\n";
}

/* ===========================================================================

clear_break

Remove a breakpoint from the list. Note that we do this in a
simplistic way. Since we anticipate never really setting (exhausting)
the breakpoint list, all I do is to set that breakpoint to zero - no
garbage collection by moving up the list or anything like that...

Inputs:  point - the breakpoint (address) to clear
Outputs: None, but the breakpoint list is changed
Returns: None

=========================================================================== */

void clear_break( const int point_arg )
{
    int i, point;

    // if no point given on command line, use pc
    point = (point_arg == -1) ? pc : point_arg;
    
    for( i = 0; i < max_break; i++ )
        if ( breakpoints[ i ] == point )
        {
            cout << "Clearing breakpoint at 0x" << hex  << setw( 4 ) 
                 << setfill( '0' ) << point << " (" << dec << setw( 0 ) 
                 << point << " decimal)\n";
            breakpoints[ i ] = 0;
            break;
        }

    if ( i >= max_break )
        cout << "I did not see a current breakpoint at 0x"
             << hex  << setw( 4 ) << setfill( '0' ) << point 
             << " (" << dec << setw( 0 ) << " decimal) to clear.\n";

    for( int i = 0; i < max_break; i++ )
        if ( breakpoints[ i ] )
            cout << hex  << "    0x" << setw( 4 ) << setfill( '0' ) 
                 << breakpoints[ i ] << endl;
}

/* ===========================================================================

is_break

Returns true if this address is a break. Used for the "continue" command.

Inputs:  point - the breakpoint (address) to clear
Outputs: None
Returns: true/FALSE

=========================================================================== */

bool is_break( const int point )
{
    int i;
    for( i = 0; i < max_break; i++ )
        if ( breakpoints[ i ] == point )
        {
            cout << "Breakpoint at 0x" << hex 
                 << setw( 4 ) << setfill( '0' )
                 << point << "; stopped...\n";
            return( true );
        }
    return( false );
}

/* ===========================================================================

dr_command

Display the registers in the simulator...

Inputs:  None
Outputs: None
Returns: None

=========================================================================== */

void dr_command( void )
{
    int i, as_int, decimals = 1, hexs = 1;
    int columns = 4;

#if 0
    // Used to do this - change the output format if it is wider than
    // the default 80 column PuTTY terminal. But hey, you can just resize it.

    // Figure out how wide to make the decimal formats.
    // Largest four byte integer is 2,xxx,xxx,xxx = 10 places.
    for( i = 0; i < max_reg; i++ )
    {
        int temp_dec = ( (int) registers[ i ] < 0 );
        int temp = (int) registers[ i ];
        for( ; temp != 0; temp_dec++, temp /= 10 )
            ;
        if ( temp_dec > decimals )
            decimals = temp_dec;
    }

    // Same with the hex.
    for( i = 0; i < max_reg; i++ )
    {
        FOUR_BYTE temp;
        int       temp_hex;
        for( temp = registers[ i ], temp_hex = 0; temp > 0; temp_hex++, temp /= 16 )
            ;
        if ( temp_hex > hexs )
            hexs = temp_hex;
    }

    // Four column output, unless it will not fit.
    if ( ( ( 6 + hexs + 2 + decimals + 4 ) * 4 ) > 80 )
        columns = 2;

#endif // 80 column test

    for( i = 0; i < max_reg; i++ )
    {
        as_int = registers[ i ];

        cout << "R" << setw( 2 ) << setfill( '0' ) << i
             << "=0x" << setw( hexs ) << hex  << registers[ i ] 
             << " (" << setw( decimals ) << setfill( ' ' ) 
             << dec << as_int << ") ";
        if ( ( ( i + 1 ) % columns ) == 0 )
            cout << "\n";
    }    
}

/* ===========================================================================

sr_command

Set a register to a value.

Inputs:  reg - the register to set (complain for register zero)
val - what to put in there
Outputs: none, but the register set is changed
Returns: None

Revisions: A register of -1 is the program counter.
=========================================================================== */

void sr_command( const int reg, const int val )
{
    if ( ( reg           ) &&
         ( reg < max_reg ) )
    {
        if ( reg == -1 )
        {
            cout << "Setting program counter to " << val << endl;
            pc = val;
        }
        else
        {
            cout << "Setting register R" << dec << reg << "\n";
            registers[ reg ] = val;
        }
        dr_command();
    }
    else
        cout << "Register value R" << reg << " to set is out of range.\n";
}

/* ===========================================================================

stack_command

Display a stack trace. It'd be nice, for CS4700, to know what the
frame format on the stack is. For now, just show us a few words back
in memory.

Inputs:  None; but we look at R15
Outputs: None
Returns: None

=========================================================================== */

void stack_command()
{
    // Remember, the stack pointer is decremented when pushing
    // (like a return address)

    FOUR_BYTE stack = (memory_mask & registers[ 15 ]);
    FOUR_BYTE above = stack + 16;

    if ( above > memory_mask )
        above = memory_mask;

    while ( stack <= above )
    {
        cout << "0x" << setw( 6 ) << setfill( '0' )
             << hex  << above << " - ";
        cout << "0x" << hex  << setw( 2 ) << setfill( '0' ) 
             << ( ram_image[ above ] & 0xff )
             << " (" << setw( 3 ) << dec << setfill( ' ' ) 
             << ( ram_image[ above ] & 0xff )
             << " decimal)";
        // Don't change this or you may get an infinite loop because they are unsigned.
        if ( stack == above )
        {
            cout << " <-- R15" << endl;
            break;
        }
        else
        {
            cout << endl;
            above--;
        }
    }

    #if 0
    cout << "R15 ->   0x" << hex  << setw( 4 ) << setfill( '0' ) 
         << (FOUR_BYTE) ( ram_image[ stack ] & 0xff )
         << " (" << setw( 3 ) << dec << setfill( ' ' )
         << (int) ( ram_image[ stack ] & 0xff )
         << " decimal) at address 0x"
         << setw( 4 ) << hex 
         << ( registers[ 15 ] & memory_mask ) << "\n";
    #endif
}

/* ===========================================================================

do_step

This is the "guts" here. We execute one instruction, then return. We
return true if everything is OK, or false if the simulation is
over. The latter happens when we execute a HCF.

Inputs:  None; as usual, we hit a buttload o' globals
Outputs: None; registers and RAM might change
Returns: true if everything is OK, else false

=========================================================================== */

bool do_step( void )
{
    bool                 ret = true;
    bool                 a_neg, b_neg, r_neg;
    char                 *p, buf[ 32 ];
    int                  as_int;
    TWO_BYTE             R1, R2, R3;
    TWO_BYTE             &condition = R1; // Same variable via reference
    FOUR_BYTE            address;
    FOUR_BYTE            short_const, long_const, temp, result, temp_r3;
    static unsigned long steps = 1;
    static bool          halted = false;
    bool                 temp_zero_flag, temp_carry_flag;
    bool                 temp_overflow_flag, temp_sign_flag;
    bool                 pc_select = false; // True if pc is calculated in the instruction.

    steps++;
    if ( steps > maxsim )
    {
        cout << "Instruction limit of " << dec << maxsim << " exceeded...\n";
        cout << "The CPU is currently halted. You need to re-start\n"
             << "the simulator to execute instructions.\n";
        return( false );
    }   

    // Check to see if we are a pipeline processor, in which case
    // handle it. In the simpler CPU we just go get the instruction,
    // no big deal.

    if ( execute_pipeline )
    {
        // The instruction we're going to actually DO is in the
        // execute stage.  We have the variable "instruction" by
        // reference to pipeline[2].front_2, so we're done.
        // cout << "Fetching from " << hex << pc << endl;
        pipeline[ 0 ].front_2 = ( ram_image[ pc ] << 8 ) | ram_image[ pc + 1 ];
        pipeline[ 0 ].back_2  = ( ram_image[ pc + 2 ] << 8 ) | ram_image[ pc + 3 ];
        // Need to be careful to cast them to four bytes first, or G++
        // shifts them off the end of the 16-bit quantity and you get 0.
        address = ( (FOUR_BYTE) ( pipeline[ 2 ].front_2 & 0x00ff ) ) << 16 |
                  ( (FOUR_BYTE) pipeline[ 2 ].back_2 );
    }
    else
    {
        // No pipeline, so simple fetch/decode/execute in one cycle.
        instruction = ( ram_image[ pc ] << 8 ) | ram_image[ pc + 1 ];
        address = ( (FOUR_BYTE) ram_image[ pc + 1 ] << 16 ) |
                  ( (FOUR_BYTE) ram_image[ pc + 2 ] << 8 ) | 
                    (FOUR_BYTE) ram_image[ pc + 3 ];
    }

    // We pretty much decode everything, whether we need to or not.
    R1 = decode_R1( instruction );
    R2 = decode_R2( instruction );
    R3 = decode_R3( instruction );

    // Sign extend the short constant
    short_const = instruction & 0x00ff;
    if ( short_const & 0x0080 )
        short_const |= 0xffffff00;

    // Sign extend the long constant
    long_const = address;
    if ( long_const & 0x800000 )
        long_const |= 0xff000000;

    switch( instruction & INSTRUCTION_MASK )
    {
        case SYSCALL_OP: // SYSCALL - checked
            // If there is a register, print it; else we stop the simulation
            if ( R1 )
            {
                switch( registers[ R1 ] )
                {
                    case 1: // Print the number in R2
                        as_int = (int) registers[ R2 ];
                        cout << "R" << R2 << " = 0x" << hex 
                             << setw( 8 ) << setfill( '0' )
                             << registers[ R2 ] << dec << " (" << setw( 6 ) << setfill( ' ' )
                             << as_int << ")\n";
                        break;
                    case 2: // print the string at the address in R2
                        // I do hope they remembered the null on that thing...
                        p = (char *) ram_image + registers[ R2 ];
                        cout << p << '\n'; // We add on a newline for them
                        break;
                    case 3: // read a number into register R2
                        cout << "Enter an integer for register R" << R2 << ": ";
                        cin >> buf;
                        temp = (FOUR_BYTE) strtol( buf, NULL, 0 );
                        cout << "R" << R2 << " = 0x"
                             << setfill( '0' ) << hex  << setw( 8 ) << temp 
                             << " (" << setw( 6 ) << setfill( ' ' ) 
                             << dec << (int) temp << ")\n";
                        registers[ R2 ] = temp;
                        break;
                    default:
                        cout << "Invalid register contents on SYSCALL instruction... Halted.\n";
                        halted = true;
                        pc -= 2;
                        break;
                }
            }
            else
            {
                cout << "Last instruction was SYSCALL R0 at 0x"
                     << hex  << pc << " - halted.\n";
                halted = true;
                ret = false; // Done!
            }
            break;

        case RETURN_OP: // RETURN - checked
            pc = ( ram_image[ ( registers[ 15 ] & memory_mask ) + 0 ] << 24 ) |
                 ( ram_image[ ( registers[ 15 ] & memory_mask ) + 1 ] << 16 ) |
                 ( ram_image[ ( registers[ 15 ] & memory_mask ) + 2 ] << 8 ) |
                 ( ram_image[ ( registers[ 15 ] & memory_mask ) + 3 ] );
            registers[ 15 ] += 4;
            pc_select = true;
            break;

        case MUL_OP: // MUL - checked
            result = registers[ R2 ] * registers[ R3 ];
            temp_zero_flag = ( result == 0 );
            temp_carry_flag = 0;
#if 1   // G++ 64-bit integer support? Then we can set overflow properly
            EIGHT_BYTE product;
            product = (unsigned long long) registers[ R2 ] *
              (unsigned long long ) registers[ R3 ];
            product >>= int_bits;
            temp_overflow_flag = ( product != 0 );
#else   // Set it in a round-about way... Somebody want to volunteer to write this?
            temp_overflow_flag = 0;
#endif
            temp_sign_flag = ( result & sign_bit ) != 0;
            if ( R1 )
                registers[ R1 ] = result;
            break;

        case DIV_OP: // DIV - checked
            FOUR_BYTE l, r;
            if ( registers[ R2 ] & sign_bit )
                l = ( registers[ R2 ] ^ all_ones ) + 1;
            else
                l = registers[ R2 ];
            if ( registers[ R3 ] & sign_bit )
                r = ( registers[ R3 ] ^ all_ones ) + 1;
            else
                r = registers[ R3 ];
            if ( r == 0 )
            {
                result = all_ones;
                temp_overflow_flag = 1;
            }
            else
            {
                result = l / r;
                temp_overflow_flag = 0;
            }

            if ( ( registers[ R2 ] & sign_bit ) != ( registers[ R3 ] & sign_bit ) )
                result = ( result ^ all_ones ) + 1;

            temp_zero_flag = ( result == 0 );
            temp_carry_flag = 0;
            temp_sign_flag = ( result & sign_bit ) != 0;
            if ( R1 )
                registers[ R1 ] = result;
            break;

        case ADD_OP: // ADD - checked
        case SUB_OP: // SUB - checked
            if ( ( instruction & 0xf000 ) == 0x5000 )
                // Form 2's complement of second operand
                temp_r3 = ( registers[ R3 ] ^ all_ones ) + 1;
            else
                temp_r3 = registers[ R3 ];
            a_neg = ( registers[ R2 ] & sign_bit ) != 0; // Set first sign
            b_neg = ( temp_r3 & sign_bit ) != 0;         // Set second sign
            result = registers[ R2 ] + temp_r3;
            r_neg = ( result & sign_bit ) != 0;
            temp_zero_flag = ( result == 0 );

#if 1   // You can use this if you have a G++ compiler that supports 64-bit int's
            EIGHT_BYTE carry_check;
            carry_check = (unsigned long long ) registers[ R2 ] + 
              (unsigned long long ) temp_r3;
            carry_check &= 0x100000000LL;
            temp_carry_flag = ( carry_check & 0x100000000LL ) != 0;
#else   // No trickery, but a bit more complicated. NEED TO RE-TEST THIS.
            FOUR_BYTE carry_in = ( ( registers[ R2 ] & big_signed ) +
                                   ( temp_r3 & big_signed ) ) >> ( int_bits - 1 );
            FOUR_BYTE msb_R2 = ( registers[ R2 ] & ~big_signed ) >> ( int_bits - 1 );
            FOUR_BYTE msb_R3 = ( temp_r3 & ~big_signed ) >> ( int_bits - 1 );
            FOUR_BYTE carry_out = carry_in + msb_R2 + msb_R3;
            temp_carry_flag = ( carry_out & 0x02 );
#endif
                
            // If it is a subtract, the carry flag is opposite
            if ( ( instruction & 0xf000 ) == 0x5000 )
                temp_carry_flag = ! temp_carry_flag;
            
            temp_overflow_flag = ( a_neg == b_neg ) && ( a_neg != r_neg );
            temp_sign_flag = ( result & sign_bit ) != 0;

            if ( R1 )
                registers[ R1 ] = result & all_ones;
            break;

        case AND_OP: // AND 
            result = registers[ R2 ] & registers[ R3 ];
            temp_zero_flag = ( result == 0 );
            temp_carry_flag = 0;
            temp_overflow_flag = 0;
            temp_sign_flag = ( result & sign_bit ) != 0;
            if ( R1 )
                registers[ R1 ] = result & all_ones;
            break;

        case OR_OP: // OR
            result = registers[ R2 ] | registers[ R3 ];
            temp_zero_flag = ( result == 0 );
            temp_carry_flag = 0;
            temp_overflow_flag = 0;
            temp_sign_flag = ( result & sign_bit ) != 0;
            if ( R1 )
                registers[ R1 ] = result & all_ones;
            break;

        case XOR_OP: // XOR
            result = registers[ R2 ] ^ registers[ R3 ];
            temp_zero_flag = ( result == 0 );
            temp_carry_flag = 0;
            temp_overflow_flag = 0;
            temp_sign_flag = ( result & sign_bit ) != 0;
            if ( R1 )
                registers[ R1 ] = result & all_ones;
            break;

        case LSC_OP: // LSC - checked
            if ( R1 )
                registers[ R1 ] = short_const;
            break;

        case LDI_OP: // LDI - checked
            address = registers[ R2 ] + registers[ R3 ];
            if ( R1 )
                registers[ R1 ] = ( ram_image[ ( address + 0 ) & memory_mask ] << 24 ) |
                                  ( ram_image[ ( address + 1 ) & memory_mask ] << 16 ) |
                                  ( ram_image[ ( address + 2 ) & memory_mask ] << 8 ) |
                                  ( ram_image[ ( address + 3 ) & memory_mask ] );
            break;

        case STI_OP: // STI - checked
            address = registers[ R2 ] + registers[ R3 ];
            ram_image[ ( address + 0 ) & memory_mask ] = ( registers[ R1 ] & 0xff000000 ) >> 24;
            ram_image[ ( address + 1 ) & memory_mask ] = ( registers[ R1 ] & 0x00ff0000 ) >> 16;
            ram_image[ ( address + 2 ) & memory_mask ] = ( registers[ R1 ] & 0x0000ff00 ) >> 8;
            ram_image[ ( address + 3 ) & memory_mask ] = ( registers[ R1 ] & 0x000000ff );
            break;

        case LOAD_OP: // LOAD - checked
            if ( R1 )
                registers[ R1 ] = ( ram_image[ ( address + 0 ) & memory_mask ] << 24 ) |
                                  ( ram_image[ ( address + 1 ) & memory_mask ] << 16 ) |
                                  ( ram_image[ ( address + 2 ) & memory_mask ] << 8 ) |
                                  ( ram_image[ ( address + 3 ) & memory_mask ] );
            break;

        case STORE_OP: // STORE - checked
            ram_image[ ( address + 0 ) & memory_mask ] = ( registers[ R1 ] & 0xff000000 ) >> 24;
            ram_image[ ( address + 1 ) & memory_mask ] = ( registers[ R1 ] & 0x00ff0000 ) >> 16;
            ram_image[ ( address + 2 ) & memory_mask ] = ( registers[ R1 ] & 0x0000ff00 ) >> 8;
            ram_image[ ( address + 3 ) & memory_mask ] = ( registers[ R1 ] & 0x000000ff );
            break;

        case LLC_OP: // LLC - checked
            if ( R1 )
                registers[ R1 ] = long_const;
            break;

        case JUMP_OP: // JUMP or CALL - checked
            if ( condition == 0x01 )
            {
                // It is a call instruction. In the case of a pipeline
                // machine, by the time we execute the call the PC has
                // already been updated.
                if ( ! execute_pipeline ) 
                    pc += 4; // Increment PC first, then push it.
                // cout << "The call pushed pc=" << hex << pc << endl;
                registers[ 15 ] -= 4;
                ram_image[ ( registers[ 15 ] + 0 ) & memory_mask ] = ( pc & 0xff000000 ) >> 24; // Always zero, but ...
                ram_image[ ( registers[ 15 ] + 1 ) & memory_mask ] = ( pc & 0x00ff0000 ) >> 16;
                ram_image[ ( registers[ 15 ] + 2 ) & memory_mask ] = ( pc & 0x0000ff00 ) >> 8;
                ram_image[ ( registers[ 15 ] + 3 ) & memory_mask ] = ( pc & 0x000000ff );
                pc = address; // Poof! Off we go.
                pc_select = true;
            }
            else
                // It is a jump instruction
                if ( match_flags( condition ) )
                {
                    pc = address & memory_mask;
                    pc_select = true;
                }
            break;
    }

    // Special case - A math instruction {ADD, SUB, MUL, DIV, XOR,
    // AND, OR} with R1, R2, and R3 all zero says we do not set
    // flags. This is necessary on a pipelined machine in order to do
    // a true "no-operation" instruction, for example in between jump
    // instructions where you may have to add delays.

    if ( ( ( ( instruction & INSTRUCTION_MASK ) == MUL_OP ) ||
           ( ( instruction & INSTRUCTION_MASK ) == DIV_OP ) ||
           ( ( instruction & INSTRUCTION_MASK ) == ADD_OP ) ||
           ( ( instruction & INSTRUCTION_MASK ) == SUB_OP ) ||
           ( ( instruction & INSTRUCTION_MASK ) == AND_OP ) ||
           ( ( instruction & INSTRUCTION_MASK ) == OR_OP  ) ||
           ( ( instruction & INSTRUCTION_MASK ) == XOR_OP ) ) &&
         ( ( R1 != 0 ) || ( R2 != 0 ) || ( R3 != 0 ) ) )
    {
        zero_flag = temp_zero_flag;
        carry_flag = temp_carry_flag;
        overflow_flag = temp_overflow_flag;
        sign_flag = temp_sign_flag;
    }

    // OK, now the fetch cycle gets the next instruction. This is a
    // bit messy because what we want to do in interactive mode is to
    // show the pipeline <before> the execute stage actually
    // happens. But if the execute stage holds a jump, we need to
    // decide here whether that jump will be taken in the next cycle,
    // so that we can fetch the correct instruction in this cycle. A
    // real machine doesn't exhibit this problem because on the next
    // clock it'll fetch whatever the execute stage tells it to. But
    // since we want the user to see the pipeline <in advance> we have
    // to know before the next cycle what's actually going to happen.

    if ( execute_pipeline )
    {
        if ( pc_select )
        {
            // cout << "overriding the fetch with something else" << endl;
            pipeline[ 0 ].front_2 = ( ram_image[ pc ] << 8 ) | ram_image[ pc + 1 ];
            pipeline[ 0 ].back_2  = ( ram_image[ pc + 2 ] << 8 ) | ram_image[ pc + 3 ];
        }

        // Let's add in the cycles before we blow away the instruction
        // we just executed.

        clock_cycles += 1 + stalls();

        #if 0
        cout << "Pipeline before: ";
        for( int i = 0; i < 3; i++ )
            cout << hex << pipeline[ i ].front_2 << ' ';
        cout << endl << endl;
        #endif

        // Execute stage gets the decode stage
        pipeline[ 2 ].front_2 = pipeline[ 1 ].front_2;
        pipeline[ 2 ].back_2 = pipeline[ 1 ].back_2;

        // Decode gets the fetch stage
        pipeline[ 1 ].front_2 = pipeline[ 0 ].front_2;
        pipeline[ 1 ].back_2 = pipeline[ 0 ].back_2;

        // Fetch stage was set up before. 
        pc += PC_INCREMENT( pipeline[ 0 ].front_2 );

        #if 0
        cout << "Pipeline after: ";
        for( int i = 0; i < 3; i++ )
            cout << hex << pipeline[ i ].front_2 << ' ';
        cout << endl << endl;
        #endif
    }
    else
    {
        // Non-pipeline, so if pc_select is false just add the
        // appropriate amount.
        if ( ! pc_select )
            pc += PC_INCREMENT( instruction );
        clock_cycles += 3; // Each instruction in the non-pipeline is 3 clocks.
    }

    return( ret );
}

/* ===========================================================================

stalls

In a plain CPU we just add one clock cycle per instruction. In a
pipeline we have to factor in the pipeline stalls because of the data
hazards. So here we return the number of cycles to add in.

Inputs:  None, but we look at the pipeline contents.
Outputs: none
Returns: the number of clock cycles "executed" in this instruction.

=========================================================================== */

int stalls()
{
    // Doing something that generates a result register in the execute stage?
    bool exec = 
      ( ( pipeline[ 2 ].front_2 & INSTRUCTION_MASK ) == MUL_OP  ) ||
      ( ( pipeline[ 2 ].front_2 & INSTRUCTION_MASK ) == DIV_OP  ) ||
      ( ( pipeline[ 2 ].front_2 & INSTRUCTION_MASK ) == ADD_OP  ) ||
      ( ( pipeline[ 2 ].front_2 & INSTRUCTION_MASK ) == SUB_OP  ) ||
      ( ( pipeline[ 2 ].front_2 & INSTRUCTION_MASK ) == AND_OP  ) ||
      ( ( pipeline[ 2 ].front_2 & INSTRUCTION_MASK ) == OR_OP   ) ||
      ( ( pipeline[ 2 ].front_2 & INSTRUCTION_MASK ) == XOR_OP  ) ||
      ( ( pipeline[ 2 ].front_2 & INSTRUCTION_MASK ) == LSC_OP  ) ||
      ( ( pipeline[ 2 ].front_2 & INSTRUCTION_MASK ) == LDI_OP  ) ||
      ( ( pipeline[ 2 ].front_2 & INSTRUCTION_MASK ) == LOAD_OP ) ||
      ( ( pipeline[ 2 ].front_2 & INSTRUCTION_MASK ) == LLC_OP  );

    // Doing something requiring an operand in the decode stage?
    bool deco = 
      ( ( pipeline[ 1 ].front_2 & INSTRUCTION_MASK ) == MUL_OP ) ||
      ( ( pipeline[ 1 ].front_2 & INSTRUCTION_MASK ) == DIV_OP ) ||
      ( ( pipeline[ 1 ].front_2 & INSTRUCTION_MASK ) == ADD_OP ) ||
      ( ( pipeline[ 1 ].front_2 & INSTRUCTION_MASK ) == SUB_OP ) ||
      ( ( pipeline[ 1 ].front_2 & INSTRUCTION_MASK ) == AND_OP ) ||
      ( ( pipeline[ 1 ].front_2 & INSTRUCTION_MASK ) == OR_OP  ) ||
      ( ( pipeline[ 1 ].front_2 & INSTRUCTION_MASK ) == XOR_OP ) ||
      ( ( pipeline[ 1 ].front_2 & INSTRUCTION_MASK ) == LDI_OP ) ||
      ( ( pipeline[ 1 ].front_2 & INSTRUCTION_MASK ) == STI_OP );

    if ( exec && deco )
    {
        BYTE result =    ( pipeline[ 2 ].front_2 & 0x0f00 ) >> 8;
        BYTE operand_1 = ( pipeline[ 1 ].front_2 & 0x00f0 ) >> 4;
        BYTE operand_2 = ( pipeline[ 1 ].front_2 & 0x000f );
        // A result register of zero does not cost you, of course.
        if ( result && ( operand_1 == result || operand_2 == result ) )
        {
            #if 0
            cout << "This is a stall - R" << ( (int) result )
                 << " used in next instruction, at about PC=0x" 
                 << hex << setw( 4 ) << setfill( '0' ) << pc
                 << " instruction 0x" << hex << setw( 4 ) << setfill( '0' ) << pipeline[ 1 ].front_2
                 << " depends on 0x"  << hex << setw( 4 ) << setfill( '0' ) << pipeline[ 2 ].front_2 
                 << endl;
            #endif
            return( 1 );
        }
    }
    return( 0 );
}


/* ===========================================================================

match_flags

See if the flags (zero, etc) match the condition passed in. See the
documentation for which bit combination matches what flags - once
again I have used magic numbers all over the damn place which I really
shouldn't, but it's late...

Inputs:  cond - the condition portion of the instruction (the R1 field)
Outputs: none
Returns: true if we should do the jump/call, else false

=========================================================================== */

static bool match_flags( TWO_BYTE cond )
{
    switch( cond << FLAG_SHIFT )
    {
        case 0x00: // always jump
            return( true );
        case SLT_FLAG: // SLT; jump if sign != overflow
            return( sign_flag != overflow_flag );
        case SLE_FLAG: // SLE; jump if sign != overflow or zero
            return( ( sign_flag != overflow_flag ) || ( zero_flag ) );
        case ULT_FLAG: // ULT; jump if carry flag is set
            return( carry_flag );
        case ULE_FLAG: // ULE; jump if carry flag or zero flag
            return( carry_flag || zero_flag );
        case EQ_FLAG: // EQ; jump if zero set
            return( zero_flag );
        case NE_FLAG: // NE; jump of zero not set
            return( ! zero_flag );
        case P_FLAG: // P; jump if sign bit not set
            return( ! sign_flag );
        case N_FLAG: // N; jump if sign bit set
            return( sign_flag );
        case OV_FLAG: // OV; jump if overflow is set
            return( overflow_flag );
        default: // throw an illegal instruction trap?!
            cout << "Illegal instruction (unknown jump/call condition)\n";
            return( false );
    }
}

/* ===========================================================================

show_source

Display source line, used by show_next and list

=========================================================================== */

void show_source(ASM_SOURCE_PTR p)
{
    cout << "Line " << dec << p->line_num
         << hex 
         << " [0x" << setw( 4 ) << setfill( '0' ) << p->pc
         << "]: " << p->source << endl;
}

/* ===========================================================================

show_next

Print out what the next instruction is.  There's some lingering
hard-coded instruction opcodes in here that need to be fixed some
day. Maybe the next version...

=========================================================================== */

static void show_flags()
{
    char flags[ 5 ];
    flags[ 0 ] = zero_flag ? 'Z' : 'z';
    flags[ 1 ] = carry_flag ? 'C' : 'c';
    flags[ 2 ] = overflow_flag ? 'O' : 'o';
    flags[ 3 ] = sign_flag ? 'N' : 'n';
    flags[ 4 ] = '\0';
    cout << "Flags=" << flags;
}

static void show_one( TWO_BYTE inst, TWO_BYTE addr )
{
    static char *inst_decode[] = { 
      "SYSCALL",  // 0
      "RETURN",   // 1
      "MUL",      // 2
      "DIV",      // 3
      "ADD",      // 4
      "SUB",      // 5
      "AND",      // 6
      "OR",       // 7
      "XOR",      // 8
      "LSC",      // 9
      "LDI",      // 10
      "STI",      // 11
      "LOAD",     // 12
      "STORE",    // 13
      "LLC",      // 14
      "JUMP",     // 15
      "CALL"      // 15 special case...
    };

    BYTE op = ( inst & INSTRUCTION_MASK ) >> INSTRUCTION_SHIFT;
    BYTE flag_field = ( inst & FLAG_MASK ) >> FLAG_SHIFT;

    if ( op >= 0x0c )
    {
        // Check to see if it is really a "call" and if so, bump up
        // the subscript into the above string table.
        if ( op == 0x0f && flag_field == 0x01 )
            op++;
        cout << hex 
             << "Inst 0x" << setw( 4 ) << setfill( '0' ) << inst << setw( 4 ) << addr 
             << " (" << inst_decode[ op ] << ")";
    }
    else
        cout << hex 
             << "Inst 0x" << setw( 4 ) << setfill( '0' ) << inst << " (" 
             << inst_decode[ op ] << ")";
}

void show_next( void )
{
    TWO_BYTE inst, addr;

    cout << "Next instruction (not executed yet):" << endl;
    if ( ! execute_pipeline )
    {
        // Plain old CPU
        inst = ( ram_image[ pc ] << 8 ) | ram_image[ pc + 1 ];
        addr = ( ram_image[ pc + 2 ] << 8 ) | ram_image[ pc + 3 ];

        ASM_SOURCE_PTR p;
        if ((pc >= 0) && (pc <= ram_image_size)
            && ((p = asm_source_by_pc[pc]) != NULL))
            show_source(p);
        else
            show_one( inst, addr );

        show_flags();
        cout << endl;
    }
    else
    {

        inst = pipeline[ 0 ].front_2;
        addr = pipeline[ 0 ].back_2;

        // Show source line
        cout << "About to fetch: ";
        ASM_SOURCE_PTR p;
        if ((pc >= 0) && (pc <= ram_image_size)
            && ((p = asm_source_by_pc[pc]) != NULL))
            show_source(p);
        else
        {
            show_one( inst, addr );
            cout << endl;
        }

        inst = pipeline[ 1 ].front_2;
        addr = pipeline[ 1 ].back_2;
        cout << "About to decode: ";
        show_one( inst, addr );

        cout << endl;
        cout << "About to execute: ";
        inst = pipeline[ 2 ].front_2;
        addr = pipeline[ 2 ].back_2;
        show_one( inst, addr );
        show_flags();
        cout << endl;
    }
    
    dr_command();

}

/* ===========================================================================

do_list

Interpret LIST command; display next lines of source code

=========================================================================== */

void do_list( int list_count )
{
    static int last_line_was = 0;
    static FOUR_BYTE last_pc_was = 0xffffffff;
    ASM_SOURCE_PTR p;
    if ((pc >= 0) && (pc <= ram_image_size)
        && ((p = asm_source_by_pc[pc]) != NULL))
    {
        int i, endline, line;
        if ((last_pc_was == pc) && (last_line_was != 0))
            line = last_line_was;
        else
            line = p->line_num;
        endline = line + ((list_count > 0) ? list_count : 4) - 1;
        if (endline > asm_source_line_count)
            endline = asm_source_line_count;
        for (i = line; i <= endline; i++)
            show_source( asm_source_lines[i] );
        last_line_was = endline;
        last_pc_was = pc;
    }
    else
        cout << "No source code available for this location" << endl;
}

