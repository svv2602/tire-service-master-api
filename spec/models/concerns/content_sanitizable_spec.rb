# frozen_string_literal: true

require 'rails_helper'

RSpec.describe ContentSanitizable do
  # Create a test model class that includes the concern
  let(:test_class) do
    Class.new do
      include ActiveModel::Model
      include ActiveModel::Callbacks
      include ContentSanitizable

      attr_accessor :content, :title

      define_model_callbacks :save

      def self.name
        'TestModel'
      end

      # Simulate sanitizable_fields class attribute
      class_attribute :sanitizable_fields, default: []

      # Define fields to sanitize
      def self.sanitize_fields(*fields)
        self.sanitizable_fields = fields.map(&:to_sym)
      end

      sanitize_fields :content

      def save
        run_callbacks :save do
          true
        end
      end
    end
  end

  let(:model) { test_class.new }

  describe 'ALLOWED_TAGS' do
    it 'includes common formatting tags' do
      expect(ContentSanitizable::ALLOWED_TAGS).to include('p', 'br', 'strong', 'em', 'b', 'i')
    end

    it 'includes heading tags' do
      expect(ContentSanitizable::ALLOWED_TAGS).to include('h1', 'h2', 'h3', 'h4', 'h5', 'h6')
    end

    it 'includes list tags' do
      expect(ContentSanitizable::ALLOWED_TAGS).to include('ul', 'ol', 'li')
    end

    it 'includes table tags' do
      expect(ContentSanitizable::ALLOWED_TAGS).to include('table', 'thead', 'tbody', 'tr', 'td', 'th')
    end

    it 'includes link and image tags' do
      expect(ContentSanitizable::ALLOWED_TAGS).to include('a', 'img')
    end
  end

  describe '#sanitize_content_fields' do
    context 'with safe HTML content' do
      it 'allows safe tags to pass through' do
        model.content = '<p>Hello <strong>World</strong></p>'
        model.save
        expect(model.content).to include('<p>')
        expect(model.content).to include('<strong>')
      end

      it 'allows list tags' do
        model.content = '<ul><li>Item 1</li><li>Item 2</li></ul>'
        model.save
        expect(model.content).to include('<ul>')
        expect(model.content).to include('<li>')
      end

      it 'allows links with href' do
        model.content = '<a href="https://example.com">Link</a>'
        model.save
        expect(model.content).to include('<a')
        expect(model.content).to include('href')
      end

      it 'allows images with src and alt' do
        model.content = '<img src="https://example.com/image.jpg" alt="Test Image">'
        model.save
        expect(model.content).to include('<img')
        expect(model.content).to include('src=')
        expect(model.content).to include('alt=')
      end
    end

    context 'with script tags (XSS attempts)' do
      it 'removes script tags completely' do
        model.content = '<p>Hello</p><script>alert("XSS")</script><p>World</p>'
        model.save
        expect(model.content).not_to include('<script')
        expect(model.content).not_to include('alert')
        expect(model.content).to include('<p>Hello</p>')
        expect(model.content).to include('<p>World</p>')
      end

      it 'removes inline script in tags' do
        model.content = '<p>Test</p><script type="text/javascript">document.cookie</script>'
        model.save
        expect(model.content).not_to include('script')
        expect(model.content).not_to include('document.cookie')
      end
    end

    context 'with event handlers (XSS attempts)' do
      it 'removes onclick handlers' do
        model.content = '<p onclick="alert(1)">Click me</p>'
        model.save
        expect(model.content).not_to include('onclick')
        expect(model.content).to include('Click me')
      end

      it 'removes onerror handlers' do
        model.content = '<img src="x" onerror="alert(1)">'
        model.save
        expect(model.content).not_to include('onerror')
      end

      it 'removes onload handlers' do
        model.content = '<body onload="alert(1)">Content</body>'
        model.save
        expect(model.content).not_to include('onload')
      end

      it 'removes onmouseover handlers' do
        model.content = '<div onmouseover="alert(1)">Hover</div>'
        model.save
        expect(model.content).not_to include('onmouseover')
      end
    end

    context 'with javascript: URLs' do
      it 'removes javascript: URLs from href attributes' do
        model.content = '<a href="javascript:alert(1)">Click</a>'
        model.save
        expect(model.content).not_to include('javascript:')
      end

      it 'removes data: URLs from href attributes' do
        model.content = '<a href="data:text/html,<script>alert(1)</script>">Link</a>'
        model.save
        expect(model.content).not_to include('data:')
      end

      it 'removes vbscript: URLs from href attributes' do
        model.content = '<a href="vbscript:msgbox(1)">Link</a>'
        model.save
        expect(model.content).not_to include('vbscript:')
      end

      it 'allows safe URL schemes' do
        model.content = '<a href="https://example.com">HTTPS</a> <a href="mailto:test@test.com">Email</a>'
        model.save
        expect(model.content).to include('https://example.com')
        expect(model.content).to include('mailto:test@test.com')
      end
    end

    context 'with blank content' do
      it 'handles nil content gracefully' do
        model.content = nil
        expect { model.save }.not_to raise_error
        expect(model.content).to be_nil
      end

      it 'handles empty string content' do
        model.content = ''
        expect { model.save }.not_to raise_error
        expect(model.content).to eq('')
      end
    end

    context 'with mixed safe and unsafe content' do
      it 'removes only dangerous parts and keeps safe parts' do
        model.content = <<~HTML
          <h1>Title</h1>
          <p>Normal paragraph</p>
          <script>malicious()</script>
          <p onclick="bad()">Text with handler</p>
          <a href="javascript:void(0)">Bad link</a>
          <a href="https://safe.com">Safe link</a>
        HTML
        model.save

        expect(model.content).to include('<h1>Title</h1>')
        expect(model.content).to include('<p>Normal paragraph</p>')
        expect(model.content).not_to include('script')
        expect(model.content).not_to include('onclick')
        expect(model.content).not_to include('javascript:')
        expect(model.content).to include('https://safe.com')
      end
    end
  end

  describe 'field configuration' do
    it 'only sanitizes configured fields' do
      model.content = '<script>alert(1)</script>'
      model.title = '<script>alert(1)</script>'
      model.save

      expect(model.content).not_to include('<script')
      # title is not in sanitizable_fields, so it should remain unchanged
      expect(model.title).to eq('<script>alert(1)</script>')
    end
  end
end
