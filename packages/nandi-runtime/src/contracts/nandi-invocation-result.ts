export type NandiInvocationStatus =
  | "completed"
  | "rejected"
  | "pending_approval"
  | "failed";

export interface NandiInvocationResult {
  readonly invocationId: string;
  readonly organizationId: string;
  readonly actorId: string;
  readonly correlationId: string;

  readonly status: NandiInvocationStatus;

  readonly output?: Readonly<Record<string, unknown>>;

  readonly error?: {
    readonly code: string;
    readonly message: string;
  };
}
