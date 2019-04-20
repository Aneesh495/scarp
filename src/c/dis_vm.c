/*
 * dis_vm.c: Implementation of the Dis Virtual Machine Engine
 *
 * Implements bytecode execution, cooperative multi-threading,
 * and CSP channel synchronization for Limbo programs.
 */

#include "dis_vm.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

DisVM* dis_vm_create(void) {
    DisVM* vm = (DisVM*)calloc(1, sizeof(DisVM));
    if (!vm) return NULL;
    vm->code_cap = 1024;
    vm->code = (DisInstr*)malloc(vm->code_cap * sizeof(DisInstr));
    vm->next_thread_id = 1;
    vm->running = false;
    return vm;
}

void dis_vm_destroy(DisVM* vm) {
    if (!vm) return;
    DisThread* curr = vm->thread_head;
    while (curr) {
        DisThread* nxt = curr->next;
        DisFrame* f = curr->top_frame;
        while (f) {
            DisFrame* pf = f->prev;
            if (f->locals) free(f->locals);
            free(f);
            f = pf;
        }
        free(curr);
        curr = nxt;
    }
    if (vm->code) free(vm->code);
    free(vm);
}

int dis_vm_load_code(DisVM* vm, const DisInstr* instructions, size_t count) {
    if (!vm || !instructions) return -1;
    if (count > vm->code_cap) {
        DisInstr* ncode = (DisInstr*)realloc(vm->code, count * sizeof(DisInstr));
        if (!ncode) return -1;
        vm->code = ncode;
        vm->code_cap = count;
    }
    memcpy(vm->code, instructions, count * sizeof(DisInstr));
    vm->code_len = count;
    return 0;
}

DisThread* dis_vm_spawn_thread(DisVM* vm, uint32_t start_pc, size_t frame_size) {
    if (!vm) return NULL;
    DisThread* t = (DisThread*)calloc(1, sizeof(DisThread));
    if (!t) return NULL;
    t->thread_id = vm->next_thread_id++;
    t->state = THREAD_READY;
    t->pc = start_pc;

    DisFrame* frame = (DisFrame*)calloc(1, sizeof(DisFrame));
    if (!frame) {
        free(t);
        return NULL;
    }
    frame->frame_size = frame_size > 0 ? frame_size : 256;
    frame->locals = (uint8_t*)calloc(1, frame->frame_size);
    t->top_frame = frame;

    t->next = vm->thread_head;
    vm->thread_head = t;
    return t;
}

size_t dis_vm_thread_count(const DisVM* vm) {
    if (!vm) return 0;
    size_t count = 0;
    DisThread* curr = vm->thread_head;
    while (curr) {
        count++;
        curr = curr->next;
    }
    return count;
}

size_t dis_vm_active_thread_count(const DisVM* vm) {
    if (!vm) return 0;
    size_t count = 0;
    DisThread* curr = vm->thread_head;
    while (curr) {
        if (curr->state == THREAD_READY || curr->state == THREAD_RUNNING) {
            count++;
        }
        curr = curr->next;
    }
    return count;
}

uint64_t dis_vm_cycle_count(const DisVM* vm) {
    return vm ? vm->cycle_counter : 0;
}

static void* resolve_addr(DisVM* vm, DisThread* t, const DisOperand* op) {
    switch (op->mode) {
        case DIS_ADDR_FRAME:
            if (t && t->top_frame && op->offset >= 0 &&
                (size_t)op->offset < t->top_frame->frame_size) {
                return t->top_frame->locals + op->offset;
            }
            return NULL;
        case DIS_ADDR_REG:
            if (op->offset >= 0 && op->offset < (int32_t)sizeof(vm->global_mem)) {
                return vm->global_mem + op->offset;
            }
            return NULL;
        default:
            return NULL;
    }
}

static int32_t read_int32(DisVM* vm, DisThread* t, const DisOperand* op) {
    if (op->mode == DIS_ADDR_IMM) {
        return (int32_t)op->imm_int;
    }
    void* ptr = resolve_addr(vm, t, op);
    if (ptr) {
        int32_t val;
        memcpy(&val, ptr, sizeof(int32_t));
        return val;
    }
    return 0;
}

