# Changelog

## 2.0.0

Supports Rails (ActiveRecord) 6.1 through 8.1 on Ruby 3.0 and later.

### Breaking changes

- Requires ActiveRecord 6.1+ and Ruby 3.0+.
- `instantiate_draft` builds the draft without saving it, as originally intended.
  `instantiate_draft!` still saves it.
- On a new record, `instantiate_draft!` no longer saves the record. The draft is saved along with the
  record instead. `save_to_draft` raises `ActiveRecord::RecordNotSaved`.
- The foreign key defaults to `"#{belongs_to}_id"`, so with `belongs_to: :element` it's
  `element_id` rather than one named after the including class. This is unchanged when `:belongs_to`
  isn't given.
- The Railtie and the `init.rb` files are gone. The gem hooks into ActiveRecord when it's required.

### Fixes

- `save_to_draft`, `destroy_draft!` and the `with_draft`/`without_draft` scopes work on modern Rails.
- `save_to_draft` returns false when the draft fails to save.
- Defining a model no longer needs a database connection. Drafted columns are worked out on first use.
- Columns that only exist on the draft table are no longer copied, which used to raise `NoMethodError`.
- A symbol `:foreign_key` is no longer copied as if it were a drafted column.

## 1.4.0 and earlier

See the [commit history](https://github.com/eigenben/has_draft/commits/master).
