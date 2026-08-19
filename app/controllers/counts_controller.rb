class CountsController < ApplicationController
  def index
    @counts = CycleCount.includes(:sku, :location).order(counted_at: :desc).limit(60)
    @skus = Sku.order(:name)
    @locations = Location.order(:name)
  end

  def create
    sku = Sku.find(params[:sku_id])
    loc = Location.find(params[:location_id])
    cc = CycleCount.create!(sku: sku, location: loc, counted: params[:counted].to_i,
                            counted_by: params[:counted_by].presence || "floor staff",
                            counted_at: Time.current)
    PostCycleCountJob.perform_later(cc.id)
    redirect_to counts_path, notice: "Count recorded. Reconciliation queued."
  rescue ActiveRecord::RecordInvalid => e
    redirect_to counts_path, alert: e.message
  end

  def post_now
    cc = Inventory::ReconcileCount.call(CycleCount.find(params[:id]))
    redirect_to counts_path,
                notice: "Posted. Variance #{cc.variance}. Running it again would change nothing."
  end
end
