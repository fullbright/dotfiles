from collections import defaultdict
#import requests  # For downloading word lists (optional)

# Sample TLDs (add more cheap ones)
cheap_tlds = ['.to', '.it', '.me', '.in', '.xyz', '.top', '.site']

# Load word list (replace with your file path or URL)
def load_words(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return [line.strip().lower() for line in f if line.strip()]

# Group words by their endings
def group_by_ending(words, tld):
    ending_groups = defaultdict(list)
    tld_len = len(tld) - 1  # Exclude the dot
    for word in words:
        if len(word) > tld_len and word.endswith(tld[1:]):  # Match TLD without dot
            suffix = word[-tld_len-4:-tld_len] + tld  # e.g., "shot.to"
            prefix = word[:-tld_len-4]  # e.g., "snap"
            if prefix and 3 <= len(suffix) - tld_len <= 6:  # Short domain (3-6 chars)
                ending_groups[suffix].append(prefix)
    return ending_groups

# Find best suffixes and generate SaaS names
def find_best_suffixes(ending_groups, min_matches=3):
    best_suffixes = {}
    for suffix, prefixes in ending_groups.items():
        if len(prefixes) >= min_matches:  # At least 3 matching words
            best_suffixes[suffix] = prefixes[:10]  # Limit to 10 for brevity
    return best_suffixes

# Main function
def suggest_domains(word_file, tlds):
    words = load_words(word_file)
    for tld in tlds:
        print(f"\nAnalyzing TLD: {tld}")
        groups = group_by_ending(words, tld)
        best = find_best_suffixes(groups)
        for suffix, prefixes in best.items():
            print(f"Domain: {suffix}")
            print("Possible SaaS names:")
            for prefix in prefixes:
                print(f"  {prefix}.{suffix}")
            print()

# Example usage
word_file = "english_words.txt"  # Replace with your dictionary file
suggest_domains(word_file, cheap_tlds)