# Backbar

Movement-ledger inventory for multi-store retail, in Rails 8 on PostgreSQL with Hotwire
and Solid Queue.

There is no `quantity` column. On-hand for a SKU at a location is `SUM(quantity)` over an
append-only `movements` table, computed at read time. That is a deliberate trade: a stored
count is a second source of truth, and once a retried scanner or a crashed job writes one
without the other, the two disagree forever and nobody can say which was right.

## The three things it actually gets right

**Every write is idempotent.** Every movement carries an `idempotency_key` with a unique
index on it. A point-of-sale that retries a sale, a receiving scanner that double-fires on
bad wifi, a replayed webhook: all of them land as one row. Uniqueness is enforced by
Postgres and the `RecordNotUnique` race is caught and resolved to the winner's row, because
a read-then-write check loses to a concurrent writer that read the same "not present".

**Stock cannot go negative, and the check holds under concurrency.** A decrementing
movement takes a row lock on the SKU before summing, so two concurrent sales cannot both
observe enough stock and both succeed. A transfer is two movements in one transaction, so
a case is never in both stores or in neither, and a transfer larger than stock leaves both
locations exactly as they were.

**A cycle count reconciles exactly once.** Recording a physical count does not edit
anything. `Inventory::ReconcileCount` writes one adjustment movement keyed on the count's
id, so posting the same count twice, or retrying `PostCycleCountJob` after a timeout that
had actually succeeded, adjusts nothing the second time. Double-posting a count is how a
store ends up forty bottles up on paper with a clean audit trail explaining it.

## Tests

    bin/rails test

13 tests. The ones worth reading:

- a replayed sale posted five times moves one unit
- a transfer replayed three times moves the stock once
- an over-large transfer leaves zero `transfer_in` rows behind
- 60 randomized receive/sell/count rounds, asserting after every reconciliation that the
  ledger sum equals the counted number exactly
- the job is run twice on the same count and produces one adjustment
- movements raise `ActiveRecord::ReadOnlyRecord` on update and destroy

## Stack

Rails 8.1, PostgreSQL 17, Hotwire, Solid Queue, Propshaft, Puma. No JavaScript build step.

## Running it

    bin/rails db:create db:migrate db:seed
    bin/rails server

The seed builds an invented twelve-SKU catalogue across five invented stores and refuses to
finish if it has produced a negative cell.
