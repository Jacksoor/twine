module Twine
  module Formatters
    class AppleXcstrings < Abstract
      def format_name
        'apple-xcstrings'
      end

      def extension
        '.xcstrings'
      end

      def default_file_name
        'Localizable.xcstrings'
      end

      def can_handle_directory?(path)
        Dir.entries(path).any? { |item| /^.+#{Regexp.escape(extension)}$/.match(item) }
      end

      # There’s no language encoded in the path; return a sane default so the runner proceeds.
      def determine_language_given_path(path)
        @options[:developer_language] || 'en'
      end

      def read(io, _lang)
        begin
          require 'json'
        rescue LoadError
          raise Twine::Error.new 'You must run `gem install json` to read/write .xcstrings files.'
        end

        data = JSON.parse(io.read.to_s)

        strings = data['strings'] || {}
        strings.each do |key, entry|
          comment = entry['comment']

          (entry['localizations'] || {}).each do |lang, loc|
            value =
              if loc.is_a?(Hash) && loc['stringUnit'].is_a?(Hash)
                loc['stringUnit']['value']
              end

            next if value.nil?
            set_translation_for_key(key, lang, value)
            set_comment_for_key(key, comment) if comment
          end

        end
      end

      # Override to generate one multi-language JSON file.
      # Applies tag filtering and include semantics per language via OutputProcessor,
      # and limits languages according to --lang when provided.
      def format_file(_lang)
        begin
          require 'json'
        rescue LoadError
          raise Twine::Error.new 'You must run `gem install json` to read/write .xcstrings files.'
        end

        if @options[:command] == "generate-all-localization-files"
          raise Twine::Error.new "Use `generate-localization-file` command instead for #{format_name} format"
        end

        languages_to_emit = if @options[:languages] && @options[:languages].length > 0
          @options[:languages]
        else
          @twine_file.language_codes
        end

        output_processor = Processors::OutputProcessor.new(@twine_file, @options)
        strings_hash = {}

        languages_to_emit.each do |language_code|
          processed = output_processor.process(language_code)

          processed.sections.each do |section|
            section.definitions.each do |definition|
              value = definition.translation_for_lang(language_code)
              next unless value

              entry = strings_hash[definition.key] ||= { 'localizations' => {} }
              # Prefer first non-empty comment encountered
              if !entry.key?('comment') && definition.comment && !definition.comment.empty?
                entry['comment'] = definition.comment
              end

              entry['localizations'][language_code] = {
                'stringUnit' => {
                  'state' => 'translated',
                  'value' => value
                }
              }
            end
          end
        end

        return nil if strings_hash.empty?

        data = {
          'version' => '1.0',
          'generator' => "twine #{Twine::VERSION}",
          'sourceLanguage' => (@options[:developer_language] || @twine_file.language_codes.first || 'en'),
          'strings' => strings_hash
        }

        JSON.pretty_generate(data) + "\n"
      end
    end
  end
end
  
Twine::Formatters.formatters << Twine::Formatters::AppleXcstrings.new