# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_08_18_220000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "cycle_counts", force: :cascade do |t|
    t.integer "counted", null: false
    t.datetime "counted_at", null: false
    t.string "counted_by", null: false
    t.datetime "created_at", null: false
    t.bigint "location_id", null: false
    t.bigint "sku_id", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.integer "variance"
    t.index ["location_id"], name: "index_cycle_counts_on_location_id"
    t.index ["sku_id", "location_id", "status"], name: "index_cycle_counts_on_sku_id_and_location_id_and_status"
    t.index ["sku_id"], name: "index_cycle_counts_on_sku_id"
    t.check_constraint "counted >= 0", name: "count_non_negative"
  end

  create_table "locations", force: :cascade do |t|
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_locations_on_code", unique: true
  end

  create_table "movements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "idempotency_key", null: false
    t.string "kind", null: false
    t.bigint "location_id", null: false
    t.string "note"
    t.datetime "occurred_at", null: false
    t.integer "quantity", null: false
    t.bigint "sku_id", null: false
    t.index ["idempotency_key"], name: "index_movements_on_idempotency_key", unique: true
    t.index ["location_id"], name: "index_movements_on_location_id"
    t.index ["sku_id", "location_id", "occurred_at"], name: "index_movements_on_sku_id_and_location_id_and_occurred_at"
    t.index ["sku_id"], name: "index_movements_on_sku_id"
    t.check_constraint "quantity <> 0", name: "movement_nonzero"
  end

  create_table "skus", force: :cascade do |t|
    t.string "category"
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.integer "unit_price_cents", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_skus_on_code", unique: true
  end

  add_foreign_key "cycle_counts", "locations"
  add_foreign_key "cycle_counts", "skus"
  add_foreign_key "movements", "locations"
  add_foreign_key "movements", "skus"
end
