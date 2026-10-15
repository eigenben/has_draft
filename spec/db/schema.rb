ActiveRecord::Schema.define do
  [:articles, :article_drafts].each do |table_name|
    create_table table_name, force: true do |t|
      t.references :article if table_name == :article_drafts

      t.string :title
      t.text :summary
      t.text :body
      t.date :post_date
      t.timestamps
    end
  end

  [:posts, :post_drafts].each do |table_name|
    create_table table_name, force: true do |t|
      t.references :post if table_name == :post_drafts

      t.string :type
      t.string :title
      t.text :body
    end
  end

  [:pages, :page_copies].each do |table_name|
    create_table table_name, force: true do |t|
      t.references :live_page if table_name == :page_copies

      t.string :title
      t.text :body
    end
  end
end
