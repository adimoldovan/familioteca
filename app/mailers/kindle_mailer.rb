class KindleMailer < ApplicationMailer
  def deliver_book
    delivery = params[:delivery]
    path = params[:file_path]
    @member = delivery.member
    @book = delivery.book

    folded_title = DiacriticFolding.ascii_fold(@book.title)
    folded_author = DiacriticFolding.ascii_fold(@book.author)
    descriptor = [ folded_author, folded_title ].compact_blank.join(" - ")
    extension = @book.format

    attachments["#{descriptor}.#{extension}"] = File.binread(path)

    mail(
      to: @member.kindle_email,
      subject: "Familioteca: #{descriptor}"
    )
  end
end
