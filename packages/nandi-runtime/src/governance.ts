export type NandiGovernanceOutcome =
  | "allow"
  | "deny"
  | "require_human_approval";

export interface NandiGovernanceDecision {
  readonly outcome: NandiGovernanceOutcome;
  readonly decisionId?: string;
  readonly reason?: string;
}
