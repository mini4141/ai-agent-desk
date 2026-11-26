# Sidekiq jobs run outside a request, so every job re-establishes its tenant explicitly.
module TenantJob
  def with_company(company_id, &block)
    ActsAsTenant.with_tenant(Company.find(company_id), &block)
  end
end