static void write_int32(DisVM* vm, DisThread* t, const DisOperand* op, int32_t val) {
    void* ptr = resolve_addr(vm, t, op);
    if (ptr) {
        memcpy(ptr, &val, sizeof(int32_t));
    }
}

static double read_float(DisVM* vm, DisThread* t, const DisOperand* op) {
    if (op->mode == DIS_ADDR_IMM) {
        return op->imm_float;
    }
    void* ptr = resolve_addr(vm, t, op);
    if (ptr) {
        double val;
        memcpy(&val, ptr, sizeof(double));
        return val;
    }
    return 0.0;
}

static void write_float(DisVM* vm, DisThread* t, const DisOperand* op, double val) {
    void* ptr = resolve_addr(vm, t, op);
    if (ptr) {
        memcpy(ptr, &val, sizeof(double));
    }
}

int dis_vm_step(DisVM* vm) {
    if (!vm || !vm->thread_head) return 0;

    DisThread* t = vm->current_thread;
    if (!t || t->state != THREAD_RUNNING) {
        t = vm->thread_head;
        while (t && t->state != THREAD_READY) {
            t = t->next;
        }
        if (!t) return 0; /* All threads blocked or terminated */
        t->state = THREAD_RUNNING;
        vm->current_thread = t;
    }

    if (t->pc >= vm->code_len) {
        t->state = THREAD_TERMINATED;
        vm->current_thread = NULL;
        return 1;
    }

    const DisInstr* inst = &vm->code[t->pc++];
    vm->cycle_counter++;

    switch (inst->op) {
        case DIS_OP_NOP:
            break;
        case DIS_OP_ADDW: {
            int32_t a = read_int32(vm, t, &inst->src1);
            int32_t b = read_int32(vm, t, &inst->src2);
            write_int32(vm, t, &inst->dst, a + b);
            break;
        }
        case DIS_OP_SUBW: {
            int32_t a = read_int32(vm, t, &inst->src1);
            int32_t b = read_int32(vm, t, &inst->src2);
            write_int32(vm, t, &inst->dst, a - b);
            break;
        }
        case DIS_OP_MULW: {
            int32_t a = read_int32(vm, t, &inst->src1);
            int32_t b = read_int32(vm, t, &inst->src2);
            write_int32(vm, t, &inst->dst, a * b);
            break;
        }
        case DIS_OP_DIVW: {
            int32_t a = read_int32(vm, t, &inst->src1);
            int32_t b = read_int32(vm, t, &inst->src2);
            write_int32(vm, t, &inst->dst, b != 0 ? a / b : 0);
            break;
        }
        case DIS_OP_MODW: {
            int32_t a = read_int32(vm, t, &inst->src1);
            int32_t b = read_int32(vm, t, &inst->src2);
            write_int32(vm, t, &inst->dst, b != 0 ? a % b : 0);
            break;
        }
        case DIS_OP_ADDF: {
            double a = read_float(vm, t, &inst->src1);
            double b = read_float(vm, t, &inst->src2);
            write_float(vm, t, &inst->dst, a + b);
            break;
        }
        case DIS_OP_SUBF: {
            double a = read_float(vm, t, &inst->src1);
            double b = read_float(vm, t, &inst->src2);
            write_float(vm, t, &inst->dst, a - b);
            break;
        }
        case DIS_OP_MULF: {
            double a = read_float(vm, t, &inst->src1);
            double b = read_float(vm, t, &inst->src2);
            write_float(vm, t, &inst->dst, a * b);
            break;
        }
        case DIS_OP_DIVF: {
            double a = read_float(vm, t, &inst->src1);
            double b = read_float(vm, t, &inst->src2);
            write_float(vm, t, &inst->dst, b != 0.0 ? a / b : 0.0);
            break;
        }
        case DIS_OP_MOVW: {
            int32_t val = read_int32(vm, t, &inst->src1);
            write_int32(vm, t, &inst->dst, val);
            break;
        }
        case DIS_OP_MOVF: {
            double val = read_float(vm, t, &inst->src1);
            write_float(vm, t, &inst->dst, val);
            break;
        }
        case DIS_OP_JMP: {
            t->pc = (uint32_t)inst->dst.imm_int;
            break;
        }
        case DIS_OP_BEQW: {
            int32_t a = read_int32(vm, t, &inst->src1);
            int32_t b = read_int32(vm, t, &inst->src2);
            if (a == b) t->pc = (uint32_t)inst->dst.imm_int;
            break;
        }
        case DIS_OP_BNEW: {
            int32_t a = read_int32(vm, t, &inst->src1);
            int32_t b = read_int32(vm, t, &inst->src2);
            if (a != b) t->pc = (uint32_t)inst->dst.imm_int;
            break;
        }
        case DIS_OP_BLTW: {
            int32_t a = read_int32(vm, t, &inst->src1);
            int32_t b = read_int32(vm, t, &inst->src2);
            if (a < b) t->pc = (uint32_t)inst->dst.imm_int;
            break;
        }
        case DIS_OP_BLEW: {
            int32_t a = read_int32(vm, t, &inst->src1);
            int32_t b = read_int32(vm, t, &inst->src2);
            if (a <= b) t->pc = (uint32_t)inst->dst.imm_int;
            break;
        }
        case DIS_OP_BGTW: {
            int32_t a = read_int32(vm, t, &inst->src1);
            int32_t b = read_int32(vm, t, &inst->src2);
            if (a > b) t->pc = (uint32_t)inst->dst.imm_int;
            break;
        }
        case DIS_OP_BGEW: {
            int32_t a = read_int32(vm, t, &inst->src1);
            int32_t b = read_int32(vm, t, &inst->src2);
            if (a >= b) t->pc = (uint32_t)inst->dst.imm_int;
            break;
        }
        case DIS_OP_CALL: {
            DisFrame* nf = (DisFrame*)calloc(1, sizeof(DisFrame));
            if (nf) {
                nf->frame_size = 256;
                nf->locals = (uint8_t*)calloc(1, 256);
                nf->ret_pc = t->pc;
                nf->prev = t->top_frame;
                t->top_frame = nf;
                t->pc = (uint32_t)inst->dst.imm_int;
            }
            break;
        }
        case DIS_OP_RET: {
            if (t->top_frame && t->top_frame->prev) {
                DisFrame* old = t->top_frame;
                t->pc = old->ret_pc;
                t->top_frame = old->prev;
                if (old->locals) free(old->locals);
                free(old);
            } else {
                t->state = THREAD_TERMINATED;
                vm->current_thread = NULL;
            }
            break;
        }
        case DIS_OP_EXIT:
        case DIS_OP_HALT:
            t->state = THREAD_TERMINATED;
            vm->current_thread = NULL;
            break;
        default:
            break;
    }

    /* Cooperative yield to next thread */
    if (t->state == THREAD_RUNNING) {
        t->state = THREAD_READY;
        vm->current_thread = NULL;
    }
    return 1;
}

