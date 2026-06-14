# frozen_string_literal: true

module Ai
  class GenerateSummaryService
    def self.summarize(booking:, transcript:)
      return nil if transcript.blank?

      summary_text, parsed_action_items = fetch_summary_and_action_items(booking, transcript)

      # Save to DB
      summary_record = SessionSummary.find_or_initialize_by(booking: booking)
      summary_record.update!(
        summary: summary_text,
        action_items: parsed_action_items || [],
        transcript: transcript
      )

      summary_record
    end

    private_class_method def self.fetch_summary_and_action_items(booking, transcript)
      api_key = ENV["ANTHROPIC_API_KEY"]

      system_prompt = <<~SYSTEM
        You are an AI meeting assistant. Analyze the transcript of a consultation booking between expert "#{booking.expert.displayed_name}" and client "#{booking.client.displayed_name}".
        Provide a concise high-level summary of the session.
        At the end of your response, output a JSON structure of action items inside <action_items> tags in this format:

        <action_items>
        [
          {
            "description": "Task description here",
            "assignee": "expert" or "client",
            "due_date": "YYYY-MM-DD" or null
          }
        ]
        </action_items>
      SYSTEM

      if api_key.blank? || api_key == "sk-ant-xxx"
        # Mock summary and action items for test/dev
        mock_summary = "During this consultation, the expert and client discussed project requirements, timeline, and budget. The expert offered guidance on technology choices."
        mock_action_items = [
          { "description" => "Share API credentials", "assignee" => "client", "due_date" => nil },
          { "description" => "Draft project scope document", "assignee" => "expert", "due_date" => (Date.current + 3.days).to_s }
        ]
        return [mock_summary, mock_action_items]
      end

      # Construct request to Claude
      conn = Faraday.new(url: "https://api.anthropic.com") do |f|
        f.request :json
        f.response :json
        f.adapter Faraday.default_adapter
      end

      response = conn.post("/v1/messages") do |req|
        req.headers["x-api-key"] = api_key
        req.headers["anthropic-version"] = "2023-06-01"
        req.body = {
          model: "claude-3-5-sonnet-20241022",
          max_tokens: 1500,
          system: system_prompt,
          messages: [
            { role: "user", content: "Analyze this transcript:\n\n#{transcript}" }
          ]
        }
      end

      if response.success?
        reply_content = response.body.dig("content", 0, "text").to_s
        
        # Extract the summary text by stripping the action items block
        summary_clean = reply_content.gsub(/<action_items>.*?<\/action_items>/m, "").strip
        action_items = extract_action_items(reply_content)

        [summary_clean, action_items]
      else
        Rails.logger.error "Anthropic Summary API error: #{response.status} - #{response.body}"
        ["An error occurred while generating the session summary.", []]
      end
    end

    private_class_method def self.extract_action_items(text)
      match = text.match(/<action_items>(.*?)<\/action_items>/m)
      return [] unless match

      begin
        JSON.parse(match[1].strip)
      rescue JSON::ParserError
        []
      end
    end
  end
end
