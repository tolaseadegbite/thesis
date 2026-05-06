class ChaptersController < ApplicationController
  before_action :set_thesis
  before_action :set_chapter, only: [ :show, :destroy ]

  def show
  end

  def destroy
    @chapter.destroy!
    @thesis.chapters.order(:order).each_with_index { |ch, idx| ch.update(order: idx) }
    @thesis.regenerate_outline_from_chapters!

    render turbo_stream: turbo_stream.update("chapters-fields",
      partial: "theses/chapters_fields", locals: { thesis: @thesis })
  end

  private

  def set_thesis
    @thesis = Thesis.find(params[:thesis_id])
  end

  def set_chapter
    @chapter = @thesis.chapters.find(params[:id])
  end
end
