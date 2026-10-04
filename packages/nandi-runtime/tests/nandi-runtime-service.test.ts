import { describe, expect, it, vi } from "vitest";

import type {
  NandiCapabilityExecutor,
  NandiCapabilityExecutionRequest,
} from "../src/capability-executor.js";
import type {
  NandiGovernanceEvaluator,
  NandiGovernanceEvaluationRequest,
} from "../src/governance-evaluator.js";
import type { NandiEventProducer } from "../src/events/nandi-event-producer.js";
import type { NandiRuntimeEvent } from "../src/events/nandi-event.js";
import type { NandiInvocationRequest } from "../src/contracts/nandi-invocation.js";
import { NandiRuntimeService } from "../src/nandi-runtime-service.js";

const baseRequest: NandiInvocationRequest = {
  organizationId: "org-001",
  actorId: "actor-001",
  correlationId: "corr-001",
  capability: "example",
  operation: "execute",
  inputContext: {
    message: "hello",
    value: 42,
  },
};

function createGovernanceEvaluator(
  outcome: "allow" | "deny" | "require_human_approval",
): NandiGovernanceEvaluator {
  return {
    evaluate: vi.fn(
      async (
        _request: NandiGovernanceEvaluationRequest,
      ) => ({
        outcome,
        decisionId: "decision-001",
      }),
    ),
  };
}

function createCapabilityExecutor(): NandiCapabilityExecutor {
  return {
    execute: vi.fn(
      async (
        _request: NandiCapabilityExecutionRequest,
      ) => ({
        output: {
          result: "success",
        },
      }),
    ),
  };
}

function createEventProducer(): NandiEventProducer {
  return {
    publish: vi.fn(
      async (_event: NandiRuntimeEvent): Promise<void> => {
        // Test double only. Event publication is not wired yet.
      },
    ),
  };
}

