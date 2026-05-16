module DiacriticFolding
  MAP = {
    "ă" => "a", "â" => "a", "î" => "i",
    "ș" => "s", "ş" => "s",
    "ț" => "t", "ţ" => "t",
    "Ă" => "A", "Â" => "A", "Î" => "I",
    "Ș" => "S", "Ş" => "S",
    "Ț" => "T", "Ţ" => "T"
  }.freeze

  PATTERN = Regexp.union(MAP.keys).freeze

  def self.fold(string)
    return nil if string.nil?
    string.unicode_normalize(:nfc).gsub(PATTERN, MAP).downcase
  end
end
