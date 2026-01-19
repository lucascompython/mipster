export class MipsterSimulator {
    private instance: WebAssembly.Instance | null = null;
    private memory: WebAssembly.Memory | null = null;
    private outputCallback: ((text: string) => void) | null = null;

    constructor() {}

    async load(wasmUrl: string): Promise<boolean> {
        try {
            const result = await WebAssembly.instantiateStreaming(fetch(wasmUrl));
            this.instance = result.instance;
            this.memory = this.instance.exports.memory as WebAssembly.Memory;
            return true;
        } catch (error) {
            console.error("Failed to load WASM:", error);
            return false;
        }
    }

    setOutputCallback(callback: (text: string) => void) {
        this.outputCallback = callback;
    }

    private getString(ptr: number, len: number): string {
        if (!this.memory) return "";
        const bytes = new Uint8Array(this.memory.buffer, ptr, len);
        return new TextDecoder().decode(bytes);
    }

    checkOutput() {
        if (!this.instance) return;
        const exports = this.instance.exports as any;
        const outputPtr = exports.getOutputPtr();
        const outputLen = exports.getOutputLen();

        if (outputLen > 0) {
            const output = this.getString(outputPtr, outputLen);
            if (this.outputCallback) this.outputCallback(output);
            exports.clearOutput();
        }
    }

    getRegisters(): number[] {
        if (!this.instance) return [];
        const exports = this.instance.exports as any;
        const registers: number[] = [];
        for (let i = 0; i < 32; i++) {
            registers.push(exports.getRegister(i));
        }
        return registers;
    }

    isWaitingForInput(): boolean {
        if (!this.instance) return false;
        return (this.instance.exports as any).isWaitingForInput();
    }

    run(code: string): number {
        if (!this.instance || !this.memory) throw new Error("WASM not loaded");
        
        const encoder = new TextEncoder();
        const codeBytes = encoder.encode(code);

        // Allocate code at 4096 (arbitrary safe area?)
        const codePtr = 4096;
        const memory = new Uint8Array(this.memory.buffer);
        
        if (codePtr + codeBytes.length > memory.length) {
            throw new Error("Code too large for simulator memory");
        }

        memory.set(codeBytes, codePtr);

        const result = (this.instance.exports as any).run(codePtr, codeBytes.length);
        this.checkOutput();
        return result;
    }

    provideInput(input: string): number {
         if (!this.instance || !this.memory) throw new Error("WASM not loaded");
         
         const encoder = new TextEncoder();
         const inputBytes = encoder.encode(input);

         const inputPtr = 2048; // Input buffer location assumption
         const memory = new Uint8Array(this.memory.buffer);
         memory.set(inputBytes, inputPtr);

         (this.instance.exports as any).provideInput(inputPtr, inputBytes.length);
         
         const result = (this.instance.exports as any).continueAfterInput();
         this.checkOutput();
         return result;
    }
}
