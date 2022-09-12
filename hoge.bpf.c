//+build ignore
#include "vmlinux.h"
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_tracing.h>

#ifdef asm_inline
#undef asm_inline
#define asm_inline asm
#endif

char LICENSE[] SEC("license") = "GPL";

struct {
    __uint(type, BPF_MAP_TYPE_RINGBUF);
    __uint(max_entries, 1 << 24);
} events SEC(".maps");

long ringbuffer_flags = 0;

SEC("tp/syscalls/sys_enter_kill")
int tracepoint__sys_enter_kill(struct trace_event_raw_sys_enter* args) {
    // Reserve space on the ringbuffer for the sample
    int* p = bpf_ringbuf_reserve(&events, sizeof(int) * 2, ringbuffer_flags);
    if (!p) {
        return 0;
    }
    int tpid = args->args[0];
    int sig = args->args[1];

    p[0] = tpid;
    p[1] = sig;

    bpf_ringbuf_submit(p, ringbuffer_flags);
    return 0;
}

/* SEC("kprobe/sys_kill") */
/* int kprobe__sys_kill(const struct pt_regs* ctx) { */
/*     int* ptr = (int*)PT_REGS_PARM1(ctx); */
/*  */
/*     long* p; */
/*  */
/*     // Reserve space on the ringbuffer for the sample */
/*     p = bpf_ringbuf_reserve(&events, sizeof(long), ringbuffer_flags); */
/*     if (!p) { */
/*         return 0; */
/*     } */
/*  */
/*     bpf_ringbuf_submit(p, ringbuffer_flags); */
/*     return 0; */
/* } */
