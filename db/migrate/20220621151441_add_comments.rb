class AddComments < ActiveRecord::Migration[7.0]
  def change
    create_table :comments do |t|
      t.text :body

      t.timestamps

      t.belongs_to :post, foreign_key: true, index: true
    end
  end
end
