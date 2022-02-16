import matplotlib.pyplot as plt
import os
import json
import numpy as np

top_data = {}
with open("./15k_dune_analytics.json", "r") as file:
    top_data = json.load(file)
    top_data = {data['data']['to']: data['data']['rank'] for data in top_data}
mapping = {
    "loop-calculation": "RCL",
    "state-data-arrangement ": "STADA",
    "de-morgan-condition ": "ORE",
    "external-function ": "DLFV",
    "immutable-restrict-modification ": "ISV",
    "constant-restrict-modification  ": "CSV",
    "loop-duplication": "LC",
    "struct-data-arrangement ": "MAS"
}


def normalize_data(folder_data):
    files = []
    for r, d, f in os.walk(folder_data):
        for file in f:
            files.append(os.path.join(r, file))
    data = {}

    for i in range(0, len(files)):
        with open(files[i], "r") as file:
            data_ = json.load(file)
            tempData = {"time": data_['time'], "results": []}
            for t in data_['results']:
                if t['type'] != "state-data-arrangement ":
                    tempData['results'].append(t)
            if len(tempData['results']) > 0:
                data[f[i][:-5]] = tempData
    print("Number wasted contract", len(data), "/ all file: 4615")

    contract_number_each_type = {}
    vulnerability_number_each_type = {}
    for (key, _data) in data.items():
        vul_each_contract = {}
        for res in _data['results']:
            vul_each_contract[res['type']] = 1
            if res['type'] not in vulnerability_number_each_type:
                vulnerability_number_each_type[res['type']] = 1
            else:
                vulnerability_number_each_type[res['type']] += 1
        for _type in vul_each_contract.keys():
            if key.lower() not in top_data:
                rank = -1
            else:
                rank = top_data[key.lower()]
            if _type not in contract_number_each_type:
                contract_number_each_type[_type] = [{"address": key, "rank": rank}]
            else:
                contract_number_each_type[_type].append({"address": key, "rank": rank})
        for k in contract_number_each_type.keys():
            contract_number_each_type[k].sort(key=lambda x: x['rank'])
    return data


def normalize_python_data(folder_data):
    files = []
    for r, d, f in os.walk(folder_data):
        for file in f:
            files.append(os.path.join(r, file))
    print("Number wasted contract", len(files), "/ all file: 4615")
    data = {}

    for i in range(0, len(files)):
        with open(files[i], "r") as file:
            data_ = json.load(file)
            data[f[i][:-5]] = data_
    return data


def time_execution_plot(data, data_name="tamara_data"):
    fig, ax = plt.subplots()
    time_execution = [x['time'] for x in data.values()]
    time_execution = sorted(time_execution)
    ax.plot(range(0, len(time_execution)), time_execution)
    ax.set_ylabel('Time (ms)')
    ax.set_title('Time execution')
    plt.savefig(f"./results/time_execution_{data_name}.pdf")


def number_vulnerability_each_contract(data, data_name="tamara_data"):
    fig, ax = plt.subplots()
    ax.plot(
        range(0, len(data.values())),
        sorted([len(a['results']) for a in data.values()])
    )
    ax.set_ylabel('Number Vulnerabilities')
    ax.set_title('Vulnerabilities Each Contract')
    plt.savefig(f"./results/number_vulnerability_each_contract_{data_name}.pdf")


def number_vulnerability_each_contract_all(data1, data2):
    fig, (ax1, ax2) = plt.subplots(nrows=2, ncols=1)
    vulnerability_number_each_type = {}

    plt.savefig(f"./results/number_vulnerability_each_contract_all.pdf")


def number_vulnerability_each_type(data, data_name="tamara_data"):
    vulnerability_number_each_type = {}
    for data_ in data.values():
        for _res in data_['results']:
            if _res['type'] not in vulnerability_number_each_type:
                vulnerability_number_each_type[_res['type']] = 1
            else:
                vulnerability_number_each_type[_res['type']] += 1

    fig2, ax2 = plt.subplots()
    ax2.bar(vulnerability_number_each_type.keys(), vulnerability_number_each_type.values())

    plt.xticks(
        range(len(vulnerability_number_each_type.keys())),
        [mapping[item] for item in vulnerability_number_each_type.keys()]
    )
    ax2.set_ylabel('Number Vulnerabilities')
    ax2.set_xlabel('Vulnerabilities type')
    ax2.set_title('Vulnerabilities Type Distribution')
    for type_ in range(len(vulnerability_number_each_type.keys())):
        plt.annotate(
            str(list(vulnerability_number_each_type.values())[type_]),
            xy=(type_, list(vulnerability_number_each_type.values())[type_]),
            ha='center',
            va='bottom'
        )
    plt.savefig(f"./results/number_vulnerability_each_type_{data_name}.pdf")


