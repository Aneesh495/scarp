/*
 * dis_vm.h: Dis Virtual Machine and Bytecode Runtime Engine for Limbo
 *
 * Implements the Dis virtual machine memory model, instruction decoder,
 * cooperative thread scheduler, and Communicating Sequential Processes (CSP)
 * channel communication primitives.
 */

#ifndef SCARP_DIS_VM_H
#define SCARP_DIS_VM_H

#include <stdint.h>
#include <stddef.h>
#include <stdbool.h>
#include <pthread.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Dis Opcode Enumeration */
typedef enum {
    DIS_OP_NOP        = 0x00,
    DIS_OP_ADDW       = 0x01,
    DIS_OP_SUBW       = 0x02,
    DIS_OP_MULW       = 0x03,
    DIS_OP_DIVW       = 0x04,
    DIS_OP_MODW       = 0x05,
    DIS_OP_ADDF       = 0x06,
    DIS_OP_SUBF       = 0x07,
    DIS_OP_MULF       = 0x08,
    DIS_OP_DIVF       = 0x09,
    DIS_OP_MOVW       = 0x0A,
    DIS_OP_MOVF       = 0x0B,
    DIS_OP_MOVB       = 0x0C,
    DIS_OP_JMP        = 0x10,
    DIS_OP_BEQW       = 0x11,
    DIS_OP_BNEW       = 0x12,
    DIS_OP_BLTW       = 0x13,
    DIS_OP_BLEW       = 0x14,
    DIS_OP_BGTW       = 0x15,
    DIS_OP_BGEW       = 0x16,
    DIS_OP_BEQF       = 0x17,
    DIS_OP_BLTF       = 0x18,
    DIS_OP_BGTF       = 0x19,
    DIS_OP_CALL       = 0x20,
    DIS_OP_RET        = 0x21,
    DIS_OP_SPAWN      = 0x22,
    DIS_OP_EXIT       = 0x23,
    DIS_OP_NEW        = 0x30,
    DIS_OP_NEWZ       = 0x31,
    DIS_OP_NEWARRAY   = 0x32,
    DIS_OP_CHAN       = 0x33,
    DIS_OP_SEND       = 0x34,
    DIS_OP_RECV       = 0x35,
    DIS_OP_ALT        = 0x36,
    DIS_OP_HALT       = 0xFF
} DisOpcode;

/* Dis Addressing Modes */
typedef enum {
    DIS_ADDR_NONE      = 0,
    DIS_ADDR_IMM       = 1,
    DIS_ADDR_FRAME     = 2,
    DIS_ADDR_REG       = 3,
    DIS_ADDR_INDIRECT  = 4
} DisAddrMode;

/* 3-Address Operand Descriptor */
typedef struct {
    DisAddrMode mode;
    int32_t     offset;
    double      imm_float;
    int64_t     imm_int;
} DisOperand;

/* Dis Bytecode Instruction */
typedef struct {
    DisOpcode   op;
    DisOperand  src1;
    DisOperand  src2;
    DisOperand  dst;
} DisInstr;

/* Limbo Value Container */
typedef union {
    int32_t     w;
    int64_t     b;
    double      f;
    void*       ptr;
} DisValue;

/* Limbo Channel Control Block */
typedef struct DisChannel {
    pthread_mutex_t lock;
    pthread_cond_t  cond_send;
    pthread_cond_t  cond_recv;
    size_t          elem_size;
    size_t          capacity;
    size_t          head;
    size_t          tail;
    size_t          count;
    uint8_t*        buffer;
    bool            closed;
} DisChannel;

/* Dis Call Stack Frame */
typedef struct DisFrame {
    struct DisFrame* prev;
    uint32_t         ret_pc;
    size_t           frame_size;
    uint8_t*         locals;
} DisFrame;

/* Dis Thread / Process (Fiber) State */
typedef enum {
    THREAD_READY,
    THREAD_RUNNING,
    THREAD_BLOCKED_SEND,
    THREAD_BLOCKED_RECV,
    THREAD_TERMINATED
} DisThreadState;

typedef struct DisThread {
    uint32_t          thread_id;
    DisThreadState    state;
    uint32_t          pc;
    DisFrame*         top_frame;
    DisChannel*       blocked_chan;
    struct DisThread* next;
} DisThread;

/* Dis Virtual Machine Instance */
typedef struct DisVM {
    DisInstr*         code;
    size_t            code_len;
    size_t            code_cap;
    DisThread*        thread_head;
    DisThread*        current_thread;
    uint32_t          next_thread_id;
    uint64_t          cycle_counter;
    bool              running;
    uint8_t           global_mem[65536];
} DisVM;

/* Limbo Channel Alt Operation Descriptor */
typedef enum {
    DIS_ALT_RECV = 0,
    DIS_ALT_SEND = 1
} DisAltOp;

typedef struct {
    DisChannel* chan;
    DisAltOp    op;
    void*       data_ptr;
    bool        ready;
} DisAltCase;

/* Virtual Machine API */
DisVM*       dis_vm_create(void);
void         dis_vm_destroy(DisVM* vm);
int          dis_vm_load_code(DisVM* vm, const DisInstr* instructions, size_t count);
DisThread*   dis_vm_spawn_thread(DisVM* vm, uint32_t start_pc, size_t frame_size);
size_t       dis_vm_thread_count(const DisVM* vm);
size_t       dis_vm_active_thread_count(const DisVM* vm);
int          dis_vm_step(DisVM* vm);
int          dis_vm_run(DisVM* vm, uint64_t max_cycles);
uint64_t     dis_vm_cycle_count(const DisVM* vm);

/* Channel API */
DisChannel*  dis_chan_create(size_t elem_size, size_t capacity);
void         dis_chan_destroy(DisChannel* ch);
int          dis_chan_send(DisChannel* ch, const void* data, bool nonblocking);
int          dis_chan_recv(DisChannel* ch, void* out_data, bool nonblocking);
int          dis_chan_alt(DisAltCase* cases, size_t ncases, bool nonblocking);
void         dis_chan_close(DisChannel* ch);

#ifdef __cplusplus
}
#endif

#endif /* SCARP_DIS_VM_H */
