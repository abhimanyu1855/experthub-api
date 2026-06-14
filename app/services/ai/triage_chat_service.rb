# frozen_string_literal: true

module Ai
  class TriageChatService
    def self.send_message(session:, content:)
      # 1. Append user message
      messages = session.messages.dup
      messages << { role: "user", content: content }

      # 2. Call Anthropic
      reply, parsed_recommendations = get_chatbot_reply(messages, session.tenant)

      # 3. Append assistant response
      messages << { role: "assistant", content: reply }
      
      # 4. Determine status
      status = parsed_recommendations.present? ? "triaged" : "active"

      # 5. Save changes
      session.update!(
        messages: messages,
        status: status
      )

      {
        reply: reply,
        status: status,
        recommendations: parsed_recommendations
      }
    end

    private_class_method def self.get_chatbot_reply(messages, tenant)
      api_key = ENV["ANTHROPIC_API_KEY"]
      
      categories = tenant.categories.pluck(:name, :slug).map { |n, s| "- #{n} (slug: #{s})" }.join("\n")
      system_prompt = <<~SYSTEM
        You are an AI triage assistant for "#{tenant.name}", a marketplace for consultation services.
        Your goal is to guide the user to the right category of experts.
        
        Available categories:
        #{categories}

        Keep your responses short, helpful, and friendly.
        Once you have identified the user's needs, output a JSON recommendations structure at the end of your response inside <recommendations> tags, matching the closest category slugs:
        
        <recommendations>
        {
          "category_slugs": ["slug-1", "slug-2"]
        }
        </recommendations>
        
        Only include categories that are in the list above. If none match, ask follow up questions.
      SYSTEM

      if api_key.blank? || api_key == "sk-ant-xxx"
        # Mock chatbot fallback for development/testing
        mock_reply = "Based on what you said, I think these services might help you."
        matched_slugs = []
        
        # Simple heuristic matching for test/dev
        last_message = messages.last[:content].to_s.downcase
        tenant.categories.each do |cat|
          if last_message.include?(cat.name.downcase) || last_message.include?(cat.slug.downcase)
            matched_slugs << cat.slug
          end
        end

        # Default fallback match if no match found but user seems done
        matched_slugs << tenant.categories.first.slug if matched_slugs.empty? && tenant.categories.any?

        recommendations_json = { "category_slugs" => matched_slugs }
        full_reply = "#{mock_reply}\n\n<recommendations>\n#{JSON.pretty_generate(recommendations_json)}\n</recommendations>"
        return [full_reply, recommendations_json]
      end

      # Construct request
      conn = Faraday.new(url: "https://api.anthropic.com") do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end

      # Clean messages structure for Claude
      formatted_messages = messages.map do |m|
        { role: m["role"] || m[:role], content: m["content"] || m[:content] }
      end

      response = conn.post("/v1/messages") do |req|
        req.headers["x-api-key"] = api_key
        req.headers["anthropic-version"] = "2023-06-01"
        req.body = {
          model: "claude-3-5-sonnet-20241022",
          max_tokens: 1000,
          system: system_prompt,
          messages: formatted_messages
        }
      end

      if response.success?
        reply_content = response.body.dig("content", 0, "text").to_s
        parsed_recs = extract_recommendations(reply_content)
        [reply_content, parsed_recs]
      else
        Rails.logger.error "Anthropic Triage Chat API error: #{response.status} - #{response.body}"
        ["I'm sorry, I encountered an error while trying to process your request.", nil]
      end
    end

    private_class_method def self.extract_recommendations(text)
      match = text.match(/<recommendations>(.*?)<\/recommendations>/m)
      return nil unless match

      begin
        JSON.parse(match[1].strip)
      rescue JSON::ParserError
        nil
      end
    end
  end
end