def contract_compare_plot(contract_number_each_type, con_each_type):
    barWidth = 0.45
    fig = plt.subplots(figsize=(12, 8))

    # Set position of bar on X axis
    br1 = np.arange(len(contract_number_each_type.keys()))
    br2 = [x + barWidth for x in br1]

    # Make the plot
    plt.bar(br1, [len(contract_number_each_type[key]) for key in contract_number_each_type.keys()], width=barWidth,
            edgecolor='grey', label='Owner')
    plt.bar(br2, [len(con_each_type[key]) for key in contract_number_each_type.keys()], width=barWidth,
            edgecolor='grey', label='Tamara')

    # Adding Xticks
    plt.title('Contracts Comparison')
    # plt.xlabel('AAAA', fontweight='bold', fontsize=15)
    # plt.ylabel('AAAA', fontweight='bold', fontsize=15)
    plt.xticks([r + barWidth / 2 for r in range(len(br2))],
               [mapping[key] for key in contract_number_each_type.keys()])
    for i in range(len(contract_number_each_type.keys())):
        plt.annotate(len(list(contract_number_each_type.values())[i]),
                     xy=(i, len(list(contract_number_each_type.values())[i])), ha='center', va='bottom', size=35)

    for i in range(len(contract_number_each_type.keys())):
        plt.annotate(len(con_each_type[list(contract_number_each_type.keys())[i]]),
                     xy=(i + barWidth, len(con_each_type[list(contract_number_each_type.keys())[i]])), ha='center',
                     va='bottom', size=35)
        plt.legend()
        plt.savefig(f"./results/number_contract_comparison.pdf")


def vulnerability_compare_plot(vulnerability_number_each_type, vul_each_type):
    barWidth = 0.45
    fig = plt.subplots(figsize=(12, 8))

    # Set position of bar on X axis
    br1 = np.arange(len(vulnerability_number_each_type.keys()))
    br2 = [x + barWidth for x in br1]

    # Make the plot
    plt.bar(br1, [vulnerability_number_each_type[key] for key in vulnerability_number_each_type.keys()], width=barWidth,
            edgecolor='grey', label='Owner')
    plt.bar(br2, [vul_each_type[key] for key in vulnerability_number_each_type.keys()], width=barWidth,
            edgecolor='grey', label='Tamara')

    # Adding Xticks
    # plt.title('Vulnerabilities Comparison')
    plt.ylabel('Number vulnerabilities', fontsize=18)
    # plt.ylabel('AAAA', fontweight='bold', fontsize=15)
    plt.xticks([r + barWidth / 2 for r in range(len(br2))],
               [mapping[key] for key in vulnerability_number_each_type.keys()], fontsize=18)
    plt.yticks(fontsize=18)
    for i in range(len(vulnerability_number_each_type.keys())):
        plt.annotate(str(list(vulnerability_number_each_type.values())[i]),
                     xy=(i, list(vulnerability_number_each_type.values())[i]), ha='center', va='bottom', size=18)

    for i in range(len(vulnerability_number_each_type.keys())):
        plt.annotate(str(vul_each_type[list(vulnerability_number_each_type.keys())[i]]),
                     xy=(i + barWidth, vul_each_type[list(vulnerability_number_each_type.keys())[i]]), ha='center',
                     va='bottom', size=18)
    plt.legend(fontsize=18)
    plt.savefig(f"./results/number_vulnerability_comparison.pdf")


