require "logger" # Rails < 7.1 expects Logger to be loaded already
require "active_record"
require "has_draft"

ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: ":memory:")
ActiveRecord::Schema.verbose = false
load File.expand_path("db/schema.rb", __dir__)

class Article < ActiveRecord::Base
  validates :title, presence: true

  has_draft
end

# Plain base class for testing the :extends and :belongs_to options
class Post < ActiveRecord::Base
end

class BlogPost < Post
  has_draft extends: Post, belongs_to: :post
end

class Page < ActiveRecord::Base
  has_draft class_name: "Copy", foreign_key: :live_page_id, table_name: "page_copies" do
    def approve!
      update!(approved: true)
    end
  end
end

RSpec.configure do |config|
  config.disable_monkey_patching!
  config.order = :random

  config.around do |example|
    ActiveRecord::Base.transaction do
      example.run
      raise ActiveRecord::Rollback
    end
  end
end
