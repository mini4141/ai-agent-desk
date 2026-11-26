// Browser audio helpers: hold-to-talk PCM capture (16 kHz PCM16 frames) and sentence-by-sentence playback.
import type { Viseme } from "./types";

export type SpeechRecognitionLike = {
  lang: string;
  interimResults: boolean;
  onresult: ((e: { results: ArrayLike<ArrayLike<{ transcript: string }>> }) => void) | null;
  onerror: (() => void) | null;
  onend: (() => void) | null;
  start: () => void;
  stop: () => void;
};

const toBase64 = (bytes: Uint8Array) => {
  let s = "";
  for (let i = 0; i < bytes.length; i += 0x8000) s += String.fromCharCode(...bytes.subarray(i, i + 0x8000));
  return btoa(s);
};

export class PushToTalk {
  private ctx?: AudioContext;
  private stream?: MediaStream;
  private node?: ScriptProcessorNode;
  private recognition?: SpeechRecognitionLike;
  private transcript = "";
  seq = 0;

  async start(onFrame: (seq: number, pcmBase64: string) => void, lang: string) {
    this.seq = 0;
    this.transcript = "";
    this.stream = await navigator.mediaDevices.getUserMedia({ audio: true });
    this.ctx = new AudioContext();
    const source = this.ctx.createMediaStreamSource(this.stream);
    this.node = this.ctx.createScriptProcessor(4096, 1, 1);
    const ratio = this.ctx.sampleRate / 16000;
    this.node.onaudioprocess = (e) => {
      const input = e.inputBuffer.getChannelData(0);
      const out = new Int16Array(Math.floor(input.length / ratio));
      for (let i = 0; i < out.length; i++) {
        const v = Math.max(-1, Math.min(1, input[Math.floor(i * ratio)]));
        out[i] = v < 0 ? v * 0x8000 : v * 0x7fff;
      }
      onFrame(this.seq++, toBase64(new Uint8Array(out.buffer)));
    };
    source.connect(this.node);
    this.node.connect(this.ctx.destination);
    this.startRecognition(lang);
  }

  // Web Speech API is the local STT path; it fails quietly where unavailable (e.g. headless Chromium).
  private startRecognition(lang: string) {
    const w = window as unknown as Record<string, new () => SpeechRecognitionLike>;
    const Ctor = w.SpeechRecognition ?? w.webkitSpeechRecognition;
    if (!Ctor) return;
    try {
      this.recognition = new Ctor();
      this.recognition.lang = lang;
      this.recognition.interimResults = false;
      this.recognition.onresult = (e) => {
        this.transcript = Array.from(e.results).map((r) => r[0].transcript).join(" ");
      };
      this.recognition.onerror = () => {};
      this.recognition.start();
    } catch {
      this.recognition = undefined;
    }
  }

  async stop(): Promise<{ total: number; hint: string | undefined }> {
    this.node?.disconnect();
    this.stream?.getTracks().forEach((t) => t.stop());
    await this.ctx?.close();
    this.recognition?.stop();
    if (this.recognition) await new Promise((r) => setTimeout(r, 500));
    const hint = this.transcript || (window as unknown as { __AGENT_DESK_STT_HINT__?: string }).__AGENT_DESK_STT_HINT__;
    return { total: this.seq, hint };
  }
}

export interface SpeakEvent {
  seq: number;
  text: string;
  audio: string | null;
  mime: string | null;
  visemes: Viseme[];
}

// Plays `speak` events strictly in sequence. Audio (Polly) drives visemes; otherwise speechSynthesis speaks the text.
export class SpeechPlayer {
  private pending = new Map<number, SpeakEvent>();
  private next = 1;
  private playing = false;
  spoken: string[] = [];

  constructor(
    private lang: () => string,
    private onMouth: (viseme: string | null) => void,
    private onState: (speaking: boolean, spoken: string[]) => void,
  ) {}

  enqueue(ev: SpeakEvent) {
    this.pending.set(ev.seq, ev);
    void this.pump();
  }

  reset() {
    this.pending.clear();
    this.next = 1;
    window.speechSynthesis?.cancel();
  }

  private async pump() {
    if (this.playing) return;
    this.playing = true;
    let ev: SpeakEvent | undefined;
    while ((ev = this.pending.get(this.next))) {
      this.pending.delete(this.next++);
      this.onState(true, this.spoken);
      await this.play(ev);
      this.spoken = [...this.spoken, ev.text];
    }
    this.playing = false;
    this.onState(false, this.spoken);
    this.onMouth(null);
  }

  private play(ev: SpeakEvent): Promise<void> {
    return ev.audio ? this.playAudio(ev) : this.playSynthesis(ev);
  }

  private playAudio(ev: SpeakEvent): Promise<void> {
    return new Promise((resolve) => {
      const audio = new Audio(`data:${ev.mime};base64,${ev.audio}`);
      audio.ontimeupdate = () => {
        const ms = audio.currentTime * 1000;
        const current = [...ev.visemes].reverse().find((v) => v.time <= ms);
        this.onMouth(current?.value ?? "sil");
      };
      audio.onended = () => resolve();
      audio.onerror = () => resolve();
      audio.play().catch(() => resolve());
    });
  }

  // No visemes locally: amplitude-style mouth movement while the browser voice speaks.
  private playSynthesis(ev: SpeakEvent): Promise<void> {
    return new Promise((resolve) => {
      const wiggle = window.setInterval(() => this.onMouth(["a", "e", "o", "i", "u"][Math.floor(Math.random() * 5)]), 110);
      let finished = false;
      const done = () => {
        if (finished) return;
        finished = true;
        window.clearInterval(wiggle);
        resolve();
      };
      // Safety net: some environments (headless) never fire `end`.
      window.setTimeout(done, Math.max(500, ev.text.length * 90));
      try {
        const u = new SpeechSynthesisUtterance(ev.text);
        u.lang = this.lang();
        u.onend = done;
        u.onerror = done;
        window.speechSynthesis?.speak(u);
      } catch {
        /* no speechSynthesis available */
      }
    });
  }
}
