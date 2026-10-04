import type { NandiCapabilityExecutor } from "./capability-executor.js";
import type { NandiGovernanceEvaluator } from "./governance-evaluator.js";
import type { NandiInvocationRequest } from "./contracts/nandi-invocation.js";
import type { NandiInvocationResult } from "./contracts/nandi-invocation-result.js";

export interface NandiRuntimeDependencies {
  readonly governanceEvaluator: NandiGovernanceEvaluator;
  readonly capabilityExecutor: NandiCapabilityExecutor;
}

export interface NandiRuntime {
  invoke(
    request: NandiInvocationRequest,
  ): Promise<NandiInvocationResult>;
}
