class ThesesController < ApplicationController
  before_action :set_thesis, only: %i[show edit update approve_outline
                                    start_research start_drafting start_verification
                                    download_pdf add_chapter confirm_facts]

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
    # Only try to update if the 'thesis' key is present in params
    success = params[:thesis].present? ? @thesis.update(thesis_params) : true

    if success
      @thesis.regenerate_outline_from_chapters!
      @thesis.approve_outline!
      @thesis.update!(status: :research_in_progress)
      ResearchPapersJob.perform_later(@thesis.id)

      render turbo_stream: [
        turbo_stream.replace("thesis_status", partial: "theses/status", locals: { thesis: @thesis }),
        turbo_stream.replace("outline_section", partial: "theses/outline", locals: { thesis: @thesis }),
        turbo_stream.replace("research_section", partial: "theses/research_progress", locals: { thesis: @thesis }),
        turbo_stream.replace("actions_section", partial: "theses/actions", locals: { thesis: @thesis }),
        turbo_stream.replace("chapters_section", partial: "theses/chapters_section", locals: { thesis: @thesis }),
        turbo_stream.replace("chapter_progress", partial: "theses/chapter_progress", locals: { thesis: @thesis })
      ]
    else
      render :show, status: :unprocessable_entity
    end
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
    # Safety‑guard: fact review must be completed before drafting can begin
    unless @thesis.fact_review_completed?
      redirect_to @thesis, alert: "Please review and confirm the extracted facts before drafting."
      return
    end

    @thesis.chapters.each { |chapter| DraftChapterJob.perform_later(chapter.id) }
    @thesis.start_drafting!

    # Instantly show the chapter progress bar and remove the start button
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

  # This action is triggered when the user clicks "Confirm & Start Drafting"
  def confirm_facts
    # 1. Always reset all to false first (handles the "none selected" case)
    @thesis.extracted_facts.update_all(selected: false)

    # 2. Only set selected to true if IDs were actually checked
    if params[:fact_ids].present?
      @thesis.extracted_facts.where(id: params[:fact_ids]).update_all(selected: true)
    end

    @thesis.update!(fact_review_completed: true)
    @thesis.start_drafting!
    @thesis.chapters.each { |chapter| DraftChapterJob.perform_later(chapter.id) }

    render turbo_stream: [
      turbo_stream.replace("thesis_status", partial: "theses/status", locals: { thesis: @thesis }),
      turbo_stream.replace("research_section", partial: "theses/research_progress", locals: { thesis: @thesis }),
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

  def add_chapter
    @chapter = @thesis.chapters.build(order: @thesis.chapters.size)

    render turbo_stream: turbo_stream.append("chapters-fields",
      partial: "theses/chapter_fields",
      locals: { thesis: @thesis, chapter: @chapter })
  end

  private

  def set_thesis
    @thesis = Thesis.find(params[:id])
  end

  def thesis_params
    # We must permit chapters_attributes and the _destroy flag
    params.require(:thesis).permit(:topic, :cost_estimate,
      chapters_attributes: [ :id, :title, :order, :_destroy ])
  end
end
