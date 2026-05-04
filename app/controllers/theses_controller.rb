class ThesesController < ApplicationController
  before_action :set_thesis, only: %i[show edit update approve_outline
                                      start_research start_drafting start_verification
                                      download_pdf]

  def index
    @theses = Thesis.order(created_at: :desc)
  end

  def show; end

  def new
    @thesis = Thesis.new
  end

  def create
    @thesis = Thesis.new(thesis_params)
    if @thesis.save
      redirect_to @thesis, notice: "Thesis created. Generating outline..."
      GenerateOutlineJob.perform_later(@thesis.id)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit; end

  def update
    if @thesis.update(thesis_params)
      redirect_to @thesis, notice: "Thesis updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def approve_outline
    @thesis.approve_outline!                       # status → outline_approved
    @thesis.update!(status: :research_in_progress) # status → research_in_progress
    ResearchPapersJob.perform_later(@thesis.id)

    render turbo_stream:[
      turbo_stream.replace("thesis_status", partial: "theses/status", locals: { thesis: @thesis }),
      turbo_stream.replace("research_section", partial: "theses/research_progress", locals: { thesis: @thesis }),
      turbo_stream.replace("actions_section", partial: "theses/actions", locals: { thesis: @thesis }),
      # ADD THIS LINE to inject the chapters when approved:
      turbo_stream.replace("chapters_section", partial: "theses/chapters_section", locals: { thesis: @thesis })
    ]
  end

  def start_research
    ResearchPapersJob.perform_later(@thesis.id)

    render turbo_stream: [
      turbo_stream.replace("thesis_status", partial: "theses/status", locals: { thesis: @thesis }),
      turbo_stream.replace("research_section", partial: "theses/research_progress", locals: { thesis: @thesis }),
      turbo_stream.replace("actions_section", partial: "theses/actions", locals: { thesis: @thesis })
    ]
  end

  def start_drafting
    @thesis.chapters.each { |chapter| DraftChapterJob.perform_later(chapter.id) }
    @thesis.start_drafting!

    # Instantly trigger the chapter progress bar and remove the start button
    render turbo_stream: [
      turbo_stream.replace("thesis_status", partial: "theses/status", locals: { thesis: @thesis }),
      turbo_stream.replace("chapter_progress", partial: "theses/chapter_progress", locals: { thesis: @thesis }),
      turbo_stream.replace("actions_section", partial: "theses/actions", locals: { thesis: @thesis })
    ]
  end

  def start_verification
    @thesis.chapters.each { |chapter| VerifyChapterJob.perform_later(chapter.id) }
    @thesis.start_verification!

    # Instantly transition the progress bar to "Verifying" and remove the start button
    render turbo_stream: [
      turbo_stream.replace("thesis_status", partial: "theses/status", locals: { thesis: @thesis }),
      turbo_stream.replace("chapter_progress", partial: "theses/chapter_progress", locals: { thesis: @thesis }),
      turbo_stream.replace("actions_section", partial: "theses/actions", locals: { thesis: @thesis })
    ]
  end

  def download_pdf
    pdf_html = render_to_string(template: "theses/pdf", locals: { thesis: @thesis })
    pdf = FerrumPdf.render_pdf(html: pdf_html,
                               pdf_options: { paper_width: 8.5, paper_height: 11 })
    send_data pdf, filename: "#{@thesis.topic.parameterize}.pdf", type: :pdf
  end

  private

  def set_thesis
    @thesis = Thesis.find(params[:id])
  end

  def thesis_params
    params.require(:thesis).permit(:topic, :cost_estimate)
  end
end
