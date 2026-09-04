class YearDocsController < ApplicationController
  def update
    year = Integer(params[:year], exception: false)
    head :bad_request and return unless year&.between?(1900, 2200)

    doc = year_docs.find_or_initialize_by(year: year)
    doc.body = year_doc_params[:body].to_s

    if doc.new_record? && doc.body.blank?
      render json: payload(doc, persisted: false)
    else
      doc.save!
      render json: payload(doc, persisted: true)
    end
  end

  private
    def year_doc_params
      params.fetch(:year_doc, ActionController::Parameters.new).permit(:body)
    end

    def payload(doc, persisted:)
      { year: doc.year, body: doc.body, persisted: persisted, url: year_doc_path(doc.year) }
    end
end
