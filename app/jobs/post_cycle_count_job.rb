class PostCycleCountJob < ApplicationJob
  queue_as :default
  retry_on StandardError, wait: :polynomially_longer, attempts: 5

  # Safe to retry: ReconcileCount is idempotent on the count record, so a retry after
  # a timeout that actually succeeded posts nothing a second time.
  def perform(cycle_count_id)
    Inventory::ReconcileCount.call(CycleCount.find(cycle_count_id))
  end
end
