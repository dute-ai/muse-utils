#!/usr/bin/env python3
"""Generate a FAKE tax-return-like PDF with planted PII for testing.
All values are invented test fixtures, not real data."""
import pymupdf

doc = pymupdf.open()
p1 = doc.new_page()
lines = [
    "Form 1040        U.S. Individual Income Tax Return        2025",
    "",
    "Your first name and last name:  John Q Taxpayer",
    "Your social security number:  123-45-6789",
    "Spouse's social security number:  234-56-7890",
    "",
    "1a  Total amount from Form W-2, box 1 .......... 287,450",
    "9   Total income .............................. 312,908",
    "24  Total other taxes ......................... 61,203",
    "",
    "Refund direct deposit:",
    "Routing number: 021000021",
    "Account number: 123456789012",
    "",
    "Payment voucher reference (not a routing number): 123456789",
    "Credit card on file: 4111-1111-1111-1111",
    "Phone: (650) 555-0142     Email: fake.taxpayer@example.com",
    "Home address: 123 Main Street, Palo Alto, CA 94301",
]
y = 72
for ln in lines:
    p1.insert_text((72, y), ln, fontsize=11)
    y += 22

p2 = doc.new_page()
lines2 = [
    "Schedule E (Form 1040)   Supplemental Income and Loss     2025",
    "Name(s) shown on return:  John Q Taxpayer",
    "Your social security number:  123-45-6789",
    "",
    "Partnership: Somerset LIX   Rental real estate income:  4,215",
    "Passive activity loss allowed:  (18,340)",
]
y = 72
for ln in lines2:
    p2.insert_text((72, y), ln, fontsize=11)
    y += 22

doc.set_metadata({"title": "2025 Tax Return", "author": "TurboTax",
                  "creator": "test-fixture"})
doc.save("sample_return.pdf")
print("wrote sample_return.pdf")
