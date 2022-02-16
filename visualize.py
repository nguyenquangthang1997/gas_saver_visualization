from plot_services import *

data1 = normalize_data("../tamara_results_final")

time_execution_plot(data1)
number_vulnerability_each_contract(data1)
number_vulnerability_each_type(data1)
number_contract_each_type_mix(data1)

data2 = normalize_data("../top_contracts_final")
time_execution_plot(data2, "top_results")
number_vulnerability_each_contract(data2, "top_results")
number_vulnerability_each_type(data2, "top_results")
number_contract_each_type_mix(data2, "top_results")

number_vulnerability_each_contract_all(data1, data2)
