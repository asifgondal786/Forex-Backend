#!/usr/bin/env python3
"""
Generates a comprehensive PDF documentation of the entire Tajir project
"""

import os
import sys
from datetime import datetime
from reportlab.lib.pagesizes import letter, A4
from reportlab.lib.styles import getSampleStyleSheet, ParagraphStyle
from reportlab.lib.units import inch
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer, PageBreak, Table, TableStyle, Image, Preformatted
from reportlab.lib import colors
from reportlab.lib.enums import TA_CENTER, TA_LEFT, TA_JUSTIFY
from pathlib import Path

def get_project_structure(root_path, max_depth=3, current_depth=0):
    """Generate a text representation of project structure"""
    if current_depth >= max_depth:
        return ""
    
    items = []
    try:
        entries = sorted(os.listdir(root_path))
        for entry in entries:
            if entry.startswith('.'):
                continue
            if entry in ['__pycache__', '.venv', 'node_modules', '.pytest_cache', 'build', 'dist', '.firebase']:
                continue
            
            full_path = os.path.join(root_path, entry)
            indent = "  " * current_depth
            
            if os.path.isdir(full_path):
                items.append(f"{indent}📁 {entry}/")
                items.append(get_project_structure(full_path, max_depth, current_depth + 1))
            else:
                items.append(f"{indent}📄 {entry}")
    except PermissionError:
        pass
    
    return "\n".join(filter(None, items))

def read_file_safely(filepath, max_lines=100):
    """Safely read file content with line limit"""
    try:
        with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
            lines = f.readlines()[:max_lines]
            return ''.join(lines)
    except Exception as e:
        return f"Error reading file: {str(e)}"

def get_key_files_content(root_path):
    """Extract content from key configuration and documentation files"""
    files_to_include = {
        'README files': ['Backend/READ.md', 'Frontend/README.md', 'README.md'],
        'Configuration': ['package.json', 'firebase.json', 'Backend/requirements.txt', 'Frontend/pubspec.yaml'],
        '.env-like': ['Backend/.env']
    }
    
    content = {}
    for category, files in files_to_include.items():
        category_content = {}
        for file_pattern in files:
            filepath = os.path.join(root_path, file_pattern)
            if os.path.exists(filepath):
                category_content[file_pattern] = read_file_safely(filepath, max_lines=50)
        if category_content:
            content[category] = category_content
    
    return content

def get_python_modules(root_path):
    """Extract info about Python modules"""
    modules = {}
    backend_path = os.path.join(root_path, 'Backend', 'app')
    
    for item in os.listdir(backend_path):
        item_path = os.path.join(backend_path, item)
        if os.path.isdir(item_path) and not item.startswith('_'):
            init_file = os.path.join(item_path, '__init__.py')
            if os.path.exists(init_file):
                py_files = [f for f in os.listdir(item_path) if f.endswith('.py') and f != '__init__.py']
                modules[item] = py_files
    
    return modules