int dis_vm_run(DisVM* vm, uint64_t max_cycles) {
    if (!vm) return -1;
    vm->running = true;
    uint64_t cycles = 0;
    while (vm->running && (max_cycles == 0 || cycles < max_cycles)) {
        int res = dis_vm_step(vm);
        if (res == 0) break; /* No runnable threads */
        cycles++;
    }
    vm->running = false;
    return (int)cycles;
}

/* Channel Implementation */
DisChannel* dis_chan_create(size_t elem_size, size_t capacity) {
    DisChannel* ch = (DisChannel*)calloc(1, sizeof(DisChannel));
    if (!ch) return NULL;
    pthread_mutex_init(&ch->lock, NULL);
    pthread_cond_init(&ch->cond_send, NULL);
    pthread_cond_init(&ch->cond_recv, NULL);
    ch->elem_size = elem_size;
    ch->capacity = capacity > 0 ? capacity : 1;
    ch->buffer = (uint8_t*)malloc(ch->elem_size * ch->capacity);
    ch->closed = false;
    return ch;
}

void dis_chan_destroy(DisChannel* ch) {
    if (!ch) return;
    pthread_mutex_lock(&ch->lock);
    ch->closed = true;
    pthread_cond_broadcast(&ch->cond_send);
    pthread_cond_broadcast(&ch->cond_recv);
    pthread_mutex_unlock(&ch->lock);
    pthread_mutex_destroy(&ch->lock);
    pthread_cond_destroy(&ch->cond_send);
    pthread_cond_destroy(&ch->cond_recv);
    if (ch->buffer) free(ch->buffer);
    free(ch);
}

