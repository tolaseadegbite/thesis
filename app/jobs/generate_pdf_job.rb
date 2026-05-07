class GeneratePdfJob < ApplicationJob
  queue_as :default

  def perform(thesis_id)
    thesis = Thesis.find(thesis_id)
    thesis.pdf_generating!

    # 1. Immediate broadcast to show "Generating PDF..." spinner
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "actions_section",
      partial: "theses/actions",
      locals: { thesis: thesis }
    )

    # 2. Simulate PDF Generation Time (Ferrum logic)
    sleep(4)

    # In a real app, you would save this to S3 via ActiveStorage:
    # pdf_html = ApplicationController.render(template: "theses/pdf", locals: { thesis: thesis })
    # pdf = FerrumPdf.render_pdf(html: pdf_html)
    # thesis.pdf_file.attach(io: StringIO.new(pdf), filename: "thesis.pdf")

    thesis.pdf_ready!

    # 3. Final broadcast to show the "Download Now" link
    Turbo::StreamsChannel.broadcast_replace_to(
      "thesis_#{thesis.id}",
      target: "actions_section",
      partial: "theses/actions",
      locals: { thesis: thesis }
    )
  end
end
