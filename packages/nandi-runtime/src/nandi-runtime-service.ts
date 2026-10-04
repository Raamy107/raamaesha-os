import type { NandiCapabilityExecutor } from "./capability-executor.js";
import type { NandiGovernanceEvaluator } from "./governance-evaluator.js";
import { NandiEventTypes } from "./events/nandi-event-types.js";
import type { NandiEventProducer } from "./events/nandi-event-producer.js";
import type { NandiInvocationRequest } from "./contracts/nandi-invocation.js";
import type { NandiInvocationResult } from "./contracts/nandi-invocation-result.js";
import type {
  NandiRuntime,
  NandiRuntimeDependencies,
} from "./nandi-runtime.js";

export interface NandiRuntimeDependenciesWithEvents
  extends NandiRuntimeDependencies {
  readonly eventProducer: NandiEventProducer;
}

export class NandiRuntimeService implements NandiRuntime {
  private readonly governanceEvaluator: NandiGovernanceEvaluator;
  private readonly capabilityExecutor: NandiCapabilityExecutor;
  private readonly eventProducer: NandiEventProducer;

  constructor(dependencies: NandiRuntimeDependenciesWithEvents) {
    this.governanceEvaluator = dependencies.governanceEvaluator;
    this.capabilityExecutor = dependencies.capabilityExecutor;
    this.eventProducer = dependencies.eventProducer;
  }

  async invoke(
    request: NandiInvocationRequest,
  ): Promise<NandiInvocationResult> {
    const invocationId =
      request.invocationId ?? crypto.randomUUID();

    try {
      await this.eventProducer.publish({
        organizationId: request.organizationId,
        actorId: request.actorId,
        eventType: NandiEventTypes.invocationStarted,
        occurredAt: new Date(),
        correlationId: request.correlationId,
        payload: {
          eventVersion: 1,
          source: "nandi_runtime",
          entityType: "agent_invocation",
          entityId: invocationId,
          references: {
            invocationId,
          },
        },
      });
    } catch {
      return {
        invocationId,
        organizationId: request.organizationId,
        actorId: request.actorId,
        correlationId: request.correlationId,
        status: "failed",
        error: {
          code: "EVENT_PUBLICATION_FAILED",
          message: "Nandi invocation start event could not be published.",
        },
      };
    }

    const governanceDecision =
      await this.governanceEvaluator.evaluate({
        capability: request.capability,
        operation: request.operation,
        organizationId: request.organizationId,
        actorId: request.actorId,
        correlationId: request.correlationId,
        input: request.inputContext,
      });

    if (governanceDecision.outcome === "deny") {
      return {
        invocationId,
        organizationId: request.organizationId,
        actorId: request.actorId,
        correlationId: request.correlationId,
        status: "rejected",
        error: {
          code: "GOVERNANCE_DENIED",
          message:
            governanceDecision.reason ??
            "Governance denied the invocation.",
        },
      };
    }

    if (governanceDecision.outcome === "require_human_approval") {
      return {
        invocationId,
        organizationId: request.organizationId,
        actorId: request.actorId,
        correlationId: request.correlationId,
        status: "pending_approval",
        error: {
          code: "HUMAN_APPROVAL_REQUIRED",
          message:
            governanceDecision.reason ??
            "Human approval is required before execution.",
        },
      };
    }

    try {
      const executionResult =
        await this.capabilityExecutor.execute({
          capability: request.capability,
          operation: request.operation,
          organizationId: request.organizationId,
          actorId: request.actorId,
          correlationId: request.correlationId,
          input: request.inputContext,
        });

      try {
        await this.eventProducer.publish({
          organizationId: request.organizationId,
          actorId: request.actorId,
          eventType: NandiEventTypes.invocationCompleted,
          occurredAt: new Date(),
          correlationId: request.correlationId,
          payload: {
            eventVersion: 1,
            source: "nandi_runtime",
            entityType: "agent_invocation",
            entityId: invocationId,
            references: {
              invocationId,
            },
          },
        });
      } catch {
        // Event publication failure must not change successful runtime execution.
      }

      return {
        invocationId,
        organizationId: request.organizationId,
        actorId: request.actorId,
        correlationId: request.correlationId,
        status: "completed",
        output: executionResult.output,
      };
    } catch {
      try {
        await this.eventProducer.publish({
          organizationId: request.organizationId,
          actorId: request.actorId,
          eventType: NandiEventTypes.invocationFailed,
          occurredAt: new Date(),
          correlationId: request.correlationId,
          payload: {
            eventVersion: 1,
            source: "nandi_runtime",
            entityType: "agent_invocation",
            entityId: invocationId,
            references: {
              invocationId,
            },
            metadata: {
              errorCode: "CAPABILITY_EXECUTION_FAILED",
            },
          },
        });
      } catch {
        // Event publication failure must not change failed runtime execution.
      }

      return {
        invocationId,
        organizationId: request.organizationId,
        actorId: request.actorId,
        correlationId: request.correlationId,
        status: "failed",
        error: {
          code: "CAPABILITY_EXECUTION_FAILED",
          message: "Capability execution failed.",
        },
      };
    }
  }
}