def create_project_pdf(output_path):
    """Create comprehensive PDF documentation"""
    
    root_path = os.path.dirname(os.path.abspath(__file__))
    
    # Create PDF document
    doc = SimpleDocTemplate(
        output_path,
        pagesize=A4,
        rightMargin=0.75*inch,
        leftMargin=0.75*inch,
        topMargin=0.75*inch,
        bottomMargin=0.75*inch
    )
    
    # Container for PDF elements
    elements = []
    
    # Define styles
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle(
        'CustomTitle',
        parent=styles['Heading1'],
        fontSize=28,
        textColor=colors.HexColor('#1f4788'),
        spaceAfter=30,
        alignment=TA_CENTER,
        fontName='Helvetica-Bold'
    )
    
    heading_style = ParagraphStyle(
        'CustomHeading',
        parent=styles['Heading2'],
        fontSize=16,
        textColor=colors.HexColor('#2e5c8a'),
        spaceAfter=12,
        spaceBefore=12,
        fontName='Helvetica-Bold'
    )
    
    subheading_style = ParagraphStyle(
        'CustomSubHeading',
        parent=styles['Heading3'],
        fontSize=12,
        textColor=colors.HexColor('#3a6fa8'),
        spaceAfter=10,
        fontName='Helvetica-Bold'
    )
    
    body_style = ParagraphStyle(
        'CustomBody',
        parent=styles['BodyText'],
        fontSize=10,
        alignment=TA_JUSTIFY,
        spaceAfter=8
    )
    
    # Title Page
    elements.append(Spacer(1, 1.5*inch))
    elements.append(Paragraph("TAJIR PROJECT", title_style))
    elements.append(Paragraph("Complete Project Documentation", styles['Heading2']))
    elements.append(Spacer(1, 0.3*inch))
    elements.append(Paragraph(f"Generated on: {datetime.now().strftime('%B %d, %Y at %H:%M')}", styles['Normal']))
    elements.append(PageBreak())
    
    # Table of Contents
    elements.append(Paragraph("Table of Contents", heading_style))
    toc_items = [
        "1. Project Overview",
        "2. Project Structure",
        "3. Backend Architecture",
        "4. Frontend Architecture",
        "5. Configuration Files",
        "6. Key Modules & Services",
        "7. Setup Instructions",
        "8. Requirements & Dependencies"
    ]
    for item in toc_items:
        elements.append(Paragraph(item, body_style))
        elements.append(Spacer(1, 0.1*inch))
    
    elements.append(PageBreak())
    
    # 1. Project Overview
    elements.append(Paragraph("1. Project Overview", heading_style))
    elements.append(Paragraph(
        "TAJIR is a comprehensive trading and financial analysis platform with both backend and frontend components. "
        "It provides real-time data processing, AI-driven analysis, and WebSocket-based live updates for trading decisions.",
        body_style
    ))
    elements.append(Spacer(1, 0.2*inch))
    
    # Key Features
    elements.append(Paragraph("Key Features:", subheading_style))
    features = [
        "🔄 Real-time WebSocket data streaming",
        "🤖 AI-powered market analysis",
        "💹 Forex data integration",
        "📊 Technical analysis with pandas-ta",
        "🔔 Live notification system",
        "📱 Cross-platform Flutter frontend",
        "🛡️ Secure user authentication"
    ]
    for feature in features:
        elements.append(Paragraph(feature, body_style))
        elements.append(Spacer(1, 0.05*inch))
    
    elements.append(PageBreak())
    
    # 2. Project Structure
    elements.append(Paragraph("2. Project Structure", heading_style))
    structure_text = get_project_structure(root_path, max_depth=4)
    elements.append(Preformatted(structure_text, styles['Normal']))
    elements.append(PageBreak())
    
    # 3. Backend Architecture
    elements.append(Paragraph("3. Backend Architecture", heading_style))
    elements.append(Paragraph(
        "The backend is built with Flask and provides RESTful APIs, WebSocket connections, and real-time data processing capabilities.",
        body_style
    ))
    elements.append(Spacer(1, 0.1*inch))
    
    # Backend modules
    elements.append(Paragraph("Backend Modules:", subheading_style))
    try:
        modules = get_python_modules(root_path)
        for module_name, files in modules.items():
            module_text = f"<b>{module_name}:</b> {', '.join(files[:5])}"
            if len(files) > 5:
                module_text += f" ... and {len(files)-5} more"
            elements.append(Paragraph(module_text, body_style))
    except:
        elements.append(Paragraph("Backend modules information", body_style))
    
    elements.append(PageBreak())
    
    # 4. Frontend Architecture
    elements.append(Paragraph("4. Frontend Architecture", heading_style))
    elements.append(Paragraph(
        "The frontend is a cross-platform Flutter application providing intuitive UI for market analysis and trading operations.",
        body_style
    ))
    elements.append(Spacer(1, 0.1*inch))
    elements.append(Paragraph("Supported Platforms: iOS, Android, Web, Windows, macOS, Linux", body_style))
    
    elements.append(PageBreak())
    
    # 5. Configuration Files
    elements.append(Paragraph("5. Configuration Files", heading_style))
    
    try:
        config_content = get_key_files_content(root_path)
        for category, files in config_content.items():
            elements.append(Paragraph(category, subheading_style))
            for filename, content in files.items():
                elements.append(Paragraph(f"File: {filename}", ParagraphStyle('FileLabel', parent=styles['Normal'], fontSize=9, textColor=colors.grey)))
                preview = content[:500] + "..." if len(content) > 500 else content
                elements.append(Preformatted(preview, styles['Normal']))
                elements.append(Spacer(1, 0.1*inch))
    except Exception as e:
        elements.append(Paragraph(f"Error reading configuration files: {str(e)}", body_style))
    
    elements.append(PageBreak())
    
    # 6. Key Services
    elements.append(Paragraph("6. Key Services & Components", heading_style))
    
    services = {
        "WebSocket Manager": "Manages real-time WebSocket connections and message broadcasting",
        "Forex Data Service": "Fetches and processes live forex market data",
        "AI Analysis Service": "Performs AI-driven market analysis and predictions",
        "ML Processor": "Handles machine learning model processing and inference",
        "Trading Bot Service": "Automates trading decisions and order execution",
        "Notification Service": "Sends real-time alerts and notifications to users",
        "Connection Manager": "Manages database and service connections"
    }
    
    for service_name, description in services.items():
        elements.append(Paragraph(f"• <b>{service_name}:</b> {description}", body_style))
        elements.append(Spacer(1, 0.08*inch))
    
    elements.append(PageBreak())
    
    # 7. Setup Instructions
    elements.append(Paragraph("7. Setup & Installation", heading_style))
    
    elements.append(Paragraph("Backend Setup:", subheading_style))
    backend_steps = [
        '1. Navigate to Backend directory: <font color="blue"><b>cd Backend</b></font>',
        '2. Create virtual environment: <font color="blue"><b>python -m venv .venv</b></font>',
        '3. Activate virtual environment: <font color="blue"><b>.venv\\Scripts\\activate</b></font>',
        '4. Install dependencies: <font color="blue"><b>pip install -r requirements.txt</b></font>',
        "5. Configure .env file with necessary API keys and settings",
        '6. Run the application: <font color="blue"><b>python run.py</b></font>'
    ]
    for step in backend_steps:
        elements.append(Paragraph(step, body_style))
        elements.append(Spacer(1, 0.08*inch))
    
    elements.append(Spacer(1, 0.2*inch))
    
    elements.append(Paragraph("Frontend Setup:", subheading_style))
    frontend_steps = [
        '1. Navigate to Frontend directory: <font color="blue"><b>cd Frontend</b></font>',
        '2. Install dependencies: <font color="blue"><b>flutter pub get</b></font>',
        "3. Configure API endpoints in the app configuration",
        '4. Run on desired platform: <font color="blue"><b>flutter run -d [device]</b></font>'
    ]
    for step in frontend_steps:
        elements.append(Paragraph(step, body_style))
        elements.append(Spacer(1, 0.08*inch))
    
    elements.append(PageBreak())
    
    # 8. Requirements & Dependencies
    elements.append(Paragraph("8. Requirements & Dependencies", heading_style))
    
    elements.append(Paragraph("Python Packages (Backend):", subheading_style))
    try:
        req_path = os.path.join(root_path, 'Backend', 'requirements.txt')
        if os.path.exists(req_path):
            requirements = read_file_safely(req_path, max_lines=50)
            elements.append(Preformatted(requirements, styles['Normal']))
    except:
        elements.append(Paragraph("Requirements could not be loaded", body_style))
    
    elements.append(Spacer(1, 0.2*inch))
    
    elements.append(Paragraph("Flutter Packages (Frontend):", subheading_style))
    try:
        pubspec_path = os.path.join(root_path, 'Frontend', 'pubspec.yaml')
        if os.path.exists(pubspec_path):
            pubspec = read_file_safely(pubspec_path, max_lines=50)
            elements.append(Preformatted(pubspec, styles['Normal']))
    except:
        elements.append(Paragraph("Pubspec could not be loaded", body_style))
    
    elements.append(PageBreak())
    
    # Summary
    elements.append(Paragraph("Project Summary", heading_style))
    elements.append(Paragraph(
        "TAJIR is a sophisticated trading platform combining real-time data processing, AI analysis, "
        "and user-friendly interfaces. The architecture supports scalability and real-time updates through "
        "WebSocket connections, while the multi-platform frontend ensures accessibility across all major platforms.",
        body_style
    ))
    elements.append(Spacer(1, 0.2*inch))
    elements.append(Paragraph(
        f"<b>Documentation Generated:</b> {datetime.now().strftime('%B %d, %Y at %H:%M:%S')}",
        body_style
    ))
    
    # Build PDF
    try:
        doc.build(elements)
        return True
    except Exception as e:
        print(f"Error building PDF: {str(e)}")
        return False

if __name__ == "__main__":
    output_file = os.path.join(os.path.dirname(__file__), "Tajir_Project_Documentation.pdf")
    print(f"Generating PDF: {output_file}")
    
    if create_project_pdf(output_file):
        print(f"✅ PDF successfully created: {output_file}")
        print(f"📄 File size: {os.path.getsize(output_file) / (1024*1024):.2f} MB")
    else:
        print("❌ Error creating PDF")
        sys.exit(1)
