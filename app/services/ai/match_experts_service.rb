# frozen_string_literal: true

module Ai
  class MatchExpertsService
    def self.match(query:, tenant:, limit: 5)
      return [] if query.blank?

      # Generate query embedding
      query_vector = fetch_query_embedding(query)
      return [] unless query_vector

      # Scope search to approved experts in this tenant
      expert_profile_ids = tenant.expert_profiles.approved.select(:id)

      # Query pgvector for closest neighbor matches (cosine distance)
      matches = ExpertEmbedding.where(expert_profile_id: expert_profile_ids)
                               .nearest_neighbors(:embedding, query_vector, distance: :cosine)
                               .limit(limit)

      # Return the expert profiles in order of similarity
      ExpertProfile.approved.where(id: matches.map(&:expert_profile_id))
    end

    private_class_method def self.fetch_query_embedding(text)
      api_key = ENV["OPENAI_API_KEY"]
      if api_key.blank? || api_key == "sk-xxx"
        # Mock embedding for test/dev environment
        Rails.logger.warn "No OPENAI_API_KEY found, generating mock embedding for query."
        return Array.new(1536) { rand - 0.5 }
      end

      conn = Faraday.new(url: "https://api.openai.com") do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end

      response = conn.post("/v1/embeddings") do |req|
        req.headers["Authorization"] = "Bearer #{api_key}"
        req.body = {
          model: "text-embedding-3-small",
          input: text
        }
      end

      if response.success?
        response.body.dig("data", 0, "embedding")
      else
        Rails.logger.error "OpenAI Embeddings API error: #{response.status} - #{response.body}"
        nil
      end
    end
  end
end
