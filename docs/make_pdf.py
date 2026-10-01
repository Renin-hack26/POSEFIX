from fpdf import FPDF
import re

with open('RELEASE_v1.1.11.md', 'r', encoding='utf-8') as f:
    md = f.read()

# Replace special chars that latin-1 can't handle
replacements = {
    '\u2014': '--',   # em dash
    '\u2013': '-',    # en dash
    '\u2018': "'",    # left single quote
    '\u2019': "'",    # right single quote
    '\u201c': '"',    # left double quote
    '\u201d': '"',    # right double quote
    '\u2026': '...',  # ellipsis
    '\u2022': '*',    # bullet
    '\u2192': '->',   # right arrow
    '\u2705': '[OK]', # checkmark
    '\u274c': '[X]',  # cross mark
    '\U0001f3af': '[TARGET]', # dart target
    '\U0001f527': '[TOOLS]',  # wrench
}
for k, v in replacements.items():
    md = md.replace(k, v)
# Strip any remaining non-latin1 chars
md = re.sub(r'[^\x00-\xff]', '', md)

pdf = FPDF()
pdf.add_page()
pdf.set_auto_page_break(auto=True, margin=20)
pdf.set_font('Helvetica', '', 10)

lines = md.split('\n')
in_code = False
code_lines = []

for line in lines:
    if line.startswith('```'):
        if not in_code:
            in_code = True
            code_lines = []
        else:
            in_code = False
            pdf.set_font('Courier', '', 8)
            pdf.set_fill_color(240, 240, 240)
            for cl in code_lines:
                pdf.multi_cell(0, 4, cl, fill=True)
            pdf.ln(3)
            pdf.set_font('Helvetica', '', 10)
        continue
    if in_code:
        code_lines.append(line)
        continue

    if line.startswith('# '):
        pdf.set_font('Helvetica', 'B', 16)
        pdf.cell(0, 10, line[2:], new_x='LMARGIN', new_y='NEXT')
        pdf.set_font('Helvetica', '', 10)
        pdf.ln(2)
    elif line.startswith('## '):
        pdf.set_font('Helvetica', 'B', 13)
        pdf.cell(0, 8, line[3:], new_x='LMARGIN', new_y='NEXT')
        pdf.set_font('Helvetica', '', 10)
        pdf.ln(1)
    elif line.startswith('### '):
        pdf.set_font('Helvetica', 'B', 11)
        pdf.cell(0, 7, line[4:], new_x='LMARGIN', new_y='NEXT')
        pdf.set_font('Helvetica', '', 10)
        pdf.ln(1)
    elif '|' in line and '---' not in line and line.strip().startswith('|'):
        cells = [c.strip() for c in line.split('|')[1:-1]]
        if cells:
            col_w = 190 / max(len(cells), 1)
            pdf.set_font('Helvetica', 'B', 8)
            for c in cells:
                try:
                    pdf.cell(col_w, 5, c[:30], border=1)
                except:
                    pass
            pdf.ln()
    else:
        line = re.sub(r'\*\*(.+?)\*\*', r'\1', line)
        line = re.sub(r'\*(.+?)\*', r'\1', line)
        line = re.sub(r'`(.+?)`', r'\1', line)
        if line.strip() == '':
            pdf.ln(3)
        elif line.strip().startswith('- '):
            pdf.set_x(pdf.l_margin)
            pdf.multi_cell(0, 5, '  - ' + line[2:])
        else:
            try:
                pdf.set_x(pdf.l_margin)
                pdf.multi_cell(0, 5, line)
            except:
                pass

pdf.output('RELEASE_v1.1.11.pdf')
print('PDF created via fpdf2')