class CreateBackbarCore < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.timestamps
    end
    add_index :locations, :code, unique: true

    create_table :skus do |t|
      t.string  :code, null: false
      t.string  :name, null: false
      t.string  :category
      t.integer :unit_price_cents, null: false, default: 0
      t.timestamps
    end
    add_index :skus, :code, unique: true

    # Every change in on-hand is a row. There is no quantity column anywhere else,
    # because a stored quantity is a second source of truth and the second source of
    # truth is always the one that is wrong.
    create_table :movements do |t|
      t.references :sku, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.integer :quantity, null: false
      t.string  :kind, null: false
      t.string  :idempotency_key, null: false
      t.string  :note
      t.datetime :occurred_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :movements, :idempotency_key, unique: true
    add_index :movements, [:sku_id, :location_id, :occurred_at]
    add_check_constraint :movements, "quantity <> 0", name: "movement_nonzero"

    create_table :cycle_counts do |t|
      t.references :sku, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      t.integer :counted, null: false
      t.string  :counted_by, null: false
      t.string  :status, null: false, default: "pending"
      t.integer :variance
      t.datetime :counted_at, null: false
      t.timestamps
    end
    add_index :cycle_counts, [:sku_id, :location_id, :status]
    add_check_constraint :cycle_counts, "counted >= 0", name: "count_non_negative"
  end
end
