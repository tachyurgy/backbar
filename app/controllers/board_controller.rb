class BoardController < ApplicationController
  def index
    @locations = Location.order(:name)
    # One grouped query, not one per cell. The point of deriving on-hand is that it
    # still has to be cheap, and N+1 across a SKU grid is how "derive it" gets
    # abandoned for a cached column.
    totals = Movement.group(:sku_id, :location_id).sum(:quantity)
    @skus = Sku.order(:name).to_a
    @grid = Hash.new(0)
    totals.each { |(sku_id, loc_id), qty| @grid[[sku_id, loc_id]] = qty }
    @negatives = @grid.select { |_, v| v.negative? }.size
    @ledger_total = Movement.sum(:quantity)
    @pending = CycleCount.pending.count
  end

  def sku
    @sku = Sku.find_by!(code: params[:code])
    @movements = @sku.movements.includes(:location).order(occurred_at: :desc, id: :desc).limit(60)
    @by_location = @sku.movements.group(:location_id).sum(:quantity)
    @locations = Location.order(:name)
  end
end
