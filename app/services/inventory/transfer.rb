module Inventory
  # Stock moving between two stores is two rows, not one, and they are written in
  # the same transaction so the pallet is never in both places or in neither.
  class Transfer
    def self.call(sku:, from:, to:, quantity:, key:, note: nil)
      raise ArgumentError, "transfer quantity must be positive" unless quantity.positive?
      raise ArgumentError, "cannot transfer to the same location" if from.id == to.id

      Movement.transaction do
        out = Post.call(sku: sku, location: from, quantity: -quantity,
                        kind: "transfer_out", key: "#{key}:out", note: note)
        into = Post.call(sku: sku, location: to, quantity: quantity,
                         kind: "transfer_in", key: "#{key}:in", note: note,
                         allow_negative: true)
        [out, into]
      end
    end
  end
end
