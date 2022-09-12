package main

import "C"

import (
	"fmt"
	"os"
	"syscall"
	"time"

	bpf "github.com/aquasecurity/libbpfgo"
)

func resizeMap(module *bpf.Module, name string, size uint32) error {
	m, err := module.GetMap("events")
	if err != nil {
		return err
	}

	if err = m.Resize(size); err != nil {
		return err
	}

	if actual := m.GetMaxEntries(); actual != size {
		return fmt.Errorf("map resize failed, expected %v, actual %v", size, actual)
	}

	return nil
}

func main() {

	bpfModule, err := bpf.NewModuleFromFile("hoge.bpf.o")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(-1)
	}
	defer bpfModule.Close()

	if err = resizeMap(bpfModule, "events", 8192); err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(-1)
	}

	bpfModule.BPFLoadObject()

	// prog, err := bpfModule.GetProgram("kprobe__sys_kill")
	// _, err = prog.AttachKprobe("__x64_sys_kill")
	// if err != nil {
	// 	fmt.Fprintln(os.Stderr, err)
	// 	os.Exit(-1)
	// }
	prog, err := bpfModule.GetProgram("tracepoint__sys_enter_kill")
	_, err = prog.AttachTracepoint("syscalls", "sys_enter_kill")
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(-1)
	}

	eventsChannel := make(chan []byte)
	rb, err := bpfModule.InitRingBuf("events", eventsChannel)
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(-1)
	}

	rb.Start()

	go func() {
		for {
			syscall.Kill(0, syscall.SIGCONT)
			time.Sleep(time.Second / 2)
		}
	}()
	for {
		b := <-eventsChannel
		for _, x := range b {
			fmt.Printf("%02x ", x)
		}
		fmt.Println("")
	}

	// Test that it won't cause a panic or block if Stop or Close called multiple times
	rb.Stop()
	rb.Stop()
	rb.Close()
	rb.Close()
	rb.Stop()
}
