ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  parallelize(workers: 1)

  def loc!(code) = Location.find_or_create_by!(code: code) { |l| l.name = code.titleize }
  def sku!(code) = Sku.find_or_create_by!(code: code) { |s| s.name = code.titleize; s.unit_price_cents = 1999 }

  def post!(sku, loc, qty, kind, key, **kw)
    Inventory::Post.call(sku: sku, location: loc, quantity: qty, kind: kind, key: key, **kw)
  end
end
