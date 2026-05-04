class ChaptersController < ApplicationController
  before_action :set_thesis
  before_action :set_chapter, only: [ :show ]

  def show
  end

  private

  def set_thesis
    @thesis = Thesis.find(params[:thesis_id])
  end

  def set_chapter
    @chapter = @thesis.chapters.find(params[:id])
  end
end
