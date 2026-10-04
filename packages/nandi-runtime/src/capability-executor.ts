import type { NandiCapabilityOperation } from "./contracts/nandi-capability-operation.js";

export interface NandiCapabilityExecutor {
  execute(
    request: NandiCapabilityExecutionRequest,
  ): Promise<NandiCapabilityExecutionResult>;
}

export interface NandiCapabilityExecutionRequest
  extends NandiCapabilityOperation {
  readonly organizationId: string;
  readonly actorId: string;
  readonly correlationId: string;
  readonly input: Readonly<Record<string, unknown>>;
}

export interface NandiCapabilityExecutionResult {
  readonly output: Readonly<Record<string, unknown>>;
}
