import { createConsumer, type Consumer } from "@rails/actioncable";
import { API_URL, tokenStore } from "./api";

let consumer: Consumer | undefined;
let consumerToken: string | null = null;

function getConsumer() {
  const token = tokenStore.get();
  if (!consumer || consumerToken !== token) {
    consumer?.disconnect();
    consumerToken = token;
    consumer = createConsumer(`${API_URL.replace(/^http/, "ws")}/cable?token=${token}`);
  }
  return consumer;
}

// Subscribes to an Action Cable channel; returns an unsubscribe function. Kept behind this one
// function so components can be tested by mocking the module.
export function subscribe(channel: string, params: Record<string, unknown>, onEvent: (event: any) => void): () => void { // eslint-disable-line @typescript-eslint/no-explicit-any
  const sub = getConsumer().subscriptions.create({ channel, ...params }, { received: onEvent });
  return () => sub.unsubscribe();
}