int dis_chan_send(DisChannel* ch, const void* data, bool nonblocking) {
    if (!ch || !data) return -1;
    pthread_mutex_lock(&ch->lock);
    while (ch->count == ch->capacity && !ch->closed) {
        if (nonblocking) {
            pthread_mutex_unlock(&ch->lock);
            return 0; /* Would block */
        }
        pthread_cond_wait(&ch->cond_send, &ch->lock);
    }
    if (ch->closed) {
        pthread_mutex_unlock(&ch->lock);
        return -1;
    }
    memcpy(ch->buffer + (ch->tail * ch->elem_size), data, ch->elem_size);
    ch->tail = (ch->tail + 1) % ch->capacity;
    ch->count++;
    pthread_cond_signal(&ch->cond_recv);
    pthread_mutex_unlock(&ch->lock);
    return 1;
}

int dis_chan_recv(DisChannel* ch, void* out_data, bool nonblocking) {
    if (!ch || !out_data) return -1;
    pthread_mutex_lock(&ch->lock);
    while (ch->count == 0 && !ch->closed) {
        if (nonblocking) {
            pthread_mutex_unlock(&ch->lock);
            return 0; /* Would block */
        }
        pthread_cond_wait(&ch->cond_recv, &ch->lock);
    }
    if (ch->count == 0 && ch->closed) {
        pthread_mutex_unlock(&ch->lock);
        return -1;
    }
    memcpy(out_data, ch->buffer + (ch->head * ch->elem_size), ch->elem_size);
    ch->head = (ch->head + 1) % ch->capacity;
    ch->count--;
    pthread_cond_signal(&ch->cond_send);
    pthread_mutex_unlock(&ch->lock);
    return 1;
}

int dis_chan_alt(DisAltCase* cases, size_t ncases, bool nonblocking) {
    if (!cases || ncases == 0) return -1;

    /* Polling loop */
    while (1) {
        for (size_t i = 0; i < ncases; i++) {
            DisChannel* ch = cases[i].chan;
            if (!ch) continue;

            pthread_mutex_lock(&ch->lock);
            if (cases[i].op == DIS_ALT_RECV) {
                if (ch->count > 0) {
                    memcpy(cases[i].data_ptr, ch->buffer + (ch->head * ch->elem_size), ch->elem_size);
                    ch->head = (ch->head + 1) % ch->capacity;
                    ch->count--;
                    pthread_cond_signal(&ch->cond_send);
                    pthread_mutex_unlock(&ch->lock);
                    return (int)i;
                }
            } else if (cases[i].op == DIS_ALT_SEND) {
                if (ch->count < ch->capacity && !ch->closed) {
                    memcpy(ch->buffer + (ch->tail * ch->elem_size), cases[i].data_ptr, ch->elem_size);
                    ch->tail = (ch->tail + 1) % ch->capacity;
                    ch->count++;
                    pthread_cond_signal(&ch->cond_recv);
                    pthread_mutex_unlock(&ch->lock);
                    return (int)i;
                }
            }
            pthread_mutex_unlock(&ch->lock);
        }

        if (nonblocking) {
            return -1;
        }

        /* Brief backoff to yield execution */
        struct timespec ts;
        ts.tv_sec = 0;
        ts.tv_nsec = 500000; /* 0.5 ms */
        nanosleep(&ts, NULL);
    }
}

void dis_chan_close(DisChannel* ch) {
    if (!ch) return;
    pthread_mutex_lock(&ch->lock);
    ch->closed = true;
    pthread_cond_broadcast(&ch->cond_send);
    pthread_cond_broadcast(&ch->cond_recv);
    pthread_mutex_unlock(&ch->lock);
}
