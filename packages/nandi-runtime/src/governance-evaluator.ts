import type { NandiCapabilityOperation } from "./contracts/nandi-capability-operation.js";
import type { NandiGovernanceDecision } from "./governance.js";

export interface NandiGovernanceEvaluator {
  evaluate(
    request: NandiGovernanceEvaluationRequest,
  ): Promise<NandiGovernanceDecision>;
}

export interface NandiGovernanceEvaluationRequest
  extends NandiCapabilityOperation {
  readonly organizationId: string;
  readonly actorId: string;
  readonly correlationId: string;
  readonly input: Readonly<Record<string, unknown>>;
}
