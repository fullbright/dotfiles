# Data Analysis Script Setup and Usage Guide

## 🚀 Quick Start

### 1. Installation
```bash
# Install required dependencies
pip install -r requirements.txt
```

### 2. Basic Usage
```bash
# Run with default settings
python data_analysis.py

# Run in dry-run mode (recommended first run)
python data_analysis.py --dry-run

# Run with custom paths
python data_analysis.py \
    --s3-input "/path/to/s3/csv/files" \
    --route53-input "/path/to/route53/csv/files" \
    --s3-output "/path/to/s3/output" \
    --route53-output "/path/to/route53/output"
```

## 📁 Directory Structure

By default, the script expects this directory structure:
```
script_directory/
├── data_analysis.py
├── requirements.txt
├── input/
│   ├── s3_data/
│   │   ├── bucket_type1_20231201.csv
│   │   ├── bucket_type1_20231215.csv  (latest will be used)
│   │   └── bucket_type2_20231201.csv
│   └── route53_data/
│       ├── rxdigitalplatform.co_20231201.csv
│       ├── rxds-a_domains_20231201.csv
│       └── rxds-b_domains_20231215.csv
├── output/
│   ├── s3_reports/
│   │   ├── S3 Buckets  - Publishers & Consumers.xlsx
│   │   └── S3 Buckets  - Publishers & Consumers_20231215_1430.xlsx
│   └── route53_reports/
│       ├── Route53_RxDS.xlsx
│       └── Route53_RxDS_20231215_1430.xlsx
└── logs/
    └── data_analysis_20231215_1430.log
```

## 📊 Input CSV File Formats

### Route 53 CSV Files
Expected filename format: `<type>_YYYYMMDD.csv`

**Required Types:**
- `rxdigitalplatform.co_YYYYMMDD.csv`
- `rxds-a_domains_YYYYMMDD.csv` 
- `rxds-b_domains_YYYYMMDD.csv`

**Required Columns:**
```
appli, env, module, name, ttl, type, value
```

**Filter Logic:** Only rows where `type` column equals "NAME" or "CNAME"

### S3 Bucket CSV Files
Expected filename format: `<type>_YYYYMMDD.csv`

**Required Columns:**
```
account_name, resourceid, application, environment, versioningstatus, encryption, bucketpolicy
```

**Processing:** Sorted by `account_name` (ascending), then `environment` (ascending)

## 🛠️ Command Line Options

| Option | Description | Default |
|--------|-------------|---------|
| `--s3-input` | S3 input folder path | `./input/s3_data` |
| `--route53-input` | Route53 input folder path | `./input/route53_data` |
| `--s3-output` | S3 output folder path | `./output/s3_reports` |
| `--route53-output` | Route53 output folder path | `./output/route53_reports` |
| `--log-folder` | Log files folder path | `./logs` |
| `--prev-route53-excel` | Previous Route53 Excel file (optional) | None |
| `--prev-s3-excel` | Previous S3 Excel file (optional) | None |
| `--dry-run` | Enable dry-run mode | False |

## 🎯 Output Files

### Route53 Reports
- **Timestamped:** `Route53_RxDS_YYYYMMDD_HHMM.xlsx`
- **Current:** `Route53_RxDS.xlsx`
- **Sheets:** 
  - `rxdigitalplatform` (from rxdigitalplatform.co CSV)
  - `rxds-a` (from rxds-a_domains CSV)  
  - `rxds-b` (from rxds-b_domains CSV)

### S3 Reports  
- **Timestamped:** `S3 Buckets  - Publishers & Consumers_YYYYMMDD_HHMM.xlsx`
- **Current:** `S3 Buckets  - Publishers & Consumers.xlsx`
- **Sheets:** 
  - `S3_Buckets` (combined and sorted data)

### Log Files
- **Format:** `data_analysis_YYYYMMDD_HHMM.log`
- **Content:** Detailed timestamped execution log with color-coded console output

## ⚠️ Error Handling

### Missing CSV Files
- **Behavior:** Empty Excel sheet created with warning
- **Console/Log:** Colorful warning with instructions to modify script

### Invalid CSV Structure  
- **Behavior:** Script exits with detailed error
- **Console/Log:** Shows expected vs actual columns

### Corrupted Excel Files
- **Behavior:** Script exits with error
- **Action:** Fix or remove corrupted file

### Missing Excel Files
- **Behavior:** Warning logged, script continues
- **Action:** No action required

## 🔧 Customization

### Adding New Route53 Types

To add or modify Route53 types, edit the `ROUTE53_TYPES` dictionary in `data_analysis.py`:

