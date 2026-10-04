import type { NandiRuntimeEvent } from "./nandi-event.js";

export interface NandiEventProducer {
  publish(event: NandiRuntimeEvent): Promise<void>;
}
