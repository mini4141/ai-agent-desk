#!/usr/bin/env bash
# Synthesises the Japanese test utterance with Amazon Polly and wraps it as a 16 kHz mono WAV that Chromium can
# use as a fake microphone (--use-file-for-fake-audio-capture). Output: .local/speech-ja.wav
source "$(dirname "$0")/_common.sh"
export AWS_PROFILE=ai-agent-desk-deployer AWS_REGION=ap-southeast-2 AWS_PAGER=""
mkdir -p .local
aws polly synthesize-speech --engine neural --voice-id Tomoko --language-code ja-JP --output-format pcm --sample-rate 16000 \
  --text "注文 A-1023 はいつ届きますか？" .local/speech-ja.pcm >/dev/null
node -e '
const fs = require("fs");
const pcm = fs.readFileSync(".local/speech-ja.pcm");
const pad = Buffer.alloc(16000 * 2 * 1); // 1 s of silence after the utterance
const data = Buffer.concat([pcm, pad]);
const h = Buffer.alloc(44);
h.write("RIFF", 0); h.writeUInt32LE(36 + data.length, 4); h.write("WAVEfmt ", 8); h.writeUInt32LE(16, 16);
h.writeUInt16LE(1, 20); h.writeUInt16LE(1, 22); h.writeUInt32LE(16000, 24); h.writeUInt32LE(32000, 28); h.writeUInt16LE(2, 32); h.writeUInt16LE(16, 34);
h.write("data", 36); h.writeUInt32LE(data.length, 40);
fs.writeFileSync(".local/speech-ja.wav", Buffer.concat([h, data]));
console.log("wrote .local/speech-ja.wav", data.length, "bytes of PCM");
'
