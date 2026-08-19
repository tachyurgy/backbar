# Invented catalogue for a five-store regional retailer. No real data anywhere.
rng = Random.new(20260818)

[["main", "Downtown"], ["annex", "Annex Warehouse"], ["north", "Northgate"],
 ["east", "Eastside"], ["hill", "Capitol Hill"]].each do |code, name|
  Location.find_or_create_by!(code: code) { |l| l.name = name }
end

catalog = [
  ["rye-750",   "Straight Rye 750ml",        "whiskey", 3499],
  ["bbn-1l",    "Small Batch Bourbon 1L",    "whiskey", 4599],
  ["gin-750",   "London Dry Gin 750ml",      "gin",     2899],
  ["vod-1750",  "Grain Vodka 1.75L",         "vodka",   3299],
  ["tequ-750",  "Blanco Tequila 750ml",      "agave",   3999],
  ["mzcl-750",  "Espadin Mezcal 750ml",      "agave",   4899],
  ["rum-750",   "Aged Rum 750ml",            "rum",     3199],
  ["amaro-700", "Alpine Amaro 700ml",        "liqueur", 3699],
  ["verm-375",  "Dry Vermouth 375ml",        "wine",    1499],
  ["cab-750",   "Columbia Valley Cabernet",  "wine",    2299],
  ["rose-750",  "Provence Rose 750ml",       "wine",    1899],
  ["ipa-6",     "Northwest IPA 6-pack",      "beer",     1399],
]
catalog.each { |code, name, cat, price|
  Sku.find_or_create_by!(code: code) { |s| s.name = name; s.category = cat; s.unit_price_cents = price } }

locations = Location.order(:code).to_a
skus = Sku.order(:code).to_a
i = 0
skus.each do |s|
  locations.each do |l|
    next if rng.rand < 0.15
    i += 1
    Inventory::Post.call(sku: s, location: l, quantity: rng.rand(12..120), kind: "receipt",
                         key: "seed-po-#{i}", note: "opening receipt",
                         occurred_at: rng.rand(40..90).days.ago)
    rng.rand(2..9).times do |k|
      have = s.on_hand(l)
      next if have < 2
      Inventory::Post.call(sku: s, location: l, quantity: -rng.rand(1..[have / 3, 1].max),
                           kind: "sale", key: "seed-sale-#{i}-#{k}",
                           occurred_at: rng.rand(1..39).days.ago)
    end
  end
end

# A few transfers between stores and a handful of counts, one of which finds shrink.
6.times do |k|
  s = skus.sample(random: rng)
  from, to = locations.sample(2, random: rng)
  have = s.on_hand(from)
  next if have < 6
  Inventory::Transfer.call(sku: s, from: from, to: to, quantity: rng.rand(2..have / 2),
                           key: "seed-tx-#{k}", note: "restock")
end

5.times do |k|
  s = skus.sample(random: rng)
  l = locations.sample(random: rng)
  have = s.on_hand(l)
  counted = [have + rng.rand(-4..1), 0].max
  cc = CycleCount.create!(sku: s, location: l, counted: counted, counted_by: "night crew",
                          counted_at: rng.rand(1..14).days.ago)
  Inventory::ReconcileCount.call(cc) if k < 4
end

neg = Movement.group(:sku_id, :location_id).sum(:quantity).select { |_, v| v.negative? }
raise "seed produced #{neg.size} negative cells" if neg.any?
puts "seeded #{Location.count} locations, #{Sku.count} skus, #{Movement.count} movements, #{CycleCount.count} counts"
