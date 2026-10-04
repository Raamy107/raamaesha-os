export const NandiEventTypes = {
  invocationStarted: "nandi.invocation.started",
  invocationCompleted: "nandi.invocation.completed",
  invocationFailed: "nandi.invocation.failed",

  governanceDecided: "nandi.governance.decided",

  dispatchAccepted: "nandi.dispatch.accepted",
  dispatchFailed: "nandi.dispatch.failed",

  agentRunStarted: "nandi.agent_run.started",
  agentRunCompleted: "nandi.agent_run.completed",
  agentRunFailed: "nandi.agent_run.failed",

  agentRunStepStarted: "nandi.agent_run_step.started",
  agentRunStepCompleted: "nandi.agent_run_step.completed",
  agentRunStepFailed: "nandi.agent_run_step.failed",

  aiExecutionStarted: "nandi.ai_execution.started",
  aiExecutionCompleted: "nandi.ai_execution.completed",
  aiExecutionFailed: "nandi.ai_execution.failed",
} as const;

export type NandiEventType =
  (typeof NandiEventTypes)[keyof typeof NandiEventTypes];