# -*- coding: utf-8 -*-

import os
import sys
import time
import csv
import json
import httplib2
from lxml import etree

RECORD_URL = "http://npl.ly.gov.tw/do/www/lawRecord?pageNo={page}&pagingSize=100"
STATISTICS_URL = "http://npl.ly.gov.tw/do/www/lawStatistics?"

CSV_STATISTICS_ORDER = ["DATE", "BILLS TITLE", "TYPE", "APPOINTED DATES & SESSIONS", "SITTINGS", "TOTAL CONTENT URL", "PROMULGATE LAWS PDF URL", "BILLS URL"]
CSV_STATISTICS_TYPE = ['法律案', '其他', '預決算案', '廢止案', '本院內規']
CSV_RECORD_ORDER = ["APPOINTED DATES & SESSIONS", "DATE", "TYPE", "SITTINGS CONTENT", "RESOLUTION/RESULT"]


def parse_statistics(cont):
    # http://npl.ly.gov.tw/do/www/lawStatistics
    
    root = etree.HTML(cont)
    table = root.xpath("//table[@style='width:550' and @align='center']")
    appoint = list(map(lambda x: x.text.strip("\t\r\n "), root.xpath("//a[@name and starts-with(@name, '0')]")))

    results = []
    for index, t in enumerate(table):
        for r in t.xpath("tr")[1:]:
            if len(list(r.iter())) <= 4: continue
            s = list(filter(lambda x: x, map(lambda x: x.replace("", "").replace("\t", "").replace("\r", "").replace("\n", "").replace("\xa0", ""),
                                             list(r.itertext()))))
            
            item = list(r.iter())
            try:
                if item[5].values()[0].startswith("http://"):
                    html_url = item[5].values()[0]
                else:
                    html_url = ""
            except:
                html_url = ""
                
            try:
                if item[9].values()[0].startswith("http://"):
                    pdf_url = item[9].values()[0]
                else:
                    pdf_url = ""
            except:
                pdf_url = ""
                
            try:
                if item[3].values()[0].startswith("http://"):
                    extend_url = item[3].values()[0]
                else:
                   extend_url = ""
            except:
                extend_url = ""
                
            
            result = {'DATE': s[0], 'TOTAL CONTENT URL': html_url,
                      'PROMULGATE LAWS PDF URL': pdf_url, 'BILLS URL': extend_url,
                      'APPOINTED DATES & SESSIONS': appoint[index],
                      'SITTINGS': s[-1]}
            
            for index, i in enumerate(s[1:-1]):
                if i in CSV_STATISTICS_TYPE:
                    result['BILLS TITLE'] = "".join(s[1: index + 1])
                    result['TYPE'] = s[index + 1]
                    break

            results.append(result)
    
    return results


def update_record(json_path, output_path):
    """update_record(json_path, output_path)
    
    json_path: ../ly-law-record/ly-law-record.json
    output_path: ../ly-law-record/ly-law-record (DON'T put on file type)
    """
    
    fi = open(json_path).read()
    d = json.loads(fi)
    
    update = parse_record(page=1, cache=False)
    for i in update:
        if i not in d:
            d.append(i)
            
            
    to_json(d, output_path + ".json")
    to_csv(d, CSV_RECORD_ORDER, output_path + ".csv")


def parse_record(page=1, cache=True):
    h = httplib2.Http(".cache")
    
    if cache:
        resp, cont = h.request(RECORD_URL.format(page=page),
                          headers={'pragma': 'cache', 'cache-control': 'min-fresh=%s' % -(sys.maxsize >> 1)})
    else:
        resp, cont = h.request(RECORD_URL.format(page=page))
    
    #cont = open("html/record.htm").read()
    root = etree.HTML(cont.decode('utf-8'))
    table = root.xpath("//table[@cellspacing='1' and @cellpadding='3']")
    
    result = []
    for t in table:
        s = list(filter(lambda x: x, map(lambda x: x.strip("\r\n ").replace("\n", ""), list(t.itertext()))))
        s[0] = s[0].split(". ")[-1]
        while len(s) < 8:
            s.append("")
                        
        s = {"DATE": s[0], "APPOINTED DATES & SESSIONS": s[1], "TYPE": s[3],
             "SITTINGS CONTENT": s[5], "RESOLUTION/RESULT": s[7]}
        
        result.append(s)
        
    return result


def to_csv(d, order, output_path):
    with open(output_path, "w", newline="") as dst:
        cv = csv.writer(dst, quoting=csv.QUOTE_ALL)
        cv.writerow(order)
        for r in d:
            out_r = [r[i] for i in order]
            cv.writerow(out_r)


def to_json(d, output_path):
    open(output_path, "w").write(json.dumps(d, ensure_ascii=False, sort_keys=True, indent=4))
    

def init_statistics(path):
    """init statistics
    
    path: ../ly-statistics/ly-statistics (DON'T put on file type, automatic generate json and csv)
    """
    
    #cont = open("html/py.htm").read()
    #cont = open('html/statistics.htm').read()
    h = httplib2.Http(".cache")
    resp, cont = h.request(STATISTICS_URL, headers={'cache-control': 'min-fresh=%s' % -(sys.maxsize >> 1)})

    d = parse_statistics(cont)
    to_json(d, path + ".json")
    to_csv(d, CSV_STATISTICS_ORDER, path + ".csv")


def init_record(path, verbose=False):
    """init statistics
    
    path: ../ly-law-record/ly-law-record (DON'T put on file type, automatic generate json and csv)
    verbose: print verbose message (processing page)
    """
    
    d = []
    for p in range(1, 144):
        if verbose: print(p)
        
        v = parse_record(page=p)
        for r in v:
            d.append(r)
            
    #to_csv(d, CSV_RECORD_ORDER, path)
    to_json(d, path + ".json")
    to_csv(d, CSV_RECORD_ORDER, path + ".csv")


if __name__ == '__main__':
    init_statistics('../ly-statistics/ly-statistics')
    update_record('../ly-law-record/ly-law-record.json', '../ly-law-record/ly-law-record')