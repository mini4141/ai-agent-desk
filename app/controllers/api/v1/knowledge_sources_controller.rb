module Api
  module V1
    class KnowledgeSourcesController < BaseController
      def index
        render json: { knowledge_sources: policy_scope(KnowledgeSource).order(:id).map(&:as_api) }
      end

      def create
        authorize KnowledgeSource
        source = KnowledgeSource.new(params.permit(:kind, :url, :title))
        if source.kind != "url"
          upload = params[:file]
          data = upload.respond_to?(:read) ? upload.read : params[:content].to_s
          source.s3_key = BlobStore.put("sources/#{current_user.company_id}/#{SecureRandom.hex(8)}.#{source.kind == 'pdf' ? 'pdf' : 'md'}", data)
        end
        source.save!
        IngestSourceJob.perform_async(source.id, current_user.company_id)
        render json: source.as_api, status: :created
      end

      def reindex
        source = KnowledgeSource.find(params[:id])
        authorize source, :reindex?
        source.update!(status: "pending")
        IngestSourceJob.perform_async(source.id, current_user.company_id)
        render json: source.as_api, status: :accepted
      end
    end
  end
end
