# Activity deletion tracking

Journal and draft deletion now emit explicit deletion events and collaborator notifications. The activity tombstone retains the title, source ID and deleting actor, without a foreign key to the removed entry. Existing participant-only history restrictions continue to apply. Journal deletion notifications open Development; removed timeline events open Timeline without a missing event ID.

Impact assessment additions, edits and deletions now notify project members as well as recording activity. Reward-only recalculations remain excluded. Forum post/reply edits and deletions are recorded and notified; cascading reply deletions under a removed post do not generate separate notices. Existing project settings, materials/costs, budget, timeline and membership tracking remains in place. Draft autosaves remain activity-only; draft deletion notifies project participants.

Validation: 12 notification routing tests passed, transaction-only database deletion/no-op regression passed and rolled back, web build passed. Migration applied to production. No historical update notification was relabeled: a missing source alone does not prove what the original update represented. Whole-project deletion still removes that project's history and notifications through existing cascade rules.
