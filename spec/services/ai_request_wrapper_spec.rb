# frozen_string_literal: true

require 'rails_helper'

RSpec.describe AiRequestWrapper, type: :service do
  before do
    described_class.reset!
  end

  after do
    described_class.reset!
  end

  describe '.call' do
    context 'when block is not given' do
      it 'raises ArgumentError' do
        expect { described_class.call(operation: 'test') }.to raise_error(ArgumentError, 'Block is required')
      end
    end

    context 'when block succeeds on first attempt' do
      it 'returns successful result with data' do
        result = described_class.call(operation: 'test') { 'success_data' }

        expect(result).to be_success
        expect(result.data).to eq('success_data')
        expect(result.error).to be_nil
        expect(result).not_to be_fallback
        expect(result.attempts).to eq(1)
        expect(result.latency_ms).to be > 0
      end

      it 'records success metric' do
        described_class.call(operation: 'test') { 'data' }

        metrics = described_class.current_metrics
        expect(metrics[:success_count]).to eq(1)
        expect(metrics[:failure_count]).to eq(0)
        expect(metrics[:retry_count]).to eq(0)
      end
    end

    context 'when block returns nil' do
      it 'returns successful result with nil data' do
        result = described_class.call(operation: 'test') { nil }

        expect(result).to be_success
        expect(result.data).to be_nil
      end
    end
  end

  describe 'retry with exponential backoff' do
    context 'when retryable error occurs then succeeds' do
      it 'retries and returns success' do
        attempts = 0

        allow(described_class).to receive(:sleep) # Stub sleep to speed up tests

        result = described_class.call(operation: 'test_retry') do
          attempts += 1
          raise Timeout::Error, 'connection timed out' if attempts < 2

          'retry_success'
        end

        expect(result).to be_success
        expect(result.data).to eq('retry_success')
        expect(result.attempts).to eq(2)
      end

      it 'records retry metric' do
        attempts = 0
        allow(described_class).to receive(:sleep)

        described_class.call(operation: 'test_retry') do
          attempts += 1
          raise Net::ReadTimeout, 'read timeout' if attempts < 2

          'data'
        end

        metrics = described_class.current_metrics
        expect(metrics[:retry_count]).to eq(1)
        expect(metrics[:success_count]).to eq(1)
      end
    end

    context 'when retryable error persists through all attempts' do
      it 'returns failure after max retries' do
        allow(described_class).to receive(:sleep)

        result = described_class.call(operation: 'test_all_fail', max_retries: 3) do
          raise Timeout::Error, 'persistent timeout'
        end

        expect(result).not_to be_success
        expect(result.error).to include('Timeout::Error')
        expect(result.error).to include('persistent timeout')
        expect(result.attempts).to eq(3)
      end

      it 'records failure metric' do
        allow(described_class).to receive(:sleep)

        described_class.call(operation: 'test_fail', max_retries: 2) do
          raise Timeout::Error, 'timeout'
        end

        metrics = described_class.current_metrics
        expect(metrics[:failure_count]).to eq(1)
        expect(metrics[:retry_count]).to eq(1) # 1 retry after first attempt
      end
    end

    context 'with Faraday errors' do
      it 'retries on Faraday::ConnectionFailed' do
        attempts = 0
        allow(described_class).to receive(:sleep)

        result = described_class.call(operation: 'faraday_test') do
          attempts += 1
          raise Faraday::ConnectionFailed, 'connection refused' if attempts < 2

          'faraday_success'
        end

        expect(result).to be_success
        expect(result.data).to eq('faraday_success')
      end
    end

    context 'with non-retryable errors' do
      it 'does not retry on StandardError' do
        attempts = 0

        result = described_class.call(operation: 'non_retryable') do
          attempts += 1
          raise StandardError, 'bad request'
        end

        expect(result).not_to be_success
        expect(attempts).to eq(1)
        expect(result.error).to include('StandardError')
      end
    end
  end

  describe 'circuit breaker' do
    before do
      allow(described_class).to receive(:sleep)
    end

    context 'when failures reach threshold' do
      it 'opens the circuit after 5 consecutive failures' do
        # Trigger 5 failures to open circuit
        5.times do
          described_class.call(operation: 'circuit_test', max_retries: 1) do
            raise Timeout::Error, 'timeout'
          end
        end

        # Next call should be rejected immediately
        result = described_class.call(operation: 'circuit_test') { 'should_not_execute' }

        expect(result).not_to be_success
        expect(result).to be_fallback
        expect(result.error).to include('Circuit breaker is open')
        expect(result.attempts).to eq(0)
      end

      it 'reports circuit state in metrics' do
        5.times do
          described_class.call(operation: 'circuit_metrics', max_retries: 1) do
            raise Timeout::Error, 'timeout'
          end
        end

        metrics = described_class.current_metrics
        expect(metrics[:circuit_state]).to eq(:open)
        expect(metrics[:circuit_failure_count]).to eq(5)
      end
    end

    context 'when circuit is open and cooldown elapses' do
      it 'transitions to half_open and allows one request' do
        # Open the circuit
        5.times do
          described_class.call(operation: 'cooldown_test', max_retries: 1) do
            raise Timeout::Error, 'timeout'
          end
        end

        # Simulate cooldown elapsed
        allow(Time).to receive(:current).and_return(Time.current + 61.seconds)

        # Should allow one request through (half_open)
        result = described_class.call(operation: 'cooldown_test') { 'recovered' }

        expect(result).to be_success
        expect(result.data).to eq('recovered')
      end

      it 'closes circuit on successful request after cooldown' do
        5.times do
          described_class.call(operation: 'close_test', max_retries: 1) do
            raise Timeout::Error, 'timeout'
          end
        end

        allow(Time).to receive(:current).and_return(Time.current + 61.seconds)

        described_class.call(operation: 'close_test') { 'success' }

        metrics = described_class.current_metrics
        expect(metrics[:circuit_state]).to eq(:closed)
        expect(metrics[:circuit_failure_count]).to eq(0)
      end
    end

    context 'when successful requests are made' do
      it 'resets failure count on success' do
        # Cause some failures (but not enough to open circuit)
        3.times do
          described_class.call(operation: 'reset_test', max_retries: 1) do
            raise Timeout::Error, 'timeout'
          end
        end

        # Success should reset counter
        described_class.call(operation: 'reset_test') { 'success' }

        metrics = described_class.current_metrics
        expect(metrics[:circuit_state]).to eq(:closed)
        expect(metrics[:circuit_failure_count]).to eq(0)
      end
    end

    context 'when authentication errors occur' do
      it 'does not count auth errors toward circuit breaker' do
        5.times do
          described_class.call(operation: 'auth_test') do
            raise StandardError, 'Invalid API key - unauthorized'
          end
        end

        # Circuit should still be closed (auth errors don't count)
        metrics = described_class.current_metrics
        expect(metrics[:circuit_state]).to eq(:closed)
      end
    end
  end

  describe '.current_metrics' do
    before do
      allow(described_class).to receive(:sleep)
    end

    it 'returns all metric fields' do
      metrics = described_class.current_metrics

      expect(metrics).to have_key(:success_count)
      expect(metrics).to have_key(:failure_count)
      expect(metrics).to have_key(:retry_count)
      expect(metrics).to have_key(:total_latency_ms)
      expect(metrics).to have_key(:total_calls)
      expect(metrics).to have_key(:avg_latency_ms)
      expect(metrics).to have_key(:circuit_state)
      expect(metrics).to have_key(:circuit_failure_count)
    end

    it 'calculates average latency correctly' do
      3.times { described_class.call(operation: 'latency') { 'data' } }

      metrics = described_class.current_metrics
      expect(metrics[:avg_latency_ms]).to be > 0
      expect(metrics[:total_calls]).to eq(3)
    end

    it 'returns zero avg latency when no calls made' do
      metrics = described_class.current_metrics
      expect(metrics[:avg_latency_ms]).to eq(0.0)
    end
  end

  describe '.reset!' do
    it 'resets all metrics and circuit state' do
      allow(described_class).to receive(:sleep)

      described_class.call(operation: 'test') { 'data' }
      described_class.call(operation: 'test', max_retries: 1) { raise Timeout::Error, 'err' }

      described_class.reset!

      metrics = described_class.current_metrics
      expect(metrics[:success_count]).to eq(0)
      expect(metrics[:failure_count]).to eq(0)
      expect(metrics[:retry_count]).to eq(0)
      expect(metrics[:circuit_state]).to eq(:closed)
    end
  end

  describe 'Result struct' do
    it 'responds to success? and fallback?' do
      result = AiRequestWrapper::Result.new(
        data: 'test',
        error: nil,
        success: true,
        fallback: false,
        attempts: 1,
        latency_ms: 10.5
      )

      expect(result).to be_success
      expect(result).not_to be_fallback
      expect(result.data).to eq('test')
      expect(result.attempts).to eq(1)
      expect(result.latency_ms).to eq(10.5)
    end
  end
end
