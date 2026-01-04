# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ChatAnalytic, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      analytic = build(:chat_analytic)
      expect(analytic).to be_valid
    end

    it 'requires session_id' do
      analytic = build(:chat_analytic, session_id: nil)
      expect(analytic).not_to be_valid
      expect(analytic.errors[:session_id]).to be_present
    end

    it 'requires user_query' do
      analytic = build(:chat_analytic, user_query: nil)
      expect(analytic).not_to be_valid
      expect(analytic.errors[:user_query]).to be_present
    end

    it 'validates response_type inclusion' do
      analytic = build(:chat_analytic, response_type: 'invalid_type')
      expect(analytic).not_to be_valid
      expect(analytic.errors[:response_type]).to be_present
    end

    it 'accepts valid response_type values' do
      ChatAnalytic::RESPONSE_TYPES.each do |type|
        analytic = build(:chat_analytic, response_type: type)
        expect(analytic).to be_valid, "Expected #{type} to be valid"
      end
    end
  end

  describe 'associations' do
    it 'belongs to conversation optionally' do
      expect(ChatAnalytic.reflect_on_association(:conversation).macro).to eq(:belongs_to)
      expect(ChatAnalytic.reflect_on_association(:conversation).options[:optional]).to be true
    end

    it 'belongs to conversation_message optionally' do
      expect(ChatAnalytic.reflect_on_association(:conversation_message).macro).to eq(:belongs_to)
      expect(ChatAnalytic.reflect_on_association(:conversation_message).options[:optional]).to be true
    end
  end

  describe 'scopes' do
    let!(:with_results) { create(:chat_analytic, had_results: true) }
    let!(:without_results) { create(:chat_analytic, had_results: false) }
    let!(:quick_question) { create(:chat_analytic, is_quick_question: true) }
    let!(:brand_comparison) { create(:chat_analytic, is_brand_comparison: true) }
    let!(:old_record) { create(:chat_analytic, created_at: 10.days.ago) }
    let!(:recent_record) { create(:chat_analytic, created_at: 1.day.ago) }

    describe '.with_results' do
      it 'returns only records with results' do
        expect(described_class.with_results).to include(with_results)
        expect(described_class.with_results).not_to include(without_results)
      end
    end

    describe '.without_results' do
      it 'returns only records without results' do
        expect(described_class.without_results).to include(without_results)
        expect(described_class.without_results).not_to include(with_results)
      end
    end

    describe '.quick_questions' do
      it 'returns quick questions' do
        expect(described_class.quick_questions).to include(quick_question)
      end
    end

    describe '.brand_comparisons' do
      it 'returns brand comparisons' do
        expect(described_class.brand_comparisons).to include(brand_comparison)
      end
    end

    describe '.recent' do
      it 'returns records from last N days' do
        expect(described_class.recent(5)).to include(recent_record)
        expect(described_class.recent(5)).not_to include(old_record)
      end
    end
  end

  describe '.popular_queries' do
    before do
      3.times { create(:chat_analytic, normalized_query: 'winter tires', created_at: 1.day.ago) }
      2.times { create(:chat_analytic, normalized_query: 'summer tires', created_at: 1.day.ago) }
      1.times { create(:chat_analytic, normalized_query: 'all season', created_at: 1.day.ago) }
    end

    it 'returns queries sorted by count' do
      result = described_class.popular_queries(limit: 10, days: 7)

      expect(result.first[:query]).to eq('winter tires')
      expect(result.first[:count]).to eq(3)
      expect(result.second[:query]).to eq('summer tires')
      expect(result.second[:count]).to eq(2)
    end

    it 'respects limit' do
      result = described_class.popular_queries(limit: 2, days: 7)
      expect(result.size).to eq(2)
    end
  end

  describe '.no_results_queries' do
    before do
      2.times { create(:chat_analytic, normalized_query: 'rare size', had_results: false, created_at: 1.day.ago) }
      1.times { create(:chat_analytic, normalized_query: 'common size', had_results: true, created_at: 1.day.ago) }
    end

    it 'returns only queries without results' do
      result = described_class.no_results_queries(limit: 10, days: 7)

      queries = result.map { |r| r[:query] }
      expect(queries).to include('rare size')
      expect(queries).not_to include('common size')
    end
  end

  describe '.conversion_rate' do
    it 'calculates correct rate' do
      3.times { create(:chat_analytic, had_results: true, created_at: 1.day.ago) }
      2.times { create(:chat_analytic, had_results: false, created_at: 1.day.ago) }

      rate = described_class.conversion_rate(days: 7)
      expect(rate).to eq(60.0) # 3/5 = 60%
    end

    it 'returns 0 when no records' do
      expect(described_class.conversion_rate(days: 7)).to eq(0.0)
    end
  end

  describe '.average_response_time' do
    before do
      create(:chat_analytic, response_time_ms: 100, created_at: 1.day.ago)
      create(:chat_analytic, response_time_ms: 200, created_at: 1.day.ago)
      create(:chat_analytic, response_time_ms: 300, created_at: 1.day.ago)
    end

    it 'calculates average' do
      avg = described_class.average_response_time(days: 7)
      expect(avg).to eq(200.0)
    end
  end

  describe '.summary' do
    before do
      3.times { create(:chat_analytic, had_results: true, is_quick_question: true, products_count: 5, created_at: 1.day.ago) }
      2.times { create(:chat_analytic, had_results: false, is_brand_comparison: true, created_at: 1.day.ago) }
    end

    it 'returns comprehensive stats' do
      summary = described_class.summary(days: 7)

      expect(summary[:total_queries]).to eq(5)
      expect(summary[:queries_with_results]).to eq(3)
      expect(summary[:queries_without_results]).to eq(2)
      expect(summary[:quick_questions]).to eq(3)
      expect(summary[:brand_comparisons]).to eq(2)
      expect(summary[:conversion_rate]).to eq(60.0)
      expect(summary[:total_products_shown]).to eq(15)
    end
  end

  describe '.intent_distribution' do
    before do
      2.times { create(:chat_analytic, intent: 'winter_tires', created_at: 1.day.ago) }
      3.times { create(:chat_analytic, intent: 'size_selection', created_at: 1.day.ago) }
    end

    it 'returns intent counts' do
      dist = described_class.intent_distribution(days: 7)

      expect(dist['winter_tires']).to eq(2)
      expect(dist['size_selection']).to eq(3)
    end
  end

  describe '.hourly_distribution' do
    it 'groups by hour' do
      create(:chat_analytic, created_at: Time.current.change(hour: 10))
      create(:chat_analytic, created_at: Time.current.change(hour: 10))
      create(:chat_analytic, created_at: Time.current.change(hour: 14))

      dist = described_class.hourly_distribution(days: 1)

      expect(dist[10]).to eq(2)
      expect(dist[14]).to eq(1)
    end
  end
end
