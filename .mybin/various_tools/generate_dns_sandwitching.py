import sys
import glob
import datetime
from collections import defaultdict

# Define tech-related TLDs
#tech_tlds = ['.tech', '.io', '.ai', '.dev', '.app', '.cloud', '.software', '.online', '.systems', '.network', '.code', '.data', '.digital', '.services', '.solutions']
tech_tlds = ['.to', '.it', '.me', '.in', '.xyz', '.top', '.site', '.tech', '.io', '.ai', '.dev', '.app', '.cloud', '.software', '.online', '.systems', '.network', '.code', '.data', '.digital', '.services', '.solutions']

# Function to load words from a file
def load_words(file_path):
    with open(file_path, 'r', encoding='utf-8') as f:
        return [line.strip().lower() for line in f if line.strip()]

# Function to group words by their endings based on TLD
def group_by_ending(words, tld):
    ending_groups = defaultdict(list)
    tld_clean = tld[1:]  # Remove the dot
    tld_len = len(tld_clean)
    for word in words:
        if len(word) > tld_len and word.endswith(tld_clean):
            # Try different suffix lengths (1 to 4 chars before TLD)
            for i in range(1, min(5, len(word) - tld_len + 1)):
                suffix = word[-tld_len - i:-tld_len] + tld
                if 3 <= len(suffix) - tld_len <= 6:  # Domain part 3-6 chars
                    prefix = word[:-tld_len - i]
                    if prefix:
                        ending_groups[suffix].append(prefix)
    return ending_groups

# Function to find best suffixes with a minimum number of matches
def find_best_suffixes(ending_groups, min_matches=3):
    best_suffixes = []
    for suffix, prefixes in ending_groups.items():
        if len(prefixes) >= min_matches:
            best_suffixes.append((suffix, prefixes[:10]))  # Limit to 10 prefixes
    # Sort by number of prefixes (largest first)
    best_suffixes.sort(key=lambda x: len(x[1]), reverse=True)
    return best_suffixes

# Function to suggest domains and output to console and file
def suggest_domains(word_file, tlds, output_file):
    words = load_words(word_file)
    for tld in tlds:
        output = f"\nAnalyzing TLD: {tld} for {word_file}\n"
        print(output, end='')
        output_file.write(output)
        
        groups = group_by_ending(words, tld)
        best = find_best_suffixes(groups)
        
        if not best:
            output = "No suitable domains found.\n"
            print(output, end='')
            output_file.write(output)
            continue
        
        for suffix, prefixes in best:
            output = f"Domain: {suffix} ({len(prefixes)} prefixes)\nPossible SaaS names:\n"
            print(output, end='')
            output_file.write(output)
            for prefix in prefixes:
                output = f"  {prefix}.{suffix}\n"
                print(output, end='')
                output_file.write(output)
            output = "\n"
            print(output, end='')
            output_file.write(output)

# Main logic
def main():
    # Create timestamped output file
    timestamp = datetime.datetime.now().strftime("%Y%m%d_%H%M%S")
    output_filename = f"domain_suggestions_{timestamp}.txt"
    
    with open(output_filename, 'w', encoding='utf-8') as output_file:
        # Check for command line argument
        if len(sys.argv) > 1:
            word_files = [sys.argv[1]]
        else:
            word_files = glob.glob("*.tld.txt")
            if not word_files:
                error_msg = "No .tld.txt files found. Please provide a word list file or place .tld.txt files in the directory.\n"
                print(error_msg)
                output_file.write(error_msg)
                sys.exit(1)
        
        for word_file in word_files:
            output = f"Analyzing {word_file}\n"
            print(output, end='')
            output_file.write(output)
            suggest_domains(word_file, tech_tlds, output_file)

if __name__ == "__main__":
    main()