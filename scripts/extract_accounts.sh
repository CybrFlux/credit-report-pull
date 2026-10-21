#!/bin/bash
# Print the key facts from the credit report loaded in the local Chrome browser, for writing the summary.
# Reads the page text directly; writes nothing to disk.
set -euo pipefail
source "$(dirname "$0")/lib.sh"

echo "document.body.innerText" | brw eval 2>/dev/null | python3 -I -c "
import json,sys,re
t=sys.stdin.read()
if not t.strip():
    sys.exit('ERROR: browser has no page - sign in and load the report again')
if 'Total Accounts:' not in t:
    sys.exit('ERROR: the open tab is not a loaded credit report - run load_report.sh first')

def section(start,end):
    m=re.search(re.escape(start)+r'(.*?)'+re.escape(end),t,re.S)
    return m.group(1).strip() if m else '(not found)'

print('== SCORES & RISK FACTORS ==')
print(section('Credit Score:','The score(s)'))
print()
print('== SUMMARY ==')
print(section('Total Accounts:','Account History').replace('Back to Top',''))
print()
print('== INQUIRIES ==')
print(section('Date of inquiry\tCredit Bureau','Public Information').replace('Back to Top',''))
print()
print('== PUBLIC RECORDS ==')
print(section('Public records typically remain on your Credit Report for 7 - 10 years.','Creditor Contacts').replace('Back to Top',''))
print()
print('== ACCOUNTS (first bureau value shown) ==')
print('creditor|type|status|opened|balance|limit|high credit|payment status|past due|late marks|bureaus')
blocks=re.split(r'\n(?=[A-Z0-9][A-Z0-9 &./-]{2,40}\n\tTransUnion\tExperian\tEquifax\nAccount #:)',t)
for b in blocks[1:]:
    def row(k):
        m=re.search(r'\n'+re.escape(k)+r'\t([^\n]*)',b)
        return [x.strip() for x in m.group(1).split('\t')] if m else []
    first=lambda a:next((x for x in a if x and x!='-'),'')
    acct=row('Account #:')
    bureaus=''.join(n for n,x in zip('TXE',acct+['','','']) if x)
    h=re.search(r'TransUnion\t([^\n]*)\nExperian\t([^\n]*)\nEquifax\t([^\n]*)',b)
    bad=sorted(set(re.findall(r'\b(30|60|90|120|150|180|CO|C/O|FC|RF|RP|V)\b',' '.join(h.groups())))) if h else []
    print('|'.join([b.split(chr(10))[0],first(row('Account Type - Detail:')),first(row('Account Status:')),
        first(row('Date Opened:')),first(row('Balance:')),first(row('Credit Limit:')),first(row('High Credit:')),
        first(row('Payment Status:')),first(row('Past Due:')),','.join(bad) or '-',bureaus]))
"
