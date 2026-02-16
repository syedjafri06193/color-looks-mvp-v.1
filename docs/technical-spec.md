# Technical Specification

Product: color-looks-mvp-v.1  
Company: client of AXIOMS  

Architecture:
- C++17 core
- OCIO v2 color management
- Metal GPU backend
- OFX-compatible design

Processing:
Input → OCIO → Scene Linear → Look Graph → OCIO → Output
