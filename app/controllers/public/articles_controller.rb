module Public
  # Read-only knowledge articles for the Next.js help center (server-rendered for SEO).
  class ArticlesController < ApplicationController
    def index
      with_company do |company|
        sources = KnowledgeSource.where(status: "ready").order(:id).to_a
        chunks = KnowledgeChunk.where(knowledge_source_id: sources.map(&:id)).order(:id).pluck(:knowledge_source_id, :content).group_by(&:first)
        articles = sources.map do |s|
          body = chunks.fetch(s.id, []).map(&:last)
          { id: s.id, title: s.title, excerpt: body.first.to_s.split("\n", 2).last.to_s.truncate(120), body: }
        end
        q = params[:q].to_s.strip
        articles = articles.select { |a| "#{a[:title]} #{a[:body].join(' ')}".downcase.include?(q.downcase) } if q.present?
        render json: { company: company_json(company), articles: articles.map { |a| a.except(:body) } }
      end
    end

    def show
      with_company do |company|
        source = KnowledgeSource.find(params[:id])
        render json: { company: company_json(company), article: { id: source.id, title: source.title, sections: source.knowledge_chunks.order(:id).pluck(:content).map { |c| c.split("\n", 2) } } }
      end
    end

    private

    def with_company
      company = ActsAsTenant.without_tenant { Company.find_by!(slug: params[:slug]) }
      ActsAsTenant.with_tenant(company) { yield company }
    end

    def company_json(company) = { name: company.name, slug: company.slug, locale: company.locale, public_key: company.public_key }
  end
end
