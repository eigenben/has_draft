# has_draft

[![CI](https://github.com/eigenben/has_draft/actions/workflows/ci.yml/badge.svg)](https://github.com/eigenben/has_draft/actions/workflows/ci.yml)
[![Gem Version](https://badge.fury.io/rb/has_draft.svg)](https://rubygems.org/gems/has_draft)

Gives your ActiveRecord models a draft copy that lives alongside the live record. Typical uses:

- A draft and a live version of a page, where edits are previewed before they're published
- An approval workflow, where the live copy stays active while a draft waits for review

Drafts are stored in a separate, nearly identical table, joined to the live record by a `has_one`.
Your existing table and queries don't change: `Page.all` still returns only live pages, with no extra
conditions needed. The draft table is backed by a model that `has_draft` creates for you as a constant
on the original class, so if `Page` has a draft, `Page::Draft` is the model for the `page_drafts` table.

Because a draft is a real model with real columns, it can have its own validations, associations and
indexes, and you can query drafts with SQL like any other table. The trade-off is that the draft table
has to be kept in step with the live table: when you add a column to one, add it to the other.

## Installation

Requires Rails (ActiveRecord) 6.1 or later and Ruby 3.0 or later.

```ruby
gem "has_draft"
```

## Basic example

```ruby
class CreateArticles < ActiveRecord::Migration[7.1]
  def change
    [:articles, :article_drafts].each do |table_name|
      create_table table_name do |t|
        t.references :article if table_name == :article_drafts

        t.string :title
        t.text :summary
        t.text :body
        t.date :post_date
        t.timestamps
      end
    end
  end
end

class Article < ApplicationRecord
  has_draft
end
```

Class methods and scopes:

```ruby
Article.draft_class   # => Article::Draft
Article.with_draft    # articles that have a draft
Article.without_draft # articles that don't
```

Working with drafts:

```ruby
article = Article.create!(title: "My Title", body: "Full body", post_date: Date.today)

article.has_draft?          # => false
article.instantiate_draft!  # copies the article into a new, saved draft
article.has_draft?          # => true
article.draft               # => #<Article::Draft ...>

article.draft.update!(title: "New Title")
article.replace_with_draft! # copies the draft onto the article and saves it
article.title               # => "New Title"

article.destroy_draft!
article.has_draft?          # => false
```

`save_to_draft` saves a record's unsaved changes into its draft (creating the draft if needed) instead
of the live table, then reloads the live record:

```ruby
article.title = "Work in progress"
article.save_to_draft        # validates the article first; returns false if invalid
article.title                # => "New Title"
article.draft.title          # => "Work in progress"

article.save_to_draft(false) # skip validation
```

Drafts belong to a saved record. On a new record, `instantiate_draft!` builds the draft and it's saved
along with the record, while `save_to_draft` raises `ActiveRecord::RecordNotSaved`.
`instantiate_draft` (without the bang) builds the draft without saving it.

Every column the two tables share is copied, except the primary key, the foreign key, `created_at`,
`updated_at` and the STI type column. Columns that only exist on the draft table (say, an `approved_at`
for a review workflow) are left alone. `Article.draft_columns` lists the columns that are copied.

## Custom options

```ruby
class Article < ApplicationRecord
  has_draft class_name: "Copy", foreign_key: :news_article_id, table_name: "article_copies"
end
```

| Option         | Default                                  |
| -------------- | ---------------------------------------- |
| `:class_name`  | `"Draft"` (defined as `Article::Draft`)   |
| `:table_name`  | `"article_drafts"`                       |
| `:belongs_to`  | `:article`, the draft's parent association |
| `:foreign_key` | `"#{belongs_to}_id"`, so `"article_id"`  |
| `:extends`     | `ActiveRecord::Base`, the draft class's superclass |

## Single table inheritance

Subclasses draft into the base class's draft table. Use `:belongs_to` so every draft class shares the
same parent association, and `:extends` to share behavior between draft classes:

```ruby
class CreateElements < ActiveRecord::Migration[7.1]
  def change
    [:elements, :element_drafts].each do |table_name|
      create_table table_name do |t|
        t.references :element if table_name == :element_drafts

        t.string :title
        t.text :content
        t.string :type
      end
    end
  end
end

class Element < ApplicationRecord
  # Uses the element_drafts table, with each subclass's draft class stored via STI
  class Draft < ApplicationRecord
    def icon_path
      "images/default.png"
    end
  end
end

class BlueElement < Element
  has_draft belongs_to: :element, extends: Element::Draft do
    def icon_path
      "images/blue.png"
    end
  end
end

class UnknownElement < Element
  has_draft belongs_to: :element, extends: Element::Draft
end
```

Now `draft.element` works on any element's draft, without needing to know to call
`draft.blue_element` or `draft.unknown_element`. Calling `has_draft` in a class whose parent already
called it does nothing.

## Callbacks

Define any of these methods to hook into the draft lifecycle:

```ruby
class Article < ApplicationRecord
  has_draft

  def before_instantiate_draft
  end

  def before_replace_with_draft
  end

  def before_destroy_draft
  end
end
```

## Extending the draft class

Since you don't define the draft class yourself, pass a block to `has_draft` to run code in its context:

```ruby
class Article < ApplicationRecord
  belongs_to :user

  has_draft do
    belongs_to :last_updated_user, class_name: "User", optional: true

    def approve!
      update!(approved_at: Time.current)
    end
  end
end
```

## Development

```sh
bundle install
bundle exec rake
```

To test against a specific Rails version, use one of the gemfiles in `gemfiles/`:

```sh
BUNDLE_GEMFILE=gemfiles/rails_6.1.gemfile bundle install
BUNDLE_GEMFILE=gemfiles/rails_6.1.gemfile bundle exec rake
```

## License

MIT
