module Inventory
  # Turn a physical count into exactly the one adjustment that makes the ledger agree
  # with the shelf, and no adjustment at all when they already agree.
  #
  # The idempotency key is derived from the count record, so posting the same count
  # twice, or retrying the job after a timeout, cannot double-adjust. That is the
  # failure that puts a store 40 bottles up on paper.
  class ReconcileCount
    def self.call(cycle_count)
      CycleCount.transaction do
        cc = CycleCount.lock.find(cycle_count.id)
        return cc if cc.status == "posted"

        have = Movement.at(cc.sku, cc.location).sum(:quantity)
        variance = cc.counted - have

        if variance.zero?
          cc.update!(status: "posted", variance: 0)
          return cc
        end

        Post.call(sku: cc.sku, location: cc.location, quantity: variance,
                  kind: "adjustment", key: "cycle-count:#{cc.id}",
                  note: "cycle count by #{cc.counted_by}", occurred_at: cc.counted_at,
                  allow_negative: true)
        cc.update!(status: "posted", variance: variance)
        cc
      end
    end
  end
end
