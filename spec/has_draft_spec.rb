RSpec.describe HasDraft do
  def create_article(attributes = {})
    Article.create!({ title: "Live title", summary: "Live summary", body: "Live body", post_date: Date.new(2020, 1, 1) }.merge(attributes))
  end

  describe "a model with has_draft" do
    it "exposes the draft class name" do
      expect(Article.draft_class_name).to eq("Draft")
    end

    it "exposes the draft class" do
      expect(Article.draft_class).to eq(Article::Draft)
    end

    it "defaults the foreign key" do
      expect(Article.draft_foreign_key).to eq("article_id")
    end

    it "defaults the draft table name" do
      expect(Article.draft_table_name).to eq("article_drafts")
      expect(Article::Draft.table_name).to eq("article_drafts")
    end

    it "defines the draft class under the model's namespace" do
      expect(Article.const_defined?(:Draft, false)).to be(true)
    end

    it "points the draft class back at the original class" do
      expect(Article::Draft.original_class).to eq(Article)
    end

    it "drafts every column except keys and timestamps" do
      expect(Article.draft_columns).to contain_exactly("title", "summary", "body", "post_date")
    end

    it "doesn't need the database until the draft columns are used" do
      stub_const("Widget", Class.new(ActiveRecord::Base))

      expect { Widget.has_draft }.not_to raise_error
      expect { Widget.draft_columns }.to raise_error(ActiveRecord::StatementInvalid)
    end
  end

  describe "#instantiate_draft!" do
    let(:article) { create_article }

    before { article.instantiate_draft! }

    it "creates a persisted draft" do
      expect(article.draft).to be_persisted
      expect(article).to have_draft
    end

    it "copies the drafted columns" do
      Article.draft_columns.each do |column|
        expect(article.draft.send(column)).to eq(article.send(column))
      end
    end

    it "sets the associations as inverses of each other" do
      expect(article.draft.article).to be(article)

      draft = Article::Draft.find(article.draft.id)
      expect(draft.article.draft).to be(draft)
    end
  end

  describe "#instantiate_draft" do
    it "builds the draft without saving it" do
      article = create_article
      draft = article.instantiate_draft

      expect(draft).to be_new_record
      expect(draft.title).to eq("Live title")
    end
  end

  describe "on a new record" do
    let(:article) { Article.new(title: "New title") }

    it "builds the draft with #instantiate_draft! and saves it along with the record" do
      article.instantiate_draft!

      expect(article).to be_new_record
      expect(article.draft).to be_new_record
      expect(Article.count).to eq(0)

      article.save!

      expect(article.draft).to be_persisted
      expect(article.reload.draft.title).to eq("New title")
    end

    it "raises from #save_to_draft without saving anything" do
      expect { article.save_to_draft }.to raise_error(ActiveRecord::RecordNotSaved)
      expect(Article.count).to eq(0)
    end
  end

  describe "#has_draft?" do
    it "is false without a draft" do
      expect(create_article).not_to have_draft
    end
  end

  describe "#save_to_draft" do
    let(:article) { create_article }

    it "saves pending changes to the draft and leaves the live record alone" do
      article.title = "Draft title"

      expect(article.save_to_draft).to be_truthy
      expect(article.title).to eq("Live title")
      expect(article.draft.title).to eq("Draft title")
      expect(Article.find(article.id).title).to eq("Live title")
    end

    it "updates an existing draft" do
      article.instantiate_draft!
      article.body = "Draft body"
      article.save_to_draft

      expect(Article::Draft.where(article_id: article.id).count).to eq(1)
      expect(article.draft.reload.body).to eq("Draft body")
    end

    it "returns false and saves nothing when the record is invalid" do
      article.title = ""

      expect(article.save_to_draft).to be(false)
      expect(article.reload).not_to have_draft
    end

    it "skips validation when asked to" do
      article.title = ""

      expect(article.save_to_draft(false)).to be_truthy
      expect(article.draft.title).to eq("")
    end
  end

  describe "#replace_with_draft!" do
    let(:article) { create_article }

    before do
      article.instantiate_draft!
      article.draft.update!(title: "Draft title", body: "Draft body")
      article.replace_with_draft!
    end

    it "copies the draft onto the live record and saves it" do
      expect(article.reload.title).to eq("Draft title")
      expect(article.body).to eq("Draft body")
    end

    it "keeps the draft" do
      expect(article).to have_draft
    end
  end

  describe "#destroy_draft!" do
    let(:article) { create_article }

    it "destroys the draft" do
      article.instantiate_draft!
      article.destroy_draft!

      expect(article).not_to have_draft
      expect(Article::Draft.count).to eq(0)
    end

    it "does nothing without a draft" do
      expect { article.destroy_draft! }.not_to raise_error
    end
  end

  describe "destroying the live record" do
    it "destroys its draft" do
      article = create_article
      article.instantiate_draft!
      article.destroy

      expect(Article::Draft.count).to eq(0)
    end
  end

  describe "scopes" do
    let!(:with) { create_article.tap(&:instantiate_draft!) }
    let!(:without) { create_article }

    it "finds records with a draft" do
      expect(Article.with_draft.to_a).to eq([with])
    end

    it "finds records without a draft" do
      expect(Article.without_draft.to_a).to eq([without])
    end
  end

  describe "callbacks" do
    let(:article) { create_article }

    it "calls before_instantiate_draft" do
      expect(article).to receive(:before_instantiate_draft)
      article.instantiate_draft!
    end

    it "calls before_replace_with_draft" do
      article.instantiate_draft!
      expect(article).to receive(:before_replace_with_draft)
      article.replace_with_draft!
    end

    it "calls before_destroy_draft" do
      article.instantiate_draft!
      expect(article).to receive(:before_destroy_draft)
      article.destroy_draft!
    end
  end

  describe ":extends and :belongs_to options" do
    it "extends ActiveRecord::Base by default" do
      expect(Article::Draft.superclass).to eq(ActiveRecord::Base)
    end

    it "extends the given class" do
      expect(BlogPost::Draft.superclass).to eq(Post)
    end

    it "names the parent association after the model by default" do
      expect(Article::Draft.reflect_on_association(:article).macro).to eq(:belongs_to)
    end

    it "names the parent association with the given name" do
      expect(BlogPost::Draft.reflect_on_association(:post).macro).to eq(:belongs_to)
    end

    it "works with single table inheritance" do
      post = BlogPost.create!(title: "Live")
      post.instantiate_draft!

      draft = BlogPost.find(post.id).draft
      expect(draft).to be_a(BlogPost::Draft)
      expect(draft.post).to eq(post)
    end
  end

  describe "the README's single table inheritance example" do
    let(:blue) { BlueElement.create!(title: "Blue") }
    let(:unknown) { UnknownElement.create!(title: "Unknown") }

    before do
      blue.instantiate_draft!
      unknown.instantiate_draft!
    end

    it "stores every subclass's drafts in the base draft table" do
      expect(Element::Draft.table_name).to eq("element_drafts")
      expect(Element::Draft.all.map(&:class)).to contain_exactly(BlueElement::Draft, UnknownElement::Draft)
    end

    it "shares the parent association across draft classes" do
      expect(Element.find(blue.id).draft.element).to eq(blue)
      expect(Element.find(unknown.id).draft.element).to eq(unknown)
    end

    it "uses each draft class's behavior" do
      expect(blue.draft.icon_path).to eq("images/blue.png")
      expect(unknown.draft.icon_path).to eq("images/default.png")
    end

    it "keeps the live record's type when replacing it with the draft" do
      blue.draft.update!(title: "New blue")
      blue.replace_with_draft!

      expect(Element.find(blue.id)).to be_a(BlueElement)
      expect(blue.reload.title).to eq("New blue")
    end
  end

  describe ":class_name, :foreign_key and :table_name options" do
    let(:page) { Page.create!(title: "Live") }

    it "uses the given names" do
      expect(Page.draft_class).to eq(Page::Copy)
      expect(Page.draft_foreign_key).to eq("live_page_id")
      expect(Page::Copy.table_name).to eq("page_copies")
    end

    it "creates drafts" do
      page.instantiate_draft!

      expect(page.draft).to be_a(Page::Copy)
      expect(page.draft.live_page_id).to eq(page.id)
    end

    it "evaluates the block in the draft class" do
      page.instantiate_draft!
      page.draft.approve!

      expect(page.draft.reload).to be_approved
    end

    it "leaves columns that only exist on the draft table alone" do
      expect(Page.draft_columns).to contain_exactly("title", "body")

      page.instantiate_draft!
      page.draft.update!(approved: true, title: "Draft")
      page.replace_with_draft!
      page.update!(title: "Edited")
      page.save_to_draft

      expect(page.draft.reload).to be_approved
    end
  end
end
