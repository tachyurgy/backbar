class Movement < ApplicationRecord
  KINDS = %w[receipt sale transfer_out transfer_in shrink adjustment return].freeze

  belongs_to :sku
  belongs_to :location

  validates :quantity, numericality: { other_than: 0 }
  validates :kind, inclusion: { in: KINDS }
  validates :idempotency_key, presence: true

  before_update  { raise ActiveRecord::ReadOnlyRecord, "movements are append-only" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "movements are append-only" }

  scope :at, ->(sku, location) { where(sku: sku, location: location) }
end
