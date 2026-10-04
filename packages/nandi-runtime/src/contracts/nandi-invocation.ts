import type { NandiCapabilityOperation } from "./nandi-capability-operation.js";

export interface NandiInvocationRequest
  extends NandiCapabilityOperation {
  readonly organizationId: string;
  readonly actorId: string;
  readonly correlationId: string;

  readonly invocationId?: string;
  readonly agentId?: string;
  readonly agentVersionId?: string;
  readonly runId?: string;
  readonly stepId?: string;
  readonly executionId?: string;
  readonly idempotencyKey?: string;

  readonly inputContext: Readonly<Record<string, unknown>>;
}
