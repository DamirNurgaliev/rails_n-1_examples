class AddPosts < ActiveRecord::Migration[7.0]
  def change
    create_table :posts do |t|
      t.text :description

      t.timestamps
    end
  end
end
