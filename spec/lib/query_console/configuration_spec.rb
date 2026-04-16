require 'rails_helper'

module QueryConsole
  RSpec.describe Configuration do
    let(:config) { Configuration.new }

    describe "autocomplete configuration" do
      describe "#autocomplete_enabled" do
        context "when both enable_autocomplete and schema_explorer are true" do
          it "returns true" do
            config.enable_autocomplete = true
            config.schema_explorer = true
            expect(config.autocomplete_enabled).to be true
          end
        end

        context "when enable_autocomplete is true but schema_explorer is false" do
          it "returns false" do
            config.enable_autocomplete = true
            config.schema_explorer = false
            expect(config.autocomplete_enabled).to be false
          end
        end

        context "when enable_autocomplete is false" do
          it "returns false" do
            config.enable_autocomplete = false
            config.schema_explorer = true
            expect(config.autocomplete_enabled).to be false
          end
        end
      end

      describe "#autocomplete_max_tables=" do
        it "accepts valid values between 1 and 1000" do
          expect { config.autocomplete_max_tables = 50 }.not_to raise_error
          expect(config.autocomplete_max_tables).to eq(50)
        end

        it "rejects values below 1" do
          expect { config.autocomplete_max_tables = 0 }.to raise_error(ArgumentError, /must be between 1 and 1000/)
        end

        it "rejects values above 1000" do
          expect { config.autocomplete_max_tables = 1001 }.to raise_error(ArgumentError, /must be between 1 and 1000/)
        end

        it "rejects non-integer values" do
          expect { config.autocomplete_max_tables = "50" }.to raise_error(ArgumentError, /must be between 1 and 1000/)
        end
      end

      describe "#autocomplete_max_columns_per_table=" do
        it "accepts valid values between 1 and 500" do
          expect { config.autocomplete_max_columns_per_table = 100 }.not_to raise_error
          expect(config.autocomplete_max_columns_per_table).to eq(100)
        end

        it "rejects values below 1" do
          expect { config.autocomplete_max_columns_per_table = 0 }.to raise_error(ArgumentError, /must be between 1 and 500/)
        end

        it "rejects values above 500" do
          expect { config.autocomplete_max_columns_per_table = 501 }.to raise_error(ArgumentError, /must be between 1 and 500/)
        end
      end

      describe "#autocomplete_cache_ttl_seconds=" do
        it "accepts positive values" do
          expect { config.autocomplete_cache_ttl_seconds = 600 }.not_to raise_error
          expect(config.autocomplete_cache_ttl_seconds).to eq(600)
        end

        it "rejects zero" do
          expect { config.autocomplete_cache_ttl_seconds = 0 }.to raise_error(ArgumentError, /must be positive/)
        end

        it "rejects negative values" do
          expect { config.autocomplete_cache_ttl_seconds = -10 }.to raise_error(ArgumentError, /must be positive/)
        end
      end

      describe "default values" do
        it "sets correct defaults" do
          expect(config.enable_autocomplete).to be true
          expect(config.autocomplete_max_tables).to eq(100)
          expect(config.autocomplete_max_columns_per_table).to eq(100)
          expect(config.autocomplete_cache_ttl_seconds).to eq(300)
        end
      end
    end
  end
end