```python
ROUTE53_TYPES = {
    'rxdigitalplatform.co': 'rxdigitalplatform',
    'rxds-a_domains': 'rxds-a',
    'rxds-b_domains': 'rxds-b',
    'new_domain_type': 'new_sheet_name'  # Add new mapping here
}
```

### Adding S3 Data Transformations

The script includes placeholder methods for additional S3 transformations. To add new transformations, modify the `apply_s3_transformations` method:

```python
def apply_s3_transformations(self, data: List[Dict]) -> List[Dict]:
    """Apply transformations to S3 data."""
    # Current: sorting by account_name and environment
    transformed_data = self.sort_s3_data(data)
    
    # Add your custom transformations here:
    # transformed_data = self._filter_by_encryption(transformed_data)
    # transformed_data = self._standardize_naming(transformed_data)
    # transformed_data = self._add_calculated_fields(transformed_data)
    
    return transformed_data
```

### Modifying Filter Criteria

To change Route53 filter values, modify the `ROUTE53_FILTER_VALUES` constant:

```python
ROUTE53_FILTER_VALUES = ['NAME', 'CNAME', 'A', 'AAAA']  # Add more types as needed
```

### Customizing Output Format

To modify Excel formatting, edit the `write_data_to_sheet` method:

```python
def write_data_to_sheet(self, wb: Workbook, sheet_name: str, data: List[Dict]):
    # Modify cell formatting, colors, fonts, etc.
    cell.font = Font(bold=True, color="FFFFFF")
    cell.fill = PatternFill(start_color="366092", end_color="366092", fill_type="solid")
```

## 🐛 Troubleshooting

### Common Issues

#### 1. Import Error: No module named 'openpyxl'
```bash
# Solution: Install requirements
pip install -r requirements.txt
```

#### 2. Permission Denied Error
```bash
# Solution: Check folder permissions or run with appropriate privileges
chmod 755 /path/to/folders
```

#### 3. CSV Encoding Issues
```bash
# The script uses UTF-8 encoding by default
# If you have encoding issues, check your CSV file encoding
file -bi your_file.csv
```

#### 4. No CSV Files Found
```bash
# Check file naming convention: <type>_YYYYMMDD.csv
# Example: rxdigitalplatform.co_20231215.csv
```

### Debug Mode

For detailed debugging, check the log file in the logs folder:

```bash
tail -f logs/data_analysis_YYYYMMDD_HHMM.log
```

## 📝 Configuration Examples

### Example 1: Custom Paths with Absolute Directories
```bash
python data_analysis.py \
    --s3-input "/opt/data/s3_csv_files" \
    --route53-input "/opt/data/route53_csv_files" \
    --s3-output "/opt/reports/s3" \
    --route53-output "/opt/reports/route53" \
    --log-folder "/var/log/data_analysis"
```

### Example 2: With Previous Excel Files for Reference
```bash
python data_analysis.py \
    --prev-route53-excel "/path/to/previous/Route53_RxDS.xlsx" \
    --prev-s3-excel "/path/to/previous/S3_Buckets.xlsx"
```

### Example 3: Dry Run Before Production
```bash
# First, test with dry run
python data_analysis.py --dry-run

# Then run for real
python data_analysis.py
```

## 🔒 Security Considerations

1. **File Permissions:** Ensure proper read/write permissions on input/output directories
2. **Path Traversal:** The script validates paths to prevent directory traversal attacks  
3. **Data Sanitization:** CSV data is cleaned and validated before processing
4. **Error Handling:** Sensitive information is not logged in error messages

## 📈 Performance Tips

1. **Large Files:** For very large CSV files, consider processing in chunks
2. **Memory Usage:** Monitor memory usage when processing multiple large files
3. **Network Storage:** Use local storage for better I/O performance
4. **Parallel Processing:** Future enhancement could include parallel CSV processing

## 🔄 Maintenance

### Regular Tasks
1. **Log Cleanup:** Regularly clean old log files from the logs directory
2. **Output Cleanup:** Archive old timestamped output files
3. **Validation:** Periodically validate that CSV file structures haven't changed
4. **Updates:** Keep openpyxl library updated for latest Excel features

### Code Maintenance
- The code is organized in a single class for easy maintenance
- All constants are defined at the class level for easy modification
- Logging is comprehensive for troubleshooting
- Error handling covers all major failure scenarios

## 📞 Support

For issues or enhancements:
1. Check the log files for detailed error information
2. Verify input file formats and structures
3. Test with dry-run mode first
4. Review the troubleshooting section above

---

**Version:** 1.0  
**Last Updated:** December 2023  
**Requirements:** Python 3.6+, openpyxl 3.1.2+