require "test_helper"

class InventoryTest < ActiveSupport::TestCase
  setup do
    @main  = loc!("main")
    @annex = loc!("annex")
    @rye   = sku!("rye-750")
  end

  test "on hand is the sum of the ledger and nothing else" do
    post!(@rye, @main, 24, "receipt", "po-1")
    post!(@rye, @main, -3, "sale", "sale-1")
    assert_equal 21, @rye.on_hand(@main)
    assert_equal 21, @rye.on_hand
  end

  test "the same idempotency key posts exactly once" do
    a = post!(@rye, @main, 12, "receipt", "po-dup")
    b = post!(@rye, @main, 12, "receipt", "po-dup")
    assert_equal a.id, b.id
    assert_equal 12, @rye.on_hand(@main)
    assert_equal 1, Movement.where(idempotency_key: "po-dup").count
  end

  test "a replayed sale does not sell the bottle twice" do
    post!(@rye, @main, 5, "receipt", "po-2")
    5.times { post!(@rye, @main, -1, "sale", "pos-9931") }
    assert_equal 4, @rye.on_hand(@main)
  end

  test "stock cannot be sold below zero" do
    post!(@rye, @main, 2, "receipt", "po-3")
    assert_raises(Inventory::Post::Insufficient) { post!(@rye, @main, -3, "sale", "sale-x") }
    assert_equal 2, @rye.on_hand(@main)
  end

  test "a transfer moves stock without creating or destroying any" do
    post!(@rye, @main, 30, "receipt", "po-4")
    Inventory::Transfer.call(sku: @rye, from: @main, to: @annex, quantity: 10, key: "tx-1")
    assert_equal 20, @rye.on_hand(@main)
    assert_equal 10, @rye.on_hand(@annex)
    assert_equal 30, @rye.on_hand
  end

  test "a replayed transfer moves the stock once" do
    post!(@rye, @main, 30, "receipt", "po-5")
    3.times { Inventory::Transfer.call(sku: @rye, from: @main, to: @annex, quantity: 10, key: "tx-2") }
    assert_equal 20, @rye.on_hand(@main)
    assert_equal 10, @rye.on_hand(@annex)
  end

  test "a transfer larger than stock leaves both locations untouched" do
    post!(@rye, @main, 4, "receipt", "po-6")
    assert_raises(Inventory::Post::Insufficient) do
      Inventory::Transfer.call(sku: @rye, from: @main, to: @annex, quantity: 9, key: "tx-3")
    end
    assert_equal 4, @rye.on_hand(@main)
    assert_equal 0, @rye.on_hand(@annex)
    assert_equal 0, Movement.where(kind: "transfer_in").count
  end

  test "movements are append-only" do
    m = post!(@rye, @main, 1, "receipt", "po-7")
    assert_raises(ActiveRecord::ReadOnlyRecord) { m.update!(quantity: 99) }
    assert_raises(ActiveRecord::ReadOnlyRecord) { m.destroy! }
  end
end

class CycleCountTest < ActiveSupport::TestCase
  setup do
    @main = loc!("main")
    @gin  = sku!("gin-1l")
  end

  def count!(counted)
    CycleCount.create!(sku: @gin, location: @main, counted: counted,
                       counted_by: "night crew", counted_at: Time.current)
  end

  test "a count that agrees with the ledger posts no adjustment" do
    post!(@gin, @main, 18, "receipt", "po-a")
    cc = Inventory::ReconcileCount.call(count!(18))
    assert_equal "posted", cc.status
    assert_equal 0, cc.variance
    assert_equal 1, Movement.count
  end

  test "a short count posts exactly one negative adjustment" do
    post!(@gin, @main, 18, "receipt", "po-b")
    cc = Inventory::ReconcileCount.call(count!(15))
    assert_equal(-3, cc.variance)
    assert_equal 15, @gin.on_hand(@main)
    adj = Movement.where(kind: "adjustment")
    assert_equal 1, adj.count
    assert_equal(-3, adj.first.quantity)
  end

  test "reconciling the same count twice adjusts once" do
    post!(@gin, @main, 40, "receipt", "po-c")
    cc = count!(31)
    3.times { Inventory::ReconcileCount.call(cc) }
    assert_equal 31, @gin.on_hand(@main)
    assert_equal 1, Movement.where(kind: "adjustment").count
  end

  test "after reconciling, the ledger equals the count exactly" do
    rng = Random.new(90210)
    60.times do |i|
      s = sku!("s#{i % 7}")
      post!(s, @main, rng.rand(1..80), "receipt", "po-r#{i}")
      rng.rand(0..3).times do |k|
        have = s.on_hand(@main)
        next if have < 2
        post!(s, @main, -rng.rand(1..have), "sale", "sale-r#{i}-#{k}")
      end
      counted = rng.rand(0..90)
      cc = CycleCount.create!(sku: s, location: @main, counted: counted,
                              counted_by: "auditor", counted_at: Time.current)
      Inventory::ReconcileCount.call(cc)
      assert_equal counted, s.on_hand(@main),
                   "ledger disagreed with the count for #{s.code}"
    end
  end

  test "the job is safe to run twice" do
    post!(@gin, @main, 10, "receipt", "po-j")
    cc = count!(7)
    PostCycleCountJob.perform_now(cc.id)
    PostCycleCountJob.perform_now(cc.id)
    assert_equal 7, @gin.on_hand(@main)
    assert_equal 1, Movement.where(kind: "adjustment").count
  end
end
