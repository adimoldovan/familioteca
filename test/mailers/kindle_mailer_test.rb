require "test_helper"

class KindleMailerTest < ActionMailer::TestCase
  setup do
    @member = members(:ana)
    @member.update!(kindle_email: "ana@kindle.com")
    @book = Book.create!(
      title: "Bizanț, Bizanț",
      author: "Lucian Boia",
      format: "epub",
      object_key: "k",
      ingested_at: Time.current
    )
    @delivery = KindleDelivery.create!(member: @member, book: @book)

    @tempfile = Tempfile.new([ "fixture-", ".epub" ])
    @tempfile.write("epub bytes")
    @tempfile.close
    @file_path = @tempfile.path
  end

  teardown do
    @tempfile.unlink
  end

  test "sends to the member's kindle_email" do
    mail = KindleMailer.with(delivery: @delivery, file_path: @file_path).deliver_book
    assert_equal [ "ana@kindle.com" ], mail.to
  end

  test "subject is ASCII-folded" do
    mail = KindleMailer.with(delivery: @delivery, file_path: @file_path).deliver_book
    assert_equal "Familioteca: Lucian Boia - Bizant, Bizant", mail.subject
  end

  test "attaches the file with an ASCII-folded filename" do
    mail = KindleMailer.with(delivery: @delivery, file_path: @file_path).deliver_book
    attachment = mail.attachments.first
    refute_nil attachment
    assert_equal "Lucian Boia - Bizant, Bizant.epub", attachment.filename
    assert_equal "epub bytes", attachment.body.decoded
  end

  test "body contains the Romanian copy" do
    mail = KindleMailer.with(delivery: @delivery, file_path: @file_path).deliver_book
    assert_match(/Salut! Atașat este cartea/, mail.text_part.body.to_s)
  end

  test "handles a book without an author (title only in subject + filename)" do
    @book.update!(author: nil)
    mail = KindleMailer.with(delivery: @delivery, file_path: @file_path).deliver_book
    assert_equal "Familioteca: Bizant, Bizant", mail.subject
    assert_equal "Bizant, Bizant.epub", mail.attachments.first.filename
  end
end
