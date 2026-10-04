import type { NandiEventType } from "./nandi-event-types.js";

export type NandiEventEntityType =
  | "agent_invocation"
  | "governance_decision"
  | "execution_dispatch"
  | "agent_run"
  | "agent_run_step"
  | "ai_execution";

export interface NandiEventReferences {
  readonly invocationId?: string;
  readonly runId?: string;
  readonly stepId?: string;
  readonly executionId?: string;
}

export interface NandiEventPayload {
  readonly eventVersion: number;
  readonly source: "nandi_runtime";
  readonly entityType: NandiEventEntityType;
  readonly entityId: string;
  readonly references: NandiEventReferences;
  readonly metadata?: Readonly<Record<string, unknown>>;
}

export interface NandiRuntimeEvent {
  readonly organizationId: string;
  readonly actorId: string;
  readonly eventType: NandiEventType;
  readonly occurredAt: Date;
  readonly correlationId: string;
  readonly payload: NandiEventPayload;
}