def compare_vs_tamara(folder, tamara_folder):
    tamara_data = normalize_python_data(tamara_folder)
    data = normalize_data(folder)
    contract_number_each_type = {}
    vulnerability_number_each_type = {}
    for (key, _data) in data.items():
        vul_each_contract = {}
        for res in _data['results']:
            vul_each_contract[res['type']] = 1
            if res['type'] not in vulnerability_number_each_type:
                vulnerability_number_each_type[res['type']] = 1
            else:
                vulnerability_number_each_type[res['type']] += 1
        for _type in vul_each_contract.keys():
            if _type not in contract_number_each_type:
                contract_number_each_type[_type] = [key]
            else:
                contract_number_each_type[_type].append(key)

    con_each_type = {}
    vul_each_type = {}
    for (key, value) in tamara_data.items():
        for (k, v) in value.items():
            if int(v) > 0:
                if k not in con_each_type:
                    con_each_type[k] = [key]
                else:
                    con_each_type[k].append(key)
                if k not in vul_each_type:
                    vul_each_type[k] = int(v)
                else:
                    vul_each_type[k] += int(v)

    contract_compare_plot(contract_number_each_type, con_each_type)
    vulnerability_compare_plot(vulnerability_number_each_type, vul_each_type)
    tamara_data = {k: v for k, v in sorted(tamara_data.items(), key=lambda item: item[1]['time'])}
    timestampComparisonPlot([data[key]['time'] for key in tamara_data.keys()],
                            [int(tamara_data[key]['time'] * 1000) for key in tamara_data.keys()])


def timestampComparisonPlot(owner, tamara):
    # plot lines
    fig = plt.subplots(figsize=(12, 8))
    plt.plot(range(len(owner)), owner, label="Owner")
    plt.yticks(fontsize=18)
    plt.xticks(fontsize=18)
    plt.ylabel("Time (ms)", fontsize=18)
    plt.plot(range(len(tamara)), tamara, label="Tamara")
    # plt.title('Time Execution Comparison')
    plt.legend(fontsize=18)
    plt.savefig(f"./results/time_comparison.pdf")


def number_contract_each_type_mix(data, data_name="tamara_data"):
    contract_number_each_type = {}
    vulnerability_number_each_type = {}
    for _data in data.values():
        vul_each_contract = {}
        for res in _data['results']:
            vul_each_contract[res['type']] = 1
            if res['type'] not in vulnerability_number_each_type:
                vulnerability_number_each_type[res['type']] = 1
            else:
                vulnerability_number_each_type[res['type']] += 1
        for _type in vul_each_contract.keys():
            if _type not in contract_number_each_type:
                contract_number_each_type[_type] = 1
            else:
                contract_number_each_type[_type] += 1

    keys = ['struct-data-arrangement ', 'external-function ', 'constant-restrict-modification  ',
            'immutable-restrict-modification ', 'de-morgan-condition ', 'loop-calculation', 'loop-duplication']
    if 'immutable-restrict-modification ' not in contract_number_each_type:
        keys = ['struct-data-arrangement ', 'external-function ', 'constant-restrict-modification  ',
                'de-morgan-condition ', 'loop-calculation', 'loop-duplication']
    barWidth = 0.48
    fig = plt.subplots(figsize=(18, 10))

    # Set position of bar on X axis
    br1 = np.arange(len(contract_number_each_type.keys()))
    br2 = [x + barWidth for x in br1]

    # Make the plot
    plt.bar(br1, [contract_number_each_type[key] for key in keys], width=barWidth,
            edgecolor='grey', label='Number contracts')
    plt.bar(br2, [vulnerability_number_each_type[key] for key in keys], width=barWidth,
            edgecolor='grey', label='Number Vulnerability')

    # Adding Xticks
    # plt.title('Vulnerabilities vs Contracts relation', fontsize=18)
    # plt.xlabel('AAAA', fontweight='bold', fontsize=15)
    # plt.ylabel('AAAA', fontweight='bold', fontsize=15)
    plt.xticks([r + barWidth / 2 for r in range(len(br2))],
               [mapping[key] for key in keys], fontsize=18)
    plt.yticks(fontsize=18)
    for i in range(len(contract_number_each_type.keys())):
        plt.annotate(str(contract_number_each_type[keys[i]]),
                     xy=(i, contract_number_each_type[keys[i]]), ha='center', va='bottom', size=18)

    for i in range(len(vulnerability_number_each_type.keys())):
        plt.annotate(str(vulnerability_number_each_type[keys[i]]),
                     xy=(i + barWidth, vulnerability_number_each_type[keys[i]]), ha='center', va='bottom',
                     size=18)
    plt.legend(fontsize=18)
    plt.savefig(f"./results/number_vulnerability_vs_number_contract_{data_name}.pdf")
