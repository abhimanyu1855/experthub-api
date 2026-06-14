# frozen_string_literal: true

class GenerateEmbeddingJob < ApplicationJob
  queue_as :default

  def perform(expert_profile_id)
    expert_profile = ExpertProfile.find_by(id: expert_profile_id)
    return unless expert_profile&.approved?

    # Prepare document for embedding
    categories_names = expert_profile.services.includes(:category).map { |s| s.category&.name }.compact.uniq.join(", ")
    services_titles = expert_profile.services.map(&:title).uniq.join(", ")
    
    text_to_embed = [
      expert_profile.title,
      expert_profile.specialization,
      expert_profile.bio,
      services_titles,
      categories_names
    ].compact.reject(&:empty?).join(" | ")

    # Calculate content hash to avoid duplicate API calls
    content_hash = Digest::SHA256.hexdigest(text_to_embed)
    existing_embedding = expert_profile.expert_embedding
    
    if existing_embedding && existing_embedding.content_hash == content_hash
      # No changes, skip
      return
    end

    # Fetch embedding from OpenAI
    embedding_vector = fetch_openai_embedding(text_to_embed)
    return unless embedding_vector

    if existing_embedding
      existing_embedding.update!(embedding: embedding_vector, content_hash: content_hash)
    else
      expert_profile.create_expert_embedding!(embedding: embedding_vector, content_hash: content_hash)
    end
  end

  private

  def fetch_openai_embedding(text)
    api_key = ENV["OPENAI_API_KEY"]
    if api_key.blank? || api_key == "sk-xxx"
      # Fallback to dummy mock embedding for development/testing if API key is not configured
      Rails.logger.warn "No OPENAI_API_KEY found, generating mock embedding vector."
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
      Rails.logger.error "OpenAI Embedding API Error: #{response.status} - #{response.body}"
      nil
    end
  end
end
