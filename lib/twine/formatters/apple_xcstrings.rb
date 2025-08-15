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
      def format_file(_lang)
        begin
          require 'json'
        rescue LoadError
          raise Twine::Error.new 'You must run `gem install json` to read/write .xcstrings files.'
        end

        if @options[:command] == "generate-all-localization-files"
          raise Twine::Error.new "Use `generate-localization-file` command instead for #{format_name} format"
        end

        strings_hash = {}

        @twine_file.sections.each do |section|
          section.definitions.each do |definition|
            language_locs = {}
            @twine_file.language_codes.each do |language_code|
              val = definition.translation_for_lang(language_code)
              next unless val
              language_locs[language_code] = {
                'stringUnit' => {
                  'state' => 'translated',
                  'value' => val
                }
              }
            end

            next if language_locs.empty?

            entry = { 'localizations' => language_locs }
            entry['comment'] = definition.comment if definition.comment && !definition.comment.empty?

            strings_hash[definition.key] = entry
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