describe("NandiRuntimeService", () => {
  it("executes the capability when governance allows", async () => {
    const governanceEvaluator = createGovernanceEvaluator("allow");
    const capabilityExecutor = createCapabilityExecutor();
    const eventProducer = createEventProducer();

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    const result = await runtime.invoke(baseRequest);

    expect(result.status).toBe("completed");
    expect(result.organizationId).toBe("org-001");
    expect(result.actorId).toBe("actor-001");
    expect(result.correlationId).toBe("corr-001");
    expect(result.output).toEqual({
      result: "success",
    });

    expect(governanceEvaluator.evaluate).toHaveBeenCalledTimes(1);
    expect(capabilityExecutor.execute).toHaveBeenCalledTimes(1);
  });

  it("passes the correct context to governance", async () => {
    const governanceEvaluator = createGovernanceEvaluator("allow");
    const capabilityExecutor = createCapabilityExecutor();
    const eventProducer = createEventProducer();

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    await runtime.invoke(baseRequest);

    expect(governanceEvaluator.evaluate).toHaveBeenCalledWith({
      capability: "example",
      operation: "execute",
      organizationId: "org-001",
      actorId: "actor-001",
      correlationId: "corr-001",
      input: {
        message: "hello",
        value: 42,
      },
    });
  });

  it("passes the same context to capability execution after governance allows", async () => {
    const governanceEvaluator = createGovernanceEvaluator("allow");
    const capabilityExecutor = createCapabilityExecutor();
    const eventProducer = createEventProducer();

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    await runtime.invoke(baseRequest);

    expect(capabilityExecutor.execute).toHaveBeenCalledWith({
      capability: "example",
      operation: "execute",
      organizationId: "org-001",
      actorId: "actor-001",
      correlationId: "corr-001",
      input: {
        message: "hello",
        value: 42,
      },
    });
  });

  it("does not execute the capability when governance denies", async () => {
    const governanceEvaluator = createGovernanceEvaluator("deny");
    const capabilityExecutor = createCapabilityExecutor();
    const eventProducer = createEventProducer();

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    const result = await runtime.invoke(baseRequest);

    expect(result.status).toBe("rejected");
    expect(result.error?.code).toBe("GOVERNANCE_DENIED");

    expect(governanceEvaluator.evaluate).toHaveBeenCalledTimes(1);
    expect(capabilityExecutor.execute).not.toHaveBeenCalled();
  });

  it("does not execute the capability when human approval is required", async () => {
    const governanceEvaluator =
      createGovernanceEvaluator("require_human_approval");
    const capabilityExecutor = createCapabilityExecutor();
    const eventProducer = createEventProducer();

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    const result = await runtime.invoke(baseRequest);

    expect(result.status).toBe("pending_approval");
    expect(result.error?.code).toBe("HUMAN_APPROVAL_REQUIRED");

    expect(governanceEvaluator.evaluate).toHaveBeenCalledTimes(1);
    expect(capabilityExecutor.execute).not.toHaveBeenCalled();
  });

  it("returns completed when capability execution succeeds", async () => {
    const governanceEvaluator = createGovernanceEvaluator("allow");
    const capabilityExecutor = createCapabilityExecutor();
    const eventProducer = createEventProducer();

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    const result = await runtime.invoke({
      ...baseRequest,
      invocationId: "invocation-001",
    });

    expect(result.status).toBe("completed");
    expect(result.invocationId).toBe("invocation-001");
  });

  it("returns failed when capability execution throws", async () => {
    const governanceEvaluator = createGovernanceEvaluator("allow");
    const eventProducer = createEventProducer();

    const capabilityExecutor: NandiCapabilityExecutor = {
      execute: vi.fn(async () => {
        throw new Error("simulated execution failure");
      }),
    };

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    const result = await runtime.invoke(baseRequest);

    expect(result.status).toBe("failed");
    expect(result.error?.code).toBe("CAPABILITY_EXECUTION_FAILED");
    expect(result.error?.message).toBe(
      "Capability execution failed.",
    );
  });

  it("preserves the request identity context", async () => {
    const governanceEvaluator = createGovernanceEvaluator("allow");
    const capabilityExecutor = createCapabilityExecutor();
    const eventProducer = createEventProducer();

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    const result = await runtime.invoke({
      ...baseRequest,
      invocationId: "invocation-123",
    });

    expect(result.invocationId).toBe("invocation-123");
    expect(result.organizationId).toBe("org-001");
    expect(result.actorId).toBe("actor-001");
    expect(result.correlationId).toBe("corr-001");
  });

  it("publishes nandi.invocation.started with the invocation context", async () => {
    const governanceEvaluator = createGovernanceEvaluator("allow");
    const capabilityExecutor = createCapabilityExecutor();
    const eventProducer = createEventProducer();

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    await runtime.invoke({
      ...baseRequest,
      invocationId: "invocation-event-001",
    });

    expect(eventProducer.publish).toHaveBeenCalledTimes(2);

    const publishedEvents = vi.mocked(eventProducer.publish).mock.calls
      .map(([event]) => event);

    const startedEvent = publishedEvents.find(
      (event) => event.eventType === "nandi.invocation.started",
    );

    expect(startedEvent).toBeDefined();

    expect(startedEvent).toMatchObject({
      organizationId: "org-001",
      actorId: "actor-001",
      eventType: "nandi.invocation.started",
      correlationId: "corr-001",
      payload: {
        eventVersion: 1,
        source: "nandi_runtime",
        entityType: "agent_invocation",
        entityId: "invocation-event-001",
        references: {
          invocationId: "invocation-event-001",
        },
      },
    });

    expect(startedEvent?.occurredAt).toBeInstanceOf(Date);
  });

  it("publishes invocation.started before governance evaluation and capability execution", async () => {
    const executionOrder: string[] = [];

    const governanceEvaluator: NandiGovernanceEvaluator = {
      evaluate: vi.fn(async () => {
        executionOrder.push("governance");
        return {
          outcome: "allow",
          decisionId: "decision-order-001",
        };
      }),
    };

    const capabilityExecutor: NandiCapabilityExecutor = {
      execute: vi.fn(async () => {
        executionOrder.push("execution");
        return {
          output: {
            result: "success",
          },
        };
      }),
    };

    const eventProducer: NandiEventProducer = {
      publish: vi.fn(async (event: NandiRuntimeEvent) => {
        if (event.eventType === "nandi.invocation.started") {
          executionOrder.push("invocation.started");
        }
      }),
    };

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    const result = await runtime.invoke({
      ...baseRequest,
      invocationId: "invocation-order-001",
    });

    expect(result.status).toBe("completed");

    expect(executionOrder).toEqual([
      "invocation.started",
      "governance",
      "execution",
    ]);
  });

  it("publishes invocation.completed only after successful capability execution", async () => {
    const executionOrder: string[] = [];

    const governanceEvaluator = createGovernanceEvaluator("allow");

    const capabilityExecutor: NandiCapabilityExecutor = {
      execute: vi.fn(async () => {
        executionOrder.push("execution");
        return { output: { result: "success" } };
      }),
    };

    const eventProducer: NandiEventProducer = {
      publish: vi.fn(async (event: NandiRuntimeEvent) => {
        executionOrder.push(event.eventType);
      }),
    };

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    const result = await runtime.invoke({
      ...baseRequest,
      invocationId: "invocation-lifecycle-001",
    });

    expect(result.status).toBe("completed");

    expect(executionOrder).toEqual([
      "nandi.invocation.started",
      "execution",
      "nandi.invocation.completed",
    ]);

    const publishedEvents = vi.mocked(eventProducer.publish).mock.calls
      .map(([event]) => event);

    expect(publishedEvents).toHaveLength(2);

    expect(publishedEvents[0]?.eventType).toBe(
      "nandi.invocation.started",
    );

    expect(publishedEvents[1]?.eventType).toBe(
      "nandi.invocation.completed",
    );

    expect(publishedEvents[0]?.organizationId).toBe("org-001");
    expect(publishedEvents[1]?.organizationId).toBe("org-001");

    expect(publishedEvents[0]?.actorId).toBe("actor-001");
    expect(publishedEvents[1]?.actorId).toBe("actor-001");

    expect(publishedEvents[0]?.correlationId).toBe("corr-001");
    expect(publishedEvents[1]?.correlationId).toBe("corr-001");

    expect(publishedEvents[0]?.payload.entityId).toBe(
      "invocation-lifecycle-001",
    );

    expect(publishedEvents[1]?.payload.entityId).toBe(
      "invocation-lifecycle-001",
    );

    expect(
      publishedEvents[0]?.payload.references.invocationId,
    ).toBe("invocation-lifecycle-001");

    expect(
      publishedEvents[1]?.payload.references.invocationId,
    ).toBe("invocation-lifecycle-001");
  });
  it("publishes invocation.failed only after capability execution fails", async () => {
    const executionOrder: string[] = [];

    const governanceEvaluator = createGovernanceEvaluator("allow");

    const capabilityExecutor: NandiCapabilityExecutor = {
      execute: vi.fn(async () => {
        executionOrder.push("execution");
        throw new Error("simulated capability failure");
      }),
    };

    const eventProducer: NandiEventProducer = {
      publish: vi.fn(async (event: NandiRuntimeEvent) => {
        executionOrder.push(event.eventType);
      }),
    };

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    const result = await runtime.invoke({
      ...baseRequest,
      invocationId: "invocation-failure-001",
    });

    expect(result.status).toBe("failed");

    expect(executionOrder).toEqual([
      "nandi.invocation.started",
      "execution",
      "nandi.invocation.failed",
    ]);

    const publishedEvents = vi.mocked(eventProducer.publish).mock.calls
      .map(([event]) => event);

    expect(publishedEvents).toHaveLength(2);

    expect(publishedEvents[0]?.eventType).toBe(
      "nandi.invocation.started",
    );

    expect(publishedEvents[1]?.eventType).toBe(
      "nandi.invocation.failed",
    );

    expect(publishedEvents[0]?.organizationId).toBe("org-001");
    expect(publishedEvents[1]?.organizationId).toBe("org-001");

    expect(publishedEvents[0]?.actorId).toBe("actor-001");
    expect(publishedEvents[1]?.actorId).toBe("actor-001");

    expect(publishedEvents[0]?.correlationId).toBe("corr-001");
    expect(publishedEvents[1]?.correlationId).toBe("corr-001");

    expect(publishedEvents[0]?.payload.entityId).toBe(
      "invocation-failure-001",
    );

    expect(publishedEvents[1]?.payload.entityId).toBe(
      "invocation-failure-001",
    );

    expect(
      publishedEvents[0]?.payload.references.invocationId,
    ).toBe("invocation-failure-001");

    expect(
      publishedEvents[1]?.payload.references.invocationId,
    ).toBe("invocation-failure-001");

    expect(
      publishedEvents[1]?.payload.metadata?.errorCode,
    ).toBe("CAPABILITY_EXECUTION_FAILED");
  });
  it("does not execute when the invocation started event cannot be published", async () => {
    const governanceEvaluator = createGovernanceEvaluator("allow");
    const capabilityExecutor = createCapabilityExecutor();

    const eventProducer: NandiEventProducer = {
      publish: vi.fn(async (event: NandiRuntimeEvent) => {
        if (event.eventType === "nandi.invocation.started") {
          throw new Error("simulated event publication failure");
        }
      }),
    };

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    const result = await runtime.invoke({
      ...baseRequest,
      invocationId: "invocation-start-event-failure-001",
    });

    expect(result.status).toBe("failed");
    expect(result.error?.code).toBe("EVENT_PUBLICATION_FAILED");
    expect(result.error?.message).toBe(
      "Nandi invocation start event could not be published.",
    );

    expect(governanceEvaluator.evaluate).not.toHaveBeenCalled();
    expect(capabilityExecutor.execute).not.toHaveBeenCalled();
    expect(eventProducer.publish).toHaveBeenCalledTimes(1);
  });
  it("keeps a successful result when the completed event cannot be published", async () => {
    const governanceEvaluator = createGovernanceEvaluator("allow");
    const capabilityExecutor = createCapabilityExecutor();

    const eventProducer: NandiEventProducer = {
      publish: vi.fn(async (event: NandiRuntimeEvent) => {
        if (event.eventType === "nandi.invocation.completed") {
          throw new Error("simulated completed event publication failure");
        }
      }),
    };

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    const result = await runtime.invoke({
      ...baseRequest,
      invocationId: "invocation-completed-event-failure-001",
    });

    expect(result.status).toBe("completed");
    expect(result.output).toEqual({
      result: "success",
    });

    expect(capabilityExecutor.execute).toHaveBeenCalledTimes(1);
    expect(eventProducer.publish).toHaveBeenCalledTimes(2);

    const publishedEvents = vi.mocked(eventProducer.publish).mock.calls
      .map(([event]) => event);

    expect(publishedEvents[0]?.eventType).toBe(
      "nandi.invocation.started",
    );

    expect(publishedEvents[1]?.eventType).toBe(
      "nandi.invocation.completed",
    );
  });
  it("keeps a failed result when the failed event cannot be published", async () => {
    const governanceEvaluator = createGovernanceEvaluator("allow");

    const capabilityExecutor: NandiCapabilityExecutor = {
      execute: vi.fn(async () => {
        throw new Error("simulated capability failure");
      }),
    };

    const eventProducer: NandiEventProducer = {
      publish: vi.fn(async (event: NandiRuntimeEvent) => {
        if (event.eventType === "nandi.invocation.failed") {
          throw new Error("simulated failed event publication failure");
        }
      }),
    };

    const runtime = new NandiRuntimeService({
      governanceEvaluator,
      capabilityExecutor,
      eventProducer,
    });

    const result = await runtime.invoke({
      ...baseRequest,
      invocationId: "invocation-failed-event-failure-001",
    });

    expect(result.status).toBe("failed");
    expect(result.error?.code).toBe("CAPABILITY_EXECUTION_FAILED");
    expect(result.error?.message).toBe(
      "Capability execution failed.",
    );

    expect(capabilityExecutor.execute).toHaveBeenCalledTimes(1);
    expect(eventProducer.publish).toHaveBeenCalledTimes(2);

    const publishedEvents = vi.mocked(eventProducer.publish).mock.calls
      .map(([event]) => event);

    expect(publishedEvents[0]?.eventType).toBe(
      "nandi.invocation.started",
    );

    expect(publishedEvents[1]?.eventType).toBe(
      "nandi.invocation.failed",
    );
  });
});
