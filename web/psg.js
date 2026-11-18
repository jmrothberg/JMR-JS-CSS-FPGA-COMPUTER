// Software output for the VM's existing sound(ch, freq, vol, frames, slide).
// Keep the hardware's three square voices, pitched LFSR noise and frame envelope.
const PHASE_MAX = 0x1000000;
const VOICE_STEP = 358 * 46875 / sampleRate;
const FRAME = sampleRate / 60;

class PSG extends AudioWorkletProcessor {
  constructor() {
    super();
    this.voices = Array.from({ length: 4 }, () => ({ phase: 0, frequency: 0, volume: 0, frames: 0, slide: 0, clock: 0 }));
    this.noise = 0xace1;
    this.port.onmessage = ({ data: { payload, clear } }) => {
      if (clear) for (const voice of this.voices) voice.frames = 0;
      if (!payload?.byteLength) return;
      const words = new DataView(payload.buffer, payload.byteOffset, payload.byteLength);
      for (let i = 0; i < payload.byteLength; i += 6) {
        const voice = this.voices[words.getUint8(i)];
        voice.phase = 0;
        voice.clock = 0;
        voice.frequency = words.getUint16(i + 1, true);
        voice.volume = words.getUint8(i + 3);
        voice.frames = words.getUint8(i + 4);
        voice.slide = words.getInt8(i + 5);
      }
    };
  }

  process(_input, output) {
    const samples = output[0][0];
    for (let i = 0; i < samples.length; i++) {
      let mix = 0;
      for (let ch = 0; ch < this.voices.length; ch++) {
        const voice = this.voices[ch];
        if (!voice.frames || !voice.volume) continue;
        const high = voice.phase >= PHASE_MAX / 2;
        voice.phase = (voice.phase + voice.frequency * VOICE_STEP) % PHASE_MAX;
        if (ch === 3 && !high && voice.phase >= PHASE_MAX / 2) {
          const bit = ((this.noise >>> 15) ^ (this.noise >>> 13) ^ (this.noise >>> 12) ^ (this.noise >>> 10)) & 1;
          this.noise = ((this.noise << 1) | bit) & 0xffff;
        }
        mix += (ch === 3 ? this.noise & 1 : high) ? voice.volume : -voice.volume;
        if (++voice.clock >= FRAME) {
          voice.clock -= FRAME;
          voice.frames--;
          voice.frequency = (voice.frequency + voice.slide) & 0xffff;
        }
      }
      samples[i] = mix / 192;
    }
    return true;
  }
}

registerProcessor('jmr-psg', PSG);
