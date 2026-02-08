# Screenshot Guidelines

This directory contains screenshots for the Query Console README.

## Required Screenshots

### 1. Query Execution (`query-execution.png`)
- **Size**: 800x400px minimum
- **Content**: Main interface showing SQL query execution with results
- **Elements to show**:
  - SQL editor with sample query
  - Results table with data
  - Execution time and row count
  - Action buttons (Run, Explain, Clear)

### 2. DML Confirmation Dialog (`dml-confirmation.png`)
- **Size**: 600x300px minimum
- **Content**: Confirmation dialog for DML operations
- **Elements to show**:
  - Warning icon
  - Clear warning message about permanent changes
  - Cancel and OK buttons
  - Background overlay

### 3. Schema Explorer (`schema-explorer.png`)
- **Size**: 800x400px minimum
- **Content**: Schema browser interface
- **Elements to show**:
  - Table list with search
  - Expanded table with columns
  - Column details (name, type, nullable)
  - Quick action buttons (SELECT, WHERE, Copy)

### 4. Query History & Management (`query-history.png`)
- **Size**: 800x400px minimum
- **Content**: History and saved queries panels
- **Elements to show**:
  - Recent queries list with timestamps
  - Saved queries with tags
  - Management buttons (Save, Export, Import)

## How to Create Screenshots

### Using the Test Server

```bash
# Start the test server
cd query_console
./bin/test_server

# Visit http://localhost:9292/query_console
# Take screenshots using your browser's screenshot tool
```

### Recommended Tools

- **macOS**: Cmd+Shift+4 (select area) or Cmd+Shift+5 (screenshot utility)
- **Windows**: Windows+Shift+S (Snipping Tool)
- **Linux**: Flameshot, GNOME Screenshot, or KDE Spectacle
- **Browser Extensions**: Awesome Screenshot, Nimbus Screenshot

### Image Optimization

After capturing screenshots:

```bash
# Install ImageMagick (if not already installed)
brew install imagemagick  # macOS
apt install imagemagick   # Linux

# Optimize PNG files
mogrify -strip -quality 85 -resize 800x *.png
```

## File Naming Convention

Use descriptive kebab-case names:
- `query-execution.png`
- `dml-confirmation.png`
- `schema-explorer.png`
- `query-history.png`

## Updating README Links

After adding screenshots, update the README.md image links:

```markdown
![Query Results](docs/images/query-execution.png)
![DML Confirmation](docs/images/dml-confirmation.png)
![Schema Browser](docs/images/schema-explorer.png)
![Query History](docs/images/query-history.png)
```

## Best Practices

- Use consistent browser window size
- Clear browser cache for clean screenshots
- Use sample data that demonstrates features
- Avoid personal or sensitive information
- Use light theme for consistency
- Ensure text is readable
- Include relevant UI elements
- Maintain professional appearance
