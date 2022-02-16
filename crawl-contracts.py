import csv
import json
import requests


def to_csv():
    with open("15k_dune_analytics.json", "r") as file:
        dune_analytics_results = json.load(file)
    with open('15k_dune_analytics.csv', 'w') as file:
        writer = csv.writer(file)
        writer.writerow(["Id"] + list(dune_analytics_results[0]['data'].keys()))
        i = 0
        for data in dune_analytics_results:
            data = data['data']
            i += 1
            writer.writerow([i] + list(data.values()))


def get_source_code(start, end, key):
    with open("./list_crawl_address.json", "r") as file:
        c = json.load(file)
    for i in range(start, end):
        print(i)
        try:
            res = requests.get(
                f"https://api.etherscan.io/api?module=contract&action=getsourcecode&address={c[i]}&apikey={key}")
            res = json.loads(res.text)
            if res['result'][0]['SourceCode'] != '':
                with open("./crawl_data/" + str(c[i]) + ".sol", "w") as file:
                    file.write(res['result'][0]['SourceCode'])
        except Exception as e:
            print(e)
            continue

