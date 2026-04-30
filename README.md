# Rokid ChatGPT HUD

iOS app that bridges **ChatGPT** (OpenAI) with **Rokid AR glasses** — fully bidirectional.

```
🗣 Voice / 📱 Type / 👓 Glasses query
         ↓
  iPhone (RokidChatGPT)
         ↓  OpenAI Chat Completions API (streaming SSE)
  api.openai.com
         ↓  streams tokens back
  iPhone ──TCP :8096──▶ Rokid Glasses (response appears in real time)
```

## How it works

The glasses are a **first-class input source** — not just a display. Any TCP client connected to port 8096 can send a text question and get ChatGPT's answer streamed back. The phone is the bridge.

### Three ways to ask ChatGPT:

| Method | How |
|--------|-----|
| 🗣 **Voice** | Tap mic → speak → auto-sends after 1.8 s of silence |
| ⌨️ **Type** | Text field in the Chat tab |
| 👓 **Glasses** | Send `QUERY: <question>\n` (or plain text) over TCP :8096 |

### What the glasses see (streamed in real time):

```json
{"type":"query",    "text":"🧑 What is the capital of France?"}
{"type":"thinking", "text":"⏳ Thinking…"}
{"type":"chunk",    "text":"The"}
{"type":"chunk",    "text":" capital"}
{"type":"chunk",    "text":" of France is Paris."}
{"type":"response", "text":"🤖 The capital of France is Paris."}
```

## Display formats

| Format | Behavior |
|--------|----------|
| **Streaming** | Every token chunk sent live as ChatGPT generates it |
| **Summary** | Wait for full response, then send first 2 sentences |
| **Minimal** | Wait for full response, then send first sentence only |

## Features

- **Streaming SSE** — response tokens appear on glasses token-by-token
- **Voice input** — iOS `SFSpeechRecognizer` with auto-submit on silence
- **Conversation memory** — configurable history (1–20 message pairs)
- **Model selector** — GPT-4o mini (fastest), GPT-4o, GPT-4 Turbo, GPT-3.5 Turbo
- **Custom system prompt** — set ChatGPT's persona and style
- **Bidirectional TCP server** — glasses can both receive output AND send queries
- **Suggested prompts** — quick-start questions on empty state

## Setup

1. Open `RokidChatGPT.xcodeproj` in Xcode 15+.
2. Set your team in Signing & Capabilities.
3. Build and run on iPhone (iOS 17+).
4. Grant **microphone** and **speech recognition** permissions when prompted.
5. In **Settings**: paste your [OpenAI API key](https://platform.openai.com/api-keys).
6. Choose a model (GPT-4o mini recommended for fastest glasses response).
7. Connect Rokid glasses to the same Wi-Fi; point TCP client at `<phone-ip>:8096`.

## TCP protocol (port 8096)

### Phone → Glasses
```
{"type":"query",    "text":"🧑 <user question>"}
{"type":"thinking", "text":"⏳ Thinking…"}
{"type":"chunk",    "text":"<token>"}          ← streaming mode only
{"type":"response", "text":"🤖 <full or summary answer>"}
{"type":"error",    "text":"❌ <error message>"}
{"type":"clear",    "text":""}
```

### Glasses → Phone
```
QUERY: What is the weather today?\n
What time is it?\n
```
Plain text lines are also accepted as queries.

## OpenAI API

Uses the [OpenAI Chat Completions API](https://platform.openai.com/docs/api-reference/chat) with streaming:

```
POST https://api.openai.com/v1/chat/completions
Authorization: Bearer <your-key>
Content-Type: application/json

{"model":"gpt-4o-mini","max_tokens":512,"stream":true,"messages":[...]}
```

Responses come back as Server-Sent Events parsed in Swift via `URLSession.bytes(for:)`.

## Recommended model for glasses

**GPT-4o mini** — lowest latency and cost, first token appears on glasses in ~300ms. Perfect for real-time AR display.

## Requirements

- iOS 17.0+
- Xcode 15+
- OpenAI API key ([platform.openai.com](https://platform.openai.com/api-keys))
- Rokid AR glasses on the same Wi-Fi (optional — app works standalone as a ChatGPT chat client)